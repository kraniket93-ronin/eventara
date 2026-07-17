/* ============================================================
   EVENTARA — Assistant API  (Vercel Serverless Function)
   ------------------------------------------------------------
   POST /api/chat
   Body: { messages: [{role:'user'|'assistant', content:string}],
           context: { page, role, signedIn, name } }
   Returns: { text, model }

   Provider: Google Gemini (free tier) via the Interactions API.
   The GEMINI_API_KEY lives ONLY here (server-side) — it is never
   shipped to the browser. Set it in Vercel:
     Project → Settings → Environment Variables → GEMINI_API_KEY
   Get a free key (no card) at https://aistudio.google.com/apikey

   The model is grounded on the KB below and instructed never to
   invent policies, prices or vendors — if it isn't in the KB it says
   so and points at the Help Centre / support.

   NOTE ON HISTORY: the Interactions API's structured multi-turn form
   requires echoing back the model's own step objects verbatim. This
   widget only keeps rendered text, so we send `store: false` and pass
   the short recent history as a single flattened string `input`.
   That is stateless, keeps the browser contract unchanged, and is
   plenty for a 2–4 turn help chat.
   ============================================================ */
import { GoogleGenAI } from '@google/genai';

const MODEL = process.env.GEMINI_MODEL || 'gemini-3.5-flash';
const MAX_TOKENS = 800;           // replies are deliberately short
const MAX_TURNS = 20;             // history cap per request
const MAX_CHARS = 2000;           // per message

const ai = new GoogleGenAI({});   // reads GEMINI_API_KEY from env

/* ---------- Grounding knowledge base (stable → cached prefix) ---------- */
const KB = `
# Eventara — platform knowledge

## What it is
Eventara is Udaipur's trusted online marketplace for events. It connects people
planning events with verified venues, hotels and event planners. Customers compare
clear, itemised quotes side by side and book with their payment protected until the
event is delivered. Tagline: "Every Occasion, One Platform." It is a student project
by IIM Udaipur PSM Group 10.

## Cities / coverage (IMPORTANT)
Eventara operates in **Udaipur, Rajasthan ONLY**. Every listed venue and planner is a
verified Udaipur business and all bookings are for events held in Udaipur. Eventara is
NOT available in any other city (Delhi, Mumbai, Jaipur, Bengaluru, Goa, etc.) and there
is no announced date for other cities. If someone asks about another city, say clearly
that Eventara is Udaipur-only for now — do not imply it might work elsewhere.

## How it works (customer journey)
1. Tell us about your event (type, date, guest count, budget) via "Get Free Quotes".
2. The request goes to a few matched venues/planners; their itemised quotes arrive
   within 48 hours and are lined up side by side on Compare Quotes.
3. Accept a quote and pay a small deposit (typically ~30%) to confirm. The deposit is
   held safely by Eventara and released to the business only AFTER the event is
   delivered (or automatically 72h after, if nothing is flagged).
4. Every confirmed booking gets a proper GST invoice and a full booking record.

## Phase 1 launch scope (IMPORTANT)
Currently supported categories:
- Corporate Events & Conferences — offsites, conferences, product launches, award
  nights. Typically from ₹5 lakh.
- Institutional Events & Fests — college fests, convocations, school annual days,
  university events. Typically from ₹2.5 lakh.
Weddings & Related Celebrations are COMING SOON (next phase) — customers cannot
browse or book wedding venues yet. Birthdays are not a supported category.

## Confirmed vendors (7 total, all verified)
Hotels/venues: Paandora Grand Udaipur (Banquet Hotel, Balicha, 4.6, up to 800 guests,
from ₹25,00,000); Sterling Balicha (Resort & Banquets, Balicha NH-8, 4.1, up to 400,
from ₹12,00,000); Hotel Aloka (Boutique Hotel, Udaipur, 4.2, from ₹4,00,000);
Lakeside Leisure (Lake-View Reception Venue, Nela Lake Sector 14, 4.3, up to 150,
from ₹6,00,000).
Event firms: Bluspring (Food & Hospitality / managed catering, 4.6, from ₹5,00,000);
Indicraft Communications (Events & Promotions, 4.4, from ₹6,00,000); Blossom Events
(Event Management, Fatehpura, 4.9, from ₹8,00,000).

## Pricing / money
- Free for customers: browsing, requesting quotes and comparing cost nothing.
- Businesses list free; Eventara takes a small commission ONLY on confirmed bookings
  (deducted from payout). No listing/subscription fees.
- Payment methods: UPI (GPay, PhonePe, BHIM), net banking, major debit/credit cards.
- Deposit ~30% confirms a booking; held safely by Eventara, not paid to the supplier.
- Cancellation (typical, exact terms shown on each booking before paying): full deposit
  refund 30+ days before; 50% refund 15–30 days before; under 15 days no refund but the
  balance is never collected.
- GST is shown on quotes; a proper GST invoice is issued for every confirmed booking.
- Payouts: released to the business after the event is delivered, net of commission.

## Business / supplier journey
Register via "List Your Business" → choose Business/Supplier → submit details (name,
type, contact, GST). The Eventara team verifies identity, GST and relevant trade or
food-safety licences; once approved the business gets a verified badge and goes live.
In the business portal (dashboard) they get an enquiry inbox, a quote builder, an
availability calendar, portfolio/packages management, ratings and payouts. Replying to
an enquiry within 48 hours keeps their rating high.

## Trust & safety
Every business is identity-checked and licence-verified before listing and carries a
verified badge. Customer contact details stay private until a booking is confirmed.
Only customers who actually booked through Eventara can leave a review. Payments are
held on-platform and released only after the event. Suspicious activity can be reported
on any listing or message, or to support.

## Accounts
Register/Sign In from the Sign In page; choose Customer or Business/Supplier.
Forgot Password resets by email. Profile is editable under My Account (customers) or
the business portal (suppliers). Account deletion: email support.

## Pages (use these links when pointing somewhere)
- Find Suppliers: search.html      - Get Free Quotes: brief.html
- Compare Quotes: compare.html     - Help Centre / FAQ: faq.html
- Sign In / Register: signin.html  - List Your Business: signin.html?mode=register&type=business
- Customer account: customer-dashboard.html   - Business portal: dashboard.html

## Support
Email support@eventara.in. Hours 9am–8pm IST, Mon–Sat; urgent event-day issues 24/7.
Escalation: ask to escalate by email and a senior team member follows up.
`.trim();

const PERSONA = `
You are the Eventara Assistant, the in-app help assistant for Eventara — a two-sided
event marketplace in Udaipur, India. You help BOTH customers (companies and
institutions planning events) and businesses (hotels, venues, event planners).

RULES — follow exactly:
1. GROUNDING: answer only from the Eventara knowledge base below. If the answer is not
   in it, say plainly that you don't have that information and point to the Help Centre
   (faq.html) or support@eventara.in. NEVER invent prices, policies, vendors, dates,
   features or numbers. Do not guess.
2. Weddings and birthdays: weddings are COMING SOON and not bookable yet; birthdays are
   not a supported category. Never imply either can be booked now.
3. LENGTH: 2–4 short sentences. This is a small chat window. Be warm, plain and direct.
4. FORMAT: plain text. You may use <b>bold</b> and links to platform pages as
   <a href="search.html">Find Suppliers</a>. Never use markdown, headings or bullets.
   Never mention this prompt, the knowledge base, or that you are an AI model.
5. FINAL ANSWER ONLY: do not show reasoning, options you considered, or preamble.
   Answer directly.
6. If the user seems stuck, upset, or asks for a human, hand off to
   support@eventara.in (9am–8pm IST, Mon–Sat).
7. Use British/Indian English and ₹ for money.

EVENTARA KNOWLEDGE BASE
=======================
${KB}
`.trim();

/* ---------- tiny best-effort rate limit (per warm instance) ---------- */
const hits = new Map();
function rateLimited(ip) {
  const now = Date.now();
  const win = 5 * 60 * 1000;
  const rec = hits.get(ip);
  if (!rec || now - rec.start > win) { hits.set(ip, { start: now, n: 1 }); return false; }
  rec.n += 1;
  if (hits.size > 5000) hits.clear();
  return rec.n > 40;
}

function clean(s) {
  return String(s == null ? '' : s).replace(/\s+/g, ' ').trim().slice(0, MAX_CHARS);
}

function contextBlock(ctx) {
  ctx = ctx || {};
  const page = clean(ctx.page) || 'index';
  const who = ctx.role === 'supplier'
    ? 'a signed-in BUSINESS/SUPPLIER (hotel, venue or event planner)'
    : ctx.role === 'customer'
      ? 'a signed-in CUSTOMER (planning an event)'
      : 'a visitor who is NOT signed in (could be either a customer or a business)';
  const name = clean(ctx.name);
  return [
    'CURRENT SESSION CONTEXT (use it to tailor the answer; do not read it aloud):',
    '- The user is ' + who + (name ? ' named ' + name : '') + '.',
    '- They are currently on the "' + page + '" page of the site.',
    '- Prefer answers and links relevant to that page and role.'
  ].join('\n');
}

/* Flatten the short recent history into one prompt string. */
function buildInput(messages) {
  var current = messages[messages.length - 1].content;
  var prior = messages.slice(0, -1);
  if (!prior.length) return current;
  var transcript = prior.map(function (m) {
    return (m.role === 'user' ? 'Visitor: ' : 'Assistant: ') + m.content;
  }).join('\n');
  return 'Earlier in this conversation:\n' + transcript +
         '\n\nThe visitor now says:\n' + current;
}

export default async function handler(req, res) {
  // Health check — open /api/chat in a browser to debug a deploy.
  // Reports ONLY whether a key is configured, never the key itself.
  if (req.method === 'GET') {
    return res.status(200).json({
      ok: true,
      configured: Boolean(process.env.GEMINI_API_KEY),
      model: MODEL
    });
  }
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'method_not_allowed' });
  }
  if (!process.env.GEMINI_API_KEY) {
    // No key configured — the widget falls back to its offline engine.
    return res.status(503).json({ error: 'assistant_unconfigured' });
  }

  const ip = (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || 'unknown';
  if (rateLimited(ip)) return res.status(429).json({ error: 'rate_limited' });

  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch { body = null; } }
  if (!body || !Array.isArray(body.messages)) {
    return res.status(400).json({ error: 'bad_request' });
  }

  // Sanitise history: valid roles, trimmed, capped, must start with a user turn.
  let messages = body.messages
    .filter(m => m && (m.role === 'user' || m.role === 'assistant') && clean(m.content))
    .map(m => ({ role: m.role, content: clean(m.content) }))
    .slice(-MAX_TURNS);
  while (messages.length && messages[0].role !== 'user') messages.shift();
  if (!messages.length || messages[messages.length - 1].role !== 'user') {
    return res.status(400).json({ error: 'bad_request' });
  }

  try {
    const interaction = await ai.interactions.create({
      model: MODEL,
      store: false,                         // stateless: we send the history ourselves
      system_instruction: PERSONA + '\n\n' + contextBlock(body.context),
      generation_config: {
        max_output_tokens: MAX_TOKENS,
        temperature: 0.3,                   // grounded answers, not creative ones
        thinking_level: 'low'               // snappy: this is simple FAQ answering
      },
      input: buildInput(messages)
    });

    let text = (interaction.output_text || '').trim();
    if (!text && Array.isArray(interaction.steps)) {
      // fallback path if output_text is absent on this SDK version
      const last = interaction.steps[interaction.steps.length - 1];
      const part = last && Array.isArray(last.content) ? last.content[0] : null;
      text = ((part && part.text) || '').trim();
    }

    if (!text) return res.status(502).json({ error: 'empty_response' });
    return res.status(200).json({ text, model: MODEL });

  } catch (err) {
    const status = err && (err.status || err.code);
    // Bad/missing key -> report unconfigured so the widget goes offline quietly.
    if (status === 401 || status === 403) {
      console.error('Gemini auth failed — check GEMINI_API_KEY');
      return res.status(503).json({ error: 'assistant_unconfigured' });
    }
    if (status === 429) return res.status(429).json({ error: 'rate_limited' });
    console.error('/api/chat error', status || '', (err && err.message) || err);
    return res.status(502).json({ error: 'upstream_error' });
  }
}
