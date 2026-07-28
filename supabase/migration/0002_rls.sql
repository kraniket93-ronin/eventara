-- ============================================================================
-- Eventara backend — 0002_rls.sql
-- Row-Level Security: default-deny, then role-aware policies.
-- Customers see only their data; suppliers only their business; admins all;
-- the public marketplace (verified suppliers, venues, reviews) is readable.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helper functions (SECURITY DEFINER so they can read profiles without
-- tripping profiles' own RLS — this avoids infinite recursion in policies).
-- ---------------------------------------------------------------------------
create or replace function public.current_role()
returns user_role language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'admin' from profiles where id = auth.uid()), false)
$$;

create or replace function public.owns_supplier(sup uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from suppliers where id = sup and owner = auth.uid())
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS on every table that holds user or business data.
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','user_preferences','customer_profiles','suppliers','supplier_profiles',
    'supplier_services','venues','venue_images','kyc_verification','gst_details',
    'bank_accounts','documents','event_requests','quotes','quote_line_items',
    'bookings','payments','escrow_transactions','wallet_ledger','invoices','reviews',
    'availability','conversations','messages','notifications','disputes','dispute_events',
    'audit_logs','activity_logs','login_events','roles','permissions','role_permissions','event_types'
  ]
  loop
    execute format('alter table %I enable row level security', t);
  end loop;
end $$;

-- Convenience macro-ish: drop-then-create so this file is re-runnable.
-- (Each policy below is explicit.)

-- ===== PROFILES =====
drop policy if exists profiles_self_read on profiles;
create policy profiles_self_read on profiles for select
  using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_self_upd on profiles;
create policy profiles_self_upd on profiles for update
  using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_self_ins on profiles;
create policy profiles_self_ins on profiles for insert
  with check (id = auth.uid() or public.is_admin());

-- ===== USER_PREFERENCES =====
drop policy if exists prefs_owner on user_preferences;
create policy prefs_owner on user_preferences for all
  using (profile_id = auth.uid() or public.is_admin())
  with check (profile_id = auth.uid() or public.is_admin());

-- ===== CUSTOMER_PROFILES =====
drop policy if exists custprof_owner on customer_profiles;
create policy custprof_owner on customer_profiles for all
  using (profile_id = auth.uid() or public.is_admin())
  with check (profile_id = auth.uid() or public.is_admin());

-- ===== SUPPLIERS (public read of active; owner/admin write) =====
drop policy if exists suppliers_public_read on suppliers;
create policy suppliers_public_read on suppliers for select
  using (status = 'active' or owner = auth.uid() or public.is_admin());
drop policy if exists suppliers_owner_write on suppliers;
create policy suppliers_owner_write on suppliers for update
  using (owner = auth.uid() or public.is_admin());
drop policy if exists suppliers_owner_ins on suppliers;
create policy suppliers_owner_ins on suppliers for insert
  with check (owner = auth.uid() or public.is_admin());

-- ===== SUPPLIER_PROFILES / SERVICES / VENUES / VENUE_IMAGES (public read) =====
drop policy if exists supprof_read on supplier_profiles;
create policy supprof_read on supplier_profiles for select using (true);
drop policy if exists supprof_write on supplier_profiles;
create policy supprof_write on supplier_profiles for all
  using (public.owns_supplier(supplier_id) or public.is_admin())
  with check (public.owns_supplier(supplier_id) or public.is_admin());

drop policy if exists services_read on supplier_services;
create policy services_read on supplier_services for select using (true);
drop policy if exists services_write on supplier_services;
create policy services_write on supplier_services for all
  using (public.owns_supplier(supplier_id) or public.is_admin())
  with check (public.owns_supplier(supplier_id) or public.is_admin());

drop policy if exists venues_read on venues;
create policy venues_read on venues for select using (true);
drop policy if exists venues_write on venues;
create policy venues_write on venues for all
  using (public.owns_supplier(supplier_id) or public.is_admin())
  with check (public.owns_supplier(supplier_id) or public.is_admin());

drop policy if exists venue_images_read on venue_images;
create policy venue_images_read on venue_images for select using (true);
drop policy if exists venue_images_write on venue_images;
create policy venue_images_write on venue_images for all
  using (public.is_admin() or exists (
    select 1 from venues v where v.id = venue_id and public.owns_supplier(v.supplier_id)))
  with check (public.is_admin() or exists (
    select 1 from venues v where v.id = venue_id and public.owns_supplier(v.supplier_id)));

-- ===== KYC / GST / BANK / DOCUMENTS (private: owner + admin only) =====
drop policy if exists kyc_owner on kyc_verification;
create policy kyc_owner on kyc_verification for all
  using (public.owns_supplier(supplier_id) or public.is_admin())
  with check (public.owns_supplier(supplier_id) or public.is_admin());

drop policy if exists gst_owner on gst_details;
create policy gst_owner on gst_details for all
  using (public.is_admin()
    or (owner_type='supplier' and public.owns_supplier(owner_id))
    or (owner_type='customer' and owner_id = auth.uid()))
  with check (public.is_admin()
    or (owner_type='supplier' and public.owns_supplier(owner_id))
    or (owner_type='customer' and owner_id = auth.uid()));

drop policy if exists bank_owner on bank_accounts;
create policy bank_owner on bank_accounts for all
  using (public.is_admin() or profile_id = auth.uid()
    or (supplier_id is not null and public.owns_supplier(supplier_id)))
  with check (public.is_admin() or profile_id = auth.uid()
    or (supplier_id is not null and public.owns_supplier(supplier_id)));

drop policy if exists docs_owner on documents;
create policy docs_owner on documents for all
  using (public.is_admin() or uploaded_by = auth.uid()
    or (owner_type='supplier' and public.owns_supplier(owner_id))
    or (owner_type in ('customer','profile') and owner_id = auth.uid()))
  with check (public.is_admin() or uploaded_by = auth.uid()
    or (owner_type='supplier' and public.owns_supplier(owner_id))
    or (owner_type in ('customer','profile') and owner_id = auth.uid()));

-- ===== EVENT_REQUESTS (customer owns; matched suppliers may read) =====
drop policy if exists req_customer on event_requests;
create policy req_customer on event_requests for all
  using (customer_id = auth.uid() or public.is_admin())
  with check (customer_id = auth.uid() or public.is_admin());
-- suppliers can read a request they have been quoted into
drop policy if exists req_supplier_read on event_requests;
create policy req_supplier_read on event_requests for select
  using (exists (select 1 from quotes q join suppliers s on s.id = q.supplier_id
                 where q.request_id = event_requests.id and s.owner = auth.uid()));

-- ===== QUOTES + LINE ITEMS =====
drop policy if exists quotes_parties on quotes;
create policy quotes_parties on quotes for select
  using (public.is_admin() or public.owns_supplier(supplier_id)
    or exists (select 1 from event_requests r where r.id = request_id and r.customer_id = auth.uid()));
drop policy if exists quotes_supplier_write on quotes;
create policy quotes_supplier_write on quotes for all
  using (public.owns_supplier(supplier_id) or public.is_admin())
  with check (public.owns_supplier(supplier_id) or public.is_admin());

drop policy if exists li_parties on quote_line_items;
create policy li_parties on quote_line_items for select
  using (exists (select 1 from quotes q where q.id = quote_id and (
    public.is_admin() or public.owns_supplier(q.supplier_id)
    or exists (select 1 from event_requests r where r.id = q.request_id and r.customer_id = auth.uid()))));
drop policy if exists li_supplier_write on quote_line_items;
create policy li_supplier_write on quote_line_items for all
  using (exists (select 1 from quotes q where q.id = quote_id and (public.owns_supplier(q.supplier_id) or public.is_admin())))
  with check (exists (select 1 from quotes q where q.id = quote_id and (public.owns_supplier(q.supplier_id) or public.is_admin())));

-- ===== BOOKINGS (both parties read; writes via SECURITY DEFINER fns) =====
drop policy if exists bookings_parties on bookings;
create policy bookings_parties on bookings for select
  using (customer_id = auth.uid() or public.owns_supplier(supplier_id) or public.is_admin());
drop policy if exists bookings_admin_write on bookings;
create policy bookings_admin_write on bookings for all
  using (public.is_admin()) with check (public.is_admin());

-- ===== PAYMENTS / ESCROW / LEDGER / INVOICES (read own; writes server-side) =====
drop policy if exists payments_parties on payments;
create policy payments_parties on payments for select
  using (public.is_admin() or exists (select 1 from bookings b where b.id = booking_id
         and (b.customer_id = auth.uid() or public.owns_supplier(b.supplier_id))));

drop policy if exists escrow_parties on escrow_transactions;
create policy escrow_parties on escrow_transactions for select
  using (public.is_admin() or exists (select 1 from bookings b where b.id = booking_id
         and (b.customer_id = auth.uid() or public.owns_supplier(b.supplier_id))));

drop policy if exists ledger_owner on wallet_ledger;
create policy ledger_owner on wallet_ledger for select
  using (public.is_admin()
    or (owner_type='customer' and owner_id = auth.uid())
    or (owner_type='supplier' and public.owns_supplier(owner_id)));

drop policy if exists invoices_parties on invoices;
create policy invoices_parties on invoices for select
  using (public.is_admin() or exists (select 1 from bookings b where b.id = booking_id
         and (b.customer_id = auth.uid() or public.owns_supplier(b.supplier_id))));

-- ===== REVIEWS (public read published; customer writes own for own booking) =====
drop policy if exists reviews_public_read on reviews;
create policy reviews_public_read on reviews for select
  using (status = 'published' or customer_id = auth.uid() or public.owns_supplier(supplier_id) or public.is_admin());
drop policy if exists reviews_customer_write on reviews;
create policy reviews_customer_write on reviews for insert
  with check (customer_id = auth.uid()
    and exists (select 1 from bookings b where b.id = booking_id
                and b.customer_id = auth.uid() and b.status = 'completed'));

-- ===== AVAILABILITY (public read; supplier writes own) =====
drop policy if exists avail_read on availability;
create policy avail_read on availability for select using (true);
drop policy if exists avail_write on availability;
create policy avail_write on availability for all
  using (public.owns_supplier(supplier_id) or public.is_admin())
  with check (public.owns_supplier(supplier_id) or public.is_admin());

-- ===== CONVERSATIONS / MESSAGES (parties only) =====
drop policy if exists convo_parties on conversations;
create policy convo_parties on conversations for all
  using (customer_id = auth.uid() or public.owns_supplier(supplier_id) or public.is_admin())
  with check (customer_id = auth.uid() or public.owns_supplier(supplier_id) or public.is_admin());
drop policy if exists messages_parties on messages;
create policy messages_parties on messages for select
  using (exists (select 1 from conversations c where c.id = conversation_id and (
    c.customer_id = auth.uid() or public.owns_supplier(c.supplier_id) or public.is_admin())));
drop policy if exists messages_send on messages;
create policy messages_send on messages for insert
  with check (sender_id = auth.uid() and exists (select 1 from conversations c where c.id = conversation_id and (
    c.customer_id = auth.uid() or public.owns_supplier(c.supplier_id))));

-- ===== NOTIFICATIONS (recipient only) =====
drop policy if exists notif_owner on notifications;
create policy notif_owner on notifications for select
  using (recipient = auth.uid() or public.is_admin());
drop policy if exists notif_owner_upd on notifications;
create policy notif_owner_upd on notifications for update
  using (recipient = auth.uid());

-- ===== DISPUTES (parties + admin) =====
drop policy if exists disputes_parties on disputes;
create policy disputes_parties on disputes for select
  using (public.is_admin() or raised_by = auth.uid() or against = auth.uid()
    or exists (select 1 from bookings b where b.id = booking_id and (b.customer_id = auth.uid() or public.owns_supplier(b.supplier_id))));
drop policy if exists disputes_raise on disputes;
create policy disputes_raise on disputes for insert
  with check (raised_by = auth.uid() or public.is_admin());
drop policy if exists dispute_events_parties on dispute_events;
create policy dispute_events_parties on dispute_events for select
  using (exists (select 1 from disputes d where d.id = dispute_id and (
    public.is_admin() or d.raised_by = auth.uid() or d.against = auth.uid())));

-- ===== ACTIVITY / LOGIN (self read); AUDIT (admin only) =====
drop policy if exists activity_self on activity_logs;
create policy activity_self on activity_logs for select
  using (profile_id = auth.uid() or public.is_admin());
drop policy if exists login_self on login_events;
create policy login_self on login_events for select
  using (profile_id = auth.uid() or public.is_admin());
drop policy if exists audit_admin on audit_logs;
create policy audit_admin on audit_logs for select using (public.is_admin());

-- ===== LOOKUPS (public read) =====
drop policy if exists roles_read on roles;            create policy roles_read on roles for select using (true);
drop policy if exists perms_read on permissions;      create policy perms_read on permissions for select using (true);
drop policy if exists rp_read on role_permissions;    create policy rp_read on role_permissions for select using (true);
drop policy if exists etypes_read on event_types;     create policy etypes_read on event_types for select using (true);

-- ============================================================================
-- end 0002_rls.sql
-- ============================================================================
