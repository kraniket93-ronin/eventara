-- ============================================================================
-- Eventara backend — 0011_supplier_public_add_slug.sql
-- v_supplier_public (0005_views.sql) predates the slug column added in
-- 0009_supplier_detail.sql and was never updated to expose it - every
-- consumer that routes by slug (e.g. EventaraAPI.getSimilarSuppliers ->
-- supplier.html?slug=...) was silently generating broken "?slug=" links.
-- Apply after 0010_supplier_detail_seed.sql.
-- ============================================================================

-- create or replace view can't reorder/insert columns mid-view (Postgres
-- matches by position), so drop and recreate instead of CREATE OR REPLACE.
drop view if exists v_supplier_public;
create view v_supplier_public
with (security_invoker = true) as
select s.id, s.slug, s.business_name, s.category, s.description, s.city, s.capacity,
       s.starting_price, s.amenities, s.rating, s.review_count, s.verified,
       s.tagline, s.featured, s.hero_image_url,
       (select url from venue_images vi join venues v on v.id = vi.venue_id
         where v.supplier_id = s.id order by vi.is_cover desc, vi.sort limit 1) as cover_image
from suppliers s
where s.status = 'active';

-- ============================================================================
-- end 0011_supplier_public_add_slug.sql
-- ============================================================================
