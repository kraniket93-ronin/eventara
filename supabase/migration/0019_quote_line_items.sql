-- ============================================================================
-- 0019_quote_line_items.sql
-- Gives the supplier dashboard a real quotation composer.
--
-- Before this, data-api.js setQuoteLineItems() did delete -> insert -> update
-- as three separate PostgREST calls. Two problems with that:
--   * It is not atomic. If the insert failed after the delete succeeded, the
--     quote silently lost every line item and kept its old total.
--   * subtotal / tax / total were computed in the browser and then written to
--     quotes. A modified client could send a total that did not match the sum
--     of its own line items - the number the customer sees and pays against.
--
-- Both are fixed by moving the whole operation into one SECURITY DEFINER
-- function that recomputes the money from the line items server-side. The
-- client sends descriptions, quantities and unit prices; the database decides
-- what the quote is worth.
--
-- Tax note: 18% GST, matching the rate already used in 0007_seed.sql and on
-- invoice.html. Held in one place (quote_tax_rate) so it is not re-typed.
-- ============================================================================

create or replace function public.quote_tax_rate() returns numeric
language sql immutable as $$ select 0.18::numeric $$;

-- ---------------------------------------------------------------------------
-- Guard: the signed-in user owns the supplier this quote belongs to
-- ---------------------------------------------------------------------------
create or replace function public.owns_quote(p_quote_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from quotes q join suppliers s on s.id = q.supplier_id
    where q.id = p_quote_id and s.owner = auth.uid()
  )
$$;

-- ---------------------------------------------------------------------------
-- save_quote_line_items - replace the whole set atomically, recompute money
--   p_items: [{"description":"Hall hire","qty":1,"unit_price":350000}, ...]
--   'amount' is deliberately NOT read from the client - it is qty * unit_price.
-- ---------------------------------------------------------------------------
create or replace function public.save_quote_line_items(
  p_quote_id    uuid,
  p_items       jsonb,
  p_notes       text default null,
  p_valid_until date default null
) returns quotes language plpgsql security definer set search_path = public as $$
declare
  v_q        quotes;
  v_subtotal integer := 0;
  v_tax      integer;
  v_row      jsonb;
  v_desc     text;
  v_qty      numeric;
  v_price    integer;
  v_amount   integer;
  v_i        integer := 0;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.owns_quote(p_quote_id) then
    raise exception 'this quote does not belong to you';
  end if;

  select * into v_q from quotes where id = p_quote_id;
  if v_q.status <> 'draft' then
    raise exception 'quote % is % - withdraw it to draft before editing', v_q.ref, v_q.status;
  end if;
  if jsonb_typeof(p_items) <> 'array' then
    raise exception 'line items must be an array';
  end if;

  delete from quote_line_items where quote_id = p_quote_id;

  for v_row in select * from jsonb_array_elements(p_items) loop
    v_desc  := btrim(coalesce(v_row->>'description', ''));
    v_qty   := coalesce((v_row->>'qty')::numeric, 1);
    v_price := coalesce((v_row->>'unit_price')::integer, 0);

    if v_desc = '' then raise exception 'every line needs a description'; end if;
    if v_qty <= 0 then raise exception 'quantity on "%" must be greater than zero', v_desc; end if;
    if v_price < 0 then raise exception 'unit price on "%" cannot be negative', v_desc; end if;

    v_amount   := round(v_qty * v_price);
    v_subtotal := v_subtotal + v_amount;

    insert into quote_line_items (quote_id, description, qty, unit_price, amount, sort)
    values (p_quote_id, v_desc, v_qty, v_price, v_amount, v_i);
    v_i := v_i + 1;
  end loop;

  v_tax := round(v_subtotal * public.quote_tax_rate());

  update quotes set
    subtotal    = v_subtotal,
    tax         = v_tax,
    total       = v_subtotal + v_tax,
    notes       = coalesce(nullif(btrim(coalesce(p_notes, '')), ''), notes),
    valid_until = coalesce(p_valid_until, valid_until),
    updated_at  = now()
  where id = p_quote_id
  returning * into v_q;

  return v_q;
end $$;

-- ---------------------------------------------------------------------------
-- submit_quote - a draft may only be sent once it actually prices something
-- ---------------------------------------------------------------------------
create or replace function public.submit_quote(p_quote_id uuid)
returns quotes language plpgsql security definer set search_path = public as $$
declare v_q quotes; v_items integer; v_cust uuid; v_name text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.owns_quote(p_quote_id) then
    raise exception 'this quote does not belong to you';
  end if;

  select * into v_q from quotes where id = p_quote_id;
  if v_q.status <> 'draft' then
    raise exception 'quote % is already %', v_q.ref, v_q.status;
  end if;

  select count(*) into v_items from quote_line_items where quote_id = p_quote_id;
  if v_items = 0 then raise exception 'add at least one line item before sending'; end if;
  if v_q.total <= 0 then raise exception 'the quote total is still zero'; end if;

  update quotes set status = 'submitted',
         valid_until = coalesce(valid_until, current_date + 14),
         updated_at = now()
   where id = p_quote_id returning * into v_q;

  -- Move the request along so the customer's panel reflects it too.
  update event_requests set status = 'quoted', updated_at = now()
   where id = v_q.request_id and status in ('new', 'matched');

  select r.customer_id into v_cust from event_requests r where r.id = v_q.request_id;
  select s.business_name into v_name from suppliers s where s.id = v_q.supplier_id;

  perform public.notify(v_cust, 'quote', 'New quote received',
    coalesce(v_name, 'A supplier') || ' sent a quote for your event request.',
    'customer-dashboard.html#briefs');

  return v_q;
end $$;

-- ---------------------------------------------------------------------------
-- withdraw_quote - back to draft so it can be edited again
-- ---------------------------------------------------------------------------
create or replace function public.withdraw_quote(p_quote_id uuid)
returns quotes language plpgsql security definer set search_path = public as $$
declare v_q quotes;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.owns_quote(p_quote_id) then
    raise exception 'this quote does not belong to you';
  end if;

  select * into v_q from quotes where id = p_quote_id;
  if v_q.status = 'accepted' then
    raise exception 'quote % was already accepted by the customer', v_q.ref;
  end if;
  if v_q.status <> 'submitted' then
    raise exception 'only a submitted quote can be withdrawn (this one is %)', v_q.status;
  end if;

  update quotes set status = 'draft', updated_at = now()
   where id = p_quote_id returning * into v_q;
  return v_q;
end $$;

-- ---------------------------------------------------------------------------
-- Seed: a live enquiry with a draft quote, so the composer has something to
-- work on. The existing seeded request/quote pair is already 'accepted', which
-- left the Enquiries panel with nothing actionable.
-- ---------------------------------------------------------------------------
insert into event_requests (id, ref, customer_id, event_type, event_date, guests, budget_band, city, status, details)
values ('66666666-6666-6666-6666-666666666667','EVT-2026-0051',
        '22222222-2222-2222-2222-222222222222',
        'conference','2026-11-18',260,'Rs 10-15L','Udaipur','matched',
        '{"brief":"Two-day regional sales conference. Need a plenary hall for 260, two breakout rooms, AV, and full-day catering."}'::jsonb)
on conflict (id) do nothing;

insert into quotes (id, ref, request_id, supplier_id, status, subtotal, tax, total, valid_until, notes)
values ('77777777-7777-7777-7777-777777777778','QT-2026-0051',
        '66666666-6666-6666-6666-666666666667','44444444-4444-4444-4444-444444444444',
        'draft', 0, 0, 0, null,
        'Draft - pricing the plenary hall, breakouts, AV and catering.')
on conflict (id) do nothing;

grant execute on function public.save_quote_line_items(uuid, jsonb, text, date) to authenticated;
grant execute on function public.submit_quote(uuid) to authenticated;
grant execute on function public.withdraw_quote(uuid) to authenticated;
grant execute on function public.owns_quote(uuid) to authenticated;
grant execute on function public.quote_tax_rate() to authenticated;
