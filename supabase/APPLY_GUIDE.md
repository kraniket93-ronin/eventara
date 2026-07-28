# Eventara Supabase Backend - Apply & Connect Guide

This backend is delivered as **versioned SQL migrations + front-end integration code**. Applying it takes ~10 minutes. Nothing here runs against your project automatically - you apply it, so you stay in control.

> Why migrations and not a live click-through? A Supabase connector was not available in this session, so I could not execute DDL against your project directly. What you have instead is the *same artifact a production team ships* - idempotent migrations you apply via the SQL editor or the Supabase CLI. This is the correct, reviewable way to build a backend.

---

## Part A - Apply the database (pick ONE method)

### Method 1: Supabase SQL Editor (no tools, fastest)
Open your project > **SQL Editor** and run each file **in order**, top to bottom:

1. `migrations/0001_schema.sql` - tables, keys, constraints, indexes
2. `migrations/0002_rls.sql` - Row-Level Security + policies
3. `migrations/0003_functions.sql` - RPC functions
4. `migrations/0004_triggers.sql` - triggers (incl. auth.users -> profiles)
5. `migrations/0005_views.sql` - dashboard/analytics views
6. `migrations/0006_storage.sql` - storage buckets + policies
7. `migrations/0007_seed.sql` - demo data (Paandora Grand, Secure Meters, etc.)

Each file is safe to re-run (idempotent guards throughout).

### Method 2: Supabase CLI (repeatable, recommended for teams)
```bash
npm i -g supabase
supabase login
supabase link --project-ref <your-project-ref>
supabase db push          # applies everything in supabase/migrations in order
```

---

## Part B - Configure Authentication (dashboard, 2 minutes)

**Authentication > Providers > Email:** enable **Email** with **password** sign-in.

**Authentication > Settings:**
- **Confirm email**: ON for production (OFF while testing so you can log in immediately).
- **Secure email change / password recovery**: leave defaults ON.
- **Site URL / Redirect URLs**: add your Vercel URL and `http://localhost:8791` (for local) so password-reset and magic links return correctly.
- **JWT expiry**: 3600s access token (default); refresh tokens rotate automatically.

Roles: a user's role (`customer` / `supplier` / `admin`) is set from **signup metadata** and stored in `public.profiles` by the `handle_new_user` trigger. RLS reads it via `public.current_role()`.

The seed creates three demo logins (password `udaipur@2026`):
| Email | Role |
|---|---|
| `customer@eventara.in` | customer (Secure Meters Ltd) |
| `hotel@eventara.in` | supplier (Paandora Grand Udaipur) |
| `ops@eventara.in` | admin |

> If your project rejects the direct `auth.users` seed (varies by Supabase version), create those three users under **Authentication > Users** with the same emails, copy their UUIDs over the fixed IDs at the top of `0007_seed.sql`, and re-run from the `MARKETPLACE` section.

---

## Part C - Connect the front-end (3 steps)

**1. Fill your keys.** Edit `prototype/supabase-config.js`:
```js
window.EVENTARA_SUPABASE = {
  url:     "https://YOURPROJECT.supabase.co",   // Settings > API > Project URL
  anonKey: "eyJhbGciOi..."                       // Settings > API > anon public key
};
```
The anon key is **public by design** - RLS is the real protection.

**2. Add the scripts** to every page's `<head>` (or the shared layout), in this order, and **replace `auth.js` with `auth-supabase.js`**:
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script src="supabase-config.js"></script>
<script src="supabase-client.js"></script>
<script src="auth-supabase.js"></script>   <!-- was: auth.js -->
<script src="data-api.js"></script>
```
Until the keys are filled, the site keeps running in **offline demo mode** - nothing breaks.

**3. Point the sign-in form at real auth.** In `signin.html`, change the handler to:
```js
async function handleSignIn(e) {
  e.preventDefault();
  const { error } = await Auth.signIn(signinEmail.value, signinPassword.value);
  if (error) showError(error.message);   // Auth.signIn redirects on success
}
```
And the Register forms to `Auth.signUp(email, password, 'customer'|'supplier', { full_name, org_name })`.

Then bind live data where pages currently hard-code it, e.g. the supplier enquiries table:
```js
const { data } = await EventaraAPI.enquiries();
renderEnquiryRows(data);           // reuse the existing markup/CSS
```
`data-api.js` exposes: `searchSuppliers`, `supplierStats`/`customerStats`, `myBookings`/`supplierBookings`, `pendingQuotes`, `myRequests`, `enquiries`, `buildQuote`, `acceptQuote`, `releaseEscrow`, `generateInvoice`, `availability`/`setAvailability`, `addReview`, `notifications`/`markRead`/`markAllRead`/`subscribeNotifications`, `disputes`/`raiseDispute`, `saveSupplierProfile`/`saveCustomerProfile`/`savePreferences`.

---

## Part D - Environment variables

**Front-end (public, safe in the browser):**
| Variable | Where | Description |
|---|---|---|
| Supabase URL | `supabase-config.js` | Project API URL |
| Supabase anon key | `supabase-config.js` | Public key; RLS-protected |

**Vercel serverless functions (SECRET - set in Vercel > Settings > Environment Variables, never in the repo):**
| Variable | Description |
|---|---|
| `SUPABASE_URL` | Same project URL (server side) |
| `SUPABASE_SERVICE_ROLE_KEY` | **Service role key** - bypasses RLS; server-only, never shipped to the browser |
| `GEMINI_API_KEY` | Existing chatbot key (rotate it - the repo was public) |
| `RZP_KEY` / `RZP_SECRET` | Razorpay (payments/escrow) when wired |
| `RESEND_API_KEY` | Transactional email |
| `WHATSAPP_TOKEN` / `WHATSAPP_PHONE_ID` | WhatsApp Cloud API |

---

## Part E - Verify it works (test checklist)

Run these in the SQL editor / app after applying:
- [ ] `select count(*) from suppliers;` returns >= 1 (seed applied)
- [ ] Log in as `hotel@eventara.in` -> lands on `supplier-dashboard.html`
- [ ] Log in as `customer@eventara.in` -> lands on `customer-dashboard.html`
- [ ] As the customer, `select * from bookings;` returns only that customer's rows (RLS working)
- [ ] As the supplier, the same query returns only their business's rows
- [ ] `select public.customer_dashboard_stats('22222222-2222-2222-2222-222222222222');` returns real counts
- [ ] Insert a review only succeeds for a **completed** booking you own (RLS + check)
- [ ] `select * from v_notification_feed;` shows unread-first notifications
- [ ] Foreign keys hold: `delete from suppliers where id='44444444-...'` cascades cleanly (or is blocked by RLS)

---

## Part F - Deploy

The front-end already deploys on Vercel. After connecting:
1. Commit the new files (`supabase/`, `supabase-config.js` **without** real keys if the repo is public - use Vercel env or a build-time inject instead, `supabase-client.js`, `data-api.js`, `auth-supabase.js`).
2. Set the **secret** env vars in Vercel (Part D).
3. Redeploy. Supabase is a managed service - no separate backend deploy needed; your serverless functions live in `prototype/api/`.

> **Security note:** make the GitHub repo **private** and **rotate the Gemini key** immediately - it was committed to a public repo. Keep the service-role key only in Vercel env, never in any `.js` shipped to the browser.
