-- ============================================================================
-- Eventara backend — 0016_fix_rls_recursion_requests_quotes.sql
--
-- BUG (pre-existing since 0002_rls.sql, latent until the dashboards actually
-- read these tables as a signed-in user):
--
--   event_requests.req_supplier_read  ->  subquery on quotes
--   quotes.quotes_parties             ->  subquery on event_requests
--
-- Each policy's subquery triggers the other table's RLS, which triggers the
-- first again: Postgres aborts with 42P17 "infinite recursion detected in
-- policy". The effect was that a signed-in customer could not read ANY
-- event_requests or quotes row at all - SELECT * returned an error, not rows.
--
-- Fix: move each cross-table check into a SECURITY DEFINER helper. A definer
-- function runs with the owner's rights and therefore does NOT re-enter the
-- other table's RLS, breaking the cycle. This is the same technique already
-- used by is_admin() / owns_supplier() elsewhere in this schema, and it does
-- not widen access: each helper answers exactly the question the policy asked.
-- Apply after 0015_set_booking_status_rpc.sql.
-- ============================================================================

create or replace function public.supplier_quoted_on_request(p_request uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from quotes q join suppliers s on s.id = q.supplier_id
    where q.request_id = p_request and s.owner = auth.uid()
  )
$$;

create or replace function public.customer_owns_request(p_request uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from event_requests r
    where r.id = p_request and r.customer_id = auth.uid()
  )
$$;

-- event_requests: customer owns it, or the supplier has been quoted into it.
drop policy if exists req_supplier_read on event_requests;
create policy req_supplier_read on event_requests for select
  using (public.supplier_quoted_on_request(id));

-- quotes: admin, the owning supplier, or the customer behind the request.
drop policy if exists quotes_parties on quotes;
create policy quotes_parties on quotes for select
  using (
    public.is_admin()
    or public.owns_supplier(supplier_id)
    or public.customer_owns_request(request_id)
  );

-- quote_line_items had the same shape of nested lookup through quotes; route
-- it through a definer helper too so it cannot reintroduce the cycle.
create or replace function public.can_read_quote(p_quote uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from quotes q
    where q.id = p_quote
      and ( public.is_admin()
            or exists (select 1 from suppliers s where s.id = q.supplier_id and s.owner = auth.uid())
            or exists (select 1 from event_requests r where r.id = q.request_id and r.customer_id = auth.uid()) )
  )
$$;

drop policy if exists li_parties on quote_line_items;
create policy li_parties on quote_line_items for select
  using (public.can_read_quote(quote_id));

-- ============================================================================
-- end 0016_fix_rls_recursion_requests_quotes.sql
-- ============================================================================
