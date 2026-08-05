-- ============================================================================
-- Eventara backend — 0014_fix_customer_profile_seed.sql
-- Latent seed bug, surfaced by wiring the customer dashboard to real data:
-- handle_new_user() creates the customer_profiles row at signup with only
-- (profile_id, org_name). 0007_seed.sql then did
--   insert into customer_profiles (...) ... on conflict (profile_id) do nothing
-- which therefore silently no-opped, so industry / gstin / billing_address
-- never landed. The dashboard was showing blanks because the data really was
-- blank - the old hardcoded HTML had been displaying values that existed
-- nowhere in the database. Backfill them (idempotent: only fills NULLs).
-- Apply after 0013_dashboard_backing_tables.sql.
-- ============================================================================

update customer_profiles set
  industry        = coalesce(industry, 'Electronics & Metering'),
  gstin           = coalesce(gstin, '08XXXXX0000X1ZK'),
  billing_address = coalesce(billing_address, 'E-Class, Pratap Nagar Industrial Area, Udaipur, Rajasthan 313003'),
  default_po      = coalesce(default_po, 'PO/2026/0148'),
  finance_email   = coalesce(finance_email, 'finance@securemeters.example')
where profile_id = '22222222-2222-2222-2222-222222222222';

-- Same class of gap on the profile itself (phone was never seeded).
update profiles set phone = coalesce(phone, '+91 294 2345 678')
where id = '22222222-2222-2222-2222-222222222222';

-- ============================================================================
-- end 0014_fix_customer_profile_seed.sql
-- ============================================================================
