-- ============================================================================
-- Eventara backend — 0007_seed.sql
-- Realistic demo data mirroring the current prototype so the app is instantly
-- demoable. Uses fixed UUIDs so rows cross-reference cleanly.
--
-- NOTE on auth users: seeding auth.users directly works in the Supabase SQL
-- editor (service role). If your project rejects the direct insert, instead
-- create these two users in Authentication > Users with the SAME emails, then
-- copy their UUIDs over the fixed IDs below and re-run from the "MARKETPLACE"
-- section. Demo credentials match the old prototype: password = udaipur@2026.
-- ============================================================================

-- ---- Lookups (always safe) -------------------------------------------------
insert into roles (code, label, description) values
  ('customer','Customer','Books events'),
  ('supplier','Supplier','Sells event services'),
  ('admin','Admin','Eventara operations')
on conflict (code) do nothing;

insert into permissions (code, label) values
  ('booking.read','Read bookings'), ('booking.write','Create/modify bookings'),
  ('quote.read','Read quotes'), ('quote.write','Create/modify quotes'),
  ('supplier.manage','Manage supplier business'), ('dispute.manage','Manage disputes'),
  ('admin.all','Full access')
on conflict (code) do nothing;

insert into role_permissions (role, permission) values
  ('customer','booking.read'), ('customer','quote.read'),
  ('supplier','booking.read'), ('supplier','quote.read'), ('supplier','quote.write'), ('supplier','supplier.manage'),
  ('admin','admin.all'), ('admin','dispute.manage')
on conflict do nothing;

insert into event_types (code, label, sort) values
  ('corporate','Corporate Event',1), ('conference','Conference',2),
  ('institutional','College / University Fest',3), ('convocation','Convocation / Annual Day',4),
  ('launch','Product Launch / Award Night',5), ('wedding','Weddings (coming soon)',6)
on conflict (code) do nothing;
update event_types set active = false where code = 'wedding';

-- ---- Demo auth users (best-effort; guarded) --------------------------------
do $$
begin
  -- customer: Secure Meters Ltd
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change)
  values ('22222222-2222-2222-2222-222222222222','00000000-0000-0000-0000-000000000000',
      'authenticated','authenticated','customer@eventara.in', crypt('udaipur@2026', gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}',
      '{"role":"customer","full_name":"Secure Meters Ltd","org_name":"Secure Meters Ltd"}', now(), now(),'','','','')
  on conflict (id) do nothing;

  -- supplier owner: Paandora Grand Udaipur
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change)
  values ('33333333-3333-3333-3333-333333333333','00000000-0000-0000-0000-000000000000',
      'authenticated','authenticated','hotel@eventara.in', crypt('udaipur@2026', gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}',
      '{"role":"supplier","full_name":"Paandora Grand Udaipur"}', now(), now(),'','','','')
  on conflict (id) do nothing;

  -- admin (ops)
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change)
  values ('11111111-1111-1111-1111-111111111111','00000000-0000-0000-0000-000000000000',
      'authenticated','authenticated','ops@eventara.in', crypt('udaipur@2026', gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}',
      '{"role":"admin","full_name":"Eventara Ops"}', now(), now(),'','','','')
  on conflict (id) do nothing;
exception when others then
  raise notice 'Direct auth.users seed skipped (%). Create the users in the dashboard and re-run from MARKETPLACE.', sqlerrm;
end $$;

-- Guarantee profiles exist with the right role (in case the trigger did not run)
insert into profiles (id, role, full_name, email) values
  ('11111111-1111-1111-1111-111111111111','admin','Eventara Ops','ops@eventara.in'),
  ('22222222-2222-2222-2222-222222222222','customer','Secure Meters Ltd','customer@eventara.in'),
  ('33333333-3333-3333-3333-333333333333','supplier','Paandora Grand Udaipur','hotel@eventara.in')
on conflict (id) do update set role = excluded.role, full_name = excluded.full_name;

insert into user_preferences (profile_id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222'),
  ('33333333-3333-3333-3333-333333333333')
on conflict do nothing;

insert into customer_profiles (profile_id, org_name, buyer, industry, gstin, billing_address)
values ('22222222-2222-2222-2222-222222222222','Secure Meters Ltd','corporate','Electronics & Metering',
        '08XXXXX0000X1ZK','E-Class, Pratap Nagar Industrial Area, Udaipur, Rajasthan 313003')
on conflict (profile_id) do nothing;

-- =========================== MARKETPLACE ====================================
-- Supplier business: Paandora Grand Udaipur
insert into suppliers (id, owner, business_name, category, description, city, capacity,
    starting_price, hall_rental, min_guarantee, cancellation_policy, amenities, verified, rating, review_count)
values ('44444444-4444-4444-4444-444444444444','33333333-3333-3333-3333-333333333333',
    'Paandora Grand Udaipur','banquet_hotel',
    'Five-star banquet hotel with lawns, pillarless ballroom and in-house catering on the Udaipur ring road.',
    'Udaipur', 800, 1850, 125000, 150, 'Moderate - 50% refund up to 30 days',
    array['Valet parking','In-house catering','AV & stage','Power backup','Bridal room','Wi-Fi'], true, 4.6, 214)
on conflict (id) do nothing;

insert into supplier_profiles (supplier_id, contact_person, contact_email, contact_phone, address)
values ('44444444-4444-4444-4444-444444444444','Rohit Menon - Banquet Head','events@paandoragrand.example',
        '+91 294 XXXX XXXX','NH-48 Ring Road, Balicha, Udaipur, Rajasthan 313001')
on conflict (supplier_id) do nothing;

insert into kyc_verification (supplier_id, gstin, gstin_status, pan, pan_status, fssai, status)
values ('44444444-4444-4444-4444-444444444444','08AAAAA0000A1Z5','verified','AAACPXXXXC','verified','123XXXXXXXX012','verified')
on conflict (supplier_id) do nothing;

insert into venues (id, supplier_id, name, capacity, price_from, is_indoor, amenities) values
  ('55555555-5555-5555-5555-555555555551','44444444-4444-4444-4444-444444444444','Grand Ballroom',800,125000,true,array['Pillarless','LED wall','AC']),
  ('55555555-5555-5555-5555-555555555552','44444444-4444-4444-4444-444444444444','Riverside Lawn',1200,90000,false,array['Open-air','Stage','Parking'])
on conflict (id) do nothing;

insert into venue_images (venue_id, url, is_cover) values
  ('55555555-5555-5555-5555-555555555551','supplier-images/44444444/ballroom.jpg',true)
on conflict do nothing;

-- Availability: block/maintenance/booked sample days in the current month
insert into availability (supplier_id, day, state) values
  ('44444444-4444-4444-4444-444444444444', date_trunc('month',now())::date + 12, 'blocked'),
  ('44444444-4444-4444-4444-444444444444', date_trunc('month',now())::date + 15, 'maintenance')
on conflict (supplier_id, day) do nothing;

-- A request from the customer, a submitted quote + line items
insert into event_requests (id, ref, customer_id, event_type, event_date, guests, budget_band, status)
values ('66666666-6666-6666-6666-666666666666','EVT-2026-0042','22222222-2222-2222-2222-222222222222',
        'corporate', (now() + interval '40 days')::date, 140, 'Rs 5-10L','accepted')
on conflict (id) do nothing;

insert into quotes (id, ref, request_id, supplier_id, status, subtotal, tax, total, valid_until)
values ('77777777-7777-7777-7777-777777777777','QT-2026-0042','66666666-6666-6666-6666-666666666666',
        '44444444-4444-4444-4444-444444444444','accepted', 850000, 153000, 1003000, (now()+interval '20 days')::date)
on conflict (id) do nothing;

insert into quote_line_items (quote_id, description, qty, unit_price, amount, sort) values
  ('77777777-7777-7777-7777-777777777777','Banquet dinner (per plate)',140,1850,259000,1),
  ('77777777-7777-7777-7777-777777777777','Grand Ballroom rental',1,125000,125000,2),
  ('77777777-7777-7777-7777-777777777777','AV, stage & lighting',1,180000,180000,3),
  ('77777777-7777-7777-7777-777777777777','Decor & florals',1,286000,286000,4)
on conflict do nothing;

-- A confirmed booking with escrow + invoice + a completed-past review
insert into bookings (id, ref, quote_id, request_id, customer_id, supplier_id, event_date, guests,
    amount, deposit, balance, commission, net_payout, status, payment_status)
values ('88888888-8888-8888-8888-888888888888','EVT-2026-0042','77777777-7777-7777-7777-777777777777',
    '66666666-6666-6666-6666-666666666666','22222222-2222-2222-2222-222222222222','44444444-4444-4444-4444-444444444444',
    (now()+interval '40 days')::date,140,1003000,300900,702100,70210,932790,'upcoming','deposit_held')
on conflict (id) do nothing;

insert into availability (supplier_id, day, state, booking_id)
values ('44444444-4444-4444-4444-444444444444',(now()+interval '40 days')::date,'booked','88888888-8888-8888-8888-888888888888')
on conflict (supplier_id, day) do update set state='booked', booking_id=excluded.booking_id;

insert into escrow_transactions (booking_id, amount, state) values
  ('88888888-8888-8888-8888-888888888888',300900,'held') on conflict do nothing;
insert into payments (booking_id, kind, amount, state) values
  ('88888888-8888-8888-8888-888888888888','deposit',300900,'paid') on conflict do nothing;
insert into invoices (invoice_no, booking_id, type, amount, cgst, sgst) values
  ('EVT/INV/2026/0042', '88888888-8888-8888-8888-888888888888','advance',300900,27352,27352) on conflict (invoice_no) do nothing;

-- A completed past booking + review (drives the 4.6 rating realistically)
insert into bookings (id, ref, customer_id, supplier_id, event_date, guests, amount, deposit, balance,
    commission, net_payout, status, payment_status)
values ('99999999-9999-9999-9999-999999999999','EVT-2025-0288','22222222-2222-2222-2222-222222222222',
    '44444444-4444-4444-4444-444444444444',(now()-interval '200 days')::date,250,495600,0,0,34692,460908,'completed','paid')
on conflict (id) do nothing;

insert into reviews (booking_id, customer_id, supplier_id, rating, title, comment) values
  ('99999999-9999-9999-9999-999999999999','22222222-2222-2222-2222-222222222222','44444444-4444-4444-4444-444444444444',
   5,'Flawless annual day','Great venue, on-time AV, professional team.') on conflict (booking_id) do nothing;

-- A dispute + timeline (matches the supplier dashboard sample)
insert into disputes (id, ref, booking_id, raised_by, against, kind, priority, status, summary) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','C-2026-03','99999999-9999-9999-9999-999999999999',
   '22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333',
   'complaint','high','under_review','AV delayed at start') on conflict (id) do nothing;
insert into dispute_events (dispute_id, actor_id, action, note) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','22222222-2222-2222-2222-222222222222','raised','Complaint about AV delay'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','11111111-1111-1111-1111-111111111111','under_review','Moved to Under Review by Eventara')
on conflict do nothing;

-- Notifications for both sides
insert into notifications (recipient, kind, title, body, link) values
  ('33333333-3333-3333-3333-333333333333','booking','Booking confirmed','Secure Meters - Annual Offsite (EVT-2026-0042).','supplier-dashboard.html#bookings'),
  ('33333333-3333-3333-3333-333333333333','dispute','Complaint update','Case C-2026-03 moved to Under Review.','supplier-dashboard.html#disputes'),
  ('22222222-2222-2222-2222-222222222222','quote','Quotes ready','Your quotes are ready to compare.','customer-dashboard.html#briefs')
on conflict do nothing;

-- Recompute the rating rollup from the seeded review
select public.calculate_supplier_rating('44444444-4444-4444-4444-444444444444');

-- ============================================================================
-- end 0007_seed.sql
-- ============================================================================
