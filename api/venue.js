/* ============================================================
   EVENTARA - Supplier page, server-rendered head  (Vercel Function)
   ------------------------------------------------------------
   GET /venue/<slug>        (rewritten to /api/venue?slug=<slug>)

   WHY THIS EXISTS
   supplier.html is one shell shared by every supplier; its title,
   canonical and structured data are written by JavaScript after a
   Supabase fetch. That is fine for people and wrong for crawlers:
   on the first pass every supplier URL serves byte-identical HTML
   titled "Supplier Profile - Eventara". Google would very likely
   keep one and drop the rest as duplicates.

   Pre-generating static files per supplier was the obvious fix and
   the wrong one - suppliers self-onboard, so a listing published on
   Tuesday would need a code deploy to become indexable, and 100+
   suppliers would mean 100+ committed files.

   Instead this function serves the SAME shell with a per-supplier
   <head> injected server-side. One file, any number of suppliers,
   and a listing is indexable the moment it is published.

   The shell is fetched from /supplier.html rather than duplicated
   here, so the page markup keeps exactly one source of truth.
   ============================================================ */

const SUPABASE_URL =
  process.env.SUPABASE_URL || 'https://jqqliblliwluzdjcmcgz.supabase.co';
// The anon key is public by design - Row-Level Security is the boundary,
// not this string. It ships to every browser already.
const SUPABASE_ANON =
  process.env.SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxcWxpYmxsaXdsdXpkamNtY2d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3MzMzNjUsImV4cCI6MjEwMDMwOTM2NX0.TOZrzu7qOcElO2vZxQmVxBVNyNUImB75Vc4obGTtHfg';

const SITE = 'https://www.eventara.co.in';

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function titleCase(s) {
  return String(s || '').split(/[-_]+/)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
}

async function rest(path) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: { apikey: SUPABASE_ANON, Authorization: `Bearer ${SUPABASE_ANON}` }
  });
  if (!r.ok) return null;
  return r.json();
}

/* ------------------------------------------------------------
   Relative -> root-absolute asset paths.

   The shell lives at /supplier.html, so its paths are written
   relative to the site root. Served from /venue/<slug> the browser
   resolves them against /venue/ instead: "styles.css" becomes
   "/venue/styles.css", which falls back into this same rewrite and
   400s. Symptom is a completely unstyled page with broken images
   and no JavaScript at all.
   ------------------------------------------------------------ */

// Already resolvable from anywhere, or must not be touched. A bare
// "#about" especially: turning it into "/#about" would send the
// section nav to the homepage instead of scrolling the page.
const ABSOLUTE = /^(\/|https?:|\/\/|#|mailto:|tel:|data:|javascript:|blob:)/i;

// Placeholder for masked script bodies. Uses characters that cannot
// occur in HTML text so it can never collide with real content.
const MASK_OPEN = '';
const MASK_CLOSE = '';

function rootRelativeAssets(html) {
  // Mask script BODIES before rewriting. They contain JavaScript that
  // builds markup by concatenation - '<img src="' + url + '"' - and a
  // plain attribute rewrite matches those fragments too, producing
  // src="/' + url + '" and corrupting every URL the page generates at
  // runtime. The opening <script src="..."> tag is left exposed, since
  // that is how data-api.js and the rest are loaded and it does need
  // rewriting.
  const bodies = [];
  html = html.replace(
    /(<script[^>]*>)([\s\S]*?)(<\/script>)/gi,
    (m, open, body, close) => {
      bodies.push(body);
      return open + MASK_OPEN + (bodies.length - 1) + MASK_CLOSE + close;
    }
  );

  // src="..." / href="..." on links, stylesheets, images and anchors
  html = html.replace(/(src|href)="([^"]*)"/gi, (m, attr, val) => {
    if (!val || ABSOLUTE.test(val)) return m;
    return attr + '="/' + val + '"';
  });

  // url(...) inside the shell's inline <style> blocks
  html = html.replace(/url\((['"]?)([^'")]+)\1\)/gi, (m, quote, val) => {
    if (!val || ABSOLUTE.test(val)) return m;
    return 'url(' + quote + '/' + val + quote + ')';
  });

  return html.replace(
    new RegExp(MASK_OPEN + '(\\d+)' + MASK_CLOSE, 'g'),
    (m, i) => bodies[Number(i)]
  );
}

function buildHead(s, url) {
  const kind = titleCase(s.category);
  const verified = s.verified ? 'Verified ' : '';
  const title = `${s.business_name} - ${verified}${kind} in ${s.city} | Eventara`;
  const desc = (s.description || s.tagline ||
      `${s.business_name} is ${s.verified ? 'a verified ' : 'a '}${kind.toLowerCase()} on Eventara in ${s.city}.`)
      .replace(/\s+/g, ' ').trim().slice(0, 300);
  const img = s.cover_image || s.hero_image_url || s.media_cover_url || `${SITE}/images/login-bg.jpg`;

  const isVenue = s.category === 'banquet_hotel';
  const node = {
    '@context': 'https://schema.org',
    '@type': isVenue ? 'EventVenue' : 'ProfessionalService',
    '@id': `${url}#business`,
    name: s.business_name,
    url,
    description: desc,
    address: {
      '@type': 'PostalAddress',
      addressLocality: s.city || 'Udaipur',
      addressRegion: 'Rajasthan',
      addressCountry: 'IN'
    },
    areaServed: { '@type': 'City', name: s.city || 'Udaipur' },
    isPartOf: { '@type': 'WebSite', '@id': `${SITE}/#website` },
    provider: { '@type': 'Organization', '@id': `${SITE}/#organization` }
  };
  if (img) node.image = img;
  if (isVenue && s.capacity) node.maximumAttendeeCapacity = s.capacity;
  if (s.starting_price) node.priceRange = `From Rs ${s.starting_price}`;
  // Only claim a rating when real reviews back it - aggregateRating with no
  // reviewCount is a manual-action risk.
  if (s.rating > 0 && s.review_count > 0) {
    node.aggregateRating = {
      '@type': 'AggregateRating',
      ratingValue: String(s.rating),
      reviewCount: String(s.review_count),
      bestRating: '5', worstRating: '1'
    };
  }

  const crumbs = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: 'Eventara', item: `${SITE}/` },
      { '@type': 'ListItem', position: 2, name: `Suppliers in ${s.city}`, item: `${SITE}/search.html` },
      { '@type': 'ListItem', position: 3, name: s.business_name, item: url }
    ]
  };

  return `
  <!-- EVENTARA-SSR -->
  <link rel="canonical" href="${esc(url)}">
  <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1">
  <meta property="og:type" content="business.business">
  <meta property="og:site_name" content="Eventara">
  <meta property="og:locale" content="en_IN">
  <meta property="og:title" content="${esc(title)}">
  <meta property="og:description" content="${esc(desc)}">
  <meta property="og:url" content="${esc(url)}">
  <meta property="og:image" content="${esc(img)}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${esc(title)}">
  <meta name="twitter:description" content="${esc(desc)}">
  <meta name="twitter:image" content="${esc(img)}">
  <script type="application/ld+json">${JSON.stringify(node)}</script>
  <script type="application/ld+json">${JSON.stringify(crumbs)}</script>
  <!-- /EVENTARA-SSR -->
`;
}

export default async function handler(req, res) {
  const raw = (req.query?.slug || '').toString().trim().toLowerCase();
  // Slugs are generated by slugify() in the database; anything else is a
  // probe. Validating here keeps the value safe to interpolate into PostgREST.
  if (!/^[a-z0-9][a-z0-9-]{0,79}$/.test(raw)) {
    res.setHeader('X-Robots-Tag', 'noindex');
    return res.status(400).send('Invalid supplier address.');
  }

  let rows = null;
  try {
    rows = await rest(
      `v_supplier_public?slug=eq.${encodeURIComponent(raw)}` +
      `&select=slug,business_name,category,description,tagline,city,capacity,` +
      `starting_price,rating,review_count,verified,cover_image,hero_image_url,media_cover_url&limit=1`
    );
  } catch (e) { /* fall through to the 503 below */ }

  if (rows === null) {
    // Database unreachable. A 503 tells Google to come back rather than
    // recording the URL as broken.
    res.setHeader('Retry-After', '120');
    res.setHeader('X-Robots-Tag', 'noindex');
    return res.status(503).send('Eventara is temporarily unavailable. Please try again shortly.');
  }

  const sup = rows[0];
  if (!sup) {
    // Unknown or unpublished (draft) supplier - a genuine 404, so Google
    // drops it instead of indexing an empty shell.
    res.setHeader('X-Robots-Tag', 'noindex');
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.status(404).send(
      `<!doctype html><meta charset="utf-8"><title>Supplier not found - Eventara</title>` +
      `<meta name="robots" content="noindex"><meta http-equiv="refresh" content="3;url=/search.html">` +
      `<p>That supplier is not listed on Eventara. Taking you to <a href="/search.html">all suppliers</a>…</p>`
    );
  }

  const url = `${SITE}/venue/${sup.slug}`;

  // One source of truth for the markup: fetch the shell rather than keeping
  // a second copy of the page in this function.
  const proto = req.headers['x-forwarded-proto'] || 'https';
  const host = req.headers.host;
  let html;
  try {
    const shell = await fetch(`${proto}://${host}/supplier.html`);
    if (!shell.ok) throw new Error(`shell ${shell.status}`);
    html = await shell.text();
  } catch (e) {
    res.setHeader('Retry-After', '120');
    return res.status(503).send('Eventara is temporarily unavailable. Please try again shortly.');
  }

  const kind = titleCase(sup.category);
  const title = `${sup.business_name} - ${sup.verified ? 'Verified ' : ''}${kind} in ${sup.city} | Eventara`;

  // Make every relative path resolve from the site root, not from /venue/.
  html = rootRelativeAssets(html);

  // Strip the shell's own generic SEO block. It carries a placeholder
  // og:title/description that appears EARLIER in the document than anything
  // injected before </head>, and scrapers take the first occurrence - so
  // leaving it would hand Facebook, WhatsApp and Google the shared
  // "Supplier Profile - Eventara" instead of this supplier's.
  html = html.replace(/<!-- EVENTARA-SEO -->[\s\S]*?<!-- \/EVENTARA-SEO -->/i, '');

  // Replace the shell's placeholder title, then inject the real head.
  html = html.replace(/<title[^>]*>[\s\S]*?<\/title>/i, `<title id="pageTitle">${esc(title)}</title>`);
  html = html.replace(/<\/head>/i, buildHead(sup, url) + '</head>');

  // Tell the client script which supplier this is. Without it boot() reads
  // ?slug= from a query string that does not exist on /venue/<slug> and shows
  // "Supplier Not Found".
  html = html.replace(/<body/i,
    `<script>window.__SSR_SLUG=${JSON.stringify(sup.slug)};window.__SSR_SEO=true;</script>\n<body`);

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  // Cached at the edge so repeat crawls and real visitors do not re-query
  // Postgres; stale-while-revalidate keeps edits appearing quickly.
  res.setHeader('Cache-Control', 'public, s-maxage=600, stale-while-revalidate=86400');
  return res.status(200).send(html);
}
