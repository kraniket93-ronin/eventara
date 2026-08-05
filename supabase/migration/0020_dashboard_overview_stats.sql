-- ============================================================================
-- 0020_dashboard_overview_stats.sql
-- Makes the Overview panel on both dashboards live, and the customer's
-- Payments panel with it.
--
-- Two parts:
--
--   A. A seed gap is filled. Booking EVT-2025-0288 is 'completed' with
--      payment_status 'paid', but it had no rows in payments, escrow_
--      transactions or invoices - so the money it claims to have moved
--      existed nowhere. Any earnings or payment-history figure computed
--      from the real tables would have silently ignored it. The full trail
--      (deposit -> balance -> escrow released -> payout -> invoices) is
--      backfilled here so a completed booking actually looks completed.
--
--   B. Two SECURITY DEFINER functions return everything the Overview panels
--      show, in one round trip each, computed from the domain tables rather
--      than typed into the HTML. Both are scoped to auth.uid(): a supplier
--      only ever aggregates its own rows, a customer only its own.
--
-- Every figure here is derived. Where a metric cannot honestly be computed
-- from the data that exists (for example a 48-hour response rate needs more
-- than one quote to mean anything), the function returns the real number and
-- the UI labels it plainly rather than inventing a flattering one.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- A. Backfill the completed booking's money trail
-- ---------------------------------------------------------------------------
do $$
declare
  v_b     bookings;
  v_dep   integer;
  v_bal   integer;
begin
  select * into v_b from bookings where ref = 'EVT-2025-0288';
  if not found then return; end if;
  if exists (select 1 from payments where booking_id = v_b.id) then return; end if;

  -- 30% advance / 70% balance, the split used everywhere else in the project.
  v_dep := round(v_b.amount * 0.30);
  v_bal := v_b.amount - v_dep;

  -- Dates follow the real sequence for this booking (event 09 Jan 2026):
  -- advance long before, balance before the event, payout only after the
  -- support window closed. Escrow is released last, never before delivery.
  insert into payments (booking_id, kind, amount, method, gateway_ref, state, created_at) values
    (v_b.id, 'deposit', v_dep,          'netbanking',   'pay_R7xK0288DEP', 'paid', '2025-11-28 11:20:00+05:30'),
    (v_b.id, 'balance', v_bal,          'netbanking',   'pay_R7xK0288BAL', 'paid', '2026-01-02 16:05:00+05:30'),
    (v_b.id, 'payout',  v_b.net_payout, 'bank_transfer','pyt_R7xK0288PO',  'paid', '2026-01-15 10:12:00+05:30');

  insert into escrow_transactions (booking_id, amount, state, held_at, released_at, release_reason)
  values (v_b.id, v_b.amount, 'released',
          '2025-11-28 11:20:00+05:30', '2026-01-15 10:12:00+05:30',
          'Event delivered and the complaint raised against it was resolved.');

  insert into invoices (invoice_no, booking_id, type, amount, cgst, sgst, igst, issued_at) values
    ('EVT/INV/2025/0288A', v_b.id, 'advance', v_dep,
      round(v_dep * 0.09), round(v_dep * 0.09), 0, '2025-11-28 11:25:00+05:30'),
    ('EVT/INV/2026/0288B', v_b.id, 'balance', v_bal,
      round(v_bal * 0.09), round(v_bal * 0.09), 0, '2026-01-02 16:10:00+05:30');
end $$;

-- A supplier that has already been paid out must have a payout account on
-- file. Without this the Overview honestly reported "Payout account: Not set
-- up" for a supplier holding a completed, paid-out booking.
insert into bank_accounts (supplier_id, profile_id, account_name, bank, account_masked, ifsc, upi, is_primary)
select '44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333',
       'Paandora Hospitality Pvt Ltd', 'HDFC Bank', 'XXXXXX4417', 'HDFC0001284',
       'paandoragrand@hdfcbank', true
where not exists (select 1 from bank_accounts where supplier_id = '44444444-4444-4444-4444-444444444444');

-- ---------------------------------------------------------------------------
-- B0. Small shared formatter so both functions phrase money identically.
--     Defined first because the overview functions call it.
-- ---------------------------------------------------------------------------
create or replace function public.rupees(p integer)
returns text language sql immutable as $$
  select case
    when p is null then 'Rs 0'
    when abs(p) >= 10000000 then 'Rs ' || round(p / 10000000.0, 2)::text || ' Cr'
    when abs(p) >= 100000   then 'Rs ' || round(p / 100000.0, 2)::text || ' L'
    else 'Rs ' || to_char(p, 'FM99,99,99,999') end
$$;

-- ---------------------------------------------------------------------------
-- B1. Supplier overview
-- ---------------------------------------------------------------------------
create or replace function public.supplier_overview_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_sid  uuid;
  v_out  jsonb;
begin
  select id into v_sid from suppliers where owner = auth.uid();
  if v_sid is null then return '{}'::jsonb; end if;

  select jsonb_build_object(
    -- headline metric cards
    'draft_quotes',     (select count(*) from quotes where supplier_id = v_sid and status = 'draft'),
    'submitted_quotes', (select count(*) from quotes where supplier_id = v_sid and status = 'submitted'),
    'new_this_week',    (select count(*) from quotes where supplier_id = v_sid and created_at > now() - interval '7 days'),
    'active_bookings',  (select count(*) from bookings where supplier_id = v_sid and status in ('upcoming','ongoing')),
    'escrow_held',      (select coalesce(sum(e.amount),0) from escrow_transactions e
                          join bookings b on b.id = e.booking_id
                          where b.supplier_id = v_sid and e.state = 'held'),
    'month_net',        (select coalesce(sum(b.net_payout),0) from bookings b
                          where b.supplier_id = v_sid and b.status = 'completed'
                            and b.event_date >= date_trunc('month', current_date)),
    'ytd_net',          (select coalesce(sum(b.net_payout),0) from bookings b
                          where b.supplier_id = v_sid and b.status = 'completed'
                            and b.event_date >= date_trunc('year', current_date)),
    'lifetime_net',     (select coalesce(sum(b.net_payout),0) from bookings b
                          where b.supplier_id = v_sid and b.status = 'completed'),

    -- pipeline funnel
    'pipeline', jsonb_build_object(
      'enquiry',   (select count(*) from quotes where supplier_id = v_sid),
      'quoted',    (select count(*) from quotes where supplier_id = v_sid and status in ('submitted','accepted','rejected')),
      'booked',    (select count(*) from bookings where supplier_id = v_sid),
      'delivered', (select count(*) from bookings where supplier_id = v_sid and status = 'completed'),
      'reviewed',  (select count(*) from reviews where supplier_id = v_sid)
    ),

    -- performance
    'rating',        (select rating from suppliers where id = v_sid),
    'review_count',  (select review_count from suppliers where id = v_sid),
    'quoted_rate',   (select case when count(*) = 0 then null
                        else round(100.0 * count(*) filter (where status <> 'draft') / count(*)) end
                      from quotes where supplier_id = v_sid),
    -- extract() returns double precision; round(x, n) needs numeric.
    'median_quote_hours', (select round((extract(epoch from percentile_cont(0.5) within group (
                              order by q.updated_at - r.created_at)) / 3600.0)::numeric, 1)
                            from quotes q join event_requests r on r.id = q.request_id
                            where q.supplier_id = v_sid and q.status <> 'draft'),
    'delivery_rate', (select case when count(*) filter (where status in ('completed','cancelled')) = 0 then null
                        else round(100.0 * count(*) filter (where status = 'completed')
                                   / count(*) filter (where status in ('completed','cancelled'))) end
                      from bookings where supplier_id = v_sid),
    'kyc_state',     (select coalesce(max(status::text), 'not_started') from kyc_verification where supplier_id = v_sid),
    'payout_ready',  (select exists (select 1 from bank_accounts where supplier_id = v_sid)),

    -- "Needs your attention"
    'attention', coalesce((
      select jsonb_agg(a order by a->>'rank') from (
        select jsonb_build_object('rank','1','tone','coral','title','Quote awaiting your pricing',
          'body', coalesce(r.event_type,'Event') || ' on ' || to_char(r.event_date,'DD Mon YYYY') ||
                  coalesce(' (' || r.guests || ' guests)', '') || ' - still a draft.',
          'panel','enquiries','cta','Build quote') as a
        from quotes q join event_requests r on r.id = q.request_id
        where q.supplier_id = v_sid and q.status = 'draft'
        union all
        select jsonb_build_object('rank','2','tone','warning','title','Case waiting for your response',
          'body','Case ' || d.ref || ' - ' || coalesce(d.summary,'') ,
          'panel','disputes','cta','Open')
        from disputes d
        where d.against = auth.uid() and d.status in ('open','waiting_supplier')
        union all
        select jsonb_build_object('rank','3','tone','gold','title','Event coming up',
          'body', b.ref || ' on ' || to_char(b.event_date,'DD Mon YYYY') || ' - ' || b.guests || ' guests.',
          'panel','bookings','cta','View')
        from bookings b
        where b.supplier_id = v_sid and b.status = 'upcoming'
          and b.event_date between current_date and current_date + 30
      ) t), '[]'::jsonb),

    -- "Recent activity", newest first
    'activity', coalesce((
      select jsonb_agg(x order by x->>'at' desc) from (
        select jsonb_build_object('at', p.created_at, 'text',
          case p.kind when 'payout' then 'Payout of ' || public.rupees(p.amount) || ' released for ' || b.ref
                      when 'deposit' then 'Deposit of ' || public.rupees(p.amount) || ' received for ' || b.ref
                      else 'Balance of ' || public.rupees(p.amount) || ' received for ' || b.ref end) as x
        from payments p join bookings b on b.id = p.booking_id
        where b.supplier_id = v_sid and p.state = 'paid'
        union all
        select jsonb_build_object('at', b.created_at,
          'text', 'Booking confirmed - ' || b.ref || ' for ' || to_char(b.event_date,'DD Mon YYYY') || '.')
        from bookings b where b.supplier_id = v_sid
        union all
        select jsonb_build_object('at', q.updated_at,
          'text', 'Quote ' || q.ref || ' sent for ' || public.rupees(q.total) || '.')
        from quotes q where q.supplier_id = v_sid and q.status <> 'draft'
        union all
        select jsonb_build_object('at', e.created_at,
          'text', 'Case ' || d.ref || ' - ' || e.action || '.')
        from dispute_events e join disputes d on d.id = e.dispute_id
        where d.against = auth.uid() or d.raised_by = auth.uid()
      ) t), '[]'::jsonb)
  ) into v_out;

  return v_out;
end $$;

-- ---------------------------------------------------------------------------
-- B2. Customer overview
-- ---------------------------------------------------------------------------
create or replace function public.customer_overview_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_out jsonb;
begin
  if v_me is null then return '{}'::jsonb; end if;

  select jsonb_build_object(
    'active_requests',  (select count(*) from event_requests
                          where customer_id = v_me and status in ('new','matched','quoted','under_review')),
    'awaiting_quotes',  (select count(*) from event_requests r
                          where r.customer_id = v_me and r.status in ('new','matched')
                            and not exists (select 1 from quotes q where q.request_id = r.id and q.status <> 'draft')),
    'quotes_to_review', (select count(*) from quotes q join event_requests r on r.id = q.request_id
                          where r.customer_id = v_me and q.status = 'submitted'),
    'confirmed_bookings',(select count(*) from bookings where customer_id = v_me and status in ('upcoming','ongoing')),
    'completed_bookings',(select count(*) from bookings where customer_id = v_me and status = 'completed'),
    'escrow_held',      (select coalesce(sum(e.amount),0) from escrow_transactions e
                          join bookings b on b.id = e.booking_id
                          where b.customer_id = v_me and e.state = 'held'),
    'balance_due',      (select coalesce(sum(b.balance),0) from bookings b
                          where b.customer_id = v_me and b.status in ('upcoming','ongoing')
                            and b.payment_status in ('deposit_held','balance_due','pending')),
    'lifetime_spend',   (select coalesce(sum(amount),0) from bookings where customer_id = v_me and status = 'completed'),
    'next_event',       (select jsonb_build_object('ref', b.ref, 'date', b.event_date,
                                'supplier', s.business_name, 'guests', b.guests)
                          from bookings b join suppliers s on s.id = b.supplier_id
                          where b.customer_id = v_me and b.status in ('upcoming','ongoing')
                          order by b.event_date limit 1),

    'attention', coalesce((
      select jsonb_agg(a order by a->>'rank') from (
        select jsonb_build_object('rank','1','tone','gold','title',
          count(*) || ' quote' || case when count(*) = 1 then '' else 's' end || ' ready to compare',
          'body', 'Request ' || r.ref || ' - suppliers have responded.',
          'panel','briefs','cta','Compare') as a
        from quotes q join event_requests r on r.id = q.request_id
        where r.customer_id = v_me and q.status = 'submitted'
        group by r.ref
        union all
        select jsonb_build_object('rank','2','tone','coral','title','Balance due before your event',
          'body', public.rupees(b.balance) || ' for ' || b.ref || ', due before ' ||
                  to_char(b.event_date - 21, 'DD Mon YYYY') || '.',
          'panel','payments','cta','Pay')
        from bookings b
        where b.customer_id = v_me and b.status = 'upcoming' and b.balance > 0
        union all
        select jsonb_build_object('rank','3','tone','info','title','Request awaiting quotes',
          'body', r.ref || ' - ' || coalesce(r.event_type,'event') || ' on ' ||
                  to_char(r.event_date,'DD Mon YYYY') || '.',
          'panel','briefs','cta','View')
        from event_requests r
        where r.customer_id = v_me and r.status in ('new','matched')
          and not exists (select 1 from quotes q where q.request_id = r.id and q.status <> 'draft')
        union all
        select jsonb_build_object('rank','4','tone','warning','title','Case waiting for your response',
          'body','Case ' || d.ref || ' - ' || coalesce(d.summary,''),
          'panel','disputes','cta','Open')
        from disputes d
        where d.against = v_me and d.status in ('open','waiting_customer')
      ) t), '[]'::jsonb),

    'activity', coalesce((
      select jsonb_agg(x order by x->>'at' desc) from (
        select jsonb_build_object('at', p.created_at, 'text',
          case p.kind when 'deposit' then 'Deposit of ' || public.rupees(p.amount) || ' paid and held safely for ' || b.ref || '.'
                      when 'balance' then 'Balance of ' || public.rupees(p.amount) || ' paid for ' || b.ref || '.'
                      when 'refund'  then 'Refund of ' || public.rupees(p.amount) || ' issued for ' || b.ref || '.'
                      else 'Payment recorded for ' || b.ref || '.' end) as x
        from payments p join bookings b on b.id = p.booking_id
        where b.customer_id = v_me and p.state = 'paid' and p.kind <> 'payout'
        union all
        select jsonb_build_object('at', b.created_at,
          'text', 'Booking confirmed with ' || s.business_name || ' (' || b.ref || ').')
        from bookings b join suppliers s on s.id = b.supplier_id where b.customer_id = v_me
        union all
        select jsonb_build_object('at', q.updated_at,
          'text', 'Quote received from ' || s.business_name || ' for ' || public.rupees(q.total) || '.')
        from quotes q join event_requests r on r.id = q.request_id
                      join suppliers s on s.id = q.supplier_id
        where r.customer_id = v_me and q.status <> 'draft'
        union all
        select jsonb_build_object('at', r.created_at,
          'text', 'Request ' || r.ref || ' sent to matched venues and planners.')
        from event_requests r where r.customer_id = v_me
      ) t), '[]'::jsonb)
  ) into v_out;

  return v_out;
end $$;

-- ---------------------------------------------------------------------------
-- B3. Customer payments panel - one row per money movement
-- ---------------------------------------------------------------------------
create or replace function public.my_payments()
returns table (
  id uuid, booking_ref text, supplier text, kind text, amount integer,
  method text, gateway_ref text, state text, created_at timestamptz,
  escrow_state text, event_date date
) language sql stable security definer set search_path = public as $$
  select p.id, b.ref, s.business_name, p.kind::text, p.amount,
         p.method, p.gateway_ref, p.state::text, p.created_at,
         (select e.state::text from escrow_transactions e
           where e.booking_id = b.id order by e.held_at desc limit 1),
         b.event_date
  from payments p
  join bookings b on b.id = p.booking_id
  join suppliers s on s.id = b.supplier_id
  where b.customer_id = auth.uid() and p.kind <> 'payout'
  order by p.created_at desc
$$;

grant execute on function public.supplier_overview_stats() to authenticated;
grant execute on function public.customer_overview_stats() to authenticated;
grant execute on function public.my_payments() to authenticated;
grant execute on function public.rupees(integer) to authenticated;
