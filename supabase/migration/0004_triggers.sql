-- ============================================================================
-- Eventara backend — 0004_triggers.sql
-- Timestamp maintenance, ref generation, rating rollups, payment sync,
-- notifications, audit logging, and the auth.users -> profiles bridge.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- auth.users -> profiles  (runs on every new signup)
-- ---------------------------------------------------------------------------
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','customer_profiles','suppliers','supplier_profiles','event_requests',
    'quotes','bookings','disputes','kyc_verification','availability','user_preferences']
  loop
    execute format('drop trigger if exists trg_updated_%1$s on %1$I', t);
    execute format('create trigger trg_updated_%1$s before update on %1$I for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Ref auto-generation on insert
-- ---------------------------------------------------------------------------
create or replace function public.trg_set_request_ref() returns trigger language plpgsql as $$
begin if new.ref is null then new.ref := public.next_ref('EVT','seq_evt'); end if; return new; end $$;
drop trigger if exists set_request_ref on event_requests;
create trigger set_request_ref before insert on event_requests for each row execute function public.trg_set_request_ref();

create or replace function public.trg_set_quote_ref() returns trigger language plpgsql as $$
begin if new.ref is null then new.ref := public.next_ref('QT','seq_quote'); end if; return new; end $$;
drop trigger if exists set_quote_ref on quotes;
create trigger set_quote_ref before insert on quotes for each row execute function public.trg_set_quote_ref();

create or replace function public.trg_set_dispute_ref() returns trigger language plpgsql as $$
begin if new.ref is null then new.ref := public.next_ref('D','seq_dispute'); end if; return new; end $$;
drop trigger if exists set_dispute_ref on disputes;
create trigger set_dispute_ref before insert on disputes for each row execute function public.trg_set_dispute_ref();

-- ---------------------------------------------------------------------------
-- Reviews -> recompute rating rollup + notify supplier
-- ---------------------------------------------------------------------------
create or replace function public.trg_review_after() returns trigger language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  perform public.calculate_supplier_rating(new.supplier_id);
  select owner into v_owner from suppliers where id = new.supplier_id;
  perform public.notify(v_owner, 'review', 'New review', 'You received a ' || new.rating || '-star review.', 'supplier-dashboard.html#overview');
  return new;
end $$;
drop trigger if exists review_after on reviews;
create trigger review_after after insert on reviews for each row execute function public.trg_review_after();

-- ---------------------------------------------------------------------------
-- Payments -> keep booking.payment_status in sync
-- ---------------------------------------------------------------------------
create or replace function public.trg_payment_after() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.state = 'paid' then
    if new.kind = 'balance' then
      update bookings set payment_status = 'paid' where id = new.booking_id;
    elsif new.kind = 'deposit' then
      update bookings set payment_status = 'deposit_held' where id = new.booking_id;
    end if;
  elsif new.state = 'refunded' then
    update bookings set payment_status = 'refunded' where id = new.booking_id;
  end if;
  return new;
end $$;
drop trigger if exists payment_after on payments;
create trigger payment_after after insert or update on payments for each row execute function public.trg_payment_after();

-- ---------------------------------------------------------------------------
-- Supplier verification flip -> notify + audit
-- ---------------------------------------------------------------------------
create or replace function public.trg_supplier_verified() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.verified is distinct from old.verified then
    perform public.notify(new.owner, 'system',
      case when new.verified then 'You are verified' else 'Verification revoked' end,
      case when new.verified then 'Your business is now verified on Eventara.' else 'Your verified badge was removed.' end,
      'supplier-dashboard.html#profile');
    insert into audit_logs (actor_id, action, entity_type, entity_id, diff)
      values (auth.uid(), 'supplier.verified_changed', 'suppliers', new.id::text,
              json_build_object('from', old.verified, 'to', new.verified));
  end if;
  return new;
end $$;
drop trigger if exists supplier_verified on suppliers;
create trigger supplier_verified after update on suppliers for each row execute function public.trg_supplier_verified();

-- ---------------------------------------------------------------------------
-- Generic audit for high-value tables (insert/update/delete)
-- ---------------------------------------------------------------------------
-- NOTE: NEW.id / OLD.id must not be referenced directly here. OLD is unbound
-- on INSERT (and NEW on DELETE) so any direct field access - even in an
-- unreached CASE branch - fails to compile ("record has no field"). Some
-- audited tables (kyc_verification) also key on supplier_id, not id, so the
-- id is pulled dynamically via jsonb instead of a hardcoded column name.
create or replace function public.trg_audit() returns trigger language plpgsql security definer set search_path = public as $$
declare v_id text;
begin
  if tg_op = 'DELETE' then
    v_id := coalesce(to_jsonb(old)->>'id', to_jsonb(old)->>'supplier_id', to_jsonb(old)->>'booking_id', '');
    insert into audit_logs (actor_id, action, entity_type, entity_id, diff)
      values (auth.uid(), tg_op, tg_table_name, v_id, to_jsonb(old));
    return old;
  else
    v_id := coalesce(to_jsonb(new)->>'id', to_jsonb(new)->>'supplier_id', to_jsonb(new)->>'booking_id', '');
    insert into audit_logs (actor_id, action, entity_type, entity_id, diff)
      values (auth.uid(), tg_op, tg_table_name, v_id, to_jsonb(new));
    return new;
  end if;
end $$;
do $$
declare t text;
begin
  foreach t in array array['bookings','payments','escrow_transactions','disputes','kyc_verification'] loop
    execute format('drop trigger if exists trg_audit_%1$s on %1$I', t);
    execute format('create trigger trg_audit_%1$s after insert or update or delete on %1$I for each row execute function public.trg_audit()', t);
  end loop;
end $$;

-- ============================================================================
-- end 0004_triggers.sql
-- ============================================================================
