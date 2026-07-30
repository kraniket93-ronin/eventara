-- ============================================================================
-- Eventara backend — 0010_supplier_detail_seed.sql
-- Full detail content for the Supplier Detail Page, for all 7 confirmed
-- suppliers. Apply after 0009_supplier_detail.sql.
--
-- Source of truth for names/category/capacity/rating/review_count/price/
-- location/photo used below: prototype/search.html lines 247-483. If
-- anything here looks off, re-check that file first.
--
-- Paandora Grand Udaipur (44444444-...) already has a live suppliers row -
-- this migration only UPDATEs it and adds new child rows (packages/media/
-- faqs), reusing the exact content already hardcoded in provider.html.
-- Existing venues/venue_images/bookings/quotes/reviews for it are untouched.
--
-- The other 6 suppliers get fresh suppliers/supplier_profiles/services/
-- media/packages/faqs rows. owner is set to the existing Eventara Ops
-- profile (11111111-...) rather than inventing 6 fake supplier logins -
-- these are demo listings, not accounts anyone signs into yet.
-- ============================================================================

-- ============================================================================
-- PAANDORA GRAND UDAIPUR (existing row, backfill only)
-- ============================================================================
update suppliers set
  tagline = 'Banquet Hotel & Resort - 100 rooms, banquet halls, wedding lawns',
  years_experience = 12,
  featured = true,
  hero_image_url = 'https://pandorahotels.co.in/grand-udr/Property-with-lawn-view.webp',
  -- Align displayed rating with search.html's card (4.6, 214 reviews) -
  -- the trigger-computed value from the single seeded review (5.0/1)
  -- would otherwise mismatch what the user just clicked through from.
  -- Same hardcoded-for-display approach used for the other 6 suppliers
  -- below; will drift again if real reviews accumulate later, which is
  -- expected/acceptable.
  rating = 4.6,
  review_count = 214
where id = '44444444-4444-4444-4444-444444444444';

update supplier_profiles set
  google_maps_url = 'https://maps.google.com/?q=Paandora+Grand+Udaipur+Balicha',
  payment_terms = '30% advance on confirmation, balance due 7 days before the event.',
  refund_policy = 'Moderate - 50% refund up to 30 days before the event date.',
  booking_policy = 'Dates are held for 48 hours after quote acceptance pending deposit. Guest count and menu selections must be finalised 14 days before the event.'
where supplier_id = '44444444-4444-4444-4444-444444444444';

insert into supplier_packages (supplier_id, name, price_from, price_unit, guest_max, description, inclusions, is_featured, sort) values
  ('44444444-4444-4444-4444-444444444444','Conference Day',400000,'per event',150,'A full conference day with breakout space and catering.',
    array['Conference hall (theatre / classroom / U-shape)','Projector, PA system & podium','Two tea/coffee breaks + working lunch','Breakaway room for sessions','Dedicated banquet manager on-site','Proper GST invoice for your records'], false, 1),
  ('44444444-4444-4444-4444-444444444444','Residential Offsite',900000,'per event',200,'A 2-day residential offsite with rooms, meals and a gala night.',
    array['Room block (up to 100 rooms, Aravalli view)','Conference hall + breakaway rooms','All meals - in-house catering','Sunset Deck dinner (up to 80 guests)','Team-building on lawns + pool access','AV, stage & DJ for gala night','One dedicated event manager','Proper GST invoice for your records'], true, 2),
  ('44444444-4444-4444-4444-444444444444','Grand Celebration',1800000,'per event',800,'Full-property booking for large weddings and celebrations.',
    array['Wedding lawns + banquet hall, full property','Multi-day room block for guests','Full catering - multi-cuisine, live counters','Decor, stage, mandap & lighting','Entertainment & artist coordination','Valet, security & guest hospitality desk','One dedicated event manager'], false, 3)
on conflict do nothing;

insert into supplier_media (supplier_id, category, caption, url, sort, is_cover) values
  ('44444444-4444-4444-4444-444444444444','outdoor-spaces','Lawns & Property - Aravalli View','https://pandorahotels.co.in/grand-udr/Property-with-lawn-view.webp',1,true),
  ('44444444-4444-4444-4444-444444444444','facilities','Property by Night - Gala Setup','https://pandorahotels.co.in/grand-udr/Night-view.webp',2,false),
  ('44444444-4444-4444-4444-444444444444','banquet-halls','Banquet & Event Spaces','https://pandorahotels.co.in/grand-udr/IMG_7335.webp',3,false),
  ('44444444-4444-4444-4444-444444444444','facilities','Poolside & Sunset Deck','https://pandorahotels.co.in/grand-udr/IMG_7354.webp',4,false),
  ('44444444-4444-4444-4444-444444444444','rooms','Stay - 100 Rooms','https://pandorahotels.co.in/grand-udr/IMG_7355.webp',5,false),
  ('44444444-4444-4444-4444-444444444444','outdoor-spaces','Sunset Deck - Open-Air Events','https://pandorahotels.co.in/Latest-image/sunset.webp',6,false)
on conflict do nothing;

insert into supplier_faqs (supplier_id, question, answer, sort) values
  ('44444444-4444-4444-4444-444444444444','Do you provide in-house catering?','Yes - all catering is in-house, with multi-cuisine menus and live counters available on the larger packages.',1),
  ('44444444-4444-4444-4444-444444444444','Is parking available for guests?','Yes, valet parking is included for all banquet and wedding bookings.',2),
  ('44444444-4444-4444-4444-444444444444','Can you host both indoor and outdoor functions?','Yes - we have an indoor pillarless ballroom plus the open-air wedding lawns and Sunset Deck.',3),
  ('44444444-4444-4444-4444-444444444444','What is included in the room block for residential offsites?','Up to 100 rooms with Aravalli views, breakfast included, on the same property as the conference facilities.',4),
  ('44444444-4444-4444-4444-444444444444','How far in advance should we book?','We recommend at least 6-8 weeks ahead for peak season (Oct-Mar); shorter notice is often possible off-season.',5)
on conflict do nothing;

-- ============================================================================
-- STERLING BALICHA
-- ============================================================================
insert into suppliers (id, owner, business_name, category, description, city, capacity, starting_price,
  amenities, verified, rating, review_count, status, tagline, years_experience, featured)
values ('a1a1a1a1-1111-1111-1111-111111111101','11111111-1111-1111-1111-111111111111',
  'Sterling Balicha','banquet_hotel',
  'A vintage haveli-style resort on 3 acres at Balicha, NH-8, with poolside lawns and indoor banquet halls for weddings, conferences and corporate offsites.',
  'Udaipur', 400, 1200,
  array['Valet parking','In-house catering','Poolside lawns','Heritage haveli architecture','Power backup','Wi-Fi'],
  true, 4.1, 712, 'active', 'Resort & Banquets - vintage haveli on 3 acres, NH-8 Balicha', 15, true)
on conflict (id) do nothing;

insert into supplier_profiles (supplier_id, contact_person, contact_email, contact_phone, address, google_maps_url, payment_terms, refund_policy, booking_policy) values
  ('a1a1a1a1-1111-1111-1111-111111111101','Devika Rathore - Banquet Manager','events@sterlingbalicha.example','+91 294 XXXX XXXX',
   'Balicha, NH-8, Udaipur, Rajasthan','https://maps.google.com/?q=Sterling+Balicha+NH-8+Udaipur',
   '30% advance on confirmation, balance due 7 days before the event.',
   'Moderate - 50% refund up to 30 days before the event date.',
   'Dates are held for 48 hours after quote acceptance pending deposit.')
on conflict (supplier_id) do nothing;

insert into supplier_services (supplier_id, name, description, price_from, unit) values
  ('a1a1a1a1-1111-1111-1111-111111111101','Banquet Hall Rental','Indoor hall with stage and AC, up to 400 guests', 90000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111101','Multi-cuisine Catering','Buffet or plated service, customisable menus', 1200, 'per plate'),
  ('a1a1a1a1-1111-1111-1111-111111111101','Decor & Floral Setup','Stage, entrance and table decor', 60000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111101','DJ & Sound', 'Full sound system with DJ for evening events', 35000, 'per event')
on conflict do nothing;

insert into supplier_media (supplier_id, category, caption, url, sort, is_cover) values
  ('a1a1a1a1-1111-1111-1111-111111111101','outdoor-spaces','Poolside Lawns','https://media.easemytrip.com/media/Hotel/SHL-2401311249900013/Hotel/HotelbLWLcC.png',1,true),
  ('a1a1a1a1-1111-1111-1111-111111111101','banquet-halls','Indoor Banquet Hall','https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=1600&q=80',2,false),
  ('a1a1a1a1-1111-1111-1111-111111111101','rooms','Heritage-style Rooms','https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1600&q=80',3,false),
  ('a1a1a1a1-1111-1111-1111-111111111101','facilities','Evening Event Setup','https://images.unsplash.com/photo-1478146059778-26028b07395a?auto=format&fit=crop&w=1600&q=80',4,false)
on conflict do nothing;

insert into supplier_packages (supplier_id, name, price_from, price_unit, guest_max, description, inclusions, is_featured, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111101','Conference Day',300000,'per event',150,'A day-use conference package.',
    array['Banquet hall with AV & seating','Tea/coffee breaks + working lunch','Dedicated event coordinator','GST invoice included'], false, 1),
  ('a1a1a1a1-1111-1111-1111-111111111101','Full-Day Banquet',700000,'per event',400,'Full property use for a day-long celebration.',
    array['Banquet hall + poolside lawns','Multi-cuisine catering','Decor & floral setup','Sound & DJ for the evening'], true, 2),
  ('a1a1a1a1-1111-1111-1111-111111111101','Grand Wedding Package',1200000,'per event',400,'Complete wedding celebration across the property.',
    array['Full property (hall + lawns + pool deck)','Multi-day guest rooms','Full-service catering with live counters','Decor, stage & lighting design','Dedicated event manager'], false, 3)
on conflict do nothing;

insert into supplier_faqs (supplier_id, question, answer, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111101','Do you provide in-house catering?','Yes, with customisable multi-cuisine menus for any guest count.',1),
  ('a1a1a1a1-1111-1111-1111-111111111101','Is the venue indoor, outdoor, or both?','Both - an indoor banquet hall and open poolside lawns, so you can choose per season.',2),
  ('a1a1a1a1-1111-1111-1111-111111111101','Do you offer accommodation for out-of-town guests?','Yes, heritage-style rooms are available on-site for multi-day bookings.',3),
  ('a1a1a1a1-1111-1111-1111-111111111101','Is parking available?','Yes, on-site valet parking is included.',4),
  ('a1a1a1a1-1111-1111-1111-111111111101','How far ahead should we book for a wedding date?','We recommend 2-3 months ahead for peak wedding season (Oct-Feb).',5)
on conflict do nothing;

-- ============================================================================
-- HOTEL ALOKA
-- ============================================================================
insert into suppliers (id, owner, business_name, category, description, city, capacity, starting_price,
  amenities, verified, rating, review_count, status, tagline, years_experience, featured)
values ('a1a1a1a1-1111-1111-1111-111111111102','11111111-1111-1111-1111-111111111111',
  'Hotel Aloka','banquet_hotel',
  'A boutique hotel in central Udaipur with intimate guest rooms and a compact banquet hall, suited to smaller corporate events and institutional functions.',
  'Udaipur', 200, 900,
  array['Wi-Fi','Air Conditioning','In-house catering','Parking','Projector','Rooftop seating'],
  true, 4.2, 94, 'active', 'Boutique Hotel - intimate rooms & banquet hall in central Udaipur', 8, false)
on conflict (id) do nothing;

insert into supplier_profiles (supplier_id, contact_person, contact_email, contact_phone, address, google_maps_url, payment_terms, refund_policy, booking_policy) values
  ('a1a1a1a1-1111-1111-1111-111111111102','Sanjay Bhatt - Front Office Manager','events@hotelaloka.example','+91 294 XXXX XXXX',
   'Udaipur, Rajasthan','https://maps.google.com/?q=Hotel+Aloka+Udaipur',
   '30% advance on confirmation, balance due 5 days before the event.',
   'Moderate - 50% refund up to 21 days before the event date.',
   'Dates are held for 48 hours after quote acceptance pending deposit.')
on conflict (supplier_id) do nothing;

insert into supplier_services (supplier_id, name, description, price_from, unit) values
  ('a1a1a1a1-1111-1111-1111-111111111102','Banquet Hall Rental','Compact hall suited to 50-200 guests', 60000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111102','Room Booking','Guest rooms for out-of-town attendees', 4500, 'per night'),
  ('a1a1a1a1-1111-1111-1111-111111111102','In-house Catering','Buffet-style multi-cuisine catering', 900, 'per plate'),
  ('a1a1a1a1-1111-1111-1111-111111111102','Basic AV Setup','Projector, mic and speaker setup', 15000, 'per event')
on conflict do nothing;

insert into supplier_media (supplier_id, category, caption, url, sort, is_cover) values
  ('a1a1a1a1-1111-1111-1111-111111111102','banquet-halls','Banquet Hall','https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=1600&q=80',1,true),
  ('a1a1a1a1-1111-1111-1111-111111111102','rooms','Guest Room','https://images.unsplash.com/photo-1584132967334-10e028bd69f7?auto=format&fit=crop&w=1600&q=80',2,false),
  ('a1a1a1a1-1111-1111-1111-111111111102','facilities','Rooftop Seating','https://images.unsplash.com/photo-1544148103-0773bf10d330?auto=format&fit=crop&w=1600&q=80',3,false)
on conflict do nothing;

insert into supplier_packages (supplier_id, name, price_from, price_unit, guest_max, description, inclusions, is_featured, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111102','Half-Day Event',150000,'per event',100,'A half-day meeting or small function.',
    array['Banquet hall (half-day)','Basic AV setup','Tea/coffee service'], false, 1),
  ('a1a1a1a1-1111-1111-1111-111111111102','Full Banquet Day',400000,'per event',200,'A full-day booking with catering.',
    array['Banquet hall (full day)','In-house catering','AV setup','Dedicated coordinator'], true, 2),
  ('a1a1a1a1-1111-1111-1111-111111111102','Weekend Celebration',750000,'per event',200,'A weekend function with rooms for guests.',
    array['Banquet hall + guest rooms','Full catering','Decor add-ons available','Dedicated coordinator'], false, 3)
on conflict do nothing;

insert into supplier_faqs (supplier_id, question, answer, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111102','Do you provide in-house catering?','Yes, buffet-style multi-cuisine catering is available for all bookings.',1),
  ('a1a1a1a1-1111-1111-1111-111111111102','Is the hotel suitable for smaller corporate events?','Yes - the banquet hall is sized for 50-200 guests, ideal for smaller offsites and functions.',2),
  ('a1a1a1a1-1111-1111-1111-111111111102','Is parking available?','Yes, on-site parking is included.',3),
  ('a1a1a1a1-1111-1111-1111-111111111102','Can guests stay overnight?','Yes, guest rooms can be booked alongside your event for out-of-town attendees.',4),
  ('a1a1a1a1-1111-1111-1111-111111111102','Do you have AV equipment on-site?','Yes, projector, mic and speaker setup is available as an add-on.',5)
on conflict do nothing;

-- ============================================================================
-- LAKESIDE LEISURE
-- ============================================================================
insert into suppliers (id, owner, business_name, category, description, city, capacity, starting_price,
  amenities, verified, rating, review_count, status, tagline, years_experience, featured)
values ('a1a1a1a1-1111-1111-1111-111111111103','11111111-1111-1111-1111-111111111111',
  'Lakeside Leisure','banquet_hotel',
  'A waterfront reception venue on Nela Lake with an open-air terrace, suited to smaller receptions, product launches and evening events with a view.',
  'Udaipur', 150, 1500,
  array['Lake view','Open-air terrace','Valet parking','In-house catering','Power backup','Photography-friendly lighting'],
  true, 4.3, 86, 'active', 'Lake-View Reception Venue - waterfront terrace on Nela Lake', 6, false)
on conflict (id) do nothing;

insert into supplier_profiles (supplier_id, contact_person, contact_email, contact_phone, address, google_maps_url, payment_terms, refund_policy, booking_policy) values
  ('a1a1a1a1-1111-1111-1111-111111111103','Priya Mehta - Venue Manager','events@lakesideleisure.example','+91 294 XXXX XXXX',
   'Nela Lake, Sector 14, Udaipur, Rajasthan','https://maps.google.com/?q=Lakeside+Leisure+Nela+Lake+Udaipur',
   '30% advance on confirmation, balance due 7 days before the event.',
   'Moderate - 50% refund up to 30 days before the event date.',
   'Dates are held for 48 hours after quote acceptance pending deposit.')
on conflict (supplier_id) do nothing;

insert into supplier_services (supplier_id, name, description, price_from, unit) values
  ('a1a1a1a1-1111-1111-1111-111111111103','Terrace Rental','Open-air waterfront terrace, up to 150 guests', 75000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111103','Multi-cuisine Catering','Plated or buffet service with lake views', 1500, 'per plate'),
  ('a1a1a1a1-1111-1111-1111-111111111103','Decor & Lighting','Terrace decor and ambient lighting', 45000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111103','Live Music / DJ','Evening entertainment setup', 30000, 'per event')
on conflict do nothing;

insert into supplier_media (supplier_id, category, caption, url, sort, is_cover) values
  ('a1a1a1a1-1111-1111-1111-111111111103','outdoor-spaces','Waterfront Terrace','https://media.easemytrip.com/media/Hotel/SHL-260127857612651/Hotel/HotelaOinJi.png',1,true),
  ('a1a1a1a1-1111-1111-1111-111111111103','facilities','Evening Lake View','https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1600&q=80',2,false),
  ('a1a1a1a1-1111-1111-1111-111111111103','outdoor-spaces','Terrace Reception Setup','https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&w=1600&q=80',3,false)
on conflict do nothing;

insert into supplier_packages (supplier_id, name, price_from, price_unit, guest_max, description, inclusions, is_featured, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111103','Sunset Reception',250000,'per event',80,'An intimate sunset reception on the terrace.',
    array['Terrace rental (evening slot)','Light catering & bar setup','Ambient lighting'], false, 1),
  ('a1a1a1a1-1111-1111-1111-111111111103','Lakeside Celebration',600000,'per event',150,'A full-evening lakeside celebration.',
    array['Full terrace rental','Multi-cuisine catering','Decor & lighting','Live music / DJ'], true, 2),
  ('a1a1a1a1-1111-1111-1111-111111111103','Grand Waterfront Gala',1000000,'per event',150,'A premium waterfront gala with full production.',
    array['Full terrace + adjoining lawn','Premium multi-cuisine catering','Full decor & stage lighting','Live entertainment', 'Dedicated event coordinator'], false, 3)
on conflict do nothing;

insert into supplier_faqs (supplier_id, question, answer, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111103','Is the venue fully outdoor?','Yes, it is an open-air waterfront terrace - a covered indoor fallback can be arranged on request for monsoon dates.',1),
  ('a1a1a1a1-1111-1111-1111-111111111103','Do you provide catering?','Yes, multi-cuisine plated or buffet catering is available.',2),
  ('a1a1a1a1-1111-1111-1111-111111111103','Is parking available?','Yes, valet parking is included.',3),
  ('a1a1a1a1-1111-1111-1111-111111111103','What is the best time of day to book?','Evening slots are most popular for the sunset and lake-view lighting, but daytime bookings are available too.',4),
  ('a1a1a1a1-1111-1111-1111-111111111103','Can you host product launches?','Yes, the terrace's photogenic lake-view setting is popular for product launches and brand events.',5)
on conflict do nothing;

-- ============================================================================
-- BLUSPRING
-- ============================================================================
insert into suppliers (id, owner, business_name, category, description, city, capacity, starting_price,
  amenities, verified, rating, review_count, status, tagline, years_experience, featured)
values ('a1a1a1a1-1111-1111-1111-111111111104','11111111-1111-1111-1111-111111111111',
  'Bluspring','event_manager',
  'A managed catering and hospitality service for corporate and institutional events across Udaipur, bringing full-service food and staffing to any venue.',
  'Udaipur', 9999, 800,
  array['Multi-cuisine catering','Live counters','Waitstaff & hospitality crew','Buffet & plated service','Custom menus'],
  true, 4.6, 58, 'active', 'Food & Hospitality - full-service managed catering across Udaipur', 9, false)
on conflict (id) do nothing;

insert into supplier_profiles (supplier_id, contact_person, contact_email, contact_phone, address, google_maps_url, payment_terms, refund_policy, booking_policy) values
  ('a1a1a1a1-1111-1111-1111-111111111104','Karan Soni - Operations Head','events@bluspring.example','+91 294 XXXX XXXX',
   'Udaipur, Rajasthan','https://maps.google.com/?q=Bluspring+Catering+Udaipur',
   '30% advance on confirmation, balance due 3 days before the event.',
   'Moderate - 50% refund up to 14 days before the event date.',
   'Menu and guest count must be finalised 7 days before the event.')
on conflict (supplier_id) do nothing;

insert into supplier_services (supplier_id, name, description, price_from, unit) values
  ('a1a1a1a1-1111-1111-1111-111111111104','Corporate Catering','Multi-cuisine buffet or plated service', 850, 'per plate'),
  ('a1a1a1a1-1111-1111-1111-111111111104','Live Counter Setup','Live cooking stations (chaat, pasta, grill etc.)', 25000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111104','Hospitality Staffing','Waitstaff & guest hospitality crew', 15000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111104','Menu Tasting & Planning','Pre-event tasting session with the chef', 5000, 'per session')
on conflict do nothing;

insert into supplier_media (supplier_id, category, caption, url, sort, is_cover) values
  ('a1a1a1a1-1111-1111-1111-111111111104','past-events','Corporate Buffet Setup','https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=1600&q=80',1,true),
  ('a1a1a1a1-1111-1111-1111-111111111104','past-events','Live Counter Station','https://images.unsplash.com/photo-1555244162-803834f70033?auto=format&fit=crop&w=1600&q=80',2,false),
  ('a1a1a1a1-1111-1111-1111-111111111104','corporate-events','Corporate Dinner Service','https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1600&q=80',3,false)
on conflict do nothing;

insert into supplier_packages (supplier_id, name, price_from, price_unit, description, inclusions, is_featured, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111104','Day Coordination',150000,'per event','Catering-only support for a single-day event.',
    array['Multi-cuisine buffet catering','Waitstaff for service','Menu planning session'], false, 1),
  ('a1a1a1a1-1111-1111-1111-111111111104','Full Event Management',500000,'per event','Full catering + hospitality management.',
    array['Multi-cuisine catering with live counters','Full hospitality staffing','On-site catering manager','Menu tasting included'], true, 2),
  ('a1a1a1a1-1111-1111-1111-111111111104','End-to-End Production',900000,'per event','Large-scale catering for conferences and institutional events.',
    array['Premium multi-cuisine catering, multiple live counters','Full staffing & guest hospitality desk','Dedicated catering manager on-site','Custom dietary menus (Jain/vegan/allergen-specific)'], false, 3)
on conflict do nothing;

insert into supplier_faqs (supplier_id, question, answer, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111104','Do you work with our own venue?','Yes - we bring our full catering and hospitality team to any Udaipur venue, including ones not listed on Eventara.',1),
  ('a1a1a1a1-1111-1111-1111-111111111104','Can you handle dietary restrictions?','Yes, including Jain, vegan and allergen-specific menus.',2),
  ('a1a1a1a1-1111-1111-1111-111111111104','What is the minimum guest count you cater for?','We typically take on events from 50 guests upward.',3),
  ('a1a1a1a1-1111-1111-1111-111111111104','Do you provide waitstaff?','Yes, hospitality staffing is available as an add-on or included in the larger packages.',4),
  ('a1a1a1a1-1111-1111-1111-111111111104','How far in advance should we book?','At least 2-3 weeks ahead for standard events; 6+ weeks for large institutional functions.',5)
on conflict do nothing;

-- ============================================================================
-- INDICRAFT COMMUNICATIONS
-- ============================================================================
insert into suppliers (id, owner, business_name, category, description, city, capacity, starting_price,
  amenities, verified, rating, review_count, status, tagline, years_experience, featured)
values ('a1a1a1a1-1111-1111-1111-111111111105','11111111-1111-1111-1111-111111111111',
  'Indicraft Communications','event_manager',
  'An events, branding and promotions agency handling stage production, signage and artist/celebrity coordination for corporate launches and large functions across Udaipur.',
  'Udaipur', 9999, 1000,
  array['Stage & AV production','Branding & signage','Artist/celebrity coordination','Event photography','Social media coverage'],
  true, 4.4, 73, 'active', 'Events & Promotions - branding, production and celebrity management', 11, false)
on conflict (id) do nothing;

insert into supplier_profiles (supplier_id, contact_person, contact_email, contact_phone, address, google_maps_url, payment_terms, refund_policy, booking_policy) values
  ('a1a1a1a1-1111-1111-1111-111111111105','Aditya Singh Chouhan - Client Servicing Lead','events@indicraft.example','+91 294 XXXX XXXX',
   'Udaipur, Rajasthan','https://maps.google.com/?q=Indicraft+Communications+Udaipur',
   '30% advance on confirmation, balance due 7 days before the event.',
   'Moderate - 50% refund up to 21 days before the event date.',
   'Creative brief and production plan must be signed off 10 days before the event.')
on conflict (supplier_id) do nothing;

insert into supplier_services (supplier_id, name, description, price_from, unit) values
  ('a1a1a1a1-1111-1111-1111-111111111105','Event Branding & Signage','On-site branding, signage and backdrops', 40000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111105','Stage & AV Production','Stage build, sound and lighting', 80000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111105','Artist Coordination','Booking & logistics for performers/guests', 60000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111105','Event Photography','Full-event photo coverage', 25000, 'per event')
on conflict do nothing;

insert into supplier_media (supplier_id, category, caption, url, sort, is_cover) values
  ('a1a1a1a1-1111-1111-1111-111111111105','past-events','Stage Production','https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&w=1600&q=80',1,true),
  ('a1a1a1a1-1111-1111-1111-111111111105','decor-staging','Branding & Signage Setup','https://images.unsplash.com/photo-1531058020387-3be344556be6?auto=format&fit=crop&w=1600&q=80',2,false),
  ('a1a1a1a1-1111-1111-1111-111111111105','corporate-events','Corporate Launch Event','https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1600&q=80',3,false)
on conflict do nothing;

insert into supplier_packages (supplier_id, name, price_from, price_unit, description, inclusions, is_featured, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111105','Corporate Activation',200000,'per event','A branded activation or small launch event.',
    array['Branding & signage','Basic stage & sound','Event photography'], false, 1),
  ('a1a1a1a1-1111-1111-1111-111111111105','Full Event Production',600000,'per event','Full production for a mid-size corporate event.',
    array['Stage, AV & lighting production','Branding & signage across the venue','Artist/host coordination','Full event photography'], true, 2),
  ('a1a1a1a1-1111-1111-1111-111111111105','Flagship Launch Event',1200000,'per event','A large-scale flagship product or brand launch.',
    array['Full stage & AV production with LED walls','Complete branding & experiential setup','Celebrity/artist coordination','Photography + social media coverage','Dedicated production manager'], false, 3)
on conflict do nothing;

insert into supplier_faqs (supplier_id, question, answer, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111105','Do you handle celebrity or artist bookings?','Yes, artist and celebrity coordination is one of our core services, handled end-to-end.',1),
  ('a1a1a1a1-1111-1111-1111-111111111105','Can you work at a venue we already booked?','Yes, we bring our production and branding team to any Udaipur venue.',2),
  ('a1a1a1a1-1111-1111-1111-111111111105','Do you provide event photography?','Yes, full-event photography and social media coverage are available as add-ons.',3),
  ('a1a1a1a1-1111-1111-1111-111111111105','What size events do you handle?','From focused corporate activations to large flagship launches with 500+ attendees.',4),
  ('a1a1a1a1-1111-1111-1111-111111111105','How far ahead should we brief you?','At least 3-4 weeks for standard productions; 8+ weeks for large flagship launches.',5)
on conflict do nothing;

-- ============================================================================
-- BLOSSOM EVENTS
-- ============================================================================
insert into suppliers (id, owner, business_name, category, description, city, capacity, starting_price,
  amenities, verified, rating, review_count, status, tagline, years_experience, featured)
values ('a1a1a1a1-1111-1111-1111-111111111106','11111111-1111-1111-1111-111111111111',
  'Blossom Events','event_manager',
  'A full-service event management company operating in Udaipur since 2009, covering corporate events, institutional functions and celebrations with in-house decor and production teams.',
  'Udaipur', 9999, 1400,
  array['End-to-end event planning','Decor & floral design','Stage & lighting design','Entertainment booking','On-site coordination team'],
  true, 4.9, 167, 'active', 'Event Management - full-service planning since 2009', 17, true)
on conflict (id) do nothing;

insert into supplier_profiles (supplier_id, contact_person, contact_email, contact_phone, address, google_maps_url, payment_terms, refund_policy, booking_policy) values
  ('a1a1a1a1-1111-1111-1111-111111111106','Neha Kothari - Founder & Creative Director','events@blossomevent.example','+91 294 XXXX XXXX',
   'Fatehpura, Udaipur, Rajasthan','https://maps.google.com/?q=Blossom+Events+Fatehpura+Udaipur',
   '30% advance on confirmation, balance due 7 days before the event.',
   'Moderate - 50% refund up to 30 days before the event date.',
   'Design brief and vendor coordination plan finalised 14 days before the event.')
on conflict (supplier_id) do nothing;

insert into supplier_services (supplier_id, name, description, price_from, unit) values
  ('a1a1a1a1-1111-1111-1111-111111111106','Decor & Floral Design','Stage, entrance and table decor design', 90000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111106','Stage & Lighting','Custom stage build with lighting design', 70000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111106','Entertainment Booking','Musicians, MCs and performers', 50000, 'per event'),
  ('a1a1a1a1-1111-1111-1111-111111111106','Full Event Coordination','End-to-end planning and on-site management', 120000, 'per event')
on conflict do nothing;

insert into supplier_media (supplier_id, category, caption, url, sort, is_cover) values
  ('a1a1a1a1-1111-1111-1111-111111111106','past-events','Signature Event Setup','https://blossomevent.com/wp-content/uploads/2025/06/AJ1A2224-1-scaled-1.webp',1,true),
  ('a1a1a1a1-1111-1111-1111-111111111106','decor-staging','Stage & Floral Design','https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=1600&q=80',2,false),
  ('a1a1a1a1-1111-1111-1111-111111111106','corporate-events','Corporate Function','https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&w=1600&q=80',3,false),
  ('a1a1a1a1-1111-1111-1111-111111111106','institutional-events','College Fest Production','https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?auto=format&fit=crop&w=1600&q=80',4,false)
on conflict do nothing;

insert into supplier_packages (supplier_id, name, price_from, price_unit, description, inclusions, is_featured, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111106','Corporate Day Event',250000,'per event','A single-day corporate event with essential production.',
    array['Stage & basic decor','Sound & lighting','On-site coordinator'], false, 1),
  ('a1a1a1a1-1111-1111-1111-111111111106','Full-Service Celebration',800000,'per event','Complete event management for a larger celebration.',
    array['Full decor & floral design','Stage & lighting production','Entertainment booking','Dedicated event manager end-to-end'], true, 2),
  ('a1a1a1a1-1111-1111-1111-111111111106','Signature Grand Event',1500000,'per event','A flagship, fully-produced celebration or institutional event.',
    array['Premium decor, floral & stage design','Full production (sound, lighting, LED)','Entertainment & artist coordination','Complete on-site vendor management','Dedicated senior event manager'], false, 3)
on conflict do nothing;

insert into supplier_faqs (supplier_id, question, answer, sort) values
  ('a1a1a1a1-1111-1111-1111-111111111106','Do you work with our own venue?','Yes, we can plan and produce your event at any venue in Udaipur, including ones not listed on Eventara.',1),
  ('a1a1a1a1-1111-1111-1111-111111111106','Can you handle multi-day college fests?','Yes, we regularly manage multi-day institutional events and college fests.',2),
  ('a1a1a1a1-1111-1111-1111-111111111106','Do you provide decor and floral design in-house?','Yes, our in-house decor team handles stage, floral and table design.',3),
  ('a1a1a1a1-1111-1111-1111-111111111106','How experienced is your team?','We have been operating in Udaipur since 2009, across corporate, institutional and celebration events.',4),
  ('a1a1a1a1-1111-1111-1111-111111111106','How far ahead should we book?','4-6 weeks ahead is typical; 8+ weeks recommended for large institutional or flagship events.',5)
on conflict do nothing;

-- ============================================================================
-- end 0010_supplier_detail_seed.sql
-- ============================================================================
