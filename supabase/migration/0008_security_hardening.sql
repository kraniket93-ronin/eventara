-- ============================================================================
-- Eventara backend — 0008_security_hardening.sql
-- Closes WARN-level findings from Supabase's security advisor after the
-- initial apply of 0001-0007 against the live "Eventara" project.
-- Apply after 0007_seed.sql.
-- ============================================================================

-- Pin search_path on helper functions the linter flagged as mutable.
alter function public.next_ref(text, text) set search_path = public;
alter function public.set_updated_at() set search_path = public;
alter function public.generate_invoice_number() set search_path = public;
alter function public.trg_set_request_ref() set search_path = public;
alter function public.trg_set_quote_ref() set search_path = public;
alter function public.trg_set_dispute_ref() set search_path = public;

-- These functions must only ever run as triggers (auth.users insert, or
-- table-level after-triggers) or be called internally by other SECURITY
-- DEFINER functions. They were never meant to be public RPC endpoints -
-- revoke direct execute from anon/authenticated.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.trg_audit() from public, anon, authenticated;
revoke execute on function public.trg_payment_after() from public, anon, authenticated;
revoke execute on function public.trg_review_after() from public, anon, authenticated;
revoke execute on function public.trg_supplier_verified() from public, anon, authenticated;

-- ============================================================================
-- end 0008_security_hardening.sql
-- ============================================================================
