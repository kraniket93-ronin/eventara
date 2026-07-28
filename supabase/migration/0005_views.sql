-- ============================================================================
-- Eventara backend — 0005_views.sql
-- Read models for dashboards & analytics. Views run with the querying user's
-- rights, so RLS on the base tables still applies (security_invoker for PG15+).
-- ============================================================================

-- Public supplier listing card (what search / profile pages render)
create or replace view v_supplier_public
with (security_invoker = true) as
select s.id, s.business_name, s.category, s.description, s.city, s.capacity,
       s.starting_price, s.amenities, s.rating, s.review_count, s.verified,
       (select url from venue_images vi join venues v on v.id = vi.venue_id
         where v.supplier_id = s.id order by vi.is_cover desc, vi.sort limit 1) as cover_image
from suppliers s
where s.status = 'active';

-- Supplier dashboard: bookings with customer + payment context
create or replace view v_supplier_dashboard
with (security_invoker = true) as
select b.*, p.full_name as customer_name, et.label as event_label
from bookings b
join profiles p on p.id = b.customer_id
left join event_requests r on r.id = b.request_id
left join event_types et on et.code = r.event_type;

-- Customer dashboard: bookings with supplier context
create or replace view v_customer_dashboard
with (security_invoker = true) as
select b.*, s.business_name as supplier_name, s.city
from bookings b join suppliers s on s.id = b.supplier_id;

-- Upcoming bookings (both roles; RLS filters to the caller's rows)
create or replace view v_upcoming_bookings
with (security_invoker = true) as
select b.id, b.ref, b.event_date, b.guests, b.amount, b.status, b.payment_status,
       b.customer_id, b.supplier_id, s.business_name as supplier_name, p.full_name as customer_name
from bookings b
join suppliers s on s.id = b.supplier_id
join profiles p on p.id = b.customer_id
where b.status = 'upcoming'
order by b.event_date;

-- Pending quotes awaiting a customer decision
create or replace view v_pending_quotes
with (security_invoker = true) as
select q.id, q.ref, q.total, q.valid_until, q.status,
       r.id as request_id, r.customer_id, r.event_type, r.event_date,
       s.id as supplier_id, s.business_name as supplier_name
from quotes q
join event_requests r on r.id = q.request_id
join suppliers s on s.id = q.supplier_id
where q.status = 'submitted';

-- Revenue summary per supplier (net payouts by state)
create or replace view v_revenue_summary
with (security_invoker = true) as
select s.id as supplier_id, s.business_name,
       coalesce(sum(b.net_payout) filter (where b.status='completed'),0) as earned,
       coalesce(sum(e.amount) filter (where e.state='held'),0)          as in_escrow,
       count(b.id) filter (where b.status in ('upcoming','ongoing'))     as active_bookings
from suppliers s
left join bookings b on b.supplier_id = s.id
left join escrow_transactions e on e.booking_id = b.id
group by s.id, s.business_name;

-- Monthly analytics (bookings + GMV by month)
create or replace view v_monthly_analytics
with (security_invoker = true) as
select supplier_id,
       date_trunc('month', created_at) as month,
       count(*) as bookings,
       sum(amount) as gmv,
       sum(net_payout) as net
from bookings
group by supplier_id, date_trunc('month', created_at);

-- Availability summary per supplier per month
create or replace view v_availability_summary
with (security_invoker = true) as
select supplier_id, date_trunc('month', day) as month,
       count(*) filter (where state='booked')      as booked,
       count(*) filter (where state='blocked')     as blocked,
       count(*) filter (where state='maintenance') as maintenance,
       count(*) filter (where state='held')        as held
from availability
group by supplier_id, date_trunc('month', day);

-- Disputes overview
create or replace view v_disputes_overview
with (security_invoker = true) as
select d.id, d.ref, d.kind, d.priority, d.status, d.created_at,
       d.booking_id, b.ref as booking_ref, d.raised_by, d.against
from disputes d left join bookings b on b.id = d.booking_id;

-- Notification feed (unread first)
create or replace view v_notification_feed
with (security_invoker = true) as
select id, recipient, kind, title, body, link, read, created_at
from notifications
order by read asc, created_at desc;

-- ============================================================================
-- end 0005_views.sql
-- ============================================================================
