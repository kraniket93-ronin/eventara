-- ============================================================================
-- 0025_auth_onboarding.sql
-- Production-grade sign-up and onboarding.
--
-- The audit that prompted this found the registration flow was not partially
-- wired - it was entirely absent. Both forms on signin.html called
-- Auth.login(), which only writes a localStorage object, then redirected. No
-- sb.auth.signUp() call existed anywhere in the codebase, so a "registered"
-- user had no auth.users row and could not sign in on their next visit.
--
-- Three server-side gaps had to close before the front end could be fixed:
--
--   1. handle_new_user() had a customer branch only. A supplier signing up
--      got profiles + user_preferences and nothing else - no suppliers row -
--      so every supplier dashboard call, which resolves through
--      mySupplierId(), would have failed with "no supplier owned by this
--      account". The whole portal would have been dead on arrival.
--
--   2. suppliers.status defaults to 'active', and v_supplier_public filters
--      on exactly that. A brand-new supplier with an empty profile and no
--      photos would have appeared in public search the instant they
--      registered. New signups now start 'draft' and go live through
--      publish_supplier(), which refuses until the listing is presentable.
--
--   3. Nothing tracked how far through onboarding anyone was, so the
--      "complete your profile" experience had nothing to measure.
--
-- verify_status gained 'under_review' (applied separately - Postgres will not
-- let a new enum value be added and used in the same transaction).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Onboarding progress - one row per profile
-- ---------------------------------------------------------------------------
create table if not exists onboarding_progress (
  profile_id      uuid primary key references profiles(id) on delete cascade,
  role            user_role not null,
  email_verified  boolean not null default false,
  profile_started boolean not null default false,
  profile_done    boolean not null default false,
  media_uploaded  boolean not null default false,
  submitted_for_review boolean not null default false,
  completed_at    timestamptz,
  dismissed       boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_onboarding_role on onboarding_progress(role);

alter table onboarding_progress enable row level security;

drop policy if exists onboarding_self on onboarding_progress;
create policy onboarding_self on onboarding_progress for select
  using (public.is_admin() or profile_id = auth.uid());
drop policy if exists onboarding_self_write on onboarding_progress;
create policy onboarding_self_write on onboarding_progress for update
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
drop policy if exists onboarding_self_insert on onboarding_progress;
create policy onboarding_self_insert on onboarding_progress for insert
  with check (profile_id = auth.uid() or public.is_admin());

drop trigger if exists trg_updated_onboarding on onboarding_progress;
create trigger trg_updated_onboarding before update on onboarding_progress
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. handle_new_user - now provisions BOTH roles completely
--
-- Runs inside Supabase's auth transaction. If any part of it raises, the
-- whole signup is rolled back and the user sees an opaque "Database error
-- saving new user". Each side-effect block is therefore wrapped so that a
-- failure to create an optional row can never cost the user their account -
-- the profile and role always land, the rest is best-effort and repairable
-- by ensure_account_records() below.
-- ---------------------------------------------------------------------------
-- 'draft' has to be a legal status before the trigger can use it.
-- suppliers_status_check originally allowed active/paused/delisted only, so
-- the first version of this migration silently produced supplier accounts
-- with no business record - the exception block below swallowed the check
-- violation. That block now RAISE WARNINGs so the same class of failure is
-- visible in the Postgres log instead of being invisible.
alter table suppliers drop constraint if exists suppliers_status_check;
alter table suppliers add constraint suppliers_status_check
  check (status = any (array['draft'::text,'active'::text,'paused'::text,'delisted'::text]));

comment on column suppliers.status is
  'draft = registered but not yet published (hidden from v_supplier_public); '
  'active = live in search; paused = temporarily hidden by the supplier; '
  'delisted = removed by Eventara Ops.';

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_role   user_role;
  v_name   text;
  v_sup    uuid;
  v_cat    supplier_category;
  v_err    text;
begin
  v_role := coalesce((new.raw_user_meta_data->>'role')::user_role, 'customer');
  v_name := nullif(btrim(coalesce(new.raw_user_meta_data->>'full_name', '')), '');

  insert into profiles (id, role, full_name, email, phone)
    values (new.id, v_role, coalesce(v_name, split_part(new.email, '@', 1)), new.email,
            nullif(btrim(coalesce(new.raw_user_meta_data->>'phone', '')), ''))
    on conflict (id) do nothing;

  insert into user_preferences (profile_id) values (new.id) on conflict do nothing;

  insert into onboarding_progress (profile_id, role, email_verified)
    values (new.id, v_role, new.email_confirmed_at is not null)
    on conflict (profile_id) do nothing;

  if v_role = 'customer' then
    begin
      insert into customer_profiles (profile_id, org_name, industry, billing_address)
        values (new.id,
                coalesce(nullif(btrim(coalesce(new.raw_user_meta_data->>'org_name','')),''), v_name),
                nullif(btrim(coalesce(new.raw_user_meta_data->>'industry','')),''),
                nullif(btrim(coalesce(new.raw_user_meta_data->>'billing_address','')),''))
        on conflict (profile_id) do nothing;
    exception when others then
      get stacked diagnostics v_err = message_text;
      raise warning 'handle_new_user: customer provisioning failed for % : %', new.id, v_err;
    end;

  elsif v_role = 'supplier' then
    begin
      v_cat := coalesce((new.raw_user_meta_data->>'category')::supplier_category, 'banquet_hotel');

      -- 'draft', not the column default of 'active': an empty listing must
      -- not surface in public search the moment someone registers.
      insert into suppliers (owner, business_name, category, city, status, verified)
        values (new.id,
                coalesce(nullif(btrim(coalesce(new.raw_user_meta_data->>'business_name','')),''),
                         coalesce(v_name, 'New supplier')),
                v_cat,
                coalesce(nullif(btrim(coalesce(new.raw_user_meta_data->>'city','')),''), 'Udaipur'),
                'draft', false)
        returning id into v_sup;

      insert into supplier_profiles (supplier_id, contact_person, contact_email, contact_phone,
                                     availability_default, auto_response)
        values (v_sup, v_name, new.email,
                nullif(btrim(coalesce(new.raw_user_meta_data->>'phone','')),''), true, true)
        on conflict (supplier_id) do nothing;

      insert into kyc_verification (supplier_id, gstin, status)
        values (v_sup, nullif(btrim(coalesce(new.raw_user_meta_data->>'gstin','')),''), 'pending')
        on conflict (supplier_id) do nothing;
    exception when others then
      get stacked diagnostics v_err = message_text;
      raise warning 'handle_new_user: supplier provisioning failed for % : %', new.id, v_err;
    end;
  end if;

  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 3. ensure_account_records - self-healing safety net
--
-- Called by the client right after sign-in. If any provisioning row is
-- missing - because handle_new_user's best-effort block swallowed an error,
-- or because the account predates this migration - it is created now. Makes
-- the dashboards resilient to a partially provisioned account instead of
-- showing "no supplier owned by this account" forever.
-- ---------------------------------------------------------------------------
create or replace function public.ensure_account_records()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id uuid := auth.uid();
  v_role user_role;
  v_email text;
  v_name text;
  v_sup uuid;
  v_created text[] := '{}';
begin
  if v_id is null then raise exception 'not signed in'; end if;

  select role, email, full_name into v_role, v_email, v_name from profiles where id = v_id;
  if v_role is null then return jsonb_build_object('error', 'no profile'); end if;

  if not exists (select 1 from user_preferences where profile_id = v_id) then
    insert into user_preferences (profile_id) values (v_id);
    v_created := v_created || 'user_preferences';
  end if;

  if not exists (select 1 from onboarding_progress where profile_id = v_id) then
    insert into onboarding_progress (profile_id, role) values (v_id, v_role);
    v_created := v_created || 'onboarding_progress';
  end if;

  if v_role = 'customer' and not exists (select 1 from customer_profiles where profile_id = v_id) then
    insert into customer_profiles (profile_id, org_name) values (v_id, v_name);
    v_created := v_created || 'customer_profiles';
  end if;

  if v_role = 'supplier' then
    select id into v_sup from suppliers where owner = v_id;
    if v_sup is null then
      insert into suppliers (owner, business_name, category, city, status, verified)
        values (v_id, coalesce(v_name, 'New supplier'), 'banquet_hotel', 'Udaipur', 'draft', false)
        returning id into v_sup;
      v_created := v_created || 'suppliers';
    end if;
    if not exists (select 1 from supplier_profiles where supplier_id = v_sup) then
      insert into supplier_profiles (supplier_id, contact_person, contact_email)
        values (v_sup, v_name, v_email);
      v_created := v_created || 'supplier_profiles';
    end if;
    if not exists (select 1 from kyc_verification where supplier_id = v_sup) then
      insert into kyc_verification (supplier_id, status) values (v_sup, 'pending');
      v_created := v_created || 'kyc_verification';
    end if;
  end if;

  -- Keep the onboarding flag in step with Supabase's own verification state.
  update onboarding_progress o set email_verified = true
    from auth.users u
   where o.profile_id = v_id and u.id = v_id
     and u.email_confirmed_at is not null and o.email_verified = false;

  return jsonb_build_object('role', v_role, 'repaired', v_created);
end $$;

-- ---------------------------------------------------------------------------
-- 4. profile_completion - drives the onboarding meter
--
-- Returns a percentage plus the specific fields still missing, so the UI can
-- name them rather than showing a bare number.
-- ---------------------------------------------------------------------------
create or replace function public.profile_completion()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_id uuid := auth.uid();
  v_role user_role;
  v_missing text[] := '{}';
  v_total int := 0;
  v_done int := 0;
  p profiles;
  c customer_profiles;
  s suppliers;
  sp supplier_profiles;
  k kyc_verification;
  v_media int := 0;
begin
  if v_id is null then return '{}'::jsonb; end if;
  select * into p from profiles where id = v_id;
  if not found then return '{}'::jsonb; end if;
  v_role := p.role;

  if v_role = 'customer' then
    select * into c from customer_profiles where profile_id = v_id;
    -- label, value pairs, checked in display order
    v_total := 7;
    if coalesce(btrim(p.full_name),'') <> '' then v_done := v_done + 1; else v_missing := v_missing || array['Your name']; end if;
    if coalesce(btrim(c.org_name),'') <> ''   then v_done := v_done + 1; else v_missing := v_missing || array['Organisation']; end if;
    if coalesce(btrim(c.industry),'') <> ''   then v_done := v_done + 1; else v_missing := v_missing || array['Industry']; end if;
    if coalesce(btrim(p.phone),'') <> ''      then v_done := v_done + 1; else v_missing := v_missing || array['Contact number']; end if;
    if coalesce(btrim(c.billing_address),'') <> '' then v_done := v_done + 1; else v_missing := v_missing || array['Billing address']; end if;
    if coalesce(btrim(c.gstin::text),'') <> '' then v_done := v_done + 1; else v_missing := v_missing || array['GSTIN (if applicable)']; end if;
    if coalesce(btrim(p.avatar_url),'') <> '' then v_done := v_done + 1; else v_missing := v_missing || array['Profile picture']; end if;

  elsif v_role = 'supplier' then
    select * into s from suppliers where owner = v_id;
    if s.id is null then return jsonb_build_object('percent', 0, 'missing', array['Business record']); end if;
    select * into sp from supplier_profiles where supplier_id = s.id;
    select * into k  from kyc_verification where supplier_id = s.id;
    select count(*) into v_media from supplier_media where supplier_id = s.id;

    v_total := 12;
    if coalesce(btrim(s.business_name),'') <> '' then v_done := v_done + 1; else v_missing := v_missing || array['Business name']; end if;
    if coalesce(btrim(s.description),'') <> ''   then v_done := v_done + 1; else v_missing := v_missing || array['Description']; end if;
    if coalesce(btrim(s.tagline),'') <> ''       then v_done := v_done + 1; else v_missing := v_missing || array['Short description']; end if;
    if s.capacity is not null and s.capacity > 0  then v_done := v_done + 1; else v_missing := v_missing || array['Capacity']; end if;
    if s.starting_price is not null and s.starting_price > 0 then v_done := v_done + 1; else v_missing := v_missing || array['Starting price']; end if;
    if coalesce(array_length(s.amenities,1),0) > 0 then v_done := v_done + 1; else v_missing := v_missing || array['Amenities']; end if;
    if coalesce(btrim(sp.contact_person),'') <> '' then v_done := v_done + 1; else v_missing := v_missing || array['Contact person']; end if;
    if coalesce(btrim(sp.contact_phone),'') <> ''  then v_done := v_done + 1; else v_missing := v_missing || array['Contact phone']; end if;
    if coalesce(btrim(sp.address),'') <> ''        then v_done := v_done + 1; else v_missing := v_missing || array['Address']; end if;
    if coalesce(btrim(s.cancellation_policy),'') <> '' then v_done := v_done + 1; else v_missing := v_missing || array['Cancellation policy']; end if;
    if coalesce(btrim(k.gstin::text),'') <> ''     then v_done := v_done + 1; else v_missing := v_missing || array['GSTIN']; end if;
    if v_media > 0 then v_done := v_done + 1; else v_missing := v_missing || array['At least one photo']; end if;
  end if;

  return jsonb_build_object(
    'role', v_role,
    'percent', case when v_total = 0 then 0 else round(100.0 * v_done / v_total) end,
    'done', v_done, 'total', v_total,
    'missing', to_jsonb(v_missing),
    'status', coalesce(s.status, 'n/a'),
    'verification', coalesce(k.status::text, 'n/a'),
    'media_count', v_media
  );
end $$;

-- ---------------------------------------------------------------------------
-- 5. publish_supplier - the draft -> active gate
--
-- A listing goes public only once it has the minimum a customer needs to
-- judge it. Refusing here (rather than letting an empty card into search) is
-- the whole reason new signups start as 'draft'.
-- ---------------------------------------------------------------------------
create or replace function public.publish_supplier()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_sup suppliers; v_media int; v_missing text[] := '{}';
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into v_sup from suppliers where owner = auth.uid();
  if not found then raise exception 'no business record for this account'; end if;

  select count(*) into v_media from supplier_media where supplier_id = v_sup.id;

  if coalesce(btrim(v_sup.description),'') = '' then v_missing := v_missing || array['a description']; end if;
  if v_sup.capacity is null or v_sup.capacity <= 0 then v_missing := v_missing || array['a capacity']; end if;
  if v_sup.starting_price is null or v_sup.starting_price <= 0 then v_missing := v_missing || array['a starting price']; end if;
  if v_media = 0 then v_missing := v_missing || array['at least one photo']; end if;

  if array_length(v_missing, 1) > 0 then
    return jsonb_build_object('published', false, 'missing', to_jsonb(v_missing));
  end if;

  update suppliers set status = 'active', updated_at = now() where id = v_sup.id;
  update kyc_verification set status = 'under_review', updated_at = now()
    where supplier_id = v_sup.id and status = 'pending';
  update onboarding_progress set submitted_for_review = true, profile_done = true,
         completed_at = coalesce(completed_at, now())
    where profile_id = auth.uid();

  perform public.notify(auth.uid(), 'system', 'Listing submitted',
    'Your listing is live and your documents are with Eventara Ops for verification.',
    'supplier-dashboard.html#profile');

  return jsonb_build_object('published', true, 'missing', '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------------
-- 6. Onboarding progress helpers
-- ---------------------------------------------------------------------------
create or replace function public.my_onboarding()
returns onboarding_progress language sql stable security definer set search_path = public as $$
  select * from onboarding_progress where profile_id = auth.uid()
$$;

create or replace function public.dismiss_onboarding()
returns void language sql security definer set search_path = public as $$
  update onboarding_progress set dismissed = true where profile_id = auth.uid()
$$;

grant execute on function public.ensure_account_records() to authenticated;
grant execute on function public.profile_completion()     to authenticated;
grant execute on function public.publish_supplier()       to authenticated;
grant execute on function public.my_onboarding()          to authenticated;
grant execute on function public.dismiss_onboarding()     to authenticated;

revoke execute on function public.ensure_account_records() from anon, public;
revoke execute on function public.profile_completion()     from anon, public;
revoke execute on function public.publish_supplier()       from anon, public;
revoke execute on function public.my_onboarding()          from anon, public;
revoke execute on function public.dismiss_onboarding()     from anon, public;

-- ---------------------------------------------------------------------------
-- 7. Storage buckets for the supplier portfolio
--
-- 0006_storage.sql created 8 buckets but none for video or PDF collateral.
-- Videos, brochures and menus are marketing material a customer is meant to
-- see, so they read public; writes stay folder-scoped to auth.uid() through
-- the existing "own folder insert/update/delete" policies.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('supplier-videos',   'supplier-videos',   true, 104857600, array['video/mp4','video/webm','video/quicktime']),
  ('supplier-documents','supplier-documents',true,  20971520, array['application/pdf']),
  ('brochures',         'brochures',         true,  20971520, array['application/pdf']),
  ('menus',             'menus',             true,  20971520, array['application/pdf'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg','image/png','image/webp','image/avif']
 where id in ('supplier-images','venue-images','profile-pictures');

drop policy if exists "public read" on storage.objects;
create policy "public read" on storage.objects for select
  using (bucket_id = any (array[
    'supplier-images','venue-images','profile-pictures',
    'supplier-videos','supplier-documents','brochures','menus']));

-- ---------------------------------------------------------------------------
-- 8. Backfill onboarding rows for the three demo accounts
-- ---------------------------------------------------------------------------
insert into onboarding_progress (profile_id, role, email_verified, profile_started, profile_done, media_uploaded, submitted_for_review, completed_at)
select p.id, p.role, true, true, true, true, true, now()
from profiles p
where not exists (select 1 from onboarding_progress o where o.profile_id = p.id);
