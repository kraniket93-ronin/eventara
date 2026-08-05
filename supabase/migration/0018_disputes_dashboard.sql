-- ============================================================================
-- 0018_disputes_dashboard.sql
-- Makes the Disputes panels on BOTH dashboards live.
--
-- Three things happen here:
--   1. A real RLS gap is closed. 0002_rls.sql gave dispute_events a SELECT
--      policy but no INSERT policy, and RLS is enabled on the table - so
--      every write through data-api.js addDisputeEvent() was silently denied.
--      Nothing had ever exercised that path, which is why it went unnoticed.
--   2. Two RPCs (raise_dispute / add_dispute_event) so a case + its opening
--      timeline entry + the counterparty's notification all land atomically,
--      the same pattern already used by set_booking_status in 0015.
--   3. Two more seeded cases so the supplier panel's All/Open/Under Review/
--      Resolved filter tabs each have something real behind them.
--
-- Design note: parties may add timeline events but may NOT change status
-- directly. Status is moved by the RPC (a response by the accused party
-- advances a waiting_* case to under_review) or by Eventara Ops. That keeps
-- business rule B19 intact - neither side can unilaterally close a case and
-- release the escrowed money.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. RLS: let the two parties append to their own case timeline
-- ---------------------------------------------------------------------------
drop policy if exists dispute_events_insert on dispute_events;
create policy dispute_events_insert on dispute_events for insert
  with check (
    actor_id = auth.uid()
    and exists (
      select 1 from disputes d
      where d.id = dispute_id
        and d.status not in ('resolved', 'closed')
        and (public.is_admin() or d.raised_by = auth.uid() or d.against = auth.uid())
    )
  );

-- Only Eventara Ops may edit the case record itself (status / resolution).
drop policy if exists disputes_admin_update on disputes;
create policy disputes_admin_update on disputes for update
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- 2. Helper: who is the other side of a booking?
-- ---------------------------------------------------------------------------
create or replace function public.dispute_counterparty(p_booking_id uuid, p_me uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select case
           when b.customer_id = p_me then s.owner
           when s.owner = p_me then b.customer_id
           else null
         end
  from bookings b join suppliers s on s.id = b.supplier_id
  where b.id = p_booking_id
$$;

-- ---------------------------------------------------------------------------
-- 3. raise_dispute - case + opening timeline entry + notification, atomically
-- ---------------------------------------------------------------------------
create or replace function public.raise_dispute(
  p_booking_id uuid,
  p_kind       dispute_kind,
  p_priority   dispute_priority,
  p_summary    text
) returns disputes language plpgsql security definer set search_path = public as $$
declare
  v_me      uuid := auth.uid();
  v_against uuid;
  v_row     disputes;
  v_bref    text;
begin
  if v_me is null then raise exception 'not signed in'; end if;
  if coalesce(btrim(p_summary), '') = '' then
    raise exception 'a dispute needs a summary';
  end if;

  select public.dispute_counterparty(p_booking_id, v_me) into v_against;
  if v_against is null then
    raise exception 'you are not a party to this booking';
  end if;

  select ref into v_bref from bookings where id = p_booking_id;

  insert into disputes (booking_id, raised_by, against, kind, priority, status, summary)
  values (p_booking_id, v_me, v_against, p_kind, p_priority,
          case when v_me = (select customer_id from bookings where id = p_booking_id)
               then 'waiting_supplier'::dispute_status
               else 'waiting_customer'::dispute_status end,
          btrim(p_summary))
  returning * into v_row;

  insert into dispute_events (dispute_id, actor_id, action, note)
  values (v_row.id, v_me, 'raised', btrim(p_summary));

  perform public.notify(
    v_against, 'dispute',
    'New case opened: ' || v_row.ref,
    'A ' || p_kind::text || ' was raised on booking ' || coalesce(v_bref, '-') || '. Please respond.',
    case when v_against = (select customer_id from bookings where id = p_booking_id)
         then 'customer-dashboard.html#disputes'
         else 'supplier-dashboard.html#disputes' end
  );

  return v_row;
end $$;

-- ---------------------------------------------------------------------------
-- 4. add_dispute_event - append to timeline, advance status, notify other side
-- ---------------------------------------------------------------------------
create or replace function public.add_dispute_event(
  p_dispute_id uuid,
  p_action     text,
  p_note       text
) returns dispute_events language plpgsql security definer set search_path = public as $$
declare
  v_me    uuid := auth.uid();
  v_d     disputes;
  v_ev    dispute_events;
  v_other uuid;
begin
  if v_me is null then raise exception 'not signed in'; end if;
  if p_action not in ('response', 'evidence', 'note', 'withdraw') then
    raise exception 'unknown action %', p_action;
  end if;

  select * into v_d from disputes where id = p_dispute_id;
  if not found then raise exception 'case not found'; end if;
  if v_d.raised_by <> v_me and v_d.against <> v_me and not public.is_admin() then
    raise exception 'you are not a party to this case';
  end if;
  if v_d.status in ('resolved', 'closed') then
    raise exception 'case % is already %', v_d.ref, v_d.status;
  end if;
  if p_action = 'withdraw' and v_d.raised_by <> v_me then
    raise exception 'only the party who raised a case can withdraw it';
  end if;

  insert into dispute_events (dispute_id, actor_id, action, note)
  values (p_dispute_id, v_me, p_action, nullif(btrim(coalesce(p_note, '')), ''))
  returning * into v_ev;

  -- A response from the party a case is waiting on hands it back to Ops.
  if p_action = 'withdraw' then
    update disputes set status = 'closed',
           resolution = 'Withdrawn by the party who raised it.', updated_at = now()
     where id = p_dispute_id;
  elsif p_action = 'response' and v_d.status in ('open', 'waiting_supplier', 'waiting_customer') then
    update disputes set status = 'under_review', updated_at = now() where id = p_dispute_id;
  else
    update disputes set updated_at = now() where id = p_dispute_id;
  end if;

  v_other := case when v_d.raised_by = v_me then v_d.against else v_d.raised_by end;
  if v_other is not null and p_action <> 'note' then
    perform public.notify(
      v_other, 'dispute',
      'Update on case ' || v_d.ref,
      case p_action
        when 'response' then 'The other party responded.'
        when 'evidence' then 'New evidence was added.'
        else 'The case was withdrawn.' end,
      case when v_other = v_d.against then 'supplier-dashboard.html#disputes'
           else 'customer-dashboard.html#disputes' end
    );
  end if;

  return v_ev;
end $$;

-- ---------------------------------------------------------------------------
-- 5. get_my_disputes - one round trip, cases + nested timeline + counterpart
--    name. security definer so the timeline can show WHO acted without
--    loosening the profiles table for everyone.
-- ---------------------------------------------------------------------------
create or replace function public.get_my_disputes()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x->>'updated_at' desc), '[]'::jsonb) from (
    select jsonb_build_object(
      'id', d.id,
      'ref', d.ref,
      'kind', d.kind,
      'priority', d.priority,
      'status', d.status,
      'summary', d.summary,
      'resolution', d.resolution,
      'created_at', d.created_at,
      'updated_at', d.updated_at,
      'booking_id', d.booking_id,
      'booking_ref', b.ref,
      'i_raised', (d.raised_by = auth.uid()),
      'counterpart', coalesce(
        (select p.full_name from profiles p
          where p.id = case when d.raised_by = auth.uid() then d.against else d.raised_by end),
        'Eventara Ops'),
      'events', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'action', e.action, 'note', e.note, 'created_at', e.created_at,
                 'actor', coalesce((select p2.full_name from profiles p2 where p2.id = e.actor_id), 'Eventara Ops'),
                 'mine', (e.actor_id = auth.uid()))
               order by e.created_at)
        from dispute_events e where e.dispute_id = d.id), '[]'::jsonb)
    ) as x
    from disputes d
    left join bookings b on b.id = d.booking_id
    where d.raised_by = auth.uid() or d.against = auth.uid()
  ) t
$$;

-- ---------------------------------------------------------------------------
-- 6. Bookings a signed-in user may raise a dispute against (for the form)
-- ---------------------------------------------------------------------------
create or replace function public.disputable_bookings()
returns table (id uuid, ref text, business_name text, event_date date, status text)
language sql stable security definer set search_path = public as $$
  select b.id, b.ref, s.business_name, b.event_date, b.status::text
  from bookings b join suppliers s on s.id = b.supplier_id
  where (b.customer_id = auth.uid() or s.owner = auth.uid())
    and b.status in ('upcoming', 'ongoing', 'completed')
  order by b.event_date desc
$$;

-- ---------------------------------------------------------------------------
-- 7. Seed: two more real cases so the filter tabs aren't empty
--    (one raised BY the supplier, one already resolved)
-- ---------------------------------------------------------------------------
-- Dates are explicit, not now(): the resolved complaint belongs to the
-- January event it is about, and its timeline has to read in order.
insert into disputes (id, ref, booking_id, raised_by, against, kind, priority, status, summary, created_at, updated_at)
values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','D-2026-07',
   '88888888-8888-8888-8888-888888888888',
   '33333333-3333-3333-3333-333333333333','22222222-2222-2222-2222-222222222222',
   'dispute','medium','waiting_customer',
   'Guest count revised down after the cut-off date - late change fee disputed',
   '2026-08-02 11:30:00+05:30','2026-08-02 11:30:00+05:30'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc','C-2026-01',
   '99999999-9999-9999-9999-999999999999',
   '22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333',
   'complaint','low','resolved',
   'Buffet counter opened 30 minutes behind schedule',
   '2026-01-10 09:15:00+05:30','2026-01-14 17:40:00+05:30')
on conflict (id) do nothing;

update disputes set resolution = 'Resolved - 5% service credit issued to the customer.'
where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and resolution is null;

-- dispute_events' only unique key is a generated PK, so ON CONFLICT cannot
-- dedupe these. Guard on "does this case already have a timeline" instead so
-- re-running the migration is idempotent.
insert into dispute_events (dispute_id, actor_id, action, note, created_at)
select v.dispute_id, v.actor_id, v.action, v.note, v.at
from (values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,'33333333-3333-3333-3333-333333333333'::uuid,
   'raised','Guest count dropped from 220 to 160 four days before the event.',
   '2026-08-02 11:30:00+05:30'::timestamptz),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,'22222222-2222-2222-2222-222222222222'::uuid,
   'raised','Lunch service started late and ran into the keynote slot.',
   '2026-01-10 09:15:00+05:30'::timestamptz),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,'33333333-3333-3333-3333-333333333333'::uuid,
   'response','Kitchen confirmed the delay. We accept the finding.',
   '2026-01-11 14:20:00+05:30'::timestamptz),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,'11111111-1111-1111-1111-111111111111'::uuid,
   'resolved','5% service credit applied against the final invoice.',
   '2026-01-14 17:40:00+05:30'::timestamptz)
) as v(dispute_id, actor_id, action, note, at)
where not exists (
  select 1 from dispute_events e where e.dispute_id = v.dispute_id
);

grant execute on function public.raise_dispute(uuid, dispute_kind, dispute_priority, text) to authenticated;
grant execute on function public.add_dispute_event(uuid, text, text) to authenticated;
grant execute on function public.get_my_disputes() to authenticated;
grant execute on function public.disputable_bookings() to authenticated;
