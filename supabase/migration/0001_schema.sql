-- ============================================================================
-- Eventara backend — 0001_schema.sql
-- Normalized PostgreSQL schema for a two-sided event marketplace (Supabase).
-- Idempotent-ish: safe types via DO blocks, `create table if not exists`.
-- Apply order: 0001 -> 0002 -> 0003 -> 0004 -> 0005 -> 0006 -> 0007.
-- ============================================================================

create extension if not exists "pgcrypto";      -- gen_random_uuid()
create extension if not exists "citext";         -- case-insensitive email/gstin

-- ---------------------------------------------------------------------------
-- ENUM TYPES
-- ---------------------------------------------------------------------------
do $$ begin
  create type user_role       as enum ('customer','supplier','admin');
  create type buyer_type       as enum ('corporate','institutional');
  create type supplier_category as enum ('banquet_hotel','event_manager','caterer','decorator','av_production');
  create type verify_status    as enum ('pending','verified','rejected');
  create type avail_state      as enum ('open','blocked','maintenance','held','booked');
  create type request_status   as enum ('new','matched','quoted','under_review','accepted','expired','cancelled');
  create type quote_status     as enum ('draft','submitted','accepted','rejected','expired');
  create type booking_status   as enum ('upcoming','ongoing','completed','cancelled');
  create type pay_status       as enum ('pending','deposit_held','balance_due','paid','refunded');
  create type payment_kind     as enum ('deposit','balance','refund','payout');
  create type payment_state    as enum ('created','paid','failed','refunded');
  create type escrow_state     as enum ('held','released','refunded');
  create type ledger_entry     as enum ('credit','debit');
  create type invoice_type     as enum ('advance','balance','full');
  create type dispute_kind     as enum ('complaint','dispute');
  create type dispute_priority as enum ('low','medium','high','critical');
  create type dispute_status   as enum ('open','under_review','waiting_supplier','waiting_customer','resolved','closed');
  create type doc_kind         as enum ('gstin','pan','fssai','trade_licence','evidence','attachment','other');
  create type notif_kind       as enum ('enquiry','quote','booking','payment','payout','review','dispute','calendar','system');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- RBAC CATALOG (roles / permissions) — enforced practically via profiles.role
-- + RLS, but modelled explicitly for future fine-grained control.
-- ---------------------------------------------------------------------------
create table if not exists roles (
  code        user_role primary key,
  label       text not null,
  description text
);

create table if not exists permissions (
  code        text primary key,          -- e.g. 'booking.read','quote.write'
  label       text not null,
  description text
);

create table if not exists role_permissions (
  role        user_role references roles(code) on delete cascade,
  permission  text      references permissions(code) on delete cascade,
  primary key (role, permission)          -- composite key
);

-- ---------------------------------------------------------------------------
-- IDENTITY: profiles (1:1 with auth.users) + preferences
-- ---------------------------------------------------------------------------
create table if not exists profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        user_role not null default 'customer',
  full_name   text,
  email       citext,
  phone       text,
  city        text default 'Udaipur',
  avatar_url  text,
  status      text not null default 'active' check (status in ('active','suspended','deleted')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_profiles_role on profiles(role);
create index if not exists idx_profiles_email on profiles(email);

create table if not exists user_preferences (
  profile_id     uuid primary key references profiles(id) on delete cascade,
  notify_email   boolean not null default true,
  notify_sms     boolean not null default true,
  notify_whatsapp boolean not null default false,
  notify_push    boolean not null default true,
  public_profile boolean not null default true,
  show_ratings   boolean not null default true,
  marketing_optin boolean not null default false,
  locale         text default 'en-IN',
  updated_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- CUSTOMER side
-- ---------------------------------------------------------------------------
create table if not exists customer_profiles (
  profile_id      uuid primary key references profiles(id) on delete cascade,
  org_name        text,
  buyer           buyer_type default 'corporate',
  industry        text,
  gstin           citext,
  billing_address text,
  default_po      text,
  finance_email   citext,
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- SUPPLIER side: business entity + editable profile + services + venues
-- ---------------------------------------------------------------------------
create table if not exists suppliers (
  id            uuid primary key default gen_random_uuid(),
  owner         uuid not null references profiles(id) on delete cascade,
  business_name text not null,
  category      supplier_category not null default 'banquet_hotel',
  description   text,
  city          text not null default 'Udaipur',
  capacity      int check (capacity is null or capacity >= 0),
  starting_price int check (starting_price is null or starting_price >= 0),
  hall_rental   int,
  min_guarantee int,
  cancellation_policy text,
  amenities     text[] default '{}',
  website       text,
  instagram     text,
  facebook      text,
  rating        numeric(2,1) not null default 0 check (rating between 0 and 5),
  review_count  int not null default 0,
  verified      boolean not null default false,
  status        text not null default 'active' check (status in ('active','paused','delisted')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists idx_suppliers_owner on suppliers(owner);
create index if not exists idx_suppliers_city_cat on suppliers(city, category);
create index if not exists idx_suppliers_verified on suppliers(verified) where verified = true;

create table if not exists supplier_profiles (
  supplier_id      uuid primary key references suppliers(id) on delete cascade,
  contact_person   text,
  contact_email    citext,
  contact_phone    text,
  address          text,
  working_hours    text default 'Mon-Sun, 9:00 AM - 9:00 PM',
  availability_default boolean not null default true,   -- open unless blocked
  auto_response    boolean not null default true,
  updated_at       timestamptz not null default now()
);

create table if not exists supplier_services (
  id          uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references suppliers(id) on delete cascade,
  name        text not null,
  description text,
  price_from  int check (price_from is null or price_from >= 0),
  unit        text default 'per plate'
);
create index if not exists idx_services_supplier on supplier_services(supplier_id);

create table if not exists venues (
  id          uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references suppliers(id) on delete cascade,
  name        text not null,
  capacity    int check (capacity is null or capacity >= 0),
  price_from  int,
  is_indoor   boolean default true,
  amenities   text[] default '{}',
  created_at  timestamptz not null default now()
);
create index if not exists idx_venues_supplier on venues(supplier_id);

create table if not exists venue_images (
  id        uuid primary key default gen_random_uuid(),
  venue_id  uuid not null references venues(id) on delete cascade,
  url       text not null,
  sort      int not null default 0,
  is_cover  boolean not null default false
);
create index if not exists idx_venue_images_venue on venue_images(venue_id);

-- ---------------------------------------------------------------------------
-- COMPLIANCE: KYC, GST, bank, documents
-- ---------------------------------------------------------------------------
create table if not exists kyc_verification (
  supplier_id  uuid primary key references suppliers(id) on delete cascade,
  gstin        citext,
  gstin_status verify_status not null default 'pending',
  pan          text,
  pan_status   verify_status not null default 'pending',
  fssai        text,
  trade_licence text,
  status       verify_status not null default 'pending',
  reviewed_by  uuid references profiles(id),
  reviewed_at  timestamptz,
  notes        text,
  updated_at   timestamptz not null default now()
);

create table if not exists gst_details (
  id          uuid primary key default gen_random_uuid(),
  owner_type  text not null check (owner_type in ('supplier','customer')),
  owner_id    uuid not null,                 -- suppliers.id or profiles.id
  gstin       citext not null,
  legal_name  text,
  address     text,
  state_code  text,
  created_at  timestamptz not null default now(),
  unique (owner_type, owner_id, gstin)
);
create index if not exists idx_gst_owner on gst_details(owner_type, owner_id);

create table if not exists bank_accounts (
  id            uuid primary key default gen_random_uuid(),
  supplier_id   uuid references suppliers(id) on delete cascade,
  profile_id    uuid references profiles(id) on delete cascade,
  account_name  text,
  bank          text,
  account_masked text,                       -- store only masked; never full number
  ifsc          text,
  upi           text,
  is_primary    boolean not null default true,
  created_at    timestamptz not null default now(),
  check (supplier_id is not null or profile_id is not null)
);

create table if not exists documents (
  id          uuid primary key default gen_random_uuid(),
  owner_type  text not null check (owner_type in ('supplier','customer','booking','dispute','profile')),
  owner_id    uuid not null,
  kind        doc_kind not null default 'other',
  bucket      text not null,
  storage_path text not null,
  status      verify_status default 'pending',
  uploaded_by uuid references profiles(id),
  created_at  timestamptz not null default now()
);
create index if not exists idx_documents_owner on documents(owner_type, owner_id);

-- ---------------------------------------------------------------------------
-- CATALOG: event types
-- ---------------------------------------------------------------------------
create table if not exists event_types (
  code        text primary key,              -- 'corporate','conference',...
  label       text not null,
  active      boolean not null default true,
  sort        int default 0
);

-- ---------------------------------------------------------------------------
-- DEMAND: event_requests (briefs/enquiries) -> quotes -> line items
-- ---------------------------------------------------------------------------
create table if not exists event_requests (
  id          uuid primary key default gen_random_uuid(),
  ref         text unique,                   -- EVT-2026-0051 (filled by trigger)
  customer_id uuid not null references profiles(id) on delete cascade,
  event_type  text references event_types(code),
  event_date  date,
  guests      int check (guests is null or guests >= 0),
  budget_band text,
  city        text default 'Udaipur',
  status      request_status not null default 'new',
  details     jsonb default '{}',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_requests_customer on event_requests(customer_id);
create index if not exists idx_requests_status on event_requests(status);

create table if not exists quotes (
  id          uuid primary key default gen_random_uuid(),
  ref         text unique,
  request_id  uuid not null references event_requests(id) on delete cascade,
  supplier_id uuid not null references suppliers(id) on delete cascade,
  status      quote_status not null default 'draft',
  subtotal    int not null default 0,
  tax         int not null default 0,
  total       int not null default 0,
  valid_until date,
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (request_id, supplier_id)           -- one active quote per supplier per request
);
create index if not exists idx_quotes_request on quotes(request_id);
create index if not exists idx_quotes_supplier on quotes(supplier_id);
create index if not exists idx_quotes_status on quotes(status);

create table if not exists quote_line_items (
  id          uuid primary key default gen_random_uuid(),
  quote_id    uuid not null references quotes(id) on delete cascade,
  description text not null,
  qty         numeric(10,2) not null default 1,
  unit_price  int not null default 0,
  amount      int not null default 0,
  sort        int not null default 0
);
create index if not exists idx_line_items_quote on quote_line_items(quote_id);

-- ---------------------------------------------------------------------------
-- TRANSACTION: bookings, payments, escrow, ledger, invoices
-- ---------------------------------------------------------------------------
create table if not exists bookings (
  id            uuid primary key default gen_random_uuid(),
  ref           text unique,
  quote_id      uuid references quotes(id) on delete set null,
  request_id    uuid references event_requests(id) on delete set null,
  customer_id   uuid not null references profiles(id) on delete cascade,
  supplier_id   uuid not null references suppliers(id) on delete cascade,
  event_date    date,
  guests        int,
  amount        int not null default 0,       -- gross incl GST
  deposit       int not null default 0,
  balance       int not null default 0,
  commission    int not null default 0,       -- platform take
  net_payout    int not null default 0,
  status        booking_status not null default 'upcoming',
  payment_status pay_status not null default 'pending',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists idx_bookings_customer on bookings(customer_id);
create index if not exists idx_bookings_supplier on bookings(supplier_id);
create index if not exists idx_bookings_status on bookings(status);
create index if not exists idx_bookings_date on bookings(event_date);

create table if not exists payments (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references bookings(id) on delete cascade,
  kind        payment_kind not null,
  amount      int not null,
  method      text,
  gateway_ref text,
  state       payment_state not null default 'created',
  created_at  timestamptz not null default now()
);
create index if not exists idx_payments_booking on payments(booking_id);

create table if not exists escrow_transactions (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references bookings(id) on delete cascade,
  amount        int not null,
  state         escrow_state not null default 'held',
  held_at       timestamptz not null default now(),
  released_at   timestamptz,
  release_reason text
);
create index if not exists idx_escrow_booking on escrow_transactions(booking_id);

create table if not exists wallet_ledger (
  id          uuid primary key default gen_random_uuid(),
  owner_type  text not null check (owner_type in ('supplier','customer','platform')),
  owner_id    uuid,                            -- suppliers.id / profiles.id / null(platform)
  entry       ledger_entry not null,
  amount      int not null,
  balance_after int,
  ref_type    text,                            -- 'booking','payment','payout','refund'
  ref_id      uuid,
  description text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_ledger_owner on wallet_ledger(owner_type, owner_id);

create table if not exists invoices (
  id          uuid primary key default gen_random_uuid(),
  invoice_no  text unique not null,
  booking_id  uuid not null references bookings(id) on delete cascade,
  type        invoice_type not null,
  amount      int not null,
  cgst        int not null default 0,
  sgst        int not null default 0,
  igst        int not null default 0,
  bucket      text,
  storage_path text,
  issued_at   timestamptz not null default now()
);
create index if not exists idx_invoices_booking on invoices(booking_id);

-- ---------------------------------------------------------------------------
-- TRUST: reviews (rating is atomic here; suppliers.rating is the rollup)
-- ---------------------------------------------------------------------------
create table if not exists reviews (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null unique references bookings(id) on delete cascade,  -- 1 review per real booking
  customer_id uuid not null references profiles(id) on delete cascade,
  supplier_id uuid not null references suppliers(id) on delete cascade,
  rating      int not null check (rating between 1 and 5),
  title       text,
  comment     text,
  status      text not null default 'published' check (status in ('published','hidden','flagged')),
  created_at  timestamptz not null default now()
);
create index if not exists idx_reviews_supplier on reviews(supplier_id);

-- ---------------------------------------------------------------------------
-- AVAILABILITY: single source of truth for supplier dates
-- ---------------------------------------------------------------------------
create table if not exists availability (
  supplier_id uuid not null references suppliers(id) on delete cascade,
  day         date not null,
  state       avail_state not null default 'open',
  booking_id  uuid references bookings(id) on delete set null,
  note        text,
  updated_at  timestamptz not null default now(),
  primary key (supplier_id, day)               -- composite PK
);
create index if not exists idx_avail_day on availability(day);

-- ---------------------------------------------------------------------------
-- COMMS: conversations + messages (masked), notifications
-- ---------------------------------------------------------------------------
create table if not exists conversations (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid references event_requests(id) on delete cascade,
  booking_id  uuid references bookings(id) on delete cascade,
  customer_id uuid not null references profiles(id) on delete cascade,
  supplier_id uuid not null references suppliers(id) on delete cascade,
  created_at  timestamptz not null default now()
);

create table if not exists messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id       uuid not null references profiles(id) on delete cascade,
  body            text not null,
  read            boolean not null default false,
  created_at      timestamptz not null default now()
);
create index if not exists idx_messages_convo on messages(conversation_id);

create table if not exists notifications (
  id          uuid primary key default gen_random_uuid(),
  recipient   uuid not null references profiles(id) on delete cascade,
  kind        notif_kind not null default 'system',
  title       text not null,
  body        text,
  link        text,
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists idx_notif_recipient on notifications(recipient, read);

-- ---------------------------------------------------------------------------
-- DISPUTES: case + timeline
-- ---------------------------------------------------------------------------
create table if not exists disputes (
  id          uuid primary key default gen_random_uuid(),
  ref         text unique,
  booking_id  uuid references bookings(id) on delete set null,
  raised_by   uuid not null references profiles(id) on delete cascade,
  against     uuid references profiles(id) on delete set null,
  kind        dispute_kind not null default 'complaint',
  priority    dispute_priority not null default 'medium',
  status      dispute_status not null default 'open',
  summary     text,
  resolution  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_disputes_booking on disputes(booking_id);
create index if not exists idx_disputes_status on disputes(status);

create table if not exists dispute_events (
  id          uuid primary key default gen_random_uuid(),
  dispute_id  uuid not null references disputes(id) on delete cascade,
  actor_id    uuid references profiles(id) on delete set null,
  action      text not null,
  note        text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_dispute_events on dispute_events(dispute_id);

-- ---------------------------------------------------------------------------
-- OPS: audit trail, activity feed, login events (app-level session log)
-- ---------------------------------------------------------------------------
create table if not exists audit_logs (
  id          bigint generated always as identity primary key,
  actor_id    uuid references profiles(id) on delete set null,
  action      text not null,
  entity_type text,
  entity_id   text,
  diff        jsonb,
  ip          inet,
  created_at  timestamptz not null default now()
);
create index if not exists idx_audit_entity on audit_logs(entity_type, entity_id);

create table if not exists activity_logs (
  id          bigint generated always as identity primary key,
  profile_id  uuid references profiles(id) on delete cascade,
  event       text not null,
  meta        jsonb default '{}',
  created_at  timestamptz not null default now()
);
create index if not exists idx_activity_profile on activity_logs(profile_id);

-- Supabase manages real sessions/JWTs in auth.sessions; this is an app-level
-- login/logout audit surface for the ops console.
create table if not exists login_events (
  id          bigint generated always as identity primary key,
  profile_id  uuid references profiles(id) on delete cascade,
  event       text not null check (event in ('login','logout','refresh')),
  user_agent  text,
  ip          inet,
  created_at  timestamptz not null default now()
);
create index if not exists idx_login_profile on login_events(profile_id);

-- ============================================================================
-- end 0001_schema.sql
-- ============================================================================
