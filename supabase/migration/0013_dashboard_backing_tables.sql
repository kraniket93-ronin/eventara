-- ============================================================================
-- Eventara backend — 0013_dashboard_backing_tables.sql
-- The three tables the dashboards need that did not already exist. Audited
-- the requested ~30-table list against the live schema first: everything
-- else already maps to an existing table (portfolio->supplier_media,
-- settings->user_preferences, blocked/maintenance dates->availability.state,
-- media/documents->documents, activity history->activity_logs, etc).
-- Apply after 0012_similar_suppliers_recommendations.sql.
-- ============================================================================

-- 1. saved_suppliers - replaces the localStorage wishlist ('eventara_saved_suppliers')
create table if not exists saved_suppliers (
  customer_id uuid not null references profiles(id) on delete cascade,
  supplier_id uuid not null references suppliers(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (customer_id, supplier_id)   -- composite PK == dedupe for free
);
create index if not exists idx_saved_suppliers_customer on saved_suppliers(customer_id, created_at desc);

-- 2. booking_events - the booking timeline / status history
create table if not exists booking_events (
  id         bigint generated always as identity primary key,
  booking_id uuid not null references bookings(id) on delete cascade,
  actor_id   uuid references profiles(id) on delete set null,
  event      text not null,           -- 'created' | 'status_changed' | 'payment' | 'note' ...
  from_state text,
  to_state   text,
  note       text,
  created_at timestamptz not null default now()
);
create index if not exists idx_booking_events_booking on booking_events(booking_id, created_at desc);

-- 3. support_tickets - help.html currently invents a client-side reference
-- number that can never be looked up again; this makes it real.
create table if not exists support_tickets (
  id          uuid primary key default gen_random_uuid(),
  ref         text unique,
  profile_id  uuid references profiles(id) on delete set null,
  role        text check (role in ('customer','supplier','guest')),
  kind        text not null default 'support' check (kind in ('support','complaint')),
  category    text,
  subject     text not null,
  body        text,
  contact_email citext,
  contact_phone text,
  booking_ref text,
  status      text not null default 'open' check (status in ('open','in_progress','waiting','resolved','closed')),
  priority    dispute_priority not null default 'medium',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_support_tickets_profile on support_tickets(profile_id, created_at desc);

create sequence if not exists seq_ticket;
create or replace function public.trg_set_ticket_ref() returns trigger language plpgsql as $$
begin if new.ref is null then
  new.ref := (case when new.kind='complaint' then 'CMP' else 'SUP' end)
             || '-' || extract(year from now())::int || '-'
             || lpad(nextval('seq_ticket')::text, 4, '0');
end if; return new; end $$;
alter function public.trg_set_ticket_ref() set search_path = public;
drop trigger if exists set_ticket_ref on support_tickets;
create trigger set_ticket_ref before insert on support_tickets
  for each row execute function public.trg_set_ticket_ref();

drop trigger if exists trg_updated_support_tickets on support_tickets;
create trigger trg_updated_support_tickets before update on support_tickets
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table saved_suppliers  enable row level security;
alter table booking_events   enable row level security;
alter table support_tickets  enable row level security;

-- saved_suppliers: strictly the owning customer (or admin)
drop policy if exists saved_suppliers_owner on saved_suppliers;
create policy saved_suppliers_owner on saved_suppliers for all
  using (customer_id = auth.uid() or public.is_admin())
  with check (customer_id = auth.uid() or public.is_admin());

-- booking_events: readable by either party on the booking; writes go through
-- the app/RPCs, so only admin may write directly.
drop policy if exists booking_events_parties on booking_events;
create policy booking_events_parties on booking_events for select
  using (public.is_admin() or exists (
    select 1 from bookings b where b.id = booking_id
      and (b.customer_id = auth.uid() or public.owns_supplier(b.supplier_id))));
drop policy if exists booking_events_admin_write on booking_events;
create policy booking_events_admin_write on booking_events for all
  using (public.is_admin()) with check (public.is_admin());

-- support_tickets: raiser sees/updates their own; admin sees all
drop policy if exists support_tickets_owner on support_tickets;
create policy support_tickets_owner on support_tickets for select
  using (profile_id = auth.uid() or public.is_admin());
drop policy if exists support_tickets_insert on support_tickets;
create policy support_tickets_insert on support_tickets for insert
  with check (profile_id = auth.uid() or public.is_admin());
drop policy if exists support_tickets_update on support_tickets;
create policy support_tickets_update on support_tickets for update
  using (profile_id = auth.uid() or public.is_admin());

-- ============================================================================
-- end 0013_dashboard_backing_tables.sql
-- ============================================================================
