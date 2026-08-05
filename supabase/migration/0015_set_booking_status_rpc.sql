-- ============================================================================
-- Eventara backend — 0015_set_booking_status_rpc.sql
-- Booking status transitions + timeline, as one server-side operation.
--
-- Why an RPC rather than a client-side update: booking_events is
-- admin-write-only (0013) because a timeline the actors can freely rewrite is
-- not an audit trail. This function is SECURITY DEFINER, re-checks that the
-- caller actually owns the supplier (or is the customer/admin), enforces the
-- legal transitions, and writes the booking row + its timeline entry
-- together so they can never drift apart.
-- Apply after 0014_fix_customer_profile_seed.sql.
-- ============================================================================

create or replace function public.set_booking_status(p_booking uuid, p_to booking_status, p_note text default null)
returns bookings language plpgsql security definer set search_path = public as $$
declare b bookings; v_from booking_status;
begin
  select * into b from bookings where id = p_booking;
  if b is null then raise exception 'booking not found'; end if;

  if not (public.owns_supplier(b.supplier_id) or b.customer_id = auth.uid() or public.is_admin()) then
    raise exception 'not authorized for this booking';
  end if;

  v_from := b.status;
  if v_from = p_to then return b; end if;

  -- Forward-only lifecycle. Cancellation deliberately excluded: it moves
  -- money (escrow refund) and belongs to cancel_booking().
  if not (
       (v_from = 'upcoming'  and p_to = 'ongoing')
    or (v_from = 'ongoing'   and p_to = 'completed')
    or (v_from = 'upcoming'  and p_to = 'completed')
    or public.is_admin()
  ) then
    raise exception 'illegal transition % -> %', v_from, p_to;
  end if;

  update bookings set status = p_to where id = p_booking returning * into b;

  insert into booking_events (booking_id, actor_id, event, from_state, to_state, note)
  values (p_booking, auth.uid(), 'status_changed', v_from::text, p_to::text, p_note);

  -- Tell the other side.
  perform public.notify(b.customer_id, 'booking',
    'Booking ' || p_to::text,
    'Booking ' || coalesce(b.ref,'') || ' is now ' || p_to::text || '.',
    'customer-dashboard.html#bookings');

  return b;
end $$;
alter function public.set_booking_status(uuid, booking_status, text) set search_path = public;

-- Backfill a 'created' timeline entry for bookings that predate this table,
-- so the timeline is never mysteriously empty for existing demo bookings.
insert into booking_events (booking_id, actor_id, event, to_state, note, created_at)
select b.id, b.customer_id, 'created', b.status::text, 'Booking created', b.created_at
from bookings b
where not exists (select 1 from booking_events e where e.booking_id = b.id);

-- ============================================================================
-- end 0015_set_booking_status_rpc.sql
-- ============================================================================
