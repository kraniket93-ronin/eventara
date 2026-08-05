-- ============================================================================
-- 0024_rpc_execute_hardening.sql
--
-- Found by running Supabase's security advisor after the v2.12 work. Two
-- issues, one of which is genuinely exploitable.
--
--   1. EXECUTE was never revoked from the anon role on any RPC.
--      0008_security_hardening.sql revoked public EXECUTE on the *trigger*
--      functions, but every callable RPC still carried the default PUBLIC
--      grant. Because PostgREST exposes every function at /rest/v1/rpc/<name>,
--      an unauthenticated request could invoke them with only the anon key.
--
--      Most of them fail closed anyway - they check auth.uid() or read
--      nothing an anonymous caller could use. `notify()` does not. It is
--      SECURITY DEFINER and takes the recipient as a parameter, so anyone
--      holding the (public, by design) anon key could push an arbitrary
--      notification into any user's feed - a convincing spoof, since it
--      renders identically to a real platform message. That is the one worth
--      fixing urgently; the rest are defence in depth.
--
--   2. quote_tax_rate() and rupees() were added in 0019/0020 without a pinned
--      search_path, breaking the convention 0008 established.
--
-- What deliberately KEEPS anon EXECUTE: search_suppliers and
-- get_similar_suppliers (the public search and supplier pages call them while
-- signed out), and the small policy helpers - is_admin, current_role,
-- owns_supplier, can_read_quote, customer_owns_request,
-- supplier_quoted_on_request, shares_booking_with_profile. RLS policies are
-- evaluated as the *querying* role, so anon must be able to execute the
-- helpers used by policies on world-readable tables. Revoking those would
-- break the public marketplace pages.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Pin search_path on the two helpers added in 0019 / 0020
-- ---------------------------------------------------------------------------
alter function public.quote_tax_rate()   set search_path = public;
alter function public.rupees(integer)    set search_path = public;

-- ---------------------------------------------------------------------------
-- 2. Internal-only functions: called from inside other SECURITY DEFINER
--    functions and triggers, which run as the function owner - so no caller
--    needs EXECUTE. Remove them from the REST surface entirely.
-- ---------------------------------------------------------------------------
revoke execute on function public.notify(uuid, notif_kind, text, text, text)     from public, anon, authenticated;
revoke execute on function public.calculate_supplier_rating(uuid)                from public, anon, authenticated;
revoke execute on function public.dispute_counterparty(uuid, uuid)               from public, anon, authenticated;
revoke execute on function public.owns_quote(uuid)                               from public, anon, authenticated;
-- a trigger function 0008's sweep missed
revoke execute on function public.trg_set_supplier_slug()                        from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Session-required RPCs: signed-in callers only.
--    Revoke the blanket PUBLIC/anon grant, then re-grant to authenticated.
-- ---------------------------------------------------------------------------
do $$
declare
  fn text;
  session_rpcs text[] := array[
    'accept_quote(uuid)',
    'reject_quote(uuid)',
    'create_booking(uuid, integer)',
    'cancel_booking(uuid, text)',
    'release_escrow(uuid)',
    'generate_invoice(uuid, invoice_type)',
    'set_booking_status(uuid, booking_status, text)',
    'update_availability(uuid, date, avail_state, text)',
    'supplier_dashboard_stats(uuid)',
    'customer_dashboard_stats(uuid)',
    'raise_dispute(uuid, dispute_kind, dispute_priority, text)',
    'add_dispute_event(uuid, text, text)',
    'get_my_disputes()',
    'disputable_bookings()',
    'save_quote_line_items(uuid, jsonb, text, date)',
    'submit_quote(uuid)',
    'withdraw_quote(uuid)',
    'supplier_overview_stats()',
    'customer_overview_stats()',
    'my_payments()',
    'quote_tax_rate()',
    'rupees(integer)'
  ];
begin
  foreach fn in array session_rpcs loop
    execute format('revoke execute on function public.%s from public, anon', fn);
    execute format('grant  execute on function public.%s to authenticated',  fn);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Confirm the two genuinely public RPCs still work for anon
-- ---------------------------------------------------------------------------
grant execute on function public.search_suppliers(text, integer, integer, date) to anon, authenticated;
grant execute on function public.get_similar_suppliers(uuid, integer)           to anon, authenticated;
