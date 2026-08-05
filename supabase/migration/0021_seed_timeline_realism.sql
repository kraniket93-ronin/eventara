-- ============================================================================
-- 0021_seed_timeline_realism.sql
-- Corrective migration for data already applied by 0018 and 0020.
--
-- Wiring the Overview panel to real aggregates exposed three places where the
-- seed data was internally inconsistent. None of these were visible while the
-- panel showed hardcoded numbers - the figures simply agreed with nothing.
--
--   1. Seeded dispute rows and their timeline entries all carried now() as
--      their timestamp, so a January complaint appeared to have been raised
--      today, and its four timeline entries shared one instant - meaning
--      "resolved" could sort before "raised".
--
--   2. Every event_request and its quote shared a created_at, so
--      "median time to quote" computed to 0h. A request necessarily exists
--      before a supplier quotes it.
--
--   3. The backfill in 0020 dated the payout and escrow release BEFORE the
--      event it was paying for. Escrow must only release after delivery -
--      that is the platform's core promise (business rule B19).
--
-- 0018 and 0020 have been corrected at source too, so a deployment that runs
-- the migrations from scratch produces this same state without needing 0021.
-- This file only exists to repair the database those migrations already ran
-- against.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Put the seeded disputes and their timelines on real dates
-- ---------------------------------------------------------------------------
update disputes set ref = 'C-2026-01',
       created_at = '2026-01-10 09:15:00+05:30',
       updated_at = '2026-01-14 17:40:00+05:30'
 where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

update disputes set created_at = '2026-08-02 11:30:00+05:30',
       updated_at = '2026-08-02 11:30:00+05:30'
 where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

update dispute_events set created_at = '2026-08-02 11:30:00+05:30'
 where dispute_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' and action = 'raised';

update dispute_events set created_at = '2026-01-10 09:15:00+05:30'
 where dispute_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and action = 'raised';
update dispute_events set created_at = '2026-01-11 14:20:00+05:30'
 where dispute_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and action = 'response';
update dispute_events set created_at = '2026-01-14 17:40:00+05:30'
 where dispute_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and action = 'resolved';

-- ---------------------------------------------------------------------------
-- 2. A request must predate the quote answering it
-- ---------------------------------------------------------------------------
update event_requests set created_at = '2026-07-26 10:05:00+05:30'
 where ref = 'EVT-2026-0042';
update quotes set created_at = '2026-07-27 12:40:00+05:30',
                  updated_at = '2026-07-27 18:25:00+05:30'
 where ref = 'QT-2026-0042';

update event_requests set created_at = '2026-08-03 09:30:00+05:30'
 where ref = 'EVT-2026-0051';
update quotes set created_at = '2026-08-03 10:15:00+05:30',
                  updated_at = '2026-08-03 10:15:00+05:30'
 where ref = 'QT-2026-0051';

-- ---------------------------------------------------------------------------
-- 3. Escrow releases and the payout land AFTER delivery, not before
-- ---------------------------------------------------------------------------
update payments p set created_at = '2026-01-02 16:05:00+05:30', gateway_ref = 'pay_R7xK0288BAL'
  from bookings b where b.id = p.booking_id and b.ref = 'EVT-2025-0288' and p.kind = 'balance';

update payments p set created_at = '2026-01-15 10:12:00+05:30', gateway_ref = 'pyt_R7xK0288PO'
  from bookings b where b.id = p.booking_id and b.ref = 'EVT-2025-0288' and p.kind = 'payout';

update payments p set gateway_ref = 'pay_R7xK0288DEP'
  from bookings b where b.id = p.booking_id and b.ref = 'EVT-2025-0288' and p.kind = 'deposit';

update escrow_transactions e set released_at = '2026-01-15 10:12:00+05:30',
       release_reason = 'Event delivered and the complaint raised against it was resolved.'
  from bookings b where b.id = e.booking_id and b.ref = 'EVT-2025-0288';

update invoices i set issued_at = '2026-01-02 16:10:00+05:30', invoice_no = 'EVT/INV/2026/0288B'
  from bookings b where b.id = i.booking_id and b.ref = 'EVT-2025-0288' and i.type = 'balance';

-- ---------------------------------------------------------------------------
-- 4. A supplier that has been paid out needs a payout account on file
-- ---------------------------------------------------------------------------
insert into bank_accounts (supplier_id, profile_id, account_name, bank, account_masked, ifsc, upi, is_primary)
select '44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333',
       'Paandora Hospitality Pvt Ltd', 'HDFC Bank', 'XXXXXX4417', 'HDFC0001284',
       'paandoragrand@hdfcbank', true
where not exists (select 1 from bank_accounts where supplier_id = '44444444-4444-4444-4444-444444444444');
