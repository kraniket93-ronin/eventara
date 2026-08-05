-- ============================================================================
-- Eventara backend — 0017_supplier_can_read_booked_customer.sql
--
-- BUG (pre-existing, same family as 0016, surfaced by wiring the supplier
-- Bookings panel): v_supplier_dashboard does
--     join profiles p on p.id = b.customer_id
-- but profiles' only SELECT policy is `id = auth.uid()`. The view is
-- security_invoker, so for a supplier the join found no profile row and the
-- INNER JOIN silently dropped every booking - the panel showed "no bookings"
-- while two bookings existed.
--
-- Product fix, not a hack: §11 B17 says customer contact details stay private
-- *until a booking is confirmed*. Once there is a confirmed booking, the
-- supplier legitimately needs to know who they are hosting. So: a supplier may
-- read the profile of a customer they share a booking with - and nobody else.
--
-- Uses a SECURITY DEFINER helper so the profiles policy does not re-enter
-- bookings' RLS (the 0016 recursion lesson).
-- Apply after 0016_fix_rls_recursion_requests_quotes.sql.
-- ============================================================================

create or replace function public.shares_booking_with_profile(p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from bookings b
    join suppliers s on s.id = b.supplier_id
    where b.customer_id = p_profile
      and s.owner = auth.uid()
  )
$$;

drop policy if exists profiles_booked_supplier_read on profiles;
create policy profiles_booked_supplier_read on profiles for select
  using (public.shares_booking_with_profile(id));

-- ============================================================================
-- end 0017_supplier_can_read_booked_customer.sql
-- ============================================================================
