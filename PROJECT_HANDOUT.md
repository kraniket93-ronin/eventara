# EVENTARA - PROJECT HANDOUT

> **Single source of truth for the Eventara prototype.**
> If you are an AI coding assistant (Claude, ChatGPT, Cursor, Windsurf, Copilot) or a new
> developer: **read this document fully before changing any code.** It is written to give
> you complete context without needing to read every file first.

| | |
|---|---|
| **Project** | Eventara - event marketplace prototype |
| **Type** | Academic prototype (IIM Udaipur, PSM course, Group 10) |
| **Live URL** | https://the-eventara.vercel.app |
| **Repository** | https://github.com/kraniket93-ronin/eventara |
| **Doc version** | 2.1 (see §18 Change Log) |
| **Last verified against code** | 2026-07-18 |

> ⚠️ **CRITICAL REPO LAYOUT NOTE - read before pushing anything.**
> The **GitHub repo root == the contents of the local `prototype/` folder.**
> `index.html` sits at the *repo* root; there is **no `prototype/` folder in the repo**.
> So local `prototype/api/chat.js` → repo `api/chat.js`.
>
> **This file exists in two places, and they must be kept identical:**
> | Copy | Path | Goes to GitHub? |
> |---|---|---|
> | Master | `Project B Prototype/PROJECT_HANDOUT.md` (local root) | ❌ No - local only |
> | Deployed | `Project B Prototype/prototype/PROJECT_HANDOUT.md` | ✅ Yes - lands at repo root |
>
> **You are reading the deployed copy.** When you update this document, update **both**
> copies in the same change (edit one, then copy it over the other). A divergence means
> collaborators on GitHub and anyone working locally are reading different documentation.
>
> Markdown in the repo root is served as a static file, not rendered as a page - it does not
> affect the site.

---

## TABLE OF CONTENTS

1. [Project Overview](#1-project-overview)
2. [Product Vision](#2-product-vision)
3. [Tech Stack](#3-tech-stack)
4. [Folder Structure](#4-folder-structure)
5. [Page Documentation](#5-page-documentation)
6. [Navigation Flow](#6-navigation-flow)
7. [Customer Journey](#7-customer-journey)
8. [Supplier Journey](#8-supplier-journey)
9. [Authentication Flow](#9-authentication-flow)
10. [Features Documentation](#10-features-documentation)
11. [Business Rules](#11-business-rules)
12. [UI Components](#12-ui-components)
13. [Styling Guidelines](#13-styling-guidelines)
14. [Chatbot Knowledge Base](#14-chatbot-knowledge-base)
15. [Known Limitations](#15-known-limitations)
16. [Future Roadmap](#16-future-roadmap)
17. [AI Agent Instructions](#17-ai-agent-instructions)
18. [Change Log](#18-change-log)

---

## 1. PROJECT OVERVIEW

### What Eventara is

Eventara is a **trust-first, two-sided online marketplace for events in Udaipur, Rajasthan**.
It connects people planning events (companies and institutions) with verified venues, hotels
and event planners. Customers submit one request, receive itemised quotes from several matched
suppliers within 48 hours, compare them side by side, and book with their payment held safely
until the event is delivered.

**Tagline:** *Every Occasion, One Platform.*

### Business objective

Replace the fragmented, WhatsApp-and-phone-call way events are currently booked in Udaipur with
a single accountable platform that offers price transparency, verified suppliers, protected
payments and proper GST invoicing.

### Target users

| Side | Who |
|---|---|
| **Customers** | Companies (offsites, conferences, product launches, award nights) and institutions (schools, colleges, universities - fests, convocations, annual days) |
| **Suppliers / Businesses** | Banquet hotels, resorts, lake-view venues, event management firms, catering/hospitality firms in Udaipur |

### Marketplace model

- **Free for customers** - browsing, requesting quotes and comparing cost nothing.
- **Free for suppliers to list** - no listing, subscription or upfront fees.
- **Revenue = commission on confirmed bookings only**, deducted from the supplier payout.
- Money is held by Eventara (deposit ≈30%) and released to the supplier only after delivery.

### Current phase scope (Phase 1)

**LIVE NOW - bookable categories:**
- **Corporate Events & Conferences** - typically from ₹5 lakh
- **Institutional Events & Fests** - typically from ₹2.5 lakh

**COMING SOON - visible but NOT bookable:**
- **Weddings & Related Celebrations** - shown on the homepage with a "Coming Soon" badge,
  rendered as a non-clickable card. No wedding browsing or booking anywhere in the product.

**REMOVED - do not reintroduce:**
- Birthdays & Celebrations (was a homepage category; deliberately deleted in Phase 1)

**Geography:** Udaipur only. No other city is supported or implied.

### Future roadmap

See [§16 Future Roadmap](#16-future-roadmap).

---

## 2. PRODUCT VISION

### Why the platform exists

Booking a corporate offsite or a college fest in Udaipur today means calling a dozen venues,
chasing quotes over WhatsApp, comparing inconsistent inclusion lists, and paying advances by
bank transfer with no recourse if the event underdelivers. Nothing is standardised, nothing is
protected, and nothing is auditable for a finance team.

### Problems it solves

| Problem | Eventara's answer |
|---|---|
| Quotes arrive in different formats, hard to compare | One structured request → itemised quotes on a **common inclusion list**, side by side |
| No price transparency | "Typically from" prices on every listing; itemised quotes before booking |
| Advance paid with no protection | Deposit **held by Eventara**, released only after delivery |
| Unverified suppliers | Identity, GST and licence checks before a supplier can list; **verified badge** |
| No paper trail for finance | Proper **GST invoice** + complete booking record for every confirmed booking |
| Fake reviews | Only customers who **actually booked through Eventara** can review |

### Customer value proposition

> One request. A few verified suppliers. Clear quotes in 48 hours. Payment protected until the
> event is done, with a proper invoice for your records.

### Supplier value proposition

> Genuine, qualified enquiries with no listing fee. Quote in minutes from a dashboard. Get paid
> on time, with commission taken only on confirmed bookings.

### Long-term vision

Become the default booking layer for events in tier-2 Indian cities: start with corporate and
institutional events in Udaipur, prove trust and repeat usage, expand into weddings (the largest
segment by value), then replicate the city-by-city playbook.

---

## 3. TECH STACK

**Deliberately dependency-free on the front end.** No framework, no build step, no bundler.
Every page is a standalone HTML file that a browser can open directly.

| Layer | Technology | Notes |
|---|---|---|
| **Markup** | HTML5, semantic | 13 standalone pages, no templating |
| **Styling** | Vanilla CSS, one file | `styles.css` (2,394 lines) - CSS custom properties design system |
| **Fonts** | Inter via Google Fonts | `@import` at the top of `styles.css` |
| **Scripting** | Vanilla JavaScript (ES5-style, no transpiling) | `app.js`, `auth.js`, `chatbot.js` |
| **Build** | **None** | No npm build, no bundler, no transpiler for the front end |
| **Auth** | Custom, client-side | `auth.js` + `localStorage` (prototype-grade - see §9) |
| **State** | `localStorage` (session) + `sessionStorage` (chat) | No database |
| **Backend** | 1 Vercel serverless function | `api/chat.js` (Node, ESM) |
| **AI** | Google Gemini free tier | `@google/genai` ^2.3.0, model `gemini-3.5-flash` |
| **Hosting** | Vercel, auto-deploy from GitHub `main` | https://the-eventara.vercel.app |
| **Icons** | Inline SVG | No icon library; SVGs written directly in markup |
| **Images** | Hotlinked from supplier CDNs + 5 local PNGs | See §15 for the fragility caveat |

**The only npm dependency in the entire project** is `@google/genai` (declared in
`prototype/package.json`), used solely by the serverless function. The front end installs nothing.

### Cache-busting convention

There is no build hash, so assets are versioned by **query string**, bumped manually whenever the
file changes:

```html
<link rel="stylesheet" href="styles.css?v=17">
<script src="auth.js?v=3"></script>
<script src="app.js?v=4"></script>
<script src="chatbot.js?v=9"></script>
```

> **RULE:** if you edit `styles.css`, `app.js`, `auth.js` or `chatbot.js`, you **must** bump its
> `?v=` number in **all 12 HTML files**, or returning users get a stale cached copy.

---

## 4. FOLDER STRUCTURE

```
Project B Prototype/                  ← LOCAL project root (NOT the repo root)
│
├── PROJECT_HANDOUT.md                ← THIS FILE (local only, not deployed)
├── DESIGN-airbnb.md                  ← Design-system reference the UI was derived from
├── poc.txt / product_idea.txt / psm_report.txt   ← Extracted text of the source .docx files
├── Eventara_*.docx                   ← Original academic documents (PoC, Product Idea, Report)
├── airbnb_ref/ · design_ref/ · stripe_ref/       ← Visual reference material (not shipped)
│
└── prototype/                        ← ★ THIS FOLDER'S CONTENTS == THE GITHUB REPO ROOT ★
    │
    ├── index.html                    Homepage / landing
    ├── search.html                   Find Suppliers - listing + filters
    ├── provider.html                 Supplier profile (Paandora Grand)
    ├── brief.html                    Get Free Quotes - multi-step request form
    ├── compare.html                  Quote comparison table
    ├── booking.html                  Booking confirmation + deposit payment
    ├── invoice.html                  GST invoice + booking record
    ├── faq.html                      FAQ - 50 self-service Q&As
    ├── help.html                     Help Centre - contact support / raise a complaint
    ├── signin.html                   Sign In + Register (both roles)
    ├── customer-dashboard.html       Customer account (PROTECTED)
    ├── supplier-dashboard.html                Supplier/business portal (PROTECTED)
    ├── ops.html                      Internal operations console (staff-facing)
    │
    ├── styles.css                    ★ Entire design system (2,394 lines)
    ├── app.js                        Shared UI behaviours (navbar, forms, tabs, lightbox)
    ├── auth.js                       ★ Session/auth module - window.Auth
    ├── chatbot.js                    ★ Assistant widget + offline knowledge base (50 intents)
    ├── logo.svg                      Brand logo (gold arc + blue "eventara" wordmark)
    ├── logo-light.svg                ★ White-wordmark variant for dark/photographic surfaces
    │
    ├── api/
    │   └── chat.js                   ★ Vercel serverless fn - Gemini-backed assistant
    │
    ├── images/                       Local images
    │   ├── corporate.png  fest.png  hotel.png  wedding1.png  wedding2.png
    │   ├── login-bg.jpg              ★ Sign In desktop artwork (228KB, optimised)
    │   ├── login-bg-mobile.jpg       ★ Sign In mobile artwork  (228KB, optimised)
    │   ├── Login page image bg.png   2MB source for login-bg.jpg (not referenced at runtime)
    │   ├── Sign-in-page-ui-mobile-bg.png     1.9MB source for login-bg-mobile.jpg
    │   └── Sign-in-page-ui-*-idea.png        Design references (not referenced at runtime)
    │
    ├── package.json                  Declares @google/genai (for the serverless fn only)
    ├── check_mojibake.py             Dev utility - scans for UTF-8 corruption
    └── fix_encoding.py               Dev utility - repairs mojibake
```

### Directory purposes

| Path | Purpose |
|---|---|
| `prototype/` | **The deployable product.** Everything here goes to the repo root and is served by Vercel. |
| `prototype/api/` | Serverless functions. Vercel auto-routes `api/chat.js` → `/api/chat`. Any new file here becomes an endpoint. |
| `prototype/images/` | Locally hosted images. Most supplier photos are hotlinked instead (see §15). |
| `airbnb_ref/`, `design_ref/`, `stripe_ref/` | Visual references used while designing. **Not deployed.** |
| `*.docx`, `*.txt` (root) | Source academic documents. The product requirements originate here. |

**There is no `components/`, `css/`, or `js/` subfolder** - all CSS is in one file and all JS is
flat in the root. This is intentional for a no-build prototype. Do not reorganise without reason.

---

## 5. PAGE DOCUMENTATION

There are **13 pages**. Every page includes, in `<head>` or before `</body>`:
`styles.css?v=17` · `auth.js?v=3` · `app.js?v=4` · `chatbot.js?v=9`

---

### 5.1 `index.html` - Homepage

| Field | Detail |
|---|---|
| **Purpose** | Explain the platform, present Phase 1 categories, drive to quote request or supplier browsing |
| **URL** | `/` or `/index.html` |
| **Auth** | Public |
| **Connected pages** | `search.html`, `brief.html`, `compare.html`, `signin.html`, `faq.html`, `provider.html` |

**Sections (in order):** Navbar → Hero (headline, subtitle, event-type search bar, 3 trust items)
→ Categories (3 cards) → How It Works (3 steps) → Featured suppliers (3 cards) → Trust (4 cards)
→ Stats row (animated counters) → Testimonials (3) → CTA band (supplier acquisition) → Footer.

**Category cards - the Phase 1 rule made visual:**

| Card | State | Behaviour |
|---|---|---|
| Corporate Events & Conferences | Active | `<a href="search.html">`, "Typically from ₹5 lakh" |
| Institutional Events & Fests | Active | `<a href="search.html">`, "Typically from ₹2.5 lakh" |
| Weddings & Related Celebrations | **Coming Soon** | `<div class="category-card is-soon" aria-disabled="true">` - **not a link**, carries `.cat-badge` "Coming Soon", label "Launching soon" |

**Featured suppliers:** Paandora Grand Udaipur, Sterling Balicha, Blossom Events (3 cards, all
with real photos - chosen so no card has an empty image).

**Hero event-type dropdown:** Corporate Event · Conference · College/University Fest ·
Convocation/Annual Day · Product Launch/Award Night · *Weddings - coming soon* (`disabled` option).

**Hero search bar (`.search-bar`, in `styles.css`; only used on this page):** a pill-shaped
flex row of four fields - Event Type, City, Event Date, Guest Count - separated by
`.search-divider` lines, ending in a circular `.search-btn` (an `<a href="search.html">`,
not a submit). Refined in v1.7:

| Fix | How |
|---|---|
| **Guest Count placeholder no longer clips** | `.search-field { min-width: 0 }` lets all four fields share width equally (the Event Type `<select>` was keeping its wide min-content size and squeezing Guest Count to ~134px, 1px short of the placeholder); the number spinner is also removed so it reserves no right-hand space |
| **Search button integrated, not floating** | `margin-left: var(--space-6)` gives a balanced 6px gap on both sides of the button (it was flush - 0px - against the Guest field). It was already vertically centred and the icon already centred |
| **Mobile fields full-width** | The stacked column now uses `align-items: stretch`, so every field fills the width (they were uneven - Event Type wide, Guest Count clipped) with a 44px+ touch height; the button's desktop `margin-left` is reset to 0 |
| **Date field placeholder + icon (v2.1, mobile)** | The native `<input type="date">` showed a blank field with a centred picker chevron on some Android builds. Fixed **mobile-only** (≤768px): `placeholder="dd-mm-yyyy"`, `::-webkit-datetime-edit { flex: 1 1 auto; text-align: left }` (fills the row, greyed empty format text reads as the placeholder), and `::-webkit-calendar-picker-indicator { margin-left: auto }` pins the calendar icon hard-right - matching the other fields. Desktop untouched. |

Verified equal field widths and a fitting placeholder at 1440 / 768 / 390px, the button
still routing to `search.html`, and no horizontal overflow from the search component at
320 / 360 / 375 / 390 / 412 / 430px.

**Data flow:** Static. Counters animate via `IntersectionObserver` in `app.js`.

**Future improvements:** Real search submission (currently the hero search links to `search.html`
without passing filters); dynamic featured suppliers.

---

### 5.2 `search.html` - Find Suppliers

| Field | Detail |
|---|---|
| **Purpose** | Browse and filter the 7 confirmed suppliers |
| **URL** | `/search.html` |
| **Auth** | Public |
| **Connected pages** | `provider.html` (card click), `brief.html` (CTA), `compare.html` |

**Filter toolbar:** Event Type · Guest Count · Budget · Supplier Type (segmented: All / Event
Managers / Banquet Hotels) · Sort By (Reputation / Rating / Price asc / Price desc) · Clear filters.

**The 7 confirmed suppliers (the ONLY vendors anywhere in the product):**

| # | Name | Type | `data-ptype` | Capacity | From | Cover image |
|---|---|---|---|---|---|---|
| 1 | Paandora Grand Udaipur | Banquet Hotel | `hotel` | 800 | ₹25,00,000 | Real photo |
| 2 | Sterling Balicha | Resort & Banquets | `hotel` | 400 | ₹12,00,000 | Real photo (rooftop pool) |
| 3 | Hotel Aloka | Boutique Hotel | `hotel` | 200 | ₹4,00,000 | Initials cover "HA" |
| 4 | Lakeside Leisure | Lake-View Reception Venue | `hotel` | 150 | ₹6,00,000 | Real photo (exterior) |
| 5 | Bluspring | Food & Hospitality | `manager` | 9999 | ₹5,00,000 | Initials cover "BS" |
| 6 | Indicraft Communications | Events & Promotions | `manager` | 9999 | ₹6,00,000 | Initials cover "IC" |
| 7 | Blossom Events | Event Management | `manager` | 9999 | ₹8,00,000 | Real photo |

**Filtering mechanism (important for anyone editing this page):**
The filter JS is **fully DOM-driven** - it reads every `.provider-card` live and parses rating,
price and capacity out of the *rendered card content* plus the `data-capacity` / `data-ptype`
attributes. Consequences:

- Adding or removing a card **automatically** updates counts, filters and sort. No JS edit needed.
- But the card markup **must** keep `data-capacity`, `data-ptype`, `.rating`, `.amount`.

**Two count displays** must match the number of cards: `#resultCount` and `#filterCount`.

**Mobile:** filters collapse behind a "Filters & Sort" toggle so results are visible immediately.

**Future improvements:** Accept filter params from the homepage hero; pagination when >20 suppliers.

---

### 5.3 `provider.html` - Supplier Profile

| Field | Detail |
|---|---|
| **Purpose** | Full supplier profile - gallery, about, packages, reviews, similar suppliers |
| **URL** | `/provider.html` |
| **Auth** | Public |
| **Connected pages** | `brief.html` (Send Brief for Quote), `search.html` |

**⚠️ Single-profile limitation:** This page is **hard-coded to Paandora Grand Udaipur**. Every
supplier card on `search.html` and `index.html` links here regardless of which supplier was
clicked. Making profiles per-supplier is a known roadmap item (§16).

**Sections:** Photo gallery (lightbox) → Name/verified badge/rating/address → About → Packages
(3 tiers: ₹4L / ₹9L / ₹18L) → Inclusions → Reviews (3, "only real customers who booked can
review") → Similar Suppliers (Sterling Balicha, Blossom Events, Hotel Aloka).

**Anti-leakage rule enforced here:** no outbound links to supplier websites, Instagram or
YouTube. Media is displayed in-platform only. **Do not add external supplier links.**

---

### 5.4 `brief.html` - Get Free Quotes

| Field | Detail |
|---|---|
| **Purpose** | Capture a structured event request and send it to matched suppliers |
| **URL** | `/brief.html` |
| **Auth** | Public (no sign-in required to request quotes) |
| **Connected pages** | `compare.html` (after submit) |

**Multi-step form** (driven by `initMultiStepForm()` in `app.js`):

1. **Event basics** - type, date, city (Udaipur, locked), guest count
2. **Requirements** - venue/catering/décor/AV needs, style preferences
3. **Budget** - band selection (incl. "Under ₹3L")
4. **Your details** - name/organisation, contact person, email, phone, GSTIN (optional),
   reference/PO (optional), consent

**Sidebar:** "Your Request Goes To" - shows the 3 matched suppliers (Paandora Grand, Sterling
Balicha, Blossom Events) + how-it-works mini steps + trust badges.

**On submit:** `showSubmitConfirmation()` in `app.js` replaces the final step with a success
panel: *"Request Sent!"* → names the 3 suppliers → "quotes within 48 hours" → CTA to `compare.html`.

**Data flow:** ⚠️ **Nothing is persisted.** The form does not POST anywhere; submission is a
UI simulation. See §15.

---

### 5.5 `compare.html` - Compare Quotes

| Field | Detail |
|---|---|
| **Purpose** | Show 3 quotes side by side against a common inclusion list |
| **URL** | `/compare.html` |
| **Auth** | Public |
| **Connected pages** | `booking.html` (accept a quote), `brief.html` |

**Demo scenario (consistent across the whole app):** a corporate offsite for **Secure Meters**,
140 guests, Sat 22 Aug 2026, budget ₹5L-₹10L.

**The three quotes:** Paandora Grand Udaipur (tagged *"Best value for your budget"*) ·
Sterling Balicha · Blossom Events.

**Comparison rows:** venue & conference hall, F&B per plate, rooms, AV/staging, décor,
event manager, deposit to confirm (30%), totals - with over-budget rows flagged
*"Above your ₹10L budget (before GST)"*.

**Also on page:** "Message this venue (contact stays private)" buttons · "Download / Share PDF" ·
a "Why book on Eventara" note (deposit protection, saved messages, GST invoice, support recourse).

---

### 5.6 `booking.html` - Confirm Booking

| Field | Detail |
|---|---|
| **Purpose** | Explain how payment protection works and take the deposit |
| **URL** | `/booking.html` |
| **Auth** | Public in the prototype (would be customer-only in production) |
| **Connected pages** | `invoice.html` (after payment) |

**Money flow shown as 4 steps:** Deposit Paid → *(held safely)* → Your Event Happens → Venue Is Paid.

**The canonical demo numbers - keep these consistent if you edit any of them:**

| Item | Value |
|---|---|
| Quote (before GST) | ₹8,50,000 |
| Total incl. GST | ₹10,03,000 |
| Deposit due now (30%) | **₹3,00,900** |
| Balance | ₹7,02,100 |
| Booking fee | Free (commission is supplier-side) |

**Payment methods:** UPI (recommended) · Net Banking.
**Cancellation terms shown before paying:** full refund 30+ days · 50% refund 15-30 days ·
no refund under 15 days (but balance never collected).

---

### 5.7 `invoice.html` - GST Invoice & Booking Record

| Field | Detail |
|---|---|
| **Purpose** | Downloadable GST invoice + complete audit trail of the booking |
| **URL** | `/invoice.html` |
| **Auth** | Public in the prototype |

Contains a **genuine GST invoice layout** - supplier & customer GSTIN, SAC codes, CGST/SGST
split, amount in words, "DEPOSIT - HELD SAFELY" stamp. Sample registration numbers are marked
`(sample)`.

**Booking record panel:** Chosen Quote · Payment Ref · Request Sent · Deposit Paid · Payment
Status (*Held safely - released after your event*) · Support Window (72h) · Messages Saved.

> **Terminology note:** GST/GSTIN/SAC/CGST/SGST are **correct and intentional here** - it is a
> real tax document. Do not "simplify" them the way customer-facing marketing copy was simplified.

---

### 5.8 `faq.html` - Help Centre / FAQ

| Field | Detail |
|---|---|
| **Purpose** | Self-service help centre for both audiences |
| **URL** | `/faq.html` |
| **Auth** | Public |
| **Reached from** | Footer → Support → "Help Centre" and "FAQ" (both link here) |

**50 FAQs across 8 categories:** General (4) · Booking & Events (8) · Payments (6) ·
Account & Profile (5) · Vendors & Event Planners (9) · Hotels & Venues (6) · Trust & Safety (6) ·
Support (6).

**Features:** live search (filters items + hides empty categories + empty state) · accordion
(animated `max-height`, one-at-a-time not enforced) · sticky sidebar category nav with
scroll-spy (`IntersectionObserver`) · breadcrumb (Home → Support → FAQ) · "Still need help?" CTA.

**Accessibility:** `aria-expanded` / `aria-controls` on every accordion button,
`role="region"` + `aria-labelledby` on panels, `aria-current="page"` breadcrumb, visible
`:focus-visible` outlines, semantic `h1`/`h2`/`h3`.

**Mobile:** sidebar becomes a horizontally scrolling chip row.

**Two-way link with the Help Centre:** the "Still need help?" section's primary button reads
**"Still need help? Contact Support"** and goes to `help.html`. `help.html` links back via its
"Browse FAQs" band. Keep both directions intact.

---

### 5.8b `help.html` - Help Centre (contact support)

| Field | Detail |
|---|---|
| **Purpose** | The **contact channel**. Lets customers and suppliers raise a support request or a complaint. Distinct from `faq.html`, which is self-service answers. |
| **URL** | `/help.html` |
| **Auth** | Public - open to signed-out visitors, customers and suppliers |
| **Reached from** | Footer -> Support -> **Help Centre** (all pages) - mobile menu - FAQ page CTA |
| **Connected pages** | `faq.html` (both directions), `index.html` |

**Page order:** Breadcrumb (Home -> Support -> Help Centre) -> Hero -> **FAQ deflection band**
("Looking for a quick answer?" + Browse FAQs) -> **Support-type choice** (2 cards) -> **Form** ->
Success panel -> Contact strip (email - hours - payment-protection reassurance).

**Two request types** - selecting one rewrites the form:

| Type | Covers | Shown expectation |
|---|---|---|
| **Support Request** (default) | Account - Login - Profile - Payment failures - Technical - Booking questions - Quote queries - Dashboard - General | "Typical response: 24-48 business hours" |
| **Complaint** | Supplier/customer disputes - Booking issues - Service quality - Payment disputes - Refunds - Unprofessional conduct - Policy violations - Trust & safety | "Higher priority" |

**Form fields:** User Role (Customer / Supplier) - Request Type - Full name* - Organisation
(optional for customers, expected for suppliers) - Email* - Mobile* - Booking reference
(optional, with helper text) - **Category*** (options swap by type) - Subject* -
Detailed description* - Attachments (UI only) - Preferred contact (Email / Phone) -
Consent checkbox* - Submit button (label follows type).

**Dynamic behaviour (inline `<script>`):**
- Request type -> rebuilds the Category `<select>`, changes the submit-button label, and swaps
  the description hint.
- User role -> changes the Organisation label ("(optional)" for customers) and its hint.
- Attachments -> lists chosen filenames (max 5). **Nothing is uploaded.**
- Submit -> manual validation producing **one friendly sentence** listing what is missing;
  on success hides the form and shows the confirmation panel.

**Success panel:** generated reference (**`SUP-YYYY-NNNN`** or **`CMP-YYYY-NNNN`**), request
type, category, expected response time, reply-by method, a reminder to watch email/phone, plus
Browse FAQs / Back to Home / Submit another request.

> WARNING - **reset gotcha (already handled):** the request-type and role radios sit **outside**
> `<form>`, so `form.reset()` does not clear them. "Submit another request" resets them
> explicitly. If you restructure this form, keep that behaviour.

**Data flow:** WARNING - **nothing is submitted or stored.** No POST, no ticketing system, no
file upload. The confirmation is a UI simulation and the reference number is generated
client-side.

**Future improvements:** real ticket creation + email confirmation - authenticated pre-fill of
name/email/booking - genuine file upload - status tracking.

---

### 5.9 `signin.html` - Sign In / Register

| Field | Detail |
|---|---|
| **Purpose** | Authenticate existing users; register new customers or businesses |
| **URL** | `/signin.html` (params: `?mode=register`, `?type=business`, `?next=`, `?role=`) |
| **Auth** | Public (this is the auth entry point) |

**Two tabs:** Sign In · Register. Register has a Customer / Business toggle.

#### Layout - full-bleed artwork + one floating card (redesigned v1.4)

**The headline, supporting copy and the three gold feature icons are baked into the
background artwork as pixels.** They are deliberately NOT recreated in HTML. The page
renders the background plus exactly **one** element: the glass card.

> **Do not add a hero section to this page.** An earlier revision rendered the headline,
> subtitle and icons in HTML on top of artwork that already contained them, so every
> element appeared twice. If you need to change that copy, edit the image.

| Breakpoint | Artwork | Card placement |
|---|---|---|
| ≥ 861px | `images/login-bg.jpg` (landscape, copy on the left) | Right-aligned, vertically centred |
| ≤ 860px | `images/login-bg-mobile.jpg` (portrait) | **Below the full hero** - page scrolls (see the mobile note below) |
| Landscape phone | back to the landscape artwork | Right-aligned, centred |

`background-position` is **`left center`** on desktop. With `cover`, a viewport narrower
than the artwork's 16:9 crops horizontally - anchoring left guarantees the baked-in
headline is never cut off.

Geometry is matched to `images/Sign-in-page-ui-web-idea.png` (measured off the reference,
not eyeballed) - card **34vw wide** with a **5.8% right gutter**, vertically centred.
Mobile matches `Sign-in-page-ui-mobile-idea.png` - **90% wide**, 4.9% gutters, sitting
~39% down the screen.

> `width` uses **vw, not %**. A percentage resolves against `.auth-shell`'s content box
> (viewport minus its own 5.8vw padding), which made the card ~4% too narrow.

#### Glassmorphism (`.auth-card`)

| Property | Value | Why |
|---|---|---|
| `background` | `rgba(38, 28, 52, 0.46)` | A **dark violet scrim**, carrying white text |
| `backdrop-filter` | `blur(26px) saturate(150%)` | The frost; saturation stops the bokeh going grey |
| `border` | `1px solid rgba(255,255,255,0.28)` | Catches light like a glass edge |
| `box-shadow` | `0 28px 70px rgba(0,0,0,0.45)` + inset white top highlight | Lifts the card off the photo |
| `border-radius` | `var(--radius-3xl)` (20px) | Design-system token |

> **Why dark glass, when the mock-up looks pale?** The reference card is a light lavender
> tint. Measured against the actual photograph, white text on that tint falls to
> **2.6:1 over the bright chandelier bokeh** - well under WCAG AA. The violet scrim holds
> **6.1:1** while keeping the same frosted character. Every secondary text colour is
> pinned at **α ≥ 0.82**, the measured floor for 4.5:1 on this glass.

Because the card is dark, the standard blue wordmark in `logo.svg` would sit at **1.4:1**.
The card therefore uses **`logo-light.svg`** - identical gold arc, white wordmark.

Fallback: `@supports not (backdrop-filter…)` raises the card to `rgba(28,20,40,0.92)`;
without the blur a translucent card looks muddy rather than glassy.

#### Card sizing (refined v1.4)

The card was reduced by **~10% on both axes** (490x590 → 441x531 at 1440px) to give the
artwork more breathing room. It was scaled *proportionally* - the aspect ratio moved only
1.204 → 1.206 - by trimming padding, the logo, tab and field spacing together, not by
shrinking the width alone.

Controls are still **≥44px** everywhere; `.btn-lg` is explicitly held at 14px padding to
keep the submit button at exactly 44px after the trim.

#### Frosted scrollbar

On desktop the card is capped at `calc(100dvh - var(--space-80))` and **`.auth-body`
scrolls internally** - the Business registration form is taller than most viewports. The
native scrollbar rendered as an opaque grey slab that broke the glass, so it is styled:

| Engine | Mechanism |
|---|---|
| Chrome · Edge · Safari · Opera | `::-webkit-scrollbar`, `-track`, `-thumb`, `-corner` |
| Firefox (and any engine with the standard properties) | `scrollbar-width: thin` + `scrollbar-color` |
| Anything else | Falls back to the native control - still fully usable |

The thumb is `rgba(255,255,255,0.26)` (→ 0.42 hover, 0.52 active) on a
`rgba(255,255,255,0.07)` track, pill-radius, with a **2px transparent border +
`background-clip: padding-box`** so it reads as a slim floating bar rather than a slab
wedged against the card edge.

**`scrollbar-gutter: stable`** reserves the track width up-front, so the form does not
jump sideways when switching between the short Sign In view and the tall Register view
(verified: 0px shift).

#### Back navigation button (added v1.6)

A glassmorphic **Back** button sits at the **top-left** of the page (`.auth-back`), outside
the card, over the artwork's dark chandelier zone - clear of the baked-in headline and of
the right/low-placed card at every breakpoint.

| Aspect | Detail |
|---|---|
| Markup | `<a href="index.html" aria-label="Go back to the previous page" onclick="return authGoBack(event)">` with a white arrow SVG (`aria-hidden`) |
| Style | Same glass recipe as the card - `rgba(38,28,52,0.46)`, `blur(26px) saturate(150%)`, white border, soft shadow; **44x44** circle with hover (`translateX(-2px)`), active (scale 0.94) and `:focus-visible` (2px white outline) states |
| Position | `position: absolute` at `top/left: 20px + safe-area` insets. **Absolute, not fixed**, so it scrolls away with the hero on mobile instead of drifting over the card once the page scrolls |
| Fallback | The `@supports not (backdrop-filter)` block raises it to `rgba(28,20,40,0.9)` |

**Navigation logic (`authGoBack`)** - progressive enhancement:

- The anchor's `href="index.html"` is the **no-JS / fallback** destination.
- `authGoBack()` checks `document.referrer`: if it is **same-origin** *and* `history.length > 1`,
  it `preventDefault()`s and calls `history.back()` - returning the user to the exact Eventara
  page they came from (Home → Search → Supplier → Sign In → **back to Supplier**).
- Otherwise (direct hit, refresh with no prior entry, or an **external** referrer) it does
  nothing and lets the `href` carry the user to **`index.html`**.

Accessibility: it is a real `<a>` (keyboard-focusable, Enter-activatable, **first in the tab
order**), carries an `aria-label`, hides the decorative SVG from assistive tech, and shows a
visible `:focus-visible` ring. It respects `prefers-reduced-motion`.

This is navigation-only - it touches no auth, session, form or layout code.

#### Background image loading

Both artworks are referenced by **relative path** - `url("images/login-bg.jpg")` - so they
resolve identically in local dev, the GitHub repo and Vercel. Not Base64, not absolute,
not hotlinked. The desktop artwork is `preload`ed as the page's LCP element.

> **Asset note.** The supplied sources are `images/Login page image bg.png` (2.0MB) and
> `images/Sign-in-page-ui-mobile-bg.png` (1.9MB). Multi-megabyte PNGs of photographs would
> dominate page weight - and the desktop filename's **spaces** would need percent-encoding
> in every URL. Each was converted once to a **228KB progressive JPEG**
> (`login-bg.jpg`, `login-bg-mobile.jpg`), a **-89%** saving, and those are what the page
> loads. **The originals are retained** - to switch back, change the `url()` values.
> The four `Sign-in-page-ui-*` files are design references, not runtime assets.

#### Responsive behaviour

| Width | Layout |
|---|---|
| ≥ 1101px | Landscape artwork; card 34vw, right gutter 5.8%, vertically centred |
| 861-1100px | Same hierarchy, scaled: card 38vw (max 390px), gutter 4.5% |
| ≤ 860px | **Hero shown in full at the top, card scrolls in below it** - see the note below |
| ≤ 480px | Tighter internal padding; two-up form rows collapse to one column |
| Landscape phone | Reverts to the landscape artwork (portrait art suits a short wide screen badly), card centred |

#### Mobile layout - hero first, then the card (reworked v1.5)

The portrait artwork `login-bg-mobile.jpg` bakes the headline, subtitle and the three
feature icons into its **top ~37%**; the rest is decorative photography. So on mobile the
hero is shown **in full first**, and the card sits **below** the icons - never over them.

```
   Hero artwork (headline + subtitle + 3 icons, fully visible)
        |
        v   ~4% gap
   Glass authentication card  (overlaps only the decorative lower photo)
        |
        v
   page scrolls if the form is taller than the viewport
```

How it holds on every device without magic numbers:

| Mechanism | Effect |
|---|---|
| `body { background-size: 100% auto }` | The artwork renders at full viewport **width**, so its height is a **fixed multiple** of that width (its 2.16 aspect) |
| `.auth-shell { display: block; padding-top: 86vw }` | Because the artwork height scales with width, a **`vw`** top spacer lands at the same fraction of it on **every** screen - 86vw clears the icons (which end ~80vw down) with a ~40px gap |
| `.auth-shell` natural document flow | The page grows and **scrolls**; the hero is never compressed to fit |
| `padding-bottom: calc(116px + safe-area)` | Reserves space so the fixed chatbot FAB (bottom-right) never covers the Sign In / Create Account button at full scroll (verified ~33px clearance) |
| `background-color: #140f18` | Fills below the artwork if a tall form scrolls past the image |

This replaced a flexbox `margin-top: auto` approach that bottom-aligned the card **within a
single viewport**, so on tall phones it floated up over the baked-in headline and icons -
the exact overlap the reference forbids.

**Desktop, tablet and landscape-phone layouts were not touched** - the change lives entirely
inside the `≤860px` portrait media query (plus a longhand tweak at `≤480px` so it no longer
resets `padding-top`).

**Demo credentials (hard-coded in `signin.html`, deliberately NOT shown in the UI):**

| Role | Email | Password |
|---|---|---|
| Supplier | `hotel@eventara.in` | `udaipur@2026` |
| Customer | `customer@eventara.in` | `udaipur@2026` |

**Customer registration fields:** Your Name or Organisation · Email · Mobile · Event City
(Udaipur) · Password.
**Business registration fields:** Business Name · Business Type · Contact Person · Mobile ·
Email · City · GSTIN · Password.

> **🔒 SECURITY RULE - do not undo.** A "Continue as Customer" button that bypassed
> authentication entirely was **deliberately removed**. Never add any control that reaches a
> dashboard without validating credentials.

> **The v1.3 redesign was presentation-only.** The `<script>` block - tab switching, the
> Customer/Business toggle, `handleSignIn()`, both credential constants, `Auth.login()` calls
> and post-login redirects - is **byte-for-byte identical** to the previous version (verified
> by diffing against the deployed copy). Element IDs, form `onsubmit` handlers and CSS class
> hooks were all preserved. Any future restyle must keep that contract.

---

### 5.10 `customer-dashboard.html` - Customer Account 🔒

| Field | Detail |
|---|---|
| **Purpose** | Customer's home: requests, quotes, bookings, payments, saved suppliers |
| **URL** | `/customer-dashboard.html` |
| **Auth** | **PROTECTED** - `Auth.requireRole('customer', 'signin.html?next=customer&role=customer')` in `<head>` |

**Sidebar sections (9 panels):** Overview · My Profile · Requests & Quotes · My Bookings ·
Invoices & Records · Payments & Mandate · Disputes · Saved Suppliers · **Account Settings**
(added v2.0 - Account, Notification Preferences, Privacy, with toggle switches). All switch via
`showPanel()`; no `href="#"` dead links. A `hashchange` listener lets the account dropdown's
`#profile` / `#settings` deep-links switch panels even when already on the dashboard.

**Header:** date · **Home button** (`<a href="index.html">`, home icon, between the date and
New Request - session preserved, never a logout) · **New Request** (`brief.html`).

**Panels:** metric cards (Active Requests, Deposit Held Safely ₹3.0L, …) · activity timeline ·
requests table (Request / Event / Date / Guests / Budget / Matched / Status / Action) ·
bookings · payment status with the 4-step money flow · saved suppliers (Paandora, Sterling
Balicha, Blossom).

---

### 5.11 `supplier-dashboard.html` - Supplier / Business Portal 🔒

| Field | Detail |
|---|---|
| **Purpose** | Business's home: enquiries, quoting, availability, performance, payouts |
| **URL** | `/supplier-dashboard.html` |
| **Auth** | **PROTECTED** - `Auth.requireRole('supplier', 'signin.html?next=dashboard&role=business')` in `<head>` |

Hard-coded to **Paandora Grand Udaipur** as the logged-in business.

**Architecture (rebuilt v1.8 to full parity with the Customer Account).** Same
**single-page panel-switch** model as `customer-dashboard.html`: a fixed sidebar of nav links
each carrying `data-panel`, and one `.dash-panel` per section that `showPanel(name)` shows/hides
(deep-linkable via `#hash`, syncs the mobile sidebar close and scroll-to-top). **No `href="#"`
dead links remain** - every sidebar item, action button and quick-action either switches a panel,
navigates a page, or fires a `toast()` acknowledgement.

**Sidebar → panels (7):**

| Panel | Contents |
|---|---|
| **Overview** | 4 metric cards (Today's Enquiries, Pending Quotations, Active Bookings, This Month's Earnings) · 3 quick actions · Needs-Attention list · Recent-Activity timeline · Booking Pipeline bar · Revenue Summary · Performance snapshot (response rate, median time to quote, delivery rate, **customer rating 4.6★**) |
| **Enquiries** | Status filter pills (All / New / Under Review / Quote Submitted / Accepted / Rejected / Expired) + select filters (Event Type, Budget, Customer type, Date); table with **Build/Edit Quote, Respond, Save Draft, Archive, View** actions |
| **Bookings** | Status pills (Upcoming / Ongoing / Completed / Cancelled); table with **Invoice, Contact customer, Update status, Payment status** actions |
| **Calendar** | **Month / Week / Day** view toggle; toolbar to **Block dates / Maintenance day / Reopen**; clicking an open day applies the current mode (`cycleDay`); legend for Confirmed / Tentative hold / Enquiry hold / Blocked / Maintenance. **Mobile (v2.1):** the month grid keeps a readable **640px min-width inside a `.cal-scroll` (`overflow-x: auto`) wrapper**, so all seven weekday columns are reachable by horizontal swipe instead of being clipped by the grid's `overflow: hidden` - the page itself never scrolls sideways. Desktop/tablet unchanged. |
| **Disputes & Complaints** *(new module)* | Complaints against the supplier and disputes the supplier raises; status filter (Open / Under Review / Resolved), **priority dots** (Low / Medium / High / Critical), Respond / Upload Evidence / View Timeline actions, and a resolution timeline |
| **Business Profile** | Editable business details, contact & address, **compliance (GSTIN / PAN / FSSAI)**, amenities & pricing, cancellation policy, media **upload zones** (logo / video / gallery) and social links |
| **Settings** | Account (password, email, phone-verified badge) · Business (working hours, availability default, auto-response) · Notifications (Email / SMS / WhatsApp / Push **toggle switches**) · Payment (bank / UPI / GST) · Privacy (public profile, ratings, data prefs) |

**Header:** greeting · date · **Home button** (`<a href="index.html">`, home icon - session is
preserved, it is a plain link, never a logout) · **notification bell** that opens a real
`.notif-panel` (New enquiry, Quote deadline, Booking confirmed, Payment released, New message,
Complaint update, Calendar reminders) with **Mark read / Mark all read / View all** and a live
unread count on the bell (becomes a full-width bottom sheet ≤768px).

**Session:** navigating Home / Dashboard / Search / FAQ / Help never logs the supplier out
(auth lives in `localStorage`, only `signOut()` → `Auth.logout('index.html')` clears it). Verified:
Home → `index.html` keeps the supplier session; returning to `supplier-dashboard.html` passes the gate
without re-login; the Log-out button clears the session and lands on Home.

**Reused design-system components:** `.metric-card`, `.metrics-grid`, `.card-flat`,
`.data-table`, `.status-*`, `.badge-*`, `.calendar-grid`/`.calendar-day`, `.btn-*`, `.input-group`,
`grid grid-2/3`. New page-scoped pieces (in `supplier-dashboard.html`'s `<style>`): notification panel,
filter pills, calendar toolbar/week/day views, toast, toggle switch, upload zone, priority dots.

**Responsive:** verified **zero horizontal overflow on all 7 panels** at 390 / 768 / 1440px;
sidebar collapses behind the hamburger ≤1024px; data tables scroll inside their card; the
notification panel docks to the bottom on phones.

**Audience note:** this is business-facing, so operational vocabulary ("enquiry", "payout",
"commission", "GSTIN ✓ FSSAI ✓") is appropriate - unlike customer pages.

> **Prototype scope:** action buttons that would hit a backend in production (Build Quote,
> Respond, Upload Evidence, Save Settings, etc.) confirm with a `toast()` - there is no server.
> This is the same "no real persistence" limit noted for the rest of the prototype.

---

### 5.12 `ops.html` - Operations Console (internal)

| Field | Detail |
|---|---|
| **Purpose** | Eventara staff tooling: verification queue, concierge booking, disputes, funnel |
| **URL** | `/ops.html` |
| **Auth** | Not role-gated in the prototype (would be staff-only in production) |

**Panels:** Funnel Dashboard (with go/no-go gate metrics) · Verification Queue (pending
applicants with GSTIN/FSSAI/licence doc chips) · Concierge Booking · Disputes.

> **Audience note:** this is an **internal staff tool**. Operational vocabulary (funnel, crux
> metric, mandate acceptance) is **intentional here and must not be "simplified"** the way
> customer-facing copy was. The verification queue uses illustrative prospective-applicant names
> (Mewar Grand Banquets, Aravalli Vista Resort, Utsav Event Studio) - deliberately *not* the 7
> confirmed vendors, since those are already live.

---

## 6. NAVIGATION FLOW

### Global navigation (every page)

**Navbar:** Logo → `index.html` · Find Suppliers → `search.html` · How It Works →
`index.html#how-it-works` · Compare Quotes → `compare.html` · **List Your Business** →
`signin.html?mode=register&type=business` · **Sign In** → `signin.html`

When signed in, `Auth.renderNav()` **replaces the Sign In button** with the **User Profile
Dropdown** (see §12) - avatar + name + chevron that opens a role-aware menu (Dashboard ·
My Profile · Account Settings · Log Out). The standalone Log out button was removed. On mobile
the same four items are injected into the hamburger menu under an account header.

**Footer (4 columns):**

| Column | Links |
|---|---|
| Brand | Logo, tagline, description |
| Plan an Event | Browse Venues & Planners · Get Free Quotes · Compare Quotes · How It Works |
| For Businesses | List Your Business · Business Sign In · Why Eventara |
| Support | **Help Centre → `help.html`** · FAQ → `faq.html` · Privacy Policy (`#`) · Terms of Service (`#`) |

### Primary customer path

```
index.html  (homepage)
    │
    ├──► search.html      (browse & filter 7 suppliers)
    │        │
    │        └──► provider.html   (profile - always Paandora Grand)
    │                  │
    └──► brief.html ◄──┘          (Get Free Quotes - multi-step form)
             │
             ▼  submit → "Request Sent!" confirmation
        compare.html                (3 quotes side by side)
             │
             ▼  accept a quote
        booking.html                (deposit ₹3,00,900 + terms)
             │
             ▼  pay
        invoice.html                (GST invoice + booking record)
             │
             ▼
        customer-dashboard.html 🔒  (manage bookings)
```

### Supplier path

```
index.html ──► "List Your Business"
                    │
                    ▼
        signin.html?mode=register&type=business
                    │
                    ▼  register → Auth.login('supplier')
        supplier-dashboard.html 🔒           (enquiries, quotes, availability, payouts)
```

### Auth redirect paths

```
Unauthenticated → customer-dashboard.html
        └──► signin.html?next=customer&role=customer

Unauthenticated → supplier-dashboard.html
        └──► signin.html?next=dashboard&role=business

Successful sign-in  → role's dashboard  (customer-dashboard.html | supplier-dashboard.html)
Log out (any page)  → index.html
```

### Help paths

```
Any page ──► Footer → Support → FAQ ─────────► faq.html    (self-service answers)
Any page ──► Footer → Support → Help Centre ─────► help.html   (contact the team)

        faq.html  ──"Still need help? Contact Support"──►  help.html
        help.html ──────────"Browse FAQs"──────────────►  faq.html
                     (two-way; keep both links intact)

Any page ──► floating chat button (bottom-right) ──► assistant panel (overlay, no navigation)
```

---

## 7. CUSTOMER JOURNEY

```
   Visitor
      │
      ▼
1. Land on homepage          index.html
      │                      Sees Phase 1 categories, trust signals, featured suppliers
      ▼
2. Browse suppliers          search.html
      │                      Filters by event type, guests, budget, supplier type; sorts
      ▼
3. View a supplier           provider.html
      │                      Gallery, packages, inclusions, reviews, similar suppliers
      ▼
4. Request quotes            brief.html
      │                      One structured request → matched to 2-3 suppliers
      ▼
5. Receive quotes            (within 48 hours - simulated)
      │
      ▼
6. Compare                   compare.html
      │                      Itemised, common inclusion list, gaps flagged, best-value tag
      ▼
7. Book                      booking.html
      │                      Accept quote → pay ~30% deposit → HELD SAFELY by Eventara
      ▼
8. Get documentation         invoice.html
      │                      GST invoice + full booking record
      ▼
9. Event happens             (offline)
      │
      ▼
10. Confirm delivery         Deposit released to supplier (auto after 72h if nothing flagged)
      │
      ▼
11. Manage & review          customer-dashboard.html 🔒
                             Bookings, payments, saved suppliers, raise an issue, leave a review
```

### Step detail

| Step | What the customer does | What the platform does |
|---|---|---|
| 1 | Reads the value proposition | Shows only Phase 1 categories; weddings visibly "Coming Soon" |
| 2 | Filters listings | Client-side filter/sort over the 7 verified suppliers |
| 3 | Evaluates a supplier | Shows verified badge, real photos, packages, genuine reviews |
| 4 | Fills a 4-step form | Routes one request to 2-3 matched suppliers |
| 5 | Waits | 48-hour SLA on supplier replies |
| 6 | Compares | Normalises quotes onto a common inclusion list; flags omissions and over-budget |
| 7 | Pays a deposit | Holds the money; does **not** pass it to the supplier |
| 8 | Downloads invoice | Issues GST invoice + audit trail |
| 9-10 | Attends, confirms | Releases payout net of commission after delivery |
| 11 | Reviews | Accepts a review **only** from a customer who booked |

---

## 8. SUPPLIER JOURNEY

```
1. Discover                  index.html CTA band / footer "List Your Business"
      │
      ▼
2. Register                  signin.html?mode=register&type=business
      │                      Business name, type, contact, mobile, email, city, GSTIN, password
      ▼
3. Verification              Eventara team checks identity + GSTIN + trade/food-safety licence
      │                      (FSSAI required only if in-house catering)
      ▼
4. Go live                   Verified badge granted → listing visible in search.html
      │
      ▼
5. Build profile             Photos, packages/tiers, capacity, inclusions, pricing
      │
      ▼
6. Receive enquiries         supplier-dashboard.html 🔒 enquiry inbox (customer contact stays MASKED)
      │
      ▼
7. Quote                     Quote builder → itemised quote. 48-hour reply window;
      │                      reminders at 24h and 40h; fast replies protect the rating
      ▼
8. Win the booking           Customer accepts → deposit held by Eventara → booking confirmed
      │
      ▼
9. Manage availability       Calendar - block/open dates so enquiries stay relevant
      │
      ▼
10. Deliver the event        (offline)
      │
      ▼
11. Get paid                 Payout released after delivery, NET OF COMMISSION
      │                      (auto-release 72h after the event if nothing is flagged)
      ▼
12. Build reputation         Rating from genuine post-booking reviews + response-rate metrics
```

### Verification requirements

| Check | Required for |
|---|---|
| Identity | All businesses |
| GSTIN | All businesses (required to verify and go live) |
| Trade licence | Venues / hotels |
| FSSAI licence | Only if in-house catering is offered |

### Supplier performance metrics (`supplier-dashboard.html` → "Your Performance")

48-hour Quote Response Rate · Median Time to Quote · Deposit Setup · Delivery Rate · Average Rating

---

## 9. AUTHENTICATION FLOW

> ⚠️ **PROTOTYPE-GRADE, CLIENT-SIDE ONLY.** There is no server, no password hashing and no
> token verification. It correctly enforces the UX gate in the browser, but a determined user
> can set a session via dev tools. **Do not present this as production security.** See §15.

### The module: `auth.js` → `window.Auth`

| Method | Behaviour |
|---|---|
| `Auth.login(role, info)` | Creates a session `{token, role, name, email, iat, exp}`, writes it, returns it |
| `Auth.getSession()` | Returns the session or `null`; **auto-expires** and clears if `exp` has passed |
| `Auth.isAuthenticated()` | Boolean |
| `Auth.getRole()` | `'customer'` \| `'supplier'` \| `null` |
| `Auth.dashboardUrl(role)` | `'customer-dashboard.html'` \| `'supplier-dashboard.html'` \| `'index.html'` |
| `Auth.requireRole(role, url)` | **Guard.** If no session or role mismatch → `window.location.replace(url)` |
| `Auth.logout(redirectTo)` | Clears session, re-renders nav, redirects (default `index.html`) |
| `Auth.renderNav()` | Swaps "Sign In" for the **User Profile Dropdown** (role-aware: Dashboard / My Profile / Account Settings / Log Out), in navbar **and** hamburger menu. Idempotent; re-run after any nav change. |

### Storage

| Key | Store | TTL | Contents |
|---|---|---|---|
| `eventara_session` | `localStorage` | **12 hours** (`exp` timestamp) | `{token, role, name, email, iat, exp}` |
| `eventara_auth` | `sessionStorage` | - | **Legacy.** Migrated automatically by `getSession()`, then cleared |
| `eventara_chat` | `sessionStorage` | tab lifetime | Chat transcript (see §14) |

`token` is an opaque random string (`evt_…`) standing in for a server-issued session id.
It is **not** verified anywhere.

### Sign-in flow

```
signin.html
    │  handleSignIn(event)
    ▼
Compare email+password against SUPPLIER_LOGIN / CUSTOMER_LOGIN
    │
    ├── match (supplier) ──► Auth.login('supplier', …) ──► supplier-dashboard.html
    ├── match (customer) ──► Auth.login('customer', …) ──► customer-dashboard.html
    └── no match ─────────► inline error "Incorrect email or password. Please try again."
                             (no navigation)
```

### Protected-route flow

```
Browser requests customer-dashboard.html
    │
    ▼
<head> runs auth.js, then IMMEDIATELY:
Auth.requireRole('customer', 'signin.html?next=customer&role=customer')
    │
    ├── valid customer session ──► return true → page renders
    └── no session / wrong role ─► window.location.replace(signin.html?…)
                                   ↑ runs BEFORE <body> renders,
                                     so there is NO flash of protected content
```

**Why `<head>`:** the guard must execute before any protected markup paints. If you add a new
protected page, put the `requireRole` call in `<head>`, directly after the `auth.js` include -
**not** at the end of the body.

### Session expiry

`getSession()` checks `exp` on every call. An expired session is cleared and treated as signed
out - so the next `requireRole` bounces the user to sign-in gracefully.

---

## 10. FEATURES DOCUMENTATION

### 10.1 Supplier Search & Filtering

| | |
|---|---|
| **Purpose** | Let customers narrow 7 suppliers to relevant ones |
| **Location** | `search.html` (inline `<script>`) |
| **Inputs** | Event Type, Guest Count, Budget, Supplier Type (segmented), Sort By |
| **Outputs** | Filtered/sorted `.provider-card` set; live counts; empty state |
| **Mechanism** | **DOM-driven** - reads cards live, parses rating/price from rendered content, capacity/type from `data-*` |
| **Sorting** | Reputation (original order) · Rating desc · Price asc · Price desc |
| **Business rules** | Only the 7 confirmed suppliers exist; event managers have `data-capacity="9999"` so they never fail a guest-count filter |
| **Dependencies** | None beyond the DOM |

**Empty state:** "No suppliers match those filters yet" + CTA to submit a request anyway.

---

### 10.2 Quote Request (Brief)

| | |
|---|---|
| **Purpose** | Capture one structured request and fan it out to matched suppliers |
| **Location** | `brief.html` + `initMultiStepForm()` in `app.js` |
| **Inputs** | Event type, date, guests, requirements, budget band, contact details, optional GSTIN/PO |
| **Outputs** | Confirmation panel naming the 3 matched suppliers |
| **Business rules** | No sign-in required; 48-hour quote SLA; Udaipur locked; weddings option `disabled` |
| **Limitation** | **Not persisted** - no POST, no storage |

---

### 10.3 Quote Comparison

| | |
|---|---|
| **Purpose** | Make 3 quotes objectively comparable |
| **Location** | `compare.html` |
| **Mechanism** | Static table: rows = common inclusion list, columns = suppliers |
| **Business rules** | Gaps flagged; over-budget rows flagged; one quote tagged "Best value for your budget"; deposit row shows 30%; contact details stay private |

---

### 10.4 Booking & Payment Protection

| | |
|---|---|
| **Purpose** | Confirm a booking while protecting the customer's money |
| **Location** | `booking.html` |
| **Flow** | Deposit Paid → held safely → Your Event Happens → Venue Is Paid |
| **Rules** | ~30% deposit · held by Eventara, never passed straight to the supplier · released after delivery or auto after 72h · free for customers (commission is supplier-side) · cancellation tiers (30+ / 15-30 / <15 days) |
| **Limitation** | No real payment gateway - UI simulation |

---

### 10.5 Invoicing

| | |
|---|---|
| **Purpose** | Give finance teams a filable document |
| **Location** | `invoice.html` |
| **Outputs** | GST invoice (GSTIN, SAC, CGST/SGST, amount in words) + booking audit record |
| **Rule** | Issued automatically on every confirmed booking |

---

### 10.6 Authentication

Covered fully in [§9](#9-authentication-flow).

---

### 10.7 FAQ / Help Centre

| | |
|---|---|
| **Purpose** | Deflect support load with self-service answers |
| **Location** | `faq.html` |
| **Inputs** | Free-text search; category nav |
| **Outputs** | Filtered accordion; empty state; "Still need help?" CTA |
| **Content** | 50 FAQs / 8 categories, covering both audiences |
| **A11y** | Full ARIA accordion semantics, keyboard-navigable |

---

### 10.7b Support Requests & Complaints (Help Centre)

| | |
|---|---|
| **Purpose** | Give customers and suppliers a single channel to ask for help or raise a complaint |
| **Location** | `help.html` (inline `<script>`) |
| **Inputs** | Role - request type - name - organisation - email - mobile - booking ref (optional) - category - subject - description - attachments (UI only) - preferred contact - consent |
| **Outputs** | Confirmation panel with a generated reference (`SUP-`/`CMP-YYYY-NNNN`), type, category, expected response time, reply method |
| **Workflow** | Choose type -> form adapts (categories + button label) -> validate -> confirm |
| **Business rules** | Support = 24-48 business hours - Complaints = higher priority - users with an active/completed booking are handled sooner (described in plain terms, **never exposing internal prioritisation logic**) - no live chat or ticket tracking is implied |
| **Dependencies** | None - self-contained; no backend |
| **Limitation** | Nothing is submitted, stored or uploaded (see §15 L20) |

---

### 10.8 AI Assistant (Chatbot)

| | |
|---|---|
| **Purpose** | Context-aware help on every page, for both audiences |
| **Location** | `chatbot.js` (widget + offline brain) · `api/chat.js` (Gemini brain) |
| **Availability** | **Every page**, floating button bottom-right |
| **Architecture** | **Two brains with automatic fallback** (see below) |
| **State** | `sessionStorage['eventara_chat']` - conversation survives page navigation within a tab |

**Two-brain design:**

```
User sends a message
        │
        ▼
Is this a deterministic multi-turn flow (e.g. "find suppliers" wizard)?
        │
        ├── YES ──► Offline engine (instant, scripted, predictable)
        │
        └── NO ───► POST /api/chat  (Gemini, grounded on the KB)
                          │
                          ├── 200 + text ──► show it
                          │
                          └── 404 / 405 / 501 / 503 / error / timeout(20s)
                                    │
                                    └──► Offline engine  (apiState='off', stop retrying)
```

This means **the assistant always works** - on a static host, with no API key, or if Gemini is
down, it silently degrades to the scripted engine rather than erroring.

**Full knowledge details in [§14](#14-chatbot-knowledge-base).**

---

### 10.9 Supplier Dashboard

| | |
|---|---|
| **Purpose** | Let a business run their Eventara presence |
| **Location** | `supplier-dashboard.html` 🔒 |
| **Capabilities** | Enquiry inbox · quote builder · availability calendar · portfolio/packages · performance metrics · payouts ledger |
| **Rules** | Supplier role only; customer contacts masked until booking; 48-hour reply window with 24h/40h reminders |

---

### 10.10 Customer Dashboard

| | |
|---|---|
| **Purpose** | Let a customer track everything in one place |
| **Location** | `customer-dashboard.html` 🔒 |
| **Capabilities** | Requests & quotes · bookings · payments · saved suppliers (max 5 compared) · profile · raise an issue |
| **Rules** | Customer role only |

---

## 11. BUSINESS RULES

These encode product decisions. **Do not change them without an explicit instruction.**

### Scope & catalogue

| # | Rule |
|---|---|
| B1 | **Phase 1 = Corporate Events & Conferences + Institutional Events & Fests only.** |
| B2 | **Weddings are "Coming Soon"** - visible as a disabled card, never bookable, never browsable. |
| B3 | **Birthdays are NOT a category** - removed in Phase 1. Do not reintroduce. |
| B4 | **Udaipur only.** No other city is served or implied. |
| B5 | **Only the 7 confirmed vendors** may appear anywhere (see §5.2). Removed vendors (The Ananta, Radisson Blu, Aurika, Ramada, Labh Garh, Weddings by Neeraj Kamra, Skyline, Event Gurus, Kallakriti) **must not reappear**. |

### Money

| # | Rule |
|---|---|
| B6 | Free for customers - browsing, quotes and comparison cost nothing. |
| B7 | Free for suppliers to list; **commission on confirmed bookings only**, deducted from payout. |
| B8 | Deposit ≈**30%** confirms a booking. |
| B9 | The deposit is **held by Eventara**, never paid straight to the supplier. |
| B10 | Payout is released **after delivery** (or auto 72h post-event if nothing is flagged), net of commission. |
| B11 | Cancellation: full refund 30+ days · 50% 15-30 days · none under 15 days (balance never collected). |
| B12 | Every confirmed booking gets a **proper GST invoice**. |

### Trust & access

| # | Rule |
|---|---|
| B13 | **Only authenticated users reach dashboards** - enforced by `Auth.requireRole` in `<head>`. |
| B14 | **Role separation** - customers → `customer-dashboard.html`; suppliers → `supplier-dashboard.html`. Cross-role access redirects to sign-in. |
| B15 | **No auth bypass may exist.** (A "Continue as Customer" bypass was deliberately removed.) |
| B16 | Suppliers are **verified before listing** (identity + GST + licences) and carry a verified badge. |
| B17 | **Customer contact details stay private** until a booking is confirmed. |
| B18 | **Only customers who booked through Eventara can review.** |
| B19 | **Anti-leakage:** no outbound links to supplier websites/Instagram/YouTube. Keep users on-platform. |

### Copy & tone

| # | Rule |
|---|---|
| B20 | Customer-facing pages use **plain, warm, jargon-free language**. Banned: "brief" (→ request), "advance/bank mandate/escrow" (→ deposit, held safely), "SLA" (→ within 48 hours), "budget band" (→ budget), "reputation score" (→ rating), "PoC"/"pilot"/"B2B". |
| B21 | **Exception - `supplier-dashboard.html`** is business-facing: operational vocabulary is fine. |
| B22 | **Exception - `ops.html`** is internal staff tooling: funnel/crux/mandate terminology is intentional. |
| B23 | **Exception - `invoice.html`** and business verification: GST/GSTIN/SAC/FSSAI are correct and must stay. |
| B24 | Two-sided messaging: copy must address **both** customers and businesses, never assume one. |
| B25 | **FAQ and Help Centre are distinct.** `faq.html` = self-service answers; `help.html` = contacting the team. Footer "FAQ" → `faq.html`, "Help Centre" → `help.html`. Keep the two-way links. |
| B26 | **Never expose internal escalation or prioritisation logic.** Complaint priority is described to users in plain terms ("higher priority", "we look at those first") - never as rules, scores or queues. |
| B27 | **Do not imply capabilities that do not exist** - no live chat, no ticket tracking, no real file upload, no backend integration. |
| B28 | **Every page must be usable on a 360px-wide phone.** No horizontal page scroll, touch targets ≥44px, text inputs ≥16px. Wide tables scroll inside their own container, never the page. See §13 Responsive principles. |

---

## 12. UI COMPONENTS

All components are **CSS classes in `styles.css`**, applied to hand-written HTML. There is no
component framework and no partial/include system - **markup is duplicated across pages**.

> ⚠️ **CONSEQUENCE:** changing a shared component (navbar, footer, chat widget) means editing
> **all 12 HTML files**. There is no single place to change it. Use a scripted find/replace and
> verify every page.

| Component | Class(es) | Where used | Purpose |
|---|---|---|---|
| **Navbar** | `.navbar`, `.navbar-inner`, `.navbar-logo`, `.navbar-nav`, `.navbar-actions` | 10 navbar pages | Fixed top nav; `Auth.renderNav()` injects the User Profile Dropdown |
| **User Profile Dropdown** | `.account-menu` > `.account-trigger` (`.account-avatar` + `.account-name` + `.account-chevron`) + `.account-dropdown` (`.account-dd-head`, `.account-dd-item`, `.account-dd-logout`) | Every authenticated navbar page (desktop); `.mobile-account-*` inside `.mobile-menu` on phones | **The** authenticated nav pattern. Built once in `auth.js`, styled in `styles.css`. Role-aware destinations from the session (`dashboardUrl()` + `#profile`/`#settings`). Click / hover / outside-click / ESC / arrow-key + full ARIA (`role=menu`, `aria-haspopup`, `aria-expanded`). |
| **Logo** | `.logo-img` (→ `logo.svg`) | Navbar, footer, auth card, sidebars | Brand mark. Sizes: 40px nav / 44px footer / 54px auth / 34px sidebar |
| **Mobile menu** | `.mobile-menu`, `.hamburger` | All pages | Slide-in nav; toggled by `initMobileMenu()` |
| **Footer** | `.footer`, `.footer-grid`, `.footer-brand`, `.footer-col`, `.footer-tagline`, `.footer-bottom` | All pages | 4-column footer; tagline in royal blue |
| **Supplier card** | `.provider-card`, `.card-image`, `.card-content`, `.provider-name`, `.provider-meta`, `.price-row` | `search.html`, `index.html`, `provider.html` | Listing tile. Needs `data-capacity` + `data-ptype` on search |
| **Verified badge** | `.badge-verified` | Supplier cards & profile | Blue tick + "Verified" |
| **Initials cover** | `.card-image` with flex-centred text | Suppliers without a photo (HA, BS, IC, LL) | The design's official no-photo treatment - **not** a placeholder |
| **Category card** | `.category-card`, `.category-icon`, `.is-soon`, `.cat-badge`, `.cat-soon-label` | `index.html` | Phase 1 categories; `.is-soon` = non-clickable "Coming Soon" |
| **Button** | `.btn` + `.btn-primary` / `.btn-secondary` / `.btn-ghost` / `.btn-sm` / `.btn-lg` | Everywhere | Primary = royal blue fill |
| **Filter toolbar** | `.filter-bar`, `.filter-toolbar`, `.filter-field`, `.filter-select`, `.seg`, `.filter-toggle` | `search.html` | Filters; collapses on mobile |
| **Multi-step form** | `.multi-step-form`, `.form-step`, `.step-dot`, `.step-line`, `.step-label` | `brief.html` | Driven by `initMultiStepForm()` |
| **Input** | `.input-group`, `.input-field` | Forms | Label + control |
| **Sidebar** | `.sidebar`, `.sidebar-logo`, `.sidebar-nav` | Both dashboards | Vertical nav; `toggleSidebar()` on mobile |
| **Metric card** | `.metric-card`, `.metric-label`, `.metric-value`, `.metric-change` | Dashboards | KPI tiles |
| **Data table** | `.data-table` | Dashboards, ops | Rows of requests/bookings/disputes |
| **Status badge** | `.status`, `.status-new`, `.status-quoted`, … | Dashboards, ops | Coloured state pills |
| **Money-flow steps** | `.escrow-timeline`, `.escrow-step`, `.escrow-dot` | `booking.html`, `customer-dashboard.html` | 4-step deposit → payout visual (class name is legacy; the UX says "held safely") |
| **FAQ accordion** | `.faq-item`, `.faq-q`, `.faq-a`, `.faq-chevron` | `faq.html` | ARIA-complete accordion |
| **FAQ sidebar** | `.faq-sidebar`, `.faq-navlink` | `faq.html` | Sticky category nav with scroll-spy |
| **Breadcrumb** | `.breadcrumb` | `faq.html` | Home → Support → FAQ |
| **Chat widget** | `.evb-fab`, `.evb-panel`, `.evb-row`, `.evb-msg`, `.evb-chip`, `.evb-typing`, `.evb-form` | All pages (injected by `chatbot.js`) | Floating assistant |
| **Lightbox** | created by `openLightbox()` | `provider.html` gallery | Full-screen image overlay |
| **Testimonial** | `.testimonial-card`, `.stars`, `.avatar-placeholder` | `index.html` | Social proof |
| **Stat counter** | `.stat-item`, `.stat-value[data-count]` | `index.html` | Animated count-up on scroll |

### Responsive utilities (`styles.css` §14)

Reusable rules introduced by the mobile pass - prefer these over new one-off media queries:

| Rule | What it does |
|---|---|
| `.grid > *`, `.faq-layout > *`, `.brief-layout > *`, `.dashboard-layout > *` `{ min-width: 0 }` | Stops grid/flex children widening the page |
| `body { overflow-x: hidden }` | Last-resort guard against stray overflow |
| `html { -webkit-text-size-adjust: 100% }` | Stops iOS inflating text in landscape |
| `img, svg, video { max-width: 100% }` | Media never exceeds its box |
| `.card-flat { overflow-x: auto }` + `.data-table { width: max-content; min-width: 100% }` | Data tables scroll inside their card instead of clipping |
| 44px `min-height` on `.btn`, `.input-field`, `.filter-select`, `.seg button`, `.faq-navlink`, footer/breadcrumb links, radio/checkbox labels | Touch-target compliance |
| 16px `font-size` on all text inputs | Prevents iOS zoom-on-focus |
| `@media (prefers-reduced-motion: reduce)` | Near-disables animation/transition globally |

### Sign In page classes (`signin.html`, page-scoped)

Defined in that page's inline `<style>`, not in `styles.css`, because nothing else uses them.
Reuse the **pattern** rather than the class names if another immersive page is ever added.

| Class | Role |
|---|---|
| `body.auth-page` | Carries the full-bleed artwork; swaps to the portrait image ≤860px |
| `.auth-back` | Glassmorphic top-left back button; `authGoBack()` = history-back with an `index.html` fallback |
| `.auth-shell` | Full-viewport flex wrapper that positions the card (right/centred, or low on mobile) |
| `.auth-card` | **The glass panel** - frosted, bordered, shadowed |
| `.auth-body` | Scroll container for the form; owns the frosted scrollbar |
| `.checkbox-row` / `.link-subtle` / `.form-error` / `.legal-note` | Light-on-glass text treatments |
| `@keyframes authCardIn` | Transform-only entrance (see the AI rules - never animate opacity here) |
| `.sr-only` | Visually-hidden `<h1>`, because the real headline exists only as pixels |
| `.auth-header` `.auth-logo` `.auth-tabs` `.auth-tab` `.auth-body` `.auth-view` `.type-toggle` `.type-toggle-btn` | Pre-existing card internals, retained unchanged |

### Shared behaviours - `app.js`

| Function | Purpose |
|---|---|
| `initNavbar()` | Adds `.scrolled` to the navbar past 40px |
| `initScrollAnimations()` | Reveals `.fade-in` / `.scale-in` via `IntersectionObserver`; respects `prefers-reduced-motion` |
| `initCounters()` | Animates `[data-count]` stat values |
| `initMultiStepForm()` | Step navigation + progress dots + submit confirmation |
| `initMobileMenu()` | Hamburger toggle, close on link/outside click |
| `initTabs()` | Generic `[data-tabs]` tab switching |
| `initSmoothScroll()` | Smooth-scrolls `a[href^="#"]` |
| `openLightbox(src)` | Image lightbox |
| `toggleSidebar()` | Mobile dashboard sidebar |

---

## 13. STYLING GUIDELINES

Design language derived from `DESIGN-airbnb.md`: **white canvas, ink text, one strong accent,
generous whitespace, flat surfaces.**

### Design tokens (`:root` in `styles.css`)

**Always use tokens. Never hard-code a hex value in page markup.**

#### Colour

| Token | Value | Use |
|---|---|---|
| `--coral` | `#1E40AF` | **Royal Blue - the primary brand colour.** ⚠️ The variable is named `--coral` for legacy reasons (it used to hold Airbnb's Rausch red). It is blue. Do not rename without updating every usage. |
| `--coral-hover` | `#17318A` | Pressed/hover |
| `--coral-light` | `#E7ECFB` | Pale blue tint (badges, active nav) |
| `--gold` | `#CBA135` | Stars, ratings, premium accents |
| `--gold-light` / `--gold-deep` | `#F8F1D9` / `#8A6A12` | Gold tint / legible gold text |
| `--ink` | `#222222` | Primary text |
| `--ink-secondary` / `--ink-muted` / `--ink-faint` | `#3f3f3f` / `#6a6a6a` / `#929292` | Text hierarchy |
| `--canvas` / `--canvas-alt` | `#ffffff` / `#f7f7f7` | Page / soft surface |
| `--surface` | `#ffffff` | Cards |
| `--hairline` / `--hairline-strong` | `#dddddd` / `#c1c1c1` | Borders |
| `--trust-green` | `#2D9F6F` | Success, protected-payment signals |
| `--error` / `--warning` / `--info` | `#c13515` / `#F59E0B` / `#428bff` | Semantic states |

#### Typography

- **One family:** `--font-display` = `--font-body` = **Inter** (Google Fonts).
- Scale: `--text-display-xxl` 48px → `--text-display-lg` 28px → `--text-heading-lg` 22px →
  `--text-heading-sm` 18px → `--text-body` 16px → `--text-body-sm` 14px →
  `--text-caption` 13px → `--text-micro` 12px.
- Headings 600-700 weight, `letter-spacing: -0.5px` on large display sizes.
- Body `line-height` ≈ 1.6-1.7.

#### Spacing

4px-based scale: `--space-2` … `--space-120`
(`4, 6, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64, 80, 96, 120`). **Use these, not raw px.**

#### Radius

`--radius-sm/md/lg` 8px (buttons, inputs) · `--radius-xl`/`--radius-2xl` 14px (cards) ·
`--radius-3xl` 20px (large surfaces) · `--radius-pill` 9999px.

#### Shadows

Deliberately **one tier** - `--shadow-sm` … `--shadow-xl` all resolve to the same subtle Airbnb-style
stack. Flat or this. Nothing else.

#### Motion

`--duration-fast/base/slow` + `--ease-out` / `--ease-in-out`.
Scroll reveals respect `prefers-reduced-motion`.

### Responsive behaviour

Mobile-first-ish. The shared rules live in **`styles.css` §14 "Mobile Responsiveness"** (appended
last so it wins over earlier equal-specificity rules); page-specific tweaks stay in each page's
inline `<style>`.

| Breakpoint | Effect |
|---|---|
| `max-width: 1024px` | Momentum scrolling on scroll containers |
| `max-width: 900px` | FAQ sidebar → horizontal chip row; grids collapse |
| `max-width: 768px` | **Main mobile breakpoint** - mobile menu, 44px touch targets, 16px inputs, tables scroll inside cards, single-column grids, body padding-top 64px, search filters behind a toggle |
| `max-width: 860px` | Sign In page stacks (photo → fixed backdrop, card overlays) |
| `max-width: 640px` | Full-width selects; logo 34px |
| `max-width: 480px` | Stacked full-width buttons; tighter card padding; chat panel goes edge-to-edge |
| `max-height: 480px` + landscape | Navbar becomes static to reclaim vertical space; chat panel shortens |

**Hard rule:** no page may scroll horizontally at any width. Wide content (comparison and data
tables) scrolls **inside its own container** - verified at 360 / 390 / 414 / 768 / 1280px.

### Responsive principles (follow these when adding anything)

1. **Never let a child widen the page.** Grid and flex children default to `min-width: auto` and
   refuse to shrink below their content. `styles.css` sets `min-width: 0` on the known layout
   children; do the same for any new grid/flex layout, or use `minmax(0, 1fr)`.
   *This exact bug shipped once - the FAQ chip row widened the whole page to 1349px.*
2. **Touch targets ≥ 44px** (WCAG 2.5.8 / Apple HIG). If the visible control is smaller, give the
   **wrapping label** the height - for a checkbox or radio, the label is the real tap target.
   Inline links inside a sentence are exempt.
3. **Text inputs must be ≥ 16px on mobile** or iOS Safari zooms the page on focus.
4. **Tables get `width: max-content; min-width: 100%`** inside an `overflow-x: auto` card, so
   columns stay legible and the card scrolls instead of the page.
5. **Use `dvh`, not `vh`, for anything that must survive the on-screen keyboard** (the chat panel
   uses `min(78dvh, 620px)` with a `vh` fallback).
6. **Respect the notch** - `env(safe-area-inset-*)` on fixed bottom UI (chat FAB, footer).
7. **Measure, don't eyeball.** Compare `document.documentElement.scrollWidth` against
   **`clientWidth`** - *not* `innerWidth`, which includes the overflow and hides the very bug you
   are looking for.

### Supported mobile browsers

Verified layout/behaviour targets: **Chrome (Android)**, **Safari (iOS)**, **Samsung Internet**,
**Edge Mobile**, in portrait and landscape.

- Testing was done in a Chromium engine at real device widths (360 / 390 / 414 / 768 px), so
  Chrome, Samsung Internet and Edge Mobile are directly covered.
- Safari/WebKit-specific hazards were handled defensively rather than by live device testing:
  the 16px input rule (zoom-on-focus), `-webkit-text-size-adjust: 100%` (landscape text
  inflation), `-webkit-overflow-scrolling: touch` (momentum), `dvh` units (keyboard resize) and
  `env(safe-area-inset-*)` (notch). **A physical iPhone pass has not been done.**
- `:has()` is used on `help.html` and `brief.html`. Supported in all current target browsers;
  on an older engine the affected card simply does not show its selected-state highlight - the
  form still works.

### Design principles

1. **White canvas, ink text, one accent.** Royal blue for action, gold for rating/premium only.
2. **Flat.** No gradients, no glows, no heavy shadows.
3. **Whitespace over dividers.**
4. **Tokens over literals.**
5. **Trust is visual** - verified badges, protected-payment language, real photos.
6. **Icons are inline SVG**, stroke-based, `currentColor`.

---

## 14. CHATBOT KNOWLEDGE BASE

The assistant exists in **two independent implementations that must be kept in sync.**

| | Offline engine | Gemini endpoint |
|---|---|---|
| **File** | `chatbot.js` | `api/chat.js` |
| **Form** | 50 hand-written intents (keyword + phrase matching) | Natural-language KB in the system prompt |
| **Cost** | Free | Free tier |
| **Behaviour** | Deterministic, never hallucinates | Flexible phrasing, grounded |
| **Runs when** | Endpoint unavailable, or a scripted multi-turn flow is active | Endpoint reachable and configured |

> ⚠️ **SYNC RULE:** when a product fact changes, update **BOTH** `chatbot.js` (the matching
> intent) **AND** the `KB` string in `api/chat.js`. Divergence means users get different answers
> depending on whether the API is up.

### Knowledge coverage (50 offline intents)

| Area | Intent ids |
|---|---|
| **Platform** | `what`, `how`, `scope`, `wedding`, `free`, `cities`, `who` |
| **Discovery** | `find`, `filter`, `compare` |
| **Quotes & booking** | `quote`, `after`, `prices`, `negotiate`, `bookhow`, `instant`, `multi`, `mybookings`, `cancel`, `refund`, `review` |
| **Payments** | `paymethods`, `deposit`, `secure`, `invoice` |
| **Account** | `create`, `login`, `password`, `profile`, `delete` |
| **Supplier** | `become`, `onboard`, `listing`, `availability`, `enquiry`, `portfolio`, `payout`, `commission` |
| **Trust** | `verified`, `fraud`, `privacy` |
| **Support** | `support`, `hours`, `escalate`, `bug`, `faq` |
| **Social** | `hi`, `thanks`, `bye` |

### Context recognition

Both engines receive, and adapt to:

| Signal | Source | Effect |
|---|---|---|
| **Current page** | filename | Suggests page-relevant actions and quick replies |
| **Role** | `Auth.getRole()` | Customer vs supplier phrasing (e.g. "How do I get paid?" answers from the *supplier's* side on the dashboard) |
| **Signed-in state** | `Auth.isAuthenticated()` | Offers sign-in vs account links |
| **Name** | session | Light personalisation |

### Response guidelines (enforced in the Gemini system prompt)

1. **Ground everything.** Answer only from the KB. If it isn't there, say so - never invent
   prices, policies, vendors, dates or features.
2. Weddings = coming soon; birthdays = not supported. Never imply either is bookable.
3. **2-4 short sentences.** Small chat window.
4. Plain text + `<b>` and `<a href="page.html">` only. **No markdown**, no headings, no bullets.
5. Final answer only - no reasoning, no preamble.
6. Escalate to `support@eventara.in` when stuck or asked for a human.
7. British/Indian English; ₹ for money.

### Fallback behaviour

```
Gemini fails / not configured  ──►  offline engine answers
Offline engine has no match    ──►  "I don't have enough information to answer that
                                     confidently, and I'd rather not guess."
                                     + link to Help Centre + support email
```

**Verified in production** (2026-07-17): asked *"Who is the CEO and what was your revenue last
year?"*, the assistant **declined** rather than inventing - which is the intended behaviour.

### Conversation persistence

Stored in `sessionStorage['eventara_chat']`, so the conversation **survives navigation between
pages** in the same tab and is cleared when the tab closes. A reset button clears it manually.

### Serverless endpoint reference (`api/chat.js`)

| Aspect | Detail |
|---|---|
| **Route** | `POST /api/chat` (Vercel auto-routes from `api/chat.js`) |
| **Health check** | `GET /api/chat` → `{ok, configured, model}` - reports **whether** a key exists, never the key |
| **Request** | `{ messages: [{role:'user'\|'assistant', content}], context: {page, role, signedIn, name} }` |
| **Response** | `{ text, model }` |
| **Model** | `gemini-3.5-flash` (override via `GEMINI_MODEL`) |
| **SDK** | `@google/genai`, `ai.interactions.create({...})` → `interaction.output_text` |
| **Config** | `max_output_tokens: 800`, `temperature: 0.3`, `thinking_level: 'low'`, `store: false` |
| **Env var** | **`GEMINI_API_KEY`** - set in Vercel only. **NEVER** put it in client-side files. |
| **History** | Flattened into one string (`buildInput()`) - see the note below |
| **Guards** | Method check · input validation · 2,000 chars/message · 20-turn cap · per-IP rate limit (40 / 5 min) · 20s client timeout |
| **Errors** | 401/403 → 503 `assistant_unconfigured` · 429 → `rate_limited` · else 502 |

> **Why history is flattened:** Gemini's structured multi-turn form requires echoing back the
> model's own step objects verbatim. The widget only stores rendered text, so we send
> `store: false` and pass recent history as one string. **Do not "fix" this to a turns array**
> without first solving step-object persistence.

---

## 15. KNOWN LIMITATIONS

Be honest about these - especially in a stakeholder demo.

### Architectural

| # | Limitation |
|---|---|
| L1 | **No backend or database.** Except `/api/chat`, everything is static. Nothing submitted is stored. |
| L2 | **Auth is client-side only.** No password hashing, no server verification. A user can forge a session via dev tools. The UX gate is correct; the security is not production-grade. |
| L3 | **Hard-coded credentials** live in `signin.html` (visible in page source). |
| L4 | **No component system.** Navbar/footer/widget markup is duplicated across 12 files; a shared change means 12 edits. |
| L5 | **Manual cache-busting.** Forgetting a `?v=` bump ships stale assets to returning users. |

### Functional

| # | Limitation |
|---|---|
| L6 | **`provider.html` is one hard-coded profile** (Paandora Grand). Every supplier card leads there. |
| L7 | **Forms don't submit.** `brief.html` shows a simulated confirmation; no data leaves the browser. |
| L8 | **No real payments.** `booking.html` is a UI simulation - no gateway, no UPI mandate. |
| L9 | **Static demo data** throughout: one booking (₹10,03,000 / ₹3,00,900 deposit), one customer (Secure Meters), fixed quotes. |
| L10 | **No real search backend** - filtering is client-side over 7 hard-coded cards. |
| L11 | **Reviews, availability calendar, quote builder are display-only** - not interactive. |
| L12 | **Homepage hero search doesn't pass filters** to `search.html`. |
| L20 | **Help Centre submissions go nowhere.** `help.html` does not POST, store, email or upload. The reference number is generated client-side and cannot be looked up. Attachments are listed for show only. |
| L21 | **Mobile verification was engine-based, not device-based.** Layout was measured in a Chromium engine at real device widths; **no physical iPhone/Android device test has been run.** WebKit-specific behaviour (keyboard resize, momentum scrolling, notch insets) is handled defensively but unverified on hardware. |
| L22 | **`provider.html` image gallery and `ops.html` remain desktop-oriented in density.** They fit and do not overflow on mobile, but were designed for larger screens. |
| L23 | **`backdrop-filter` is GPU-composited.** On low-end Android the Sign In glass card may repaint slowly while scrolling. The `@supports` fallback covers browsers without it, but not slow ones. |
| L24 | **The Sign In page has been verified by DOM measurement, never by screenshot.** The build environment's renderer does not composite: screenshots time out, CSS animations freeze at frame 0, IntersectionObserver never fires and `window.scrollTo` is a no-op (confirmed against `faq.html` as a control). Geometry, contrast, overflow and touch targets were measured numerically; **no human has visually signed off the rendered page.** |
| L25 | **The glass card is intentionally darker than `Sign-in-page-ui-web-idea.png`.** The mock-up's pale lavender tint measures 2.6:1 for white text over the bright bokeh - below WCAG AA. Accessibility was prioritised over pixel-matching the mock-up. |

### Data & media

| # | Limitation |
|---|---|
| L13 | **Supplier photos are hotlinked** from third-party CDNs (pandorahotels.co.in, sterlingholidays.com, blossomevent.com, media.easemytrip.com). If a host blocks hotlinking or moves a file, images break. Local copies would be more robust. |
| L14 | **3 suppliers have no verified photo** - Hotel Aloka, Bluspring, Indicraft Communications use initials covers. Their ratings/review counts/prices are **illustrative**, not sourced. |
| L15 | **"Hotel Aloka" identity is unconfirmed** - public searches resolve to a different property ("Hotel Alka"). Confirm before publishing. |
| L16 | **Testimonials and sample GST/FSSAI numbers are illustrative** (marked `(sample)` on the invoice). |

### Integrations not present

Payment gateway · email/SMS notifications · real-time messaging · file uploads · calendar sync ·
analytics · admin portal · CRM · database of any kind.

### Content gaps

`Privacy Policy` and `Terms of Service` footer links point to `#` - the pages don't exist.

### Chatbot

| # | Limitation |
|---|---|
| L17 | Gemini's **free tier has per-minute/per-day rate limits**; hitting one degrades to the offline engine mid-demo. |
| L18 | Free-tier data **may be used by Google to improve their models** - fine for prototype data, not for anything sensitive. |
| L19 | The two knowledge bases can **drift apart** if only one is updated (see the sync rule in §14). |

### Known behaviours that are NOT bugs

- Initials covers instead of photos → the design's official no-photo treatment.
- `--coral` holding a blue value → legacy variable name, intentional.
- `.escrow-*` class names → legacy; the visible UX correctly says "held safely".
- Operational jargon on `ops.html` / `supplier-dashboard.html` → intentional, audience-appropriate.

---

## 16. FUTURE ROADMAP

### Phase 2 - Product completeness

| Priority | Item | Notes |
|---|---|---|
| P0 | **Weddings & Related Celebrations marketplace** | The "Coming Soon" card becomes live; largest segment by value |
| P0 | **Per-supplier profile pages** | Replace the single hard-coded `provider.html` (fixes L6) |
| P0 | **Backend + database** | Persist requests, quotes, bookings, users (fixes L1, L7) |
| P0 | **Server-side authentication** | Real accounts, hashed passwords, verified sessions (fixes L2, L3) |
| P1 | **Online payments** | UPI/card gateway with genuine escrow (fixes L8) |
| P1 | **Supplier onboarding portal** | Self-serve document upload + verification workflow |
| P1 | **Real quote builder** | Suppliers compose and send itemised quotes |
| P1 | **Support ticketing backend** | Persist `help.html` submissions, email confirmations, real attachments, status lookup by reference (fixes L20) |
| P1 | **Availability calendar** | Interactive blocking, double-booking prevention |

### Phase 3 - Depth

| Priority | Item |
|---|---|
| P2 | Real-time messaging between customer and supplier (contacts still masked) |
| P2 | Notifications - email + SMS/WhatsApp for enquiries, quotes, reminders |
| P2 | Reviews & ratings - collection flow, moderation, aggregation |
| P2 | Admin portal - productionised `ops.html` with real auth |
| P2 | Analytics dashboard - funnel, conversion, supplier performance |
| P3 | AI recommendations - suggest suppliers from event profile and history |
| P3 | Multi-city expansion - the Udaipur playbook applied to other tier-2 cities |
| P3 | Mobile apps |
| P3 | Contract & e-signature flow |
| P3 | Privacy Policy + Terms pages (fills the `#` links) |

### Technical debt to retire

Componentise shared markup (L4) · automated build with cache-busting (L5) · host images locally
(L13) · replace hard-coded demo data (L9) · consolidate the two chatbot knowledge bases (L19) ·
add automated tests.

---

## 17. AI AGENT INSTRUCTIONS

**If you are an AI coding assistant working on this project, follow these rules.**

### Before you change anything

1. **Read this document.** It is the fastest route to full context.
2. **Verify before trusting.** This doc was accurate on the date at the top. If a detail matters,
   confirm it in the code - files change.
3. **Know the repo layout.** Local `prototype/` contents == GitHub repo root. Local
   `prototype/api/chat.js` → repo `api/chat.js`. This handout lives *outside* `prototype/` and is
   **not deployed**.

### While you work

4. **Respect the business rules in §11.** They are product decisions, not accidents. Never
   reintroduce weddings as bookable, birthdays as a category, other cities, or removed vendors.
5. **Use design tokens** (§13). Never hard-code colours, spacing or font sizes in page markup.
6. **Preserve conventions:**
   - Vanilla JS, ES5-flavoured, no frameworks, no build step.
   - Inline SVG icons, not an icon library.
   - One `styles.css`; flat JS files in the root.
   - Guards go in `<head>`, immediately after the `auth.js` include.
7. **Shared markup lives in 12 files.** Editing the navbar/footer/widget means editing every HTML
   page. Script it, then verify each page.
8. **Bump the `?v=` query** on any edited `styles.css` / `app.js` / `auth.js` / `chatbot.js` -
   in **all** HTML files.
9. **Keep both chatbot brains in sync** (§14): a fact change means editing `chatbot.js` **and**
   the `KB` in `api/chat.js`.
10. **Never put secrets in client-side files.** `GEMINI_API_KEY` belongs only in Vercel env vars.
    The repo is public.
11. **Keep the anti-leakage rule** (B19): no outbound links to supplier sites or social media.
12. **Watch encoding.** These files have had UTF-8 mojibake before. Edit as UTF-8; `check_mojibake.py`
    and `fix_encoding.py` exist for a reason. ₹ and → must survive your edit.
13. **Don't "fix" intentional things:** `--coral` is blue; `.escrow-*` is a legacy class name;
    initials covers are the official no-photo treatment; `ops.html`/`supplier-dashboard.html` jargon is
    audience-appropriate; invoice GST terminology is correct.

### Verify your work

14. **Test in a browser, don't assume.** Serve `prototype/` and check the affected pages.
15. **Check both signed-in states** when touching auth, nav or the chatbot (customer, supplier,
    signed-out).
16. **Never render the Sign In hero copy in HTML.** The headline, subtitle and the three
    feature icons are baked into `login-bg.jpg` / `login-bg-mobile.jpg`. Adding them as
    markup duplicates them on screen - this shipped once already.
17. **Do not lighten the Sign In glass card to match the mock-up.** The dark violet scrim
    is an accessibility decision, measured: the mock-up's pale tint gives white text
    2.6:1 over the chandelier bokeh. Keep secondary text at α ≥ 0.82.
18. **Never gate above-the-fold content behind an opacity animation or `.fade-in`.**
    `.fade-in` starts at `opacity: 0` and waits for app.js's IntersectionObserver; an
    opacity keyframe with `fill-mode: both` pins the element invisible if animations do
    not run. The Sign In card animates **transform only** for exactly this reason.
19. **Never blur a full-size image in CSS to make a backdrop.** CSS blur decodes the
    full image; generate a small pre-blurred asset instead.
20. **Check mobile properly.** Test at **360px** (not just 375px) and compare
    `document.documentElement.scrollWidth` against **`clientWidth`** - using `innerWidth`
    silently hides overflow bugs. Confirm: no horizontal page scroll, touch targets ≥44px,
    text inputs ≥16px, and that any new grid/flex layout has `min-width: 0` on its children.
21. **Check the console** - zero errors.
22. **Test the chatbot's offline path too.** A static server has no `/api`, which is exactly the
    fallback case.

### After you change anything

23. **UPDATE THIS DOCUMENT IN THE SAME CHANGE.** Non-negotiable. If you added a page, feature,
    component, business rule, route, env var or dependency - document it here.
    **This file exists in TWO places** - `PROJECT_HANDOUT.md` (local root, master) and
    `prototype/PROJECT_HANDOUT.md` (deployed to the repo root). Edit one, then copy it over the
    other so they stay byte-identical. Never update only one.
24. **Add a change-log entry** (§18) with a bumped version.
25. **Say plainly what you did and did not verify.** If you couldn't test something, say so.

### Things that need explicit human approval

- Adding a new npm dependency (the front end is deliberately dependency-free)
- Introducing a framework or build step
- Changing any §11 business rule
- Changing the money numbers in the demo flow (they're consistent across 4 pages)
- Anything that would put a secret in a client-side file
- Publishing unverified vendor details as fact

---

## 18. CHANGE LOG

Append a new entry for **every** change. Newest first. Bump the version at the top of this file.

---

### Version 2.1 - 2026-07-19
**Two mobile-only fixes: scrollable monthly calendar + Hero search Date field.**

| Issue | Fix (mobile-only, ≤768px) |
|---|---|
| **Supplier calendar clipped** - only Mon-Thu showed. The 7 `1fr` columns take their `min-content` width, and the "Maintenance"/"Secure Meters" `nowrap` labels forced ~95px each (~665px total), which the grid's `overflow: hidden` clipped. | Wrapped the month grid in **`.cal-scroll { overflow-x: auto }`** with **`.calendar-grid { min-width: 640px }`** (~91px columns). All seven days are now reachable by horizontal swipe **inside the calendar**; the page never scrolls sideways. |
| **Hero Date field blank + centred chevron** on some Android builds. | `placeholder="dd-mm-yyyy"`; `::-webkit-datetime-edit { flex: 1 1 auto; text-align: left }`; `::-webkit-calendar-picker-indicator { margin-left: auto }` - text left, calendar icon hard-right, matching the other fields. |

- **Files changed:** `styles.css` (date-field pseudo-elements in the ≤768 block),
  `supplier-dashboard.html` (`.cal-scroll` wrapper + mobile CSS), `index.html`
  (date placeholder). Cache-bust **`styles.css?v=17 → v=17`** across all 13 HTML files.
  **Desktop/tablet CSS untouched.**
- **Sections updated:** §5.1 (Date field row), §5.11 (Calendar mobile note), §18.
- **Verified:**
  - **All 7 weekday columns** (Mon-Sun) render; grid 640px **scrolls inside `.cal-scroll`**;
    **page does not scroll sideways**; scrolling reveals the Sunday column
  - Calendar indicators intact - 2 booked events, event dots, 4 labels, 1 maintenance,
    2 blocked, 1 tentative, today; day-click (`cycleDay`) still works
  - **Desktop calendar unchanged** (min-width 0, 7 columns fit, no scroll)
  - Date field: `placeholder="dd-mm-yyyy"`, full-width and in-viewport, still accepts values
    (picker behaviour preserved); alignment rules confirmed present in the CSSOM
  - Search component: no horizontal overflow at **320 / 360 / 375 / 390 / 412 / 430px**;
    fields uniform; **zero console errors**
- **Known pre-existing (not from these fixes, left as-is):** at **320px** the shared navbar's
  content extends ~17px (hamburger slightly clipped); `body { overflow-x: hidden }` already
  prevents an actual horizontal scrollbar. Untouched to avoid a shared-navbar regression across
  all pages; flagged for a separate pass.
- **Not verified:** no screenshot (build-renderer limit, see L24). `-webkit-` date pseudo-element
  positions can't be introspected via `getComputedStyle`; the rules are confirmed loaded and are
  the canonical cross-browser fix - a real-device glance is advised.

---

### Version 2.0 - 2026-07-19
**Authenticated navigation replaced with a reusable User Profile Dropdown.**

The header's avatar + full name + standalone Log out button became a single **profile menu**:
**avatar + name + chevron** that opens a dropdown. Built once in `Auth.renderNav()` (`auth.js`)
and styled in `styles.css`, so it is identical on every authenticated page - no per-page
duplication.

| Menu item | Customer | Supplier |
|---|---|---|
| **Dashboard** | `customer-dashboard.html` | `supplier-dashboard.html` |
| **My Profile** | `…#profile` | `…#profile` |
| **Account Settings** | `…#settings` | `…#settings` |
| **Log Out** | clears session → `index.html` | clears session → `index.html` |

Destinations are derived from the session role (`Auth.dashboardUrl()` + hash) - nothing hard-coded.

| Area | Change |
|---|---|
| **Desktop** | `.account-trigger` opens `.account-dropdown`; click-to-open, click-outside & ESC close, ArrowUp/Down move focus, chevron rotates, soft shadow + scale/opacity animation |
| **Mobile** | Same four items injected into the hamburger `.mobile-menu` under an account header; 44px+ tap targets |
| **Accessibility** | `role="menu"` / `menuitem`, `aria-haspopup`, `aria-expanded`, `:focus-visible` rings, keyboard operable, `prefers-reduced-motion` respected |
| **Customer Settings** | Added a real **Account Settings** panel (+ sidebar item) to `customer-dashboard.html` so "Account Settings" has a role-correct destination (Account, Notifications, Privacy) - mirrors the supplier settings |
| **In-page routing** | Both dashboards gained a `hashchange` listener so the dropdown's `#profile`/`#settings` links switch panels without a reload |

- **Files changed:** `auth.js` (renderNav rewritten to the dropdown), `styles.css` (dropdown +
  mobile-account styles, old `.account-chip`/`.account-logout` removed), `customer-dashboard.html`
  (Settings panel + nav item + hashchange), `supplier-dashboard.html` (hashchange). Cache-bust
  **`auth.js?v=3 → v=3`**, **`styles.css?v=17 → v=16`** across all 13 HTML files.
- **Sections updated:** §5.10, §6, §9, §12, §18, asset-version strings.
- **Verified end-to-end:**
  - Dropdown renders for **both roles** with correct avatar, name and role-aware links; the old
    standalone Log out button is gone; "Sign In" hidden while authenticated
  - Open on click; **close on click-outside and ESC**; ArrowUp/Down focus movement; full ARIA
  - **Customer** Account Settings → `customer-dashboard.html#settings` opens the new Settings
    panel (toggles work); **Supplier** → `supplier-dashboard.html#settings`
  - My Profile → each role's `#profile` panel; Dashboard → each role's dashboard
  - **Log Out** clears the session (+ legacy `sessionStorage`), returns to `index.html`, restores
    the public "Sign In" nav
  - Session **persists** across public-page navigation; dropdown present on all 10 navbar pages;
    dashboards keep their sidebar nav
  - Mobile: account block inside the hamburger, all items in viewport, 50px tap targets
  - **No horizontal overflow, no dropdown clipping** at 1280 / 390px; **zero console errors**
- **Not verified:** no screenshot / no physical device (build-renderer limit, see L24). Prototype
  settings actions are `toast()` acknowledgements (no backend).

---

### Version 1.9 - 2026-07-19
**Supplier dashboard renamed to `supplier-dashboard.html`; customer dashboard gains a Home button.**

| Change | Detail |
|---|---|
| **Rename** | `dashboard.html` → **`supplier-dashboard.html`**. Every reference updated (boundary-aware, so `customer-dashboard.html` was untouched): `auth.js` (`dashboardUrl`), `signin.html` (business register + sign-in redirect), `invoice.html` (Venue's-view link), `chatbot.js` (business-portal link), and this document. |
| **Cache-bust** | `auth.js?v=1 → v=2` and `chatbot.js?v=9 → v=9` across all 13 HTML files - a cached `auth.js` would otherwise redirect suppliers to the old, now-404 filename. |
| **Customer Home button** | Added to the customer dashboard header, **between Date and New Request** (`.btn.btn-secondary.btn-sm`, home icon), matching the supplier dashboard. Plain `index.html` link - preserves the session. |

- **Files changed:** `dashboard.html` renamed to `supplier-dashboard.html`; `auth.js`,
  `signin.html`, `invoice.html`, `chatbot.js`, `customer-dashboard.html` edited; all 13 HTML
  files version-bumped. No `styles.css` change.
- **Sections updated:** §4 (file tree), §5.10 (customer Home button), §5.11 (heading/URL), §18,
  plus asset-version strings throughout.
- **Verified end-to-end:**
  - Supplier login → **`/supplier-dashboard.html`**; `Auth.dashboardUrl('supplier')` returns the
    new name; old `dashboard.html` → **404**, new file → **200**
  - Redirect protection: unauthenticated direct hit on `supplier-dashboard.html` → `signin.html`
  - **No broken internal links** anywhere (all 13 pages resolve); **zero standalone `dashboard.html`**
    left in any html/js/css
  - Customer dashboard Home button sits **Date → Home → New Request**; both dashboards' Home
    buttons return to `index.html` with the **session preserved** (role intact); logout still only
    via the Log-out button
  - Customer nav: 8 panels switch, 0 dead links; Supplier nav: 7 panels switch, 0 dead links
  - **Zero horizontal overflow** on all panels of both dashboards at 390px; sidebar hamburger,
    open, and overlay-close all work; **zero console errors**
- **Not verified:** no screenshot / no physical device (build-renderer limit, see L24).
**Supplier Dashboard rebuilt to full feature parity with the Customer Account.**

`supplier-dashboard.html` was a single long-scroll page with **every sidebar link dead (`href="#"`)** and
no panel switching. Rebuilt on the same `showPanel()` panel architecture as
`customer-dashboard.html`, so the two portals feel like one product.

| Area | What changed |
|---|---|
| **Navigation** | 7 sidebar items, each `data-panel` → its own `.dash-panel`; deep-linkable `#hash`; **zero `href="#"` dead links** |
| **Overview** | Richer metrics, quick actions, needs-attention, activity timeline, pipeline, revenue summary, performance + customer rating |
| **Enquiries** | Full module - status pills + Event Type / Budget / Customer / Date filters; Build/Edit Quote, Respond, Save Draft, Archive, View |
| **Bookings** | Upcoming / Ongoing / Completed / Cancelled pills; Invoice, Contact, Update status, Payment |
| **Calendar** | Month / Week / Day views; Block / Maintenance / Reopen tools; click-to-apply on open days; full legend |
| **Disputes & Complaints** | **New module** - complaints & disputes, Open/Under Review/Resolved, priority dots (Low–Critical), Respond / Upload Evidence / Timeline |
| **Profile** | Business details, GSTIN/PAN/FSSAI, amenities & pricing, cancellation policy, logo/video/gallery upload zones, socials |
| **Settings** | Account, Business, Notifications (Email/SMS/WhatsApp/Push toggles), Payment, Privacy |
| **Notifications** | Decorative bell → real panel with mark-read / mark-all-read / view-all and a live unread count |
| **Home button** | Added beside the bell (`<a href="index.html">`) - **preserves the session** |

- **Files changed:** `supplier-dashboard.html` (only). No shared file touched - all new components are
  page-scoped in its `<style>`, reusing design-system classes elsewhere.
- **Sections updated:** §5.11 (rewritten), §18
- **Verified by measurement / interaction:**
  - 7 nav links → 7 panels, each switch shows exactly one panel; **0 dead links**
  - Notifications: opens, unread 4 → 3 (mark one) → badge hidden (mark all)
  - Enquiry filter All=6/New=2/back=6; Booking Cancelled=1; Dispute filters work
  - Calendar Month/Week/Day toggle; block-a-day applies and toasts
  - **Home → `index.html` keeps the supplier session; re-entering the dashboard passes the
    gate without re-login; Log-out clears the session and lands on Home** (logout only via button)
  - Auth gate (`requireRole('supplier', …)`) intact; supplier login still routes here
  - **Zero horizontal overflow on all 7 panels at 390 / 768 / 1440px**; sidebar hamburger
    <=1024px; tables scroll inside cards; notification panel docks bottom on phones
  - **Zero console errors**
- **Not verified:** no screenshot / no physical device (build-renderer limit, see L24); action
  buttons are `toast()` acknowledgements (no backend - prototype scope).

---

### Version 1.7 - 2026-07-19
**Home hero search bar - alignment and placeholder fixes.**

Three UI-only refinements to `.search-bar` (in `styles.css`, used only on `index.html`);
no markup, search routing or field logic changed.

| Issue | Cause | Fix |
|---|---|---|
| Guest Count placeholder clipped to "Guest Cou" | The Event Type `<select>` kept its wide min-content width (285px), squeezing Guest Count to 134px - 1px under the placeholder - and the number spinner ate more right-hand space | `.search-field { min-width: 0 }` equalises all four fields (177px each); number spinner removed (`appearance: textfield` + hidden webkit spin buttons) |
| Search button looked detached | It sat flush (0px) against the Guest field while having 6px to the pill's right edge | `margin-left: var(--space-6)` - balanced 6px both sides. It was already vertically centred and the icon already centred |
| Mobile fields uneven / Guest Count clipped | The stacked column inherited `align-items: center`, so fields kept intrinsic widths | Mobile block now `align-items: stretch` (all fields full-width, 52px touch height); the button's desktop `margin-left` reset to 0 |

- **Files changed:** `styles.css` (the `.search-bar` rules + its `≤768px` block). All 13
  HTML files bumped **`styles.css?v=14 → v=15`** for cache-busting. No other file touched.
- **Sections updated:** §3 & §5 (version strings), §5.1 (new hero-search subsection), §18
- **Verified by measurement** at 1440 / 768 / 390px:
  - Fields **equal width** (177px desktop; uniform full-width stacked on mobile/tablet)
  - "Guest Count" placeholder **fits** (94px into 137px desktop / 245px mobile) - no clip
  - Search button **vertically centred** (0px offset), **6px balanced gap**, icon centred (0,0)
  - Field touch height 52px on mobile (≥44)
  - Search button still routes to `search.html`; Event Type select and Guest Count input
    still accept values
  - **No horizontal overflow** at any width; **zero console errors**
  - `.search-bar` exists only on `index.html`, so no other page is affected
- **Not verified:** no screenshot - build-renderer limitation (see L24).

---

### Version 1.6 - 2026-07-19
**Added a back-navigation button to the Sign In page.**

Users reach `signin.html` from many entry points (Home, Search, Supplier, Help, FAQ). A
glassmorphic **Back** button now sits at the top-left so they can return without the
browser chrome.

| Aspect | Detail |
|---|---|
| Look | 44x44 glass circle matching the card - `rgba(38,28,52,0.46)` + `blur(26px)`, white border/arrow, hover/active/focus states |
| Place | `position: absolute`, top-left, `20px + safe-area`. Absolute (not fixed) so it scrolls away with the hero on mobile rather than drifting over the card |
| Logic | `authGoBack()` - same-origin referrer + history → `history.back()`; else the `href="index.html"` fallback fires |
| A11y | Real `<a>`, first in tab order, `aria-label`, `aria-hidden` SVG, `:focus-visible` ring, honours reduced-motion |

- **Files changed:** `signin.html` (only) - one CSS block, one `<a>`, one `authGoBack()`
  function. No auth, session, layout or background code touched.
- **Sections updated:** §5.9 (new back-button subsection), §12 (class table), §18
- **Verified end-to-end:**
  - Search → Sign In, click back → **returns to search.html** (history-back path)
  - Direct load (empty referrer), click back → **index.html** (fallback path)
  - Decision function correct for external referrer, empty+direct, empty+history and
    internal referrer
  - Button 44x44 at (20,20); **no overlap** with the card (desktop or mobile) or the
    baked-in headline (mobile button bottom 64px vs headline ~110px); no horizontal overflow
  - Keyboard-focusable, first in tab order, `:focus-visible` outline present, `aria-label`
    set, SVG `aria-hidden`
  - Auth untouched - tab switch, toggle, bad-credential error + no-session, and
    `customer@eventara.in` → `customer-dashboard.html`; zero console errors
- **Not verified:** no screenshot / device test - build renderer limitation (see L24).

---

### Version 1.5 - 2026-07-19
**Mobile Sign In layout reworked - hero shown in full, card scrolls in below it.**

On phones the card overlapped the hero: the Sign In card partly covered the baked-in
headline, and the Register card buried the headline, subtitle and all three feature icons.
Cause - the mobile layout bottom-aligned the card **inside a single viewport**
(`display: flex` + `margin-top: auto`), so on tall phones it floated up over the artwork's
top region, where the hero content lives.

Rebuilt so the artwork is shown **in full first** and the card sits **below** it, per
`images/Sign-in-page-ui-mobile-idea.png`:

| Change | Detail |
|---|---|
| Hero fully visible | `background-size: 100% auto` renders the whole portrait artwork at viewport width; the headline, subtitle and icons (top ~37%) are never covered |
| Card positioned below | `.auth-shell` switched to `display: block` with `padding-top: 86vw` - a `vw` spacer that tracks the artwork's height (a fixed 2.16x of width) on every device, landing ~40px below the icons |
| Natural scroll | The page grows and scrolls; the hero is never compressed to fit one screen |
| Chatbot clearance | `padding-bottom: calc(116px + safe-area)` keeps the fixed FAB off the Sign In / Create Account button at full scroll (~33px clearance, verified) |
| `≤480px` fix | Its shell rule was changed from the `padding` shorthand (which reset `padding-top` to 0) to longhand, so the 86vw spacer survives |

- **Files changed:** `signin.html` (only) - the three mobile media blocks. Nothing else
  touched; **`chatbot.js` was read but not modified**.
- **Sections updated:** §5.9 (placement + responsive tables, new mobile-flow note), §18
- **Verified by measurement** at 360 / 390 / 412 / 768 px and 740x380 landscape:
  - Card top always **below** the baked-in icons (computed icon-end = 37% of the rendered
    artwork height) - gaps 40-76px, **zero overlap** in both the Sign In and the tall
    Register/Business views
  - Card width ~90% (72% at 768 where `max-width: 34rem` caps it), centred
  - **Zero horizontal overflow**; page scrolls vertically as intended
  - Chatbot FAB clears the last CTA by ~33px at full scroll, both views
  - **Desktop unchanged** - 1440px still 441x533, 5.8% gutter, centred, `login-bg.jpg`
    cover/left, flex shell (byte-for-byte the v1.4 geometry)
  - Landscape phone still falls back to the landscape artwork with a centred card
  - Auth intact - tab switch, Customer/Business toggle, error + no-session on bad
    credentials, and `customer@eventara.in` → `customer-dashboard.html`; zero console errors
- **Not verified:** no screenshot / no physical device - the build renderer does not
  composite or scroll (see L24). Geometry, overlap and clearance were computed numerically;
  **the rendered mobile page has not been seen.** Worth a real-device glance.

---

### Version 1.4 - 2026-07-19
**Sign In page rebuilt to match the supplied design references, then refined.**

v1.3's split-screen was wrong in a fundamental way: the artwork **already contains** the
headline, subtitle and the three gold feature icons, and v1.3 rendered all of them again
in HTML - so every element appeared twice, in two different places. Rebuilt as the
references actually show it: full-bleed artwork, one glass card floating on it, nothing
else.

| Area | Change |
|---|---|
| **Composition** | Removed `.auth-split`, `.auth-hero*`, `.auth-bg` and all duplicated hero markup. The page is now the background plus a single `.auth-card` inside a positioning `.auth-shell`. |
| **Artwork** | `login-bg.jpg` (landscape) ≥861px; `login-bg-mobile.jpg` (portrait) ≤860px. `background-position: left center` so the baked-in headline is never cropped. |
| **Geometry** | Measured off the references rather than eyeballed - desktop card 34vw with a 5.8% right gutter, vertically centred; mobile 90% wide, 4.9% gutters, ~39% down. |
| **Glass** | Inverted to a **dark violet scrim** (`rgba(38,28,52,0.46)`) carrying white text, because the mock-up's pale tint measures **2.6:1** for white text over the chandelier bokeh. |
| **Logo** | New `logo-light.svg` (white wordmark). The standard blue wordmark scores **1.4:1** on dark glass. |
| **Sizing (refinement)** | Card reduced **~10% on both axes** (490x590 → 441x531 at 1440px), scaled proportionally - aspect ratio moved only 1.204 → 1.206. |
| **Scrollbar (refinement)** | `.auth-body`'s native scrollbar replaced with a frosted one - webkit pseudo-elements + `scrollbar-color`/`scrollbar-width`, plus `scrollbar-gutter: stable`. |

**Three latent robustness bugs found and fixed while verifying:**

1. The card used the shared **`.fade-in`** class - `opacity: 0` until app.js's
   IntersectionObserver adds `.visible`. On a page whose only content is that card, a
   missed observer means a blank background. Replaced with a **transform-only**
   `authCardIn` keyframe that never touches opacity.
2. `.auth-view.active` animated opacity the same way (inherited from the original page) -
   the entire form could render invisible. Same fix.
3. `width: 34%` resolved against `.auth-shell`'s content box, not the viewport, making the
   card ~4% narrower than intended. Now `34vw`. The tablet rule had the same defect.

- **Files changed:** `signin.html` (only). **Added:** `images/login-bg-mobile.jpg` (228KB),
  `logo-light.svg`. **Removed:** `images/login-bg-blur.jpg` (v1.3-only, now unreferenced).
  `styles.css` and every other page **untouched**.
- **Sections updated:** §4, §5.9 (rewritten), §12, §15 (L24, L25), §17 (rules 16-19), §18
- **Verified by measurement:**
  - Auth logic untouched - tab switching, Customer/Business toggle, `handleSignIn()`,
    both credential constants and redirects all unchanged
  - Customer login → `customer-dashboard.html`; supplier → `supplier-dashboard.html`; wrong
    credentials → error, **no session, no navigation**; unauthenticated dashboard access →
    bounced to `signin.html`; `?mode=register` deep link works; Customer is the default
  - Geometry within **0.3% of the desktop reference** and **0.2% of the mobile reference**
  - **Zero horizontal overflow** at 1920 / 1440 / 1280 / 1024 / 900 / 768 / 390 / 360 and
    740x380 landscape, in both the Sign In and the tall Business Register view
  - Contrast, sampled from composited pixels: white text **6.1:1**, labels 5.6, tabs and
    placeholder 4.7, legal note 4.9 - **all above WCAG AA**
  - All controls **≥44px**; custom scrollbar active (10px vs the browser's 15px default);
    **0px layout shift** between the scrolling and non-scrolling views
- **Not verified:** no screenshot and no physical device test - see L24. The build
  environment's renderer does not composite, so screenshots, CSS animations, scrolling and
  IntersectionObserver are all inert there (confirmed against `faq.html` as a control).
  **The rendered result has not been seen.**

---

### Version 1.3 - 2026-07-18
**Sign In / Register page redesigned - immersive split screen with a glass panel.**

Replaced the centred card on a flat grey field with a full-viewport two-column layout:
a photographic hero on the left (62%) and a frosted-glass authentication panel on the
right (38%). Presentation only - **no authentication logic was touched.**

| Area | Change |
|---|---|
| **Layout** | New `.auth-split` grid; hero 62% / panel 38%, narrowing to 52/48 on tablet and stacking below 860px |
| **Hero** | Photograph + directional dark scrim + headline, subtitle and three gold-icon proof points. No logo (it stays on the card) |
| **Glass** | `.auth-card` - `rgba(255,255,255,0.86)` + `blur(28px) saturate(170%)`, light-catching border, deep shadow, `--radius-3xl`, with an `@supports` opaque fallback |
| **Assets** | Source PNG (2.0MB) converted to `login-bg.jpg` (228KB, **-89%**) + a 5KB pre-blurred companion; both loaded by **relative path**; hero `preload`ed |
| **Mobile** | Photo becomes a fixed full-screen backdrop; card overlays it at 0.92 opacity with safe-area padding |

- **Files changed:** `signin.html` (only). **Added:** `images/login-bg.jpg`,
  `images/login-bg-blur.jpg`. `styles.css` and all other pages **untouched** - confirmed by
  diffing every shared asset against the deployed copy, so cross-page regression risk is nil.
- **Sections updated:** §4 (assets), §5.9 (rewritten), §12 (new class table), §13
  (breakpoint), §15 (L23, L24), §17 (AI rules 16-17), §18
- **Verified by measurement:**
  - Auth `<script>` block **byte-for-byte identical** to the deployed version
  - Customer login → `customer-dashboard.html` with a valid `customer` session; supplier
    login → `supplier-dashboard.html` with a `supplier` session
  - Wrong credentials → error shown, **no session written, no navigation**
  - Unauthenticated `customer-dashboard.html` → redirected to `signin.html` (guard intact)
  - Tab switching, Customer/Business toggle and HTML5 `required` validation all still work
  - **Zero horizontal overflow** at 1440 / 1280 / 1024 / 768 / 390 / 360px
  - Hero and card **never overlap**; card always fully inside the viewport
  - Contrast: hero headline **10.1:1**, subtitle 12.3:1, proof points 8.5:1, card body text
    **11.6:1** - all above WCAG AA, most above AAA (sampled from composited pixels)
  - All touch targets ≥44px, all text inputs ≥16px (one defect found and fixed: the
    Customer/Business toggle measured 41px)
  - Chat widget still renders and does not collide with the card
- **Not verified:** no screenshot - capture timed out in the build environment; and no
  physical device test. See L24.

---

### Version 1.2 - 2026-07-18
**Platform-wide mobile responsiveness audit and fixes.**

Audited all 13 pages by measuring the live DOM at mobile widths, then fixed what was measured
(not what was assumed). Eight real defects found:

| # | Defect | Fix |
|---|---|---|
| 1 | **`faq.html` scrolled sideways 968px** - the chip row was a grid child with `min-width: auto`, so `1fr` resolved to 1316px and the page widened to 1349px. This also pushed the chat FAB off-screen (fixed elements anchor to the widened containing block). | `minmax(0, 1fr)` + `min-width: 0` on the grid children |
| 2 | **Hamburger was 24px tall** - the primary mobile nav control | 44x44 flex box |
| 3 | **Dashboard tables clipped** - 7-8 columns squeezed into a 309px box (columns wanted 1102px) | `.card-flat { overflow-x: auto }` + `.data-table { width: max-content; min-width: 100% }` |
| 4 | **`input[type=text]` was 13.5px** - iOS Safari zooms the page on focus below 16px | 16px on all text inputs at ≤768px |
| 5 | **Footer/breadcrumb links 17px tall** (14 per page) | `min-height: 44px`, inline-flex centred |
| 6 | **Chat controls 29-39px**; panel used `vh` (breaks when the keyboard opens); no notch insets | 44px controls, 16px input, `min(78dvh, 620px)`, `env(safe-area-inset-*)` |
| 7 | **Radio/checkbox labels** could fall under 44px | `min-height: 44px` on `.seg-radio`, `.radio-group`, `.style-grid` labels |
| 8 | **File input 21px tall** on `help.html` | `min-height: 44px`, full width |

Also added: landscape-phone handling (static navbar on short viewports), `prefers-reduced-motion`
support, `-webkit-text-size-adjust`, `img/svg/video { max-width: 100% }`, and momentum scrolling.

- **Files changed:** `styles.css` (new §14, ~160 lines, appended so it wins the cascade),
  `chatbot.js` (mobile media queries), `faq.html` (grid fix), `help.html` (file input, full-width
  CTA), all 13 HTML files (asset version bumps)
- **Asset versions:** `styles.css?v=11 → v=14`, `chatbot.js?v=6 → v=8`
- **Sections updated:** §3 (versions), §5 (page asset line), §12 (new responsive-utilities table),
  §13 (rewritten responsive behaviour + principles + browser support), §11 (B28), §15 (L21, L22),
  §17 (AI rule 16)
- **Verified:** zero horizontal overflow on all 11 public pages at 360 / 768px (and dashboards at
  360 / 414 / 768 / 834px); dashboard tables scroll inside their cards; search filter drawer,
  filtering, and mobile menu all still work; **desktop at 1280px unchanged** - multi-column
  layouts intact, hamburger hidden, footer links back to 17px (mobile padding correctly scoped);
  zero console errors
- **Not verified:** no physical iOS/Android device testing - see L21

---

### Version 1.1 - 2026-07-18
**Added the Help Centre - a dedicated support/complaint channel, separate from the FAQ.**

- **New page `help.html`** - support-request and complaint workflows for both customers and
  suppliers: type selection, dynamic category list, full contact form, attachment UI,
  client-side validation, and a confirmation panel with a generated reference
  (`SUP-`/`CMP-YYYY-NNNN`)
- **Navigation:** footer "Help Centre" now -> `help.html` (was `faq.html`) on every page with a
  Support column (index, provider, faq, help); "FAQ" still -> `faq.html`
- **Two-way FAQ <-> Help Centre linking:** the FAQ's "Still need help?" CTA now reads
  "Still need help? Contact Support" -> `help.html`; `help.html` links back via "Browse FAQs"
- **Mobile menu:** added a Help Centre entry alongside FAQ
- **Business rules added:** B25 (FAQ vs Help Centre separation), B26 (never expose internal
  prioritisation logic), B27 (do not imply live chat / ticket tracking / real uploads)
- **Bug found and fixed during testing:** the request-type and role radios sit outside
  `<form>`, so `form.reset()` left the previous type selected after "Submit another request" -
  now reset explicitly
- Sections updated: §3 (page count), §4 (folder structure), §5 (new 5.8b, FAQ note),
  §6 (navigation), §10 (new 10.7b), §11 (B25-B27), §15 (L20), §16 (roadmap)
- **Verified in browser:** dynamic category swap, both submit flows, validation blocking,
  reset behaviour, mobile stacking with no horizontal overflow, two-way links, zero console
  errors. **Not verified:** nothing is persisted - by design (L20)

---

### Version 1.0 - 2026-07-17
**Initial documentation.** Captures the prototype as built, verified against the code on this date.

Project state at v1.0:
- 12 HTML pages, 1 stylesheet, 3 front-end JS files, 1 serverless function
- Phase 1 scope: Corporate + Institutional live; Weddings "Coming Soon"; Birthdays removed
- 7 confirmed vendors (4 hotels, 3 event firms)
- Client-side auth with role-gated dashboards; auth bypass removed
- FAQ Help Centre with 50 Q&As
- AI assistant: 50-intent offline engine + Gemini-backed `/api/chat` with automatic fallback,
  verified live in production
- Em-dashes replaced with hyphens across the whole prototype
- Deployed on Vercel from GitHub

Documentation setup:
- `PROJECT_HANDOUT.md` created in the local project root (master copy)
- Identical copy placed in `prototype/` so it reaches the GitHub repo root and is visible
  to collaborators and AI assistants working from the repo
- Both copies must be updated together - see the layout note at the top and AI rule #19

---

#### Template for future entries

```
### Version X.Y - YYYY-MM-DD
**Summary of the change.**

- What changed (file-level detail)
- Why
- Sections of this document updated
- What was verified, and what was not
```

---

> **This document is part of the codebase.** Update it in the same change as the code.
> Documentation that lies is worse than no documentation.
