-- ============================================================
-- 0027_submit_event_request.sql             [v2.24]
-- ------------------------------------------------------------
-- Connects the front door: turns a submitted brief into a real
-- event_requests row AND routes it to matched suppliers.
--
-- WHY AN RPC IS REQUIRED
-- ----------------------
-- A customer can insert their own event_requests row directly - RLS
-- allows it (req_customer: customer_id = auth.uid()). What they cannot
-- do is create the `quotes` rows that put the enquiry in a supplier's
-- inbox: quotes_supplier_write restricts INSERT to the supplier who
-- owns the row, correctly.
--
-- That matters because a supplier's Enquiries panel reads `quotes`
-- joined to `event_requests`, and req_supplier_read only exposes a
-- request to a supplier who has *already* been quoted into it. So a
-- bare insert creates a request that the customer can see and no
-- supplier ever will - the exact half-connected state recorded in the
-- v2.19 audit.
--
-- This function therefore does the whole hand-off in one transaction,
-- as the definer: insert the request, pick matching suppliers, open a
-- `draft` quote for each (which is what "a new enquiry" IS in this
-- schema), notify each supplier's owner, and mark the request matched.
--
-- SAFETY
-- ------
-- * SECURITY DEFINER with search_path pinned (0008 convention).
-- * The customer is taken from auth.uid(), never from a parameter, so
--   a caller cannot raise a request as somebody else.
-- * Supplier accounts are refused - a supplier raising a customer
--   enquiry against themselves would corrupt the funnel metrics.
-- * The quote insert is ON CONFLICT DO NOTHING against the existing
--   unique (request_id, supplier_id), so a double submit cannot
--   produce duplicate enquiries.
-- * EXECUTE is revoked from anon (0024 convention): sending a request
--   requires a session, so the anon key must not reach it.
--
-- Idempotent to APPLY (create or replace); each CALL creates one
-- request, by design.
-- ============================================================

begin;

create or replace function public.submit_event_request(
  p_event_type    text,
  p_event_date    date    default null,
  p_guests        int     default null,
  p_budget_band   text    default null,
  p_details       jsonb   default '{}'::jsonb,
  p_supplier_pref text    default 'both',
  p_max_matches   int     default 3
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer uuid := auth.uid();
  v_role     user_role;
  v_request  event_requests%rowtype;
  v_sup      record;
  v_matched  jsonb := '[]'::jsonb;
  v_count    int   := 0;
begin
  if v_customer is null then
    raise exception 'you must be signed in to send a request';
  end if;

  select role into v_role from profiles where id = v_customer;
  if v_role = 'supplier' then
    raise exception 'a business account cannot raise a customer request';
  end if;

  -- Phase 1 catalogue is enforced by the event_types FK plus its active
  -- flag, so weddings (active = false) cannot be requested even if a
  -- stale client still offers the option. B1/B2/B3.
  if p_event_type is not null and not exists (
       select 1 from event_types where code = p_event_type and active
     ) then
    raise exception 'that event type is not available yet';
  end if;

  insert into event_requests (customer_id, event_type, event_date, guests, budget_band, city, details)
  values (v_customer, p_event_type, p_event_date, p_guests, p_budget_band, 'Udaipur',
          coalesce(p_details, '{}'::jsonb))
  returning * into v_request;

  -- Matching. Deliberately simple and explainable rather than clever:
  -- active Udaipur suppliers, filtered by the customer's stated
  -- preference and by capacity when a guest count was given, ranked
  -- verified -> featured -> rating. A real matching engine is Phase 2;
  -- this is honest about being a rule, not a model.
  for v_sup in
    select s.id, s.owner, s.business_name, s.slug
      from suppliers s
     where s.status = 'active'
       and s.city   = 'Udaipur'
       and ( p_supplier_pref = 'both'
             or (p_supplier_pref = 'venue'         and s.category = 'banquet_hotel')
             or (p_supplier_pref = 'event-manager' and s.category = 'event_manager') )
       and ( p_guests is null or s.capacity is null or s.capacity >= p_guests )
     order by s.verified desc, s.featured desc, s.rating desc, s.business_name
     limit greatest(coalesce(p_max_matches, 3), 1)
  loop
    insert into quotes (request_id, supplier_id, status)
    values (v_request.id, v_sup.id, 'draft')
    on conflict (request_id, supplier_id) do nothing;

    perform public.notify(
      v_sup.owner,
      'enquiry'::notif_kind,
      'New enquiry - ' || coalesce(v_request.ref, 'request'),
      coalesce(initcap(v_request.event_type), 'Event')
        || coalesce(' for ' || v_request.guests::text || ' guests', '')
        || coalesce(' on ' || to_char(v_request.event_date, 'DD Mon YYYY'), '')
        || '. Please respond within 48 hours.',
      'supplier-dashboard.html#enquiries'
    );

    v_matched := v_matched || jsonb_build_object(
      'id', v_sup.id, 'name', v_sup.business_name, 'slug', v_sup.slug);
    v_count := v_count + 1;
  end loop;

  if v_count > 0 then
    update event_requests set status = 'matched' where id = v_request.id;
  end if;

  return jsonb_build_object(
    'id',      v_request.id,
    'ref',     v_request.ref,
    'status',  case when v_count > 0 then 'matched' else 'new' end,
    'matched', v_matched
  );
end $$;

comment on function public.submit_event_request(text, date, int, text, jsonb, text, int)
  is 'Creates an event_requests row for the signed-in customer and opens a draft quote + notification for each matched supplier. See 0027.';

-- 0024 convention: a session is required, so anon must not hold EXECUTE.
revoke all on function public.submit_event_request(text, date, int, text, jsonb, text, int) from public;
revoke all on function public.submit_event_request(text, date, int, text, jsonb, text, int) from anon;
grant execute on function public.submit_event_request(text, date, int, text, jsonb, text, int) to authenticated;

commit;

-- ------------------------------------------------------------
-- Verification (as a signed-in customer):
--
--   select public.submit_event_request(
--     'conference', current_date + 60, 140, '5l-10l',
--     '{"requirements":["venue","catering"]}'::jsonb, 'both', 3);
--
-- Expect: {"id":..., "ref":"EVT-2026-00NN", "status":"matched",
--          "matched":[{...},{...},{...}]}
-- Then:   select ref, status from event_requests order by created_at desc limit 1;
--         select supplier_id, status from quotes where request_id = '<id>';
-- ------------------------------------------------------------
