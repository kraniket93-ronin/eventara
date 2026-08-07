/* ============================================================
   EVENTARA - Sitemap  (Vercel Serverless Function)
   ------------------------------------------------------------
   GET /sitemap.xml   (rewritten to /api/sitemap)

   Generated from the database, not committed as a file. Suppliers
   self-onboard, so a static sitemap is out of date the moment
   someone publishes a listing - and with 100+ suppliers it would
   need regenerating and redeploying on every signup.

   Only suppliers visible in v_supplier_public are listed. That view
   already filters to status = 'active', so a 'draft' listing - one
   that has registered but not yet published - is never advertised
   to Google. Publishing puts it in this sitemap on the next crawl,
   with no deploy.
   ============================================================ */

const SUPABASE_URL =
  process.env.SUPABASE_URL || 'https://jqqliblliwluzdjcmcgz.supabase.co';
const SUPABASE_ANON =
  process.env.SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxcWxpYmxsaXdsdXpkamNtY2d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3MzMzNjUsImV4cCI6MjEwMDMwOTM2NX0.TOZrzu7qOcElO2vZxQmVxBVNyNUImB75Vc4obGTtHfg';

const SITE = 'https://www.eventara.co.in';

// Public, crawlable pages that are not supplier listings.
const STATIC = [
  { loc: '/',            changefreq: 'weekly',  priority: '1.0' },
  { loc: '/search.html', changefreq: 'daily',   priority: '0.9' },
  { loc: '/brief.html',  changefreq: 'monthly', priority: '0.8' },
  { loc: '/faq.html',    changefreq: 'monthly', priority: '0.7' },
  { loc: '/help.html',   changefreq: 'monthly', priority: '0.5' }
];

function xmlEscape(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&apos;');
}

function urlNode({ loc, changefreq, priority, lastmod }) {
  return '  <url>\n' +
    `    <loc>${xmlEscape(SITE + loc)}</loc>\n` +
    (lastmod ? `    <lastmod>${xmlEscape(lastmod)}</lastmod>\n` : '') +
    (changefreq ? `    <changefreq>${changefreq}</changefreq>\n` : '') +
    (priority ? `    <priority>${priority}</priority>\n` : '') +
    '  </url>';
}

export default async function handler(req, res) {
  let suppliers = [];
  let degraded = false;

  try {
    const r = await fetch(
      `${SUPABASE_URL}/rest/v1/v_supplier_public?select=slug&order=business_name&limit=5000`,
      { headers: { apikey: SUPABASE_ANON, Authorization: `Bearer ${SUPABASE_ANON}` } }
    );
    if (r.ok) suppliers = await r.json();
    else degraded = true;
  } catch (e) {
    degraded = true;
  }

  const urls = STATIC.map(urlNode);

  for (const s of suppliers) {
    if (!s.slug || !/^[a-z0-9][a-z0-9-]{0,79}$/.test(s.slug)) continue;
    urls.push(urlNode({ loc: `/venue/${s.slug}`, changefreq: 'weekly', priority: '0.8' }));
  }

  const xml =
    '<?xml version="1.0" encoding="UTF-8"?>\n' +
    `<!-- Generated ${new Date().toISOString()} - ${suppliers.length} supplier(s) live -->\n` +
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' +
    urls.join('\n') + '\n</urlset>\n';

  res.setHeader('Content-Type', 'application/xml; charset=utf-8');
  // If the database was unreachable the static pages are still correct, but
  // cache it briefly so a full list returns soon rather than being pinned.
  res.setHeader('Cache-Control', degraded
    ? 'public, s-maxage=60'
    : 'public, s-maxage=3600, stale-while-revalidate=86400');
  return res.status(200).send(xml);
}
