-- ============================================================
-- 0026_supplier_cover_images.sql            [v2.21]
-- ------------------------------------------------------------
-- Gives every active supplier a category-appropriate cover image.
--
-- WHY THIS EXISTS
-- ---------------
-- All seven suppliers already had a cover_image in the database; the
-- three "missing" images were only missing from search.html's static
-- markup, which had never been updated after 0010/0012 seeded them.
-- That half is fixed in the page itself (it now resolves covers from
-- v_supplier_public via EventaraAPI.supplierCovers()).
--
-- What IS wrong in the database is that two of those seeded stock
-- photos do not match the supplier they are attached to:
--
--   Hotel Aloka (banquet_hotel, "Boutique rooms & banquet hall")
--     was photo-1519225421980-... - a pastel banquet table dressed for
--     a WEDDING. Wrong on two counts: it does not depict a boutique
--     hotel, and weddings are explicitly Coming Soon (business rule
--     B2), so wedding imagery on a live listing implies a category the
--     platform does not sell yet.
--
--   Indicraft Communications (event_manager, "Events & Promotions")
--     was photo-1517457373958-... - a casual outdoor party crowd under
--     string lights, which reads social/private rather than the
--     corporate promotions and exhibitions this supplier actually runs.
--
-- Both are replaced with locally hosted, optimised images that match
-- the supplier's own name, category and description. Bluspring's photo
-- (plated fine dining) is a correct match for a Food & Hospitality
-- firm and is deliberately left alone, as are the four suppliers with
-- genuine photographs of their own property.
--
-- WHY LOCAL PATHS, NOT HOTLINKS
-- -----------------------------
-- Limitation L13: every other supplier photo is hotlinked from a third
-- party CDN and breaks if that host moves the file or blocks
-- hotlinking. These two are served from the repository instead
-- (prototype/images/suppliers/), sized once to 1200x800 at q76.
--
-- Paths are ROOT-ABSOLUTE on purpose. The same value is rendered by
-- /supplier.html?slug=... and by /venue/<slug>, which sit at different
-- path depths; a relative "images/..." would resolve to
-- "/venue/images/..." on the second and 400 against the slug
-- validator - exactly the class of bug fixed in v2.18.
--
-- Idempotent: matches on slug, and re-running is a no-op.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1. Hotel Aloka - boutique hotel interior
-- ------------------------------------------------------------
update public.suppliers
   set hero_image_url = '/images/suppliers/hotel-aloka.jpg'
 where slug = 'hotel-aloka';

update public.supplier_media
   set url = '/images/suppliers/hotel-aloka.jpg'
 where supplier_id = (select id from public.suppliers where slug = 'hotel-aloka')
   and is_cover;

-- ------------------------------------------------------------
-- 2. Indicraft Communications - corporate exhibition / conference floor
-- ------------------------------------------------------------
update public.suppliers
   set hero_image_url = '/images/suppliers/indicraft-communications.jpg'
 where slug = 'indicraft-communications';

update public.supplier_media
   set url = '/images/suppliers/indicraft-communications.jpg'
 where supplier_id = (select id from public.suppliers where slug = 'indicraft-communications')
   and is_cover;

-- ------------------------------------------------------------
-- 3. Safety net - a supplier with media but no is_cover row would
--    otherwise keep serving the old photo through media_cover_url,
--    since v_supplier_public orders by (is_cover desc, sort).
-- ------------------------------------------------------------
update public.supplier_media m
   set is_cover = true
  from public.suppliers s
 where m.supplier_id = s.id
   and s.slug in ('hotel-aloka', 'indicraft-communications')
   and m.url like '/images/suppliers/%'
   and not exists (
     select 1 from public.supplier_media x
      where x.supplier_id = m.supplier_id and x.is_cover
   );

commit;

-- ------------------------------------------------------------
-- Verification (expect a local /images/suppliers/... path for both,
-- and an unchanged value for the other five):
--
--   select slug, cover_image from public.v_supplier_public order by slug;
-- ------------------------------------------------------------
