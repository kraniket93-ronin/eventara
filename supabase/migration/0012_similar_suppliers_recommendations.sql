-- ============================================================================
-- Eventara backend — 0012_similar_suppliers_recommendations.sql
-- Fixes v_supplier_public.cover_image (only ever checked venue_images,
-- ignoring hero_image_url and supplier_media), fixes a malformed pre-existing
-- venue_images.url data value, and adds a ranked get_similar_suppliers RPC.
-- Apply after 0011_supplier_public_add_slug.sql.
-- ============================================================================

-- 1a. Data fix: this value was never a real URL (a bucket-path fragment left
-- over from before the "hotlinked URLs" convention was settled) - browsers
-- resolve it as a relative path and it 404s. Point it at a real, already-
-- working photo this same supplier already serves elsewhere.
update venue_images set url = 'https://pandorahotels.co.in/grand-udr/IMG_7335.webp'
where url = 'supplier-images/44444444/ballroom.jpg';

-- 1b. Rewrite v_supplier_public: expose raw candidate image sources
-- (media_cover_url, venue_cover_url) alongside a correctly-prioritized
-- cover_image (hero -> supplier_media -> venue_images-if-hotel), plus a
-- server-computed availability_state so cards don't need N extra queries.
drop view if exists v_supplier_public;
create view v_supplier_public
with (security_invoker = true) as
select s.id, s.slug, s.business_name, s.category, s.description, s.city, s.capacity,
       s.starting_price, s.amenities, s.rating, s.review_count, s.verified,
       s.tagline, s.featured, s.hero_image_url,
       (select sm.url from supplier_media sm where sm.supplier_id = s.id
         order by sm.is_cover desc, sm.sort limit 1) as media_cover_url,
       (select vi.url from venue_images vi join venues v on v.id = vi.venue_id
         where v.supplier_id = s.id order by vi.is_cover desc, vi.sort limit 1) as venue_cover_url,
       coalesce(
         s.hero_image_url,
         (select sm.url from supplier_media sm where sm.supplier_id = s.id order by sm.is_cover desc, sm.sort limit 1),
         case when s.category = 'banquet_hotel' then
           (select vi.url from venue_images vi join venues v on v.id = vi.venue_id
             where v.supplier_id = s.id order by vi.is_cover desc, vi.sort limit 1)
         end
       ) as cover_image,
       (select case
          when count(*) filter (where a.state in ('blocked','maintenance','booked','held'))::numeric
               / greatest(count(*), 1) > 0.6 then 'tight'
          when count(*) filter (where a.state in ('blocked','maintenance','booked','held'))::numeric
               / greatest(count(*), 1) > 0.15 then 'limited'
          else 'open' end
        from generate_series(current_date, current_date + 89, interval '1 day') d(day)
        left join availability a on a.supplier_id = s.id and a.day = d.day::date
       ) as availability_state
from suppliers s
where s.status = 'active';

-- 1c. Ranked recommendation RPC - one query, no duplicates possible (single
-- LIMIT, no UNION). Same city + same category rank highest; when a category
-- has fewer than p_limit other active suppliers, lower-ranked cross-category
-- rows naturally fill the remaining slots since this scans all active
-- suppliers, just ordered - no separate fallback query needed.
create or replace function public.get_similar_suppliers(p_supplier_id uuid, p_limit int default 3)
returns setof v_supplier_public language sql stable security definer set search_path = public as $$
  select vp.* from v_supplier_public vp, suppliers cur
  where cur.id = p_supplier_id and vp.id <> p_supplier_id
  order by
    (vp.city = cur.city) desc,
    (vp.category = cur.category) desc,
    vp.verified desc,
    vp.featured desc,
    abs(coalesce(vp.rating,0) - coalesce(cur.rating,0)) asc,
    abs(coalesce(vp.starting_price,0) - coalesce(cur.starting_price,0)) asc,
    vp.rating desc
  limit p_limit
$$;
alter function public.get_similar_suppliers(uuid, int) set search_path = public;

-- ============================================================================
-- end 0012_similar_suppliers_recommendations.sql
-- ============================================================================
