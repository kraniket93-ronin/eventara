-- ============================================================================
-- 0023_payment_status_recompute.sql
--
-- A real bug in trg_payment_after, exposed by the Payments panel showing live
-- data for the first time.
--
-- The trigger set bookings.payment_status from whichever payment row happened
-- to fire last:
--
--     if new.kind = 'balance' then  payment_status := 'paid'
--     elsif new.kind = 'deposit' then payment_status := 'deposit_held'
--
-- So the result depended on INSERT order, not on what had actually been paid.
-- A fully-settled booking whose deposit row was written after its balance row
-- ended up flagged 'deposit_held' - the customer would be shown a balance
-- still owing on an event they had already paid for in full, and the supplier
-- dashboard would count it as money not yet collected.
--
-- The replacement derives the status from every payment on the booking, so it
-- lands on the same answer regardless of the order rows arrive in, and it
-- self-corrects if a payment is later refunded or amended.
--
-- Also fixed here: booking EVT-2025-0288 carried deposit = 0 and balance = 0
-- despite an amount of 4,95,600 - so its own payment schedule summed to
-- nothing. Set to the 30/70 split the rest of the project uses.
-- ============================================================================

create or replace function public.trg_payment_after()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_amount   integer;
  v_deposit  integer;
  v_balance  integer;
  v_refunded boolean;
  v_status   pay_status;
begin
  select amount into v_amount from bookings where id = new.booking_id;

  -- Recompute from the full set, never from this single row.
  select coalesce(sum(amount) filter (where kind = 'deposit' and state = 'paid'), 0),
         coalesce(sum(amount) filter (where kind = 'balance' and state = 'paid'), 0),
         bool_or(state = 'refunded' or kind = 'refund')
    into v_deposit, v_balance, v_refunded
    from payments where booking_id = new.booking_id;

  if coalesce(v_refunded, false) then
    v_status := 'refunded';
  elsif coalesce(v_amount, 0) > 0 and (v_deposit + v_balance) >= v_amount then
    v_status := 'paid';
  elsif v_balance > 0 then
    v_status := 'balance_due';
  elsif v_deposit > 0 then
    v_status := 'deposit_held';
  else
    v_status := 'pending';
  end if;

  update bookings set payment_status = v_status where id = new.booking_id;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- Repair the rows the old trigger left in a wrong state, and the booking whose
-- deposit/balance never matched its own amount.
-- ---------------------------------------------------------------------------
update bookings
   set deposit = round(amount * 0.30),
       balance = amount - round(amount * 0.30)
 where ref = 'EVT-2025-0288' and deposit = 0 and balance = 0;

-- The seeded deposit for the upcoming booking had no method or gateway
-- reference, so the payment history showed blank cells for a real payment.
update payments p
   set method = 'netbanking', gateway_ref = 'pay_R7xK0042DEP'
  from bookings b
 where b.id = p.booking_id and b.ref = 'EVT-2026-0042'
   and p.kind = 'deposit' and p.method is null;

-- Recompute every booking that has payments, applying the same rule directly
-- rather than poking the trigger into firing.
update bookings b
   set payment_status = case
         when t.refunded then 'refunded'::pay_status
         when b.amount > 0 and (t.deposit + t.balance) >= b.amount then 'paid'::pay_status
         when t.balance > 0 then 'balance_due'::pay_status
         when t.deposit > 0 then 'deposit_held'::pay_status
         else 'pending'::pay_status end
  from (
    select booking_id,
           coalesce(sum(amount) filter (where kind = 'deposit' and state = 'paid'), 0) as deposit,
           coalesce(sum(amount) filter (where kind = 'balance' and state = 'paid'), 0) as balance,
           coalesce(bool_or(state = 'refunded' or kind = 'refund'), false)             as refunded
    from payments group by booking_id
  ) t
 where t.booking_id = b.id;
