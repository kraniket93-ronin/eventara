-- ============================================================================
-- 0022_quote_submitted_at.sql
--
-- Two related problems, both found by wiring "median time to quote" to real
-- data in 0020:
--
--   1. There was no column recording WHEN a quote was sent. The metric used
--      quotes.updated_at as a stand-in, but updated_at is maintained by the
--      set_updated_at trigger and moves on every later edit - so editing a
--      quote's notes months later would silently inflate the supplier's
--      response time. A dedicated submitted_at fixes this properly.
--
--   2. The backdating in 0021 did not stick for quotes, disputes and
--      bookings: the same set_updated_at trigger overwrote updated_at with
--      now() as those UPDATEs ran. The corrections are re-applied here with
--      the trigger disabled for the duration.
--
-- Note for anyone reading the history: 0021 is still correct for the columns
-- that have no trigger on them (created_at, dispute_events, payments,
-- invoices, escrow). Only the updated_at writes needed this second pass.
-- ============================================================================

alter table quotes add column if not exists submitted_at timestamptz;

comment on column quotes.submitted_at is
  'When the quote was actually sent to the customer. Set by submit_quote(). '
  'Distinct from updated_at, which moves on any edit.';

-- ---------------------------------------------------------------------------
-- submit_quote now stamps submitted_at
-- ---------------------------------------------------------------------------
create or replace function public.submit_quote(p_quote_id uuid)
returns quotes language plpgsql security definer set search_path = public as $fn$
declare v_q quotes; v_items integer; v_cust uuid; v_name text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.owns_quote(p_quote_id) then
    raise exception 'this quote does not belong to you'; end if;

  select * into v_q from quotes where id = p_quote_id;
  if v_q.status <> 'draft' then raise exception 'quote % is already %', v_q.ref, v_q.status; end if;

  select count(*) into v_items from quote_line_items where quote_id = p_quote_id;
  if v_items = 0 then raise exception 'add at least one line item before sending'; end if;
  if v_q.total <= 0 then raise exception 'the quote total is still zero'; end if;

  update quotes set status = 'submitted',
         submitted_at = now(),
         valid_until = coalesce(valid_until, current_date + 14),
         updated_at = now()
   where id = p_quote_id returning * into v_q;

  update event_requests set status = 'quoted', updated_at = now()
   where id = v_q.request_id and status in ('new', 'matched');

  select r.customer_id into v_cust from event_requests r where r.id = v_q.request_id;
  select s.business_name into v_name from suppliers s where s.id = v_q.supplier_id;

  perform public.notify(v_cust, 'quote', 'New quote received',
    coalesce(v_name, 'A supplier') || ' sent a quote for your event request.',
    'customer-dashboard.html#briefs');

  return v_q;
end $fn$;

-- ---------------------------------------------------------------------------
-- Re-apply the backdating with the updated_at trigger held off
-- ---------------------------------------------------------------------------
alter table quotes        disable trigger trg_updated_quotes;
alter table disputes      disable trigger trg_updated_disputes;
alter table bookings      disable trigger trg_updated_bookings;
alter table event_requests disable trigger trg_updated_event_requests;

update quotes set submitted_at = '2026-07-27 18:25:00+05:30',
                  updated_at   = '2026-07-27 18:25:00+05:30'
 where ref = 'QT-2026-0042';
update quotes set updated_at = '2026-08-03 10:15:00+05:30'
 where ref = 'QT-2026-0051';

update disputes set updated_at = '2026-01-14 17:40:00+05:30' where ref = 'C-2026-01';
update disputes set updated_at = '2026-08-02 11:30:00+05:30' where ref = 'D-2026-07';

-- Bookings were created when their quote was accepted, not when the seed ran.
update bookings set created_at = '2025-11-27 18:40:00+05:30',
                    updated_at = '2026-01-15 10:12:00+05:30'
 where ref = 'EVT-2025-0288';
update bookings set created_at = '2026-07-27 18:40:00+05:30',
                    updated_at = '2026-07-27 18:40:00+05:30'
 where ref = 'EVT-2026-0042';

update event_requests set updated_at = '2026-07-27 18:40:00+05:30' where ref = 'EVT-2026-0042';
update event_requests set updated_at = '2026-08-03 10:15:00+05:30' where ref = 'EVT-2026-0051';

alter table quotes        enable trigger trg_updated_quotes;
alter table disputes      enable trigger trg_updated_disputes;
alter table bookings      enable trigger trg_updated_bookings;
alter table event_requests enable trigger trg_updated_event_requests;

-- Any other already-sent quote gets a best-effort backfill.
update quotes set submitted_at = updated_at
 where submitted_at is null and status <> 'draft';

-- ---------------------------------------------------------------------------
-- Point the supplier metrics at submitted_at
-- ---------------------------------------------------------------------------
create or replace function public.supplier_overview_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare v_sid uuid; v_out jsonb;
begin
  select id into v_sid from suppliers where owner = auth.uid();
  if v_sid is null then return '{}'::jsonb; end if;

  select jsonb_build_object(
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
    'pipeline', jsonb_build_object(
      'enquiry',   (select count(*) from quotes where supplier_id = v_sid),
      'quoted',    (select count(*) from quotes where supplier_id = v_sid and status in ('submitted','accepted','rejected')),
      'booked',    (select count(*) from bookings where supplier_id = v_sid),
      'delivered', (select count(*) from bookings where supplier_id = v_sid and status = 'completed'),
      'reviewed',  (select count(*) from reviews where supplier_id = v_sid)
    ),
    'rating',        (select rating from suppliers where id = v_sid),
    'review_count',  (select review_count from suppliers where id = v_sid),
    'quoted_rate',   (select case when count(*) = 0 then null
                        else round(100.0 * count(*) filter (where status <> 'draft') / count(*)) end
                      from quotes where supplier_id = v_sid),
    -- measured from when the customer asked to when the quote was actually sent
    'median_quote_hours', (select round((extract(epoch from percentile_cont(0.5) within group (
                              order by q.submitted_at - r.created_at)) / 3600.0)::numeric, 1)
                            from quotes q join event_requests r on r.id = q.request_id
                            where q.supplier_id = v_sid and q.submitted_at is not null),
    'delivery_rate', (select case when count(*) filter (where status in ('completed','cancelled')) = 0 then null
                        else round(100.0 * count(*) filter (where status = 'completed')
                                   / count(*) filter (where status in ('completed','cancelled'))) end
                      from bookings where supplier_id = v_sid),
    'kyc_state',     (select coalesce(max(status::text), 'not_started') from kyc_verification where supplier_id = v_sid),
    'payout_ready',  (select exists (select 1 from bank_accounts where supplier_id = v_sid)),
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
          'body','Case ' || d.ref || ' - ' || coalesce(d.summary,''), 'panel','disputes','cta','Open')
        from disputes d where d.against = auth.uid() and d.status in ('open','waiting_supplier')
        union all
        select jsonb_build_object('rank','3','tone','gold','title','Event coming up',
          'body', b.ref || ' on ' || to_char(b.event_date,'DD Mon YYYY') || ' - ' || b.guests || ' guests.',
          'panel','bookings','cta','View')
        from bookings b where b.supplier_id = v_sid and b.status = 'upcoming'
          and b.event_date between current_date and current_date + 30
      ) t), '[]'::jsonb),
    'activity', coalesce((
      select jsonb_agg(x order by x->>'at' desc) from (
        select jsonb_build_object('at', p.created_at, 'text',
          case p.kind when 'payout'  then 'Payout of '  || public.rupees(p.amount) || ' released for ' || b.ref
                      when 'deposit' then 'Deposit of ' || public.rupees(p.amount) || ' received for ' || b.ref
                      else 'Balance of ' || public.rupees(p.amount) || ' received for ' || b.ref end) as x
        from payments p join bookings b on b.id = p.booking_id
        where b.supplier_id = v_sid and p.state = 'paid'
        union all
        select jsonb_build_object('at', b.created_at,
          'text', 'Booking confirmed - ' || b.ref || ' for ' || to_char(b.event_date,'DD Mon YYYY') || '.')
        from bookings b where b.supplier_id = v_sid
        union all
        select jsonb_build_object('at', q.submitted_at,
          'text', 'Quote ' || q.ref || ' sent for ' || public.rupees(q.total) || '.')
        from quotes q where q.supplier_id = v_sid and q.submitted_at is not null
        union all
        select jsonb_build_object('at', e.created_at, 'text', 'Case ' || d.ref || ' - ' || e.action || '.')
        from dispute_events e join disputes d on d.id = e.dispute_id
        where d.against = auth.uid() or d.raised_by = auth.uid()
      ) t), '[]'::jsonb)
  ) into v_out;
  return v_out;
end $fn$;

-- Customer activity feed uses the same field for "quote received".
create or replace function public.customer_overview_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
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
        where r.customer_id = v_me and q.status = 'submitted' group by r.ref
        union all
        select jsonb_build_object('rank','2','tone','coral','title','Balance due before your event',
          'body', public.rupees(b.balance) || ' for ' || b.ref || ', due before ' ||
                  to_char(b.event_date - 21, 'DD Mon YYYY') || '.', 'panel','payments','cta','Pay')
        from bookings b where b.customer_id = v_me and b.status = 'upcoming' and b.balance > 0
        union all
        select jsonb_build_object('rank','3','tone','info','title','Request awaiting quotes',
          'body', r.ref || ' - ' || coalesce(r.event_type,'event') || ' on ' ||
                  to_char(r.event_date,'DD Mon YYYY') || '.', 'panel','briefs','cta','View')
        from event_requests r
        where r.customer_id = v_me and r.status in ('new','matched')
          and not exists (select 1 from quotes q where q.request_id = r.id and q.status <> 'draft')
        union all
        select jsonb_build_object('rank','4','tone','warning','title','Case waiting for your response',
          'body','Case ' || d.ref || ' - ' || coalesce(d.summary,''), 'panel','disputes','cta','Open')
        from disputes d where d.against = v_me and d.status in ('open','waiting_customer')
      ) t), '[]'::jsonb),
    'activity', coalesce((
      select jsonb_agg(x order by x->>'at' desc) from (
        select jsonb_build_object('at', p.created_at, 'text',
          case p.kind when 'deposit' then 'Deposit of ' || public.rupees(p.amount) || ' paid and held safely for ' || b.ref || '.'
                      when 'balance' then 'Balance of ' || public.rupees(p.amount) || ' paid for ' || b.ref || '.'
                      when 'refund'  then 'Refund of '  || public.rupees(p.amount) || ' issued for ' || b.ref || '.'
                      else 'Payment recorded for ' || b.ref || '.' end) as x
        from payments p join bookings b on b.id = p.booking_id
        where b.customer_id = v_me and p.state = 'paid' and p.kind <> 'payout'
        union all
        select jsonb_build_object('at', b.created_at,
          'text', 'Booking confirmed with ' || s.business_name || ' (' || b.ref || ').')
        from bookings b join suppliers s on s.id = b.supplier_id where b.customer_id = v_me
        union all
        select jsonb_build_object('at', q.submitted_at,
          'text', 'Quote received from ' || s.business_name || ' for ' || public.rupees(q.total) || '.')
        from quotes q join event_requests r on r.id = q.request_id join suppliers s on s.id = q.supplier_id
        where r.customer_id = v_me and q.submitted_at is not null
        union all
        select jsonb_build_object('at', r.created_at,
          'text', 'Request ' || r.ref || ' sent to matched venues and planners.')
        from event_requests r where r.customer_id = v_me
      ) t), '[]'::jsonb)
  ) into v_out;
  return v_out;
end $fn$;
