-- ============================================================================
-- Eventara backend — 0003_functions.sql
-- Business logic as SECURITY DEFINER RPCs (safe: search_path pinned to public).
-- Callable from the front-end via supabase.rpc('fn', {...}).
-- ============================================================================

-- Sequences for human-readable refs
create sequence if not exists seq_evt;
create sequence if not exists seq_quote;
create sequence if not exists seq_booking;
create sequence if not exists seq_invoice;
create sequence if not exists seq_dispute;

create or replace function public.next_ref(p_prefix text, p_seq text)
returns text language plpgsql as $$
declare n bigint;
begin
  execute format('select nextval(%L)', p_seq) into n;
  return p_prefix || '-' || extract(year from now())::int || '-' || lpad(n::text, 4, '0');
end $$;

-- generic updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- Invoice number
create or replace function public.generate_invoice_number()
returns text language sql as $$
  select 'EVT/INV/' || extract(year from now())::int || '/' || lpad(nextval('seq_invoice')::text, 4, '0')
$$;

-- ---------------------------------------------------------------------------
-- New auth user -> profile (+ role-specific profile + preferences)
-- Reads role/name from the signup metadata; defaults to 'customer'.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_role user_role;
begin
  v_role := coalesce((new.raw_user_meta_data->>'role')::user_role, 'customer');
  insert into profiles (id, role, full_name, email)
    values (new.id, v_role, new.raw_user_meta_data->>'full_name', new.email)
    on conflict (id) do nothing;
  insert into user_preferences (profile_id) values (new.id) on conflict do nothing;
  if v_role = 'customer' then
    insert into customer_profiles (profile_id, org_name)
      values (new.id, new.raw_user_meta_data->>'org_name') on conflict do nothing;
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- notify(): insert a notification row (Realtime pushes it to the client)
-- ---------------------------------------------------------------------------
create or replace function public.notify(p_recipient uuid, p_kind notif_kind, p_title text, p_body text default null, p_link text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  insert into notifications (recipient, kind, title, body, link)
    values (p_recipient, p_kind, p_title, p_body, p_link) returning id into v_id;
  return v_id;
end $$;

-- ---------------------------------------------------------------------------
-- calculate_supplier_rating(): recompute rating rollup from published reviews
-- ---------------------------------------------------------------------------
create or replace function public.calculate_supplier_rating(p_supplier uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update suppliers s set
    rating = coalesce((select round(avg(rating)::numeric, 1) from reviews where supplier_id = p_supplier and status='published'), 0),
    review_count = (select count(*) from reviews where supplier_id = p_supplier and status='published')
  where s.id = p_supplier;
end $$;

-- ---------------------------------------------------------------------------
-- update_availability(): supplier sets a day's state
-- ---------------------------------------------------------------------------
create or replace function public.update_availability(p_supplier uuid, p_day date, p_state avail_state, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.owns_supplier(p_supplier) or public.is_admin()) then
    raise exception 'not authorized';
  end if;
  insert into availability (supplier_id, day, state, note) values (p_supplier, p_day, p_state, p_note)
    on conflict (supplier_id, day) do update set state = excluded.state, note = excluded.note, updated_at = now();
end $$;

-- ---------------------------------------------------------------------------
-- create_booking(): the canonical "accept quote -> booking" transaction.
-- Validates the caller is the customer on the request; creates the booking,
-- marks the quote accepted and siblings rejected, books the date, opens an
-- escrow hold for the deposit, and notifies both sides. Returns booking id.
-- ---------------------------------------------------------------------------
create or replace function public.create_booking(p_quote uuid, p_deposit_pct int default 30)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  q record; v_booking uuid; v_deposit int; v_commission int; v_ref text;
  v_customer uuid; v_supplier_owner uuid;
begin
  select qt.*, r.customer_id, r.event_date, r.guests
    into q from quotes qt join event_requests r on r.id = qt.request_id
    where qt.id = p_quote;
  if q is null then raise exception 'quote not found'; end if;

  v_customer := q.customer_id;
  if not (v_customer = auth.uid() or public.is_admin()) then
    raise exception 'only the requesting customer may accept this quote';
  end if;

  v_deposit := round(q.total * p_deposit_pct / 100.0);
  v_commission := round(q.total * 0.07);              -- 7% platform take
  v_ref := public.next_ref('EVT', 'seq_booking');

  insert into bookings (ref, quote_id, request_id, customer_id, supplier_id, event_date, guests,
                        amount, deposit, balance, commission, net_payout, status, payment_status)
    values (v_ref, q.id, q.request_id, v_customer, q.supplier_id, q.event_date, q.guests,
            q.total, v_deposit, q.total - v_deposit, v_commission, q.total - v_commission,
            'upcoming', 'deposit_held')
    returning id into v_booking;

  update quotes set status = 'accepted' where id = p_quote;
  update quotes set status = 'rejected' where request_id = q.request_id and id <> p_quote and status = 'submitted';
  update event_requests set status = 'accepted' where id = q.request_id;

  -- book the date (source of truth) + escrow hold for the deposit
  insert into availability (supplier_id, day, state, booking_id) values (q.supplier_id, q.event_date, 'booked', v_booking)
    on conflict (supplier_id, day) do update set state='booked', booking_id=v_booking, updated_at=now();
  insert into escrow_transactions (booking_id, amount, state) values (v_booking, v_deposit, 'held');
  insert into payments (booking_id, kind, amount, state) values (v_booking, 'deposit', v_deposit, 'paid');
  insert into wallet_ledger (owner_type, owner_id, entry, amount, ref_type, ref_id, description)
    values ('platform', null, 'credit', v_deposit, 'escrow', v_booking, 'Deposit held in escrow');

  select owner into v_supplier_owner from suppliers where id = q.supplier_id;
  perform public.notify(v_customer, 'booking', 'Booking confirmed', 'Your booking ' || v_ref || ' is confirmed. Deposit held safely.', 'customer-dashboard.html#bookings');
  perform public.notify(v_supplier_owner, 'booking', 'New booking', 'Quote accepted - booking ' || v_ref || ' created.', 'supplier-dashboard.html#bookings');
  return v_booking;
end $$;

-- accept_quote is an alias for the canonical flow
create or replace function public.accept_quote(p_quote uuid)
returns uuid language sql security definer set search_path = public as $$
  select public.create_booking(p_quote, 30)
$$;

create or replace function public.reject_quote(p_quote uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_sup uuid;
begin
  select supplier_id into v_sup from quotes where id = p_quote;
  update quotes set status = 'rejected' where id = p_quote;
  select owner into v_owner from suppliers where id = v_sup;
  perform public.notify(v_owner, 'quote', 'Quote declined', 'A customer declined your quote.', 'supplier-dashboard.html#enquiries');
end $$;

-- ---------------------------------------------------------------------------
-- release_escrow(): move a held deposit to the supplier (delivery confirmed)
-- ---------------------------------------------------------------------------
create or replace function public.release_escrow(p_booking uuid)
returns void language plpgsql security definer set search_path = public as $$
declare b record; v_owner uuid;
begin
  select * into b from bookings where id = p_booking;
  if b is null then raise exception 'booking not found'; end if;
  if not (b.customer_id = auth.uid() or public.is_admin()) then
    raise exception 'only the customer or an admin may release funds';
  end if;
  update escrow_transactions set state='released', released_at=now(), release_reason='delivery confirmed'
    where booking_id = p_booking and state='held';
  update bookings set status='completed', payment_status='paid' where id = p_booking;
  insert into wallet_ledger (owner_type, owner_id, entry, amount, ref_type, ref_id, description)
    values ('supplier', b.supplier_id, 'credit', b.net_payout, 'payout', p_booking, 'Payout released after delivery');
  insert into payments (booking_id, kind, amount, state) values (p_booking, 'payout', b.net_payout, 'paid');
  select owner into v_owner from suppliers where id = b.supplier_id;
  perform public.notify(v_owner, 'payout', 'Payment released', 'Net payout of your booking ' || b.ref || ' has been released.', 'supplier-dashboard.html#overview');
end $$;

-- ---------------------------------------------------------------------------
-- cancel_booking(): cancel + free the date + refund escrow
-- ---------------------------------------------------------------------------
create or replace function public.cancel_booking(p_booking uuid, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare b record;
begin
  select * into b from bookings where id = p_booking;
  if b is null then raise exception 'booking not found'; end if;
  if not (b.customer_id = auth.uid() or public.owns_supplier(b.supplier_id) or public.is_admin()) then
    raise exception 'not authorized';
  end if;
  update bookings set status='cancelled', payment_status='refunded' where id = p_booking;
  update availability set state='open', booking_id=null where booking_id = p_booking;
  update escrow_transactions set state='refunded', released_at=now(), release_reason=coalesce(p_reason,'cancelled')
    where booking_id = p_booking and state='held';
  insert into payments (booking_id, kind, amount, state) values (p_booking, 'refund', b.deposit, 'refunded');
  perform public.notify(b.customer_id, 'booking', 'Booking cancelled', 'Booking ' || b.ref || ' was cancelled; your deposit is refunded.', 'customer-dashboard.html#bookings');
end $$;

-- ---------------------------------------------------------------------------
-- generate_invoice(): create an invoice row + number for a booking
-- ---------------------------------------------------------------------------
create or replace function public.generate_invoice(p_booking uuid, p_type invoice_type)
returns uuid language plpgsql security definer set search_path = public as $$
declare b record; v_amt int; v_no text; v_id uuid; v_gst int;
begin
  select * into b from bookings where id = p_booking;
  if b is null then raise exception 'booking not found'; end if;
  v_amt := case p_type when 'advance' then b.deposit when 'balance' then b.balance else b.amount end;
  v_gst := round(v_amt * 18 / 118.0);                 -- 18% inclusive
  v_no  := public.generate_invoice_number();
  insert into invoices (invoice_no, booking_id, type, amount, cgst, sgst)
    values (v_no, p_booking, p_type, v_amt, round(v_gst/2.0), round(v_gst/2.0)) returning id into v_id;
  return v_id;
end $$;

-- ---------------------------------------------------------------------------
-- Dashboard stats (returns JSON so the front-end can bind directly)
-- ---------------------------------------------------------------------------
create or replace function public.supplier_dashboard_stats(p_supplier uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'todays_enquiries', (select count(*) from event_requests r join quotes q on q.request_id=r.id
                          where q.supplier_id=p_supplier and r.created_at::date = current_date),
    'pending_quotes',   (select count(*) from quotes where supplier_id=p_supplier and status in ('draft','submitted')),
    'active_bookings',  (select count(*) from bookings where supplier_id=p_supplier and status in ('upcoming','ongoing')),
    'month_earnings',   (select coalesce(sum(net_payout),0) from bookings where supplier_id=p_supplier
                          and status='completed' and date_trunc('month',updated_at)=date_trunc('month',now())),
    'rating',           (select rating from suppliers where id=p_supplier),
    'review_count',     (select review_count from suppliers where id=p_supplier)
  )
$$;

create or replace function public.customer_dashboard_stats(p_customer uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'active_requests',  (select count(*) from event_requests where customer_id=p_customer and status in ('new','matched','quoted')),
    'quotes_to_review', (select count(*) from quotes q join event_requests r on r.id=q.request_id
                          where r.customer_id=p_customer and q.status='submitted'),
    'confirmed_bookings',(select count(*) from bookings where customer_id=p_customer and status in ('upcoming','ongoing')),
    'deposit_held',     (select coalesce(sum(e.amount),0) from escrow_transactions e
                          join bookings b on b.id=e.booking_id where b.customer_id=p_customer and e.state='held')
  )
$$;

-- ---------------------------------------------------------------------------
-- search_suppliers(): the discovery query behind the search UI
-- (availability-aware when a date is supplied)
-- ---------------------------------------------------------------------------
create or replace function public.search_suppliers(
  p_city text default 'Udaipur', p_min_capacity int default null,
  p_max_price int default null, p_date date default null)
returns setof suppliers language sql stable security definer set search_path = public as $$
  select s.* from suppliers s
  where s.status='active' and s.city = coalesce(p_city, s.city)
    and (p_min_capacity is null or s.capacity >= p_min_capacity)
    and (p_max_price is null or s.starting_price <= p_max_price)
    and (p_date is null or not exists (
         select 1 from availability a where a.supplier_id=s.id and a.day=p_date and a.state in ('blocked','maintenance','booked')))
  order by s.verified desc, s.rating desc
$$;

-- ============================================================================
-- end 0003_functions.sql
-- ============================================================================
