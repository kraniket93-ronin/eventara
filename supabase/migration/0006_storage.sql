-- ============================================================================
-- Eventara backend — 0006_storage.sql
-- Storage buckets + object-level policies.
-- Public buckets: read by anyone, write by the owning authenticated user.
-- Private buckets: read/write only by the owner (path prefixed with their uid)
-- and admins. Convention: upload objects under "<auth.uid()>/filename".
-- ============================================================================

insert into storage.buckets (id, name, public) values
  ('supplier-images',    'supplier-images',    true),
  ('venue-images',       'venue-images',       true),
  ('profile-pictures',   'profile-pictures',   true),
  ('kyc-documents',      'kyc-documents',      false),
  ('invoices',           'invoices',           false),
  ('gst-documents',      'gst-documents',      false),
  ('dispute-evidence',   'dispute-evidence',   false),
  ('booking-attachments','booking-attachments',false)
on conflict (id) do nothing;

-- Public buckets: anyone can read
drop policy if exists "public read" on storage.objects;
create policy "public read" on storage.objects for select
  using (bucket_id in ('supplier-images','venue-images','profile-pictures'));

-- Authenticated users can upload into their own folder in any bucket
drop policy if exists "own folder insert" on storage.objects;
create policy "own folder insert" on storage.objects for insert to authenticated
  with check ( (storage.foldername(name))[1] = auth.uid()::text );

-- Owners can update/delete their own objects
drop policy if exists "own folder update" on storage.objects;
create policy "own folder update" on storage.objects for update to authenticated
  using ( (storage.foldername(name))[1] = auth.uid()::text );
drop policy if exists "own folder delete" on storage.objects;
create policy "own folder delete" on storage.objects for delete to authenticated
  using ( (storage.foldername(name))[1] = auth.uid()::text or public.is_admin() );

-- Private buckets: only the owner (their folder) or an admin may read
drop policy if exists "private read own" on storage.objects;
create policy "private read own" on storage.objects for select to authenticated
  using (
    bucket_id in ('kyc-documents','invoices','gst-documents','dispute-evidence','booking-attachments')
    and ( (storage.foldername(name))[1] = auth.uid()::text or public.is_admin() )
  );

-- ============================================================================
-- end 0006_storage.sql
-- ============================================================================
