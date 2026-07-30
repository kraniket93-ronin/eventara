-- ============================================================================
-- Eventara backend — 0009_supplier_detail.sql
-- Schema additions for the dynamic Supplier Detail Page: slug routing,
-- hero/tagline fields, supplier-level media/portfolio, packages, FAQs.
-- Apply after 0008_security_hardening.sql.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- suppliers: new display/routing columns
-- ---------------------------------------------------------------------------
alter table suppliers
  add column if not exists slug text,
  add column if not exists tagline text,
  add column if not exists years_experience int check (years_experience is null or years_experience >= 0),
  add column if not exists featured boolean not null default false,
  add column if not exists logo_url text,
  add column if not exists hero_image_url text;

-- ---------------------------------------------------------------------------
-- Slug generation: fill-if-null trigger, same pattern as trg_set_request_ref
-- ---------------------------------------------------------------------------
create or replace function public.slugify(p_text text)
returns text language sql immutable set search_path = public as $$
  select trim(both '-' from regexp_replace(lower(trim(p_text)), '[^a-z0-9]+', '-', 'g'))
$$;

create or replace function public.trg_set_supplier_slug()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_base text; v_slug text; v_n int := 0;
begin
  if new.slug is not null and new.slug <> '' then return new; end if;
  v_base := public.slugify(new.business_name);
  v_slug := v_base;
  while exists (select 1 from suppliers where slug = v_slug and id <> new.id) loop
    v_n := v_n + 1;
    v_slug := v_base || '-' || v_n;
  end loop;
  new.slug := v_slug;
  return new;
end $$;

drop trigger if exists set_supplier_slug on suppliers;
create trigger set_supplier_slug before insert or update on suppliers
  for each row execute function public.trg_set_supplier_slug();

-- Backfill existing rows (only Paandora Grand today), then lock down.
update suppliers set slug = public.slugify(business_name) where slug is null;
alter table suppliers alter column slug set not null;
create unique index if not exists idx_suppliers_slug on suppliers(slug);

-- ---------------------------------------------------------------------------
-- supplier_profiles: operational/booking-terms fields
-- ---------------------------------------------------------------------------
alter table supplier_profiles
  add column if not exists google_maps_url text,
  add column if not exists payment_terms text,
  add column if not exists advance_required_pct int not null default 30 check (advance_required_pct between 0 and 100),
  add column if not exists refund_policy text,
  add column if not exists booking_policy text;

-- ---------------------------------------------------------------------------
-- reviews: optional review photos (forward-compatible, not required)
-- ---------------------------------------------------------------------------
alter table reviews add column if not exists image_urls text[] not null default '{}';

-- ---------------------------------------------------------------------------
-- supplier_media: supplier-level portfolio, free-text category so any
-- supplier type can define its own sections without new enum values.
-- ---------------------------------------------------------------------------
create table if not exists supplier_media (
  id          uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references suppliers(id) on delete cascade,
  category    text not null default 'gallery',
  caption     text,
  url         text not null,
  sort        int not null default 0,
  is_cover    boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists idx_supplier_media_supplier on supplier_media(supplier_id, category, sort);

-- ---------------------------------------------------------------------------
-- supplier_packages: named pricing tiers with inclusions
-- ---------------------------------------------------------------------------
create table if not exists supplier_packages (
  id          uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references suppliers(id) on delete cascade,
  name        text not null,
  price_from  int not null check (price_from >= 0),
  price_unit  text not null default 'per event',
  guest_min   int,
  guest_max   int,
  description text,
  inclusions  text[] not null default '{}',
  is_featured boolean not null default false,
  sort        int not null default 0
);
create index if not exists idx_supplier_packages_supplier on supplier_packages(supplier_id, sort);

-- ---------------------------------------------------------------------------
-- supplier_faqs
-- ---------------------------------------------------------------------------
create table if not exists supplier_faqs (
  id          uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references suppliers(id) on delete cascade,
  question    text not null,
  answer      text not null,
  sort        int not null default 0
);
create index if not exists idx_supplier_faqs_supplier on supplier_faqs(supplier_id, sort);

-- ---------------------------------------------------------------------------
-- RLS: public read, owner/admin write — same pattern as venues/supplier_services
-- ---------------------------------------------------------------------------
alter table supplier_media    enable row level security;
alter table supplier_packages enable row level security;
alter table supplier_faqs     enable row level security;

drop policy if exists supplier_media_read on supplier_media;
create policy supplier_media_read on supplier_media for select using (true);
drop policy if exists supplier_media_write on supplier_media;
create policy supplier_media_write on supplier_media for all
  using (public.owns_supplier(supplier_id) or public.is_admin())
  with check (public.owns_supplier(supplier_id) or public.is_admin());

drop policy if exists supplier_packages_read on supplier_packages;
create policy supplier_packages_read on supplier_packages for select using (true);
drop policy if exists supplier_packages_write on supplier_packages;
create policy supplier_packages_write on supplier_packages for all
  using (public.owns_supplier(supplier_id) or public.is_admin())
  with check (public.owns_supplier(supplier_id) or public.is_admin());

drop policy if exists supplier_faqs_read on supplier_faqs;
create policy supplier_faqs_read on supplier_faqs for select using (true);
drop policy if exists supplier_faqs_write on supplier_faqs;
create policy supplier_faqs_write on supplier_faqs for all
  using (public.owns_supplier(supplier_id) or public.is_admin())
  with check (public.owns_supplier(supplier_id) or public.is_admin());

-- ============================================================================
-- end 0009_supplier_detail.sql
-- ============================================================================
