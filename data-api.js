/* ============================================================
   Eventara - Data API (replaces all mock/hard-coded data)
   ------------------------------------------------------------
   Thin wrapper over Supabase queries + RPCs. Every call returns
   { data, error }. Pages bind these to the existing markup, so
   no page has to hard-code rows any more.

   Requires window.sb (see supabase-client.js). When offline
   (window.sb == null) each method returns a clear error so the
   caller can keep the existing demo content as a fallback.
   ============================================================ */
(function () {
  function guard() {
    if (!window.sb) return { data: null, error: { message: "offline: Supabase not configured" } };
    return null;
  }

  // Current user's profile id. Every dashboard write needs it, so it lives
  // here once rather than being re-derived with an inline getSession() in
  // each method (the pattern the pre-dashboard methods used).
  async function uid() {
    const { data } = await sb.auth.getSession();
    return data && data.session ? data.session.user.id : null;
  }

  // The suppliers row the signed-in supplier owns. Cached per page load -
  // almost every supplier-dashboard call needs it, and it never changes
  // mid-session.
  let _mySupplier = null;
  async function mySupplierId() {
    if (_mySupplier) return _mySupplier;
    const id = await uid(); if (!id) return null;
    const { data } = await sb.from("suppliers").select("id").eq("owner", id).maybeSingle();
    _mySupplier = data ? data.id : null;
    return _mySupplier;
  }

  const API = {
    // ---------- Discovery ----------
    async searchSuppliers({ city = "Udaipur", minCapacity = null, maxPrice = null, date = null } = {}) {
      const g = guard(); if (g) return g;
      return sb.rpc("search_suppliers", {
        p_city: city, p_min_capacity: minCapacity, p_max_price: maxPrice, p_date: date
      });
    },
    async supplierCard(id) {
      const g = guard(); if (g) return g;
      return sb.from("v_supplier_public").select("*").eq("id", id).single();
    },

    // ---------- Supplier detail ----------
    async getSupplierDetail(idOrSlug) {
      const g = guard(); if (g) return g;
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idOrSlug || "");
      const col = isUuid ? "id" : "slug";
      // Single round-trip via PostgREST nested embedding - no N+1 queries.
      // reviews(*) naturally returns only published rows for anonymous
      // visitors because reviews_public_read RLS already filters on
      // status='published'; no extra .eq() needed here.
      return sb.from("suppliers")
        .select(`*, supplier_profiles(*), venues(*, venue_images(*)),
                  supplier_media(*), supplier_services(*), supplier_packages(*),
                  supplier_faqs(*), reviews(*)`)
        .eq(col, idOrSlug)
        .eq("status", "active")
        .order("sort", { foreignTable: "supplier_media" })
        .order("sort", { foreignTable: "supplier_packages" })
        .order("sort", { foreignTable: "supplier_faqs" })
        .order("created_at", { foreignTable: "reviews", ascending: false })
        .single();
    },
    async getSimilarSuppliers(supplierId, limit = 3) {
      const g = guard(); if (g) return g;
      // Ranking (same city/category first, then verified/featured, then
      // closest rating/price) is computed server-side in one query - see
      // get_similar_suppliers() in 0012_similar_suppliers_recommendations.sql.
      return sb.rpc("get_similar_suppliers", { p_supplier_id: supplierId, p_limit: limit });
    },

    // ---------- Dashboards (stats via RPC, lists via views) ----------
    async supplierStats(supplierId)  { const g=guard(); if(g)return g; return sb.rpc("supplier_dashboard_stats",{ p_supplier: supplierId }); },
    async customerStats(customerId)  { const g=guard(); if(g)return g; return sb.rpc("customer_dashboard_stats",{ p_customer: customerId }); },
    async myBookings()               { const g=guard(); if(g)return g; return sb.from("v_customer_dashboard").select("*").order("event_date"); },
    async supplierBookings()         { const g=guard(); if(g)return g; return sb.from("v_supplier_dashboard").select("*").order("event_date"); },
    async pendingQuotes()            { const g=guard(); if(g)return g; return sb.from("v_pending_quotes").select("*"); },
    async revenue(supplierId)        { const g=guard(); if(g)return g; return sb.from("v_revenue_summary").select("*").eq("supplier_id", supplierId).single(); },

    // ---------- Briefs / requests / quotes ----------
    async createRequest(payload) {   // the "Get Quotes" brief form
      const g = guard(); if (g) return g;
      const { data: s } = await sb.auth.getSession();
      return sb.from("event_requests").insert({ customer_id: s.session.user.id, ...payload }).select().single();
    },
    async myRequests()   { const g=guard(); if(g)return g; return sb.from("event_requests").select("*, quotes(*)").order("created_at",{ascending:false}); },
    async enquiries()    { const g=guard(); if(g)return g; return sb.from("quotes").select("*, event_requests(*)").order("created_at",{ascending:false}); },
    async buildQuote(requestId, supplierId, lineItems, notes) {
      const g = guard(); if (g) return g;
      const subtotal = lineItems.reduce((a, l) => a + (l.amount || 0), 0);
      const tax = Math.round(subtotal * 0.18);
      const { data: q, error } = await sb.from("quotes")
        .insert({ request_id: requestId, supplier_id: supplierId, status: "submitted",
                  subtotal, tax, total: subtotal + tax, notes }).select().single();
      if (error) return { data: null, error };
      await sb.from("quote_line_items").insert(lineItems.map((l, i) => ({ quote_id: q.id, ...l, sort: i })));
      return { data: q, error: null };
    },
    async acceptQuote(quoteId) { const g=guard(); if(g)return g; return sb.rpc("create_booking", { p_quote: quoteId, p_deposit_pct: 30 }); },
    async rejectQuote(quoteId) { const g=guard(); if(g)return g; return sb.rpc("reject_quote", { p_quote: quoteId }); },

    // ---------- Bookings / money ----------
    async releaseEscrow(bookingId) { const g=guard(); if(g)return g; return sb.rpc("release_escrow", { p_booking: bookingId }); },
    async cancelBooking(bookingId, reason) { const g=guard(); if(g)return g; return sb.rpc("cancel_booking", { p_booking: bookingId, p_reason: reason }); },
    async generateInvoice(bookingId, type) { const g=guard(); if(g)return g; return sb.rpc("generate_invoice", { p_booking: bookingId, p_type: type }); },
    async invoices()   { const g=guard(); if(g)return g; return sb.from("invoices").select("*").order("issued_at",{ascending:false}); },

    // ---------- Calendar / availability ----------
    async availability(supplierId, fromDay, toDay) {
      const g = guard(); if (g) return g;
      return sb.from("availability").select("*").eq("supplier_id", supplierId).gte("day", fromDay).lte("day", toDay);
    },
    async setAvailability(supplierId, day, state, note) {
      const g = guard(); if (g) return g;
      return sb.rpc("update_availability", { p_supplier: supplierId, p_day: day, p_state: state, p_note: note || null });
    },

    // ---------- Reviews ----------
    async addReview(bookingId, supplierId, rating, title, comment) {
      const g = guard(); if (g) return g;
      const { data: s } = await sb.auth.getSession();
      return sb.from("reviews").insert({ booking_id: bookingId, supplier_id: supplierId,
        customer_id: s.session.user.id, rating, title, comment }).select().single();
    },
    async supplierReviews(supplierId) { const g=guard(); if(g)return g; return sb.from("reviews").select("*").eq("supplier_id", supplierId).eq("status","published").order("created_at",{ascending:false}); },

    // ---------- Notifications (live via view; realtime optional) ----------
    async notifications() { const g=guard(); if(g)return g; return sb.from("v_notification_feed").select("*").limit(30); },
    async markRead(id)    { const g=guard(); if(g)return g; return sb.from("notifications").update({ read: true }).eq("id", id); },
    async markAllRead()   { const g=guard(); if(g)return g; return sb.from("notifications").update({ read: true }).eq("read", false); },
    subscribeNotifications(cb) {                    // Supabase Realtime push
      if (!window.sb) return null;
      return sb.channel("notif").on("postgres_changes",
        { event: "INSERT", schema: "public", table: "notifications" }, cb).subscribe();
    },

    // ---------- Disputes ----------
    async disputes() { const g=guard(); if(g)return g; return sb.from("v_disputes_overview").select("*").order("created_at",{ascending:false}); },
    async raiseDispute(bookingId, against, kind, priority, summary) {
      const g = guard(); if (g) return g;
      const { data: s } = await sb.auth.getSession();
      return sb.from("disputes").insert({ booking_id: bookingId, raised_by: s.session.user.id,
        against, kind, priority, summary }).select().single();
    },

    // ---------- Profile / settings (real persistence) ----------
    async saveSupplierProfile(supplierId, fields) { const g=guard(); if(g)return g; return sb.from("suppliers").update(fields).eq("id", supplierId); },
    async saveCustomerProfile(fields) {
      const g = guard(); if (g) return g;
      const { data: s } = await sb.auth.getSession();
      return sb.from("customer_profiles").upsert({ profile_id: s.session.user.id, ...fields });
    },
    async savePreferences(prefs) {
      const g = guard(); if (g) return g;
      const { data: s } = await sb.auth.getSession();
      return sb.from("user_preferences").upsert({ profile_id: s.session.user.id, ...prefs });
    },

    /* ==========================================================
       DASHBOARD SERVICES  [added v2.8]
       Everything below backs the customer/supplier dashboards.
       All writes are RLS-scoped: a customer can only ever touch
       rows keyed to their own auth.uid(), a supplier only rows
       tied to the suppliers row they own. Nothing here trusts a
       client-supplied owner id.
       ========================================================== */

    // ---------- Identity ----------
    async me() {
      const g = guard(); if (g) return g;
      const id = await uid();
      if (!id) return { data: null, error: { message: "not signed in" } };
      return sb.from("profiles")
        .select("*, customer_profiles(*), user_preferences(*)")
        .eq("id", id).single();
    },
    async mySupplier() {
      const g = guard(); if (g) return g;
      const id = await uid();
      if (!id) return { data: null, error: { message: "not signed in" } };
      return sb.from("suppliers")
        .select("*, supplier_profiles(*), supplier_services(*), supplier_packages(*), supplier_faqs(*), supplier_media(*)")
        .eq("owner", id).maybeSingle();
    },

    // ---------- Customer: profile + password ----------
    // Split across two tables (profiles = identity, customer_profiles =
    // billing/org), so both are written in one call and the caller doesn't
    // need to know the schema split.
    async updateMyProfile({ full_name, phone, city, avatar_url, org_name, gstin, billing_address, finance_email, buyer, industry } = {}) {
      const g = guard(); if (g) return g;
      const id = await uid(); if (!id) return { data: null, error: { message: "not signed in" } };
      const base = {}; if (full_name !== undefined) base.full_name = full_name;
      if (phone !== undefined) base.phone = phone; if (city !== undefined) base.city = city;
      if (avatar_url !== undefined) base.avatar_url = avatar_url;
      if (Object.keys(base).length) {
        const r = await sb.from("profiles").update(base).eq("id", id);
        if (r.error) return r;
      }
      const cust = {}; if (org_name !== undefined) cust.org_name = org_name;
      if (gstin !== undefined) cust.gstin = gstin; if (billing_address !== undefined) cust.billing_address = billing_address;
      if (finance_email !== undefined) cust.finance_email = finance_email;
      if (buyer !== undefined) cust.buyer = buyer; if (industry !== undefined) cust.industry = industry;
      if (Object.keys(cust).length) {
        const r = await sb.from("customer_profiles").upsert({ profile_id: id, ...cust });
        if (r.error) return r;
      }
      return this.me();
    },
    // Supabase has no "verify current password" endpoint, so re-authenticate
    // with it first - that both proves the user knows it and fails cleanly if
    // they don't, instead of silently letting a hijacked session change it.
    async changePassword(currentPassword, newPassword) {
      const g = guard(); if (g) return g;
      const { data: s } = await sb.auth.getSession();
      const email = s && s.session ? s.session.user.email : null;
      if (!email) return { data: null, error: { message: "not signed in" } };
      if (!newPassword || newPassword.length < 8) {
        return { data: null, error: { message: "New password must be at least 8 characters." } };
      }
      const check = await sb.auth.signInWithPassword({ email, password: currentPassword });
      if (check.error) return { data: null, error: { message: "Current password is incorrect." } };
      return sb.auth.updateUser({ password: newPassword });
    },

    // ---------- Customer: requests ----------
    async myRequestsFull() {
      const g = guard(); if (g) return g;
      return sb.from("event_requests")
        .select("*, quotes(*, suppliers(id, slug, business_name, rating, review_count))")
        .order("created_at", { ascending: false });
    },
    async updateRequest(id, fields) {
      const g = guard(); if (g) return g;
      return sb.from("event_requests").update(fields).eq("id", id).select().single();
    },
    async cancelRequest(id)  { return this.updateRequest(id, { status: "cancelled" }); },
    async archiveRequest(id) { return this.updateRequest(id, { status: "expired" }); },

    // ---------- Customer: saved suppliers (real table, not localStorage) ----------
    async savedSuppliers() {
      const g = guard(); if (g) return g;
      return sb.from("saved_suppliers")
        .select("created_at, suppliers(id, slug, business_name, category, city, rating, review_count, verified, tagline)")
        .order("created_at", { ascending: false });
    },
    async saveSupplier(supplierId) {
      const g = guard(); if (g) return g;
      const id = await uid(); if (!id) return { data: null, error: { message: "not signed in" } };
      return sb.from("saved_suppliers").upsert({ customer_id: id, supplier_id: supplierId });
    },
    async unsaveSupplier(supplierId) {
      const g = guard(); if (g) return g;
      const id = await uid(); if (!id) return { data: null, error: { message: "not signed in" } };
      return sb.from("saved_suppliers").delete().eq("customer_id", id).eq("supplier_id", supplierId);
    },
    async isSupplierSaved(supplierId) {
      const g = guard(); if (g) return g;
      const id = await uid(); if (!id) return { data: false, error: null };
      const r = await sb.from("saved_suppliers").select("supplier_id")
        .eq("customer_id", id).eq("supplier_id", supplierId).maybeSingle();
      return { data: !!r.data, error: r.error };
    },

    // ---------- Bookings (both roles) + timeline ----------
    // Status + timeline entry + counterparty notification happen together
    // server-side (see 0015). Transitions are validated there, so an illegal
    // jump is rejected by Postgres rather than trusted from the client.
    async setBookingStatus(bookingId, toStatus, note) {
      const g = guard(); if (g) return g;
      return sb.rpc("set_booking_status", { p_booking: bookingId, p_to: toStatus, p_note: note || null });
    },
    async bookingTimeline(bookingId) {
      const g = guard(); if (g) return g;
      return sb.from("booking_events").select("*").eq("booking_id", bookingId)
        .order("created_at", { ascending: false });
    },

    // ---------- Supplier: business profile ----------
    // Writes suppliers + supplier_profiles together. Because every public
    // surface (search.html, supplier.html, Similar Suppliers, booking pages)
    // reads these same rows through v_supplier_public / getSupplierDetail,
    // one write here propagates everywhere with no extra sync step.
    async updateMySupplier(supplierFields = {}, profileFields = {}) {
      const g = guard(); if (g) return g;
      const sid = await mySupplierId();
      if (!sid) return { data: null, error: { message: "no supplier owned by this account" } };
      if (Object.keys(supplierFields).length) {
        const r = await sb.from("suppliers").update(supplierFields).eq("id", sid);
        if (r.error) return r;
      }
      if (Object.keys(profileFields).length) {
        const r = await sb.from("supplier_profiles").upsert({ supplier_id: sid, ...profileFields });
        if (r.error) return r;
      }
      return this.mySupplier();
    },

    // Read-only for the supplier: these fields underpin the Verified badge,
    // so they are surfaced but not self-service editable (see §11 B16).
    async myKyc() {
      const g = guard(); if (g) return g;
      const sid = await mySupplierId();
      if (!sid) return { data: null, error: { message: "no supplier owned by this account" } };
      return sb.from("kyc_verification").select("*").eq("supplier_id", sid).maybeSingle();
    },
    // Payout account, for display on the Settings panel. Read-only by design:
    // changing where money lands needs a verification round trip, so the UI
    // shows the account on file and routes edits through Eventara Ops.
    async myBankAccount() {
      const g = guard(); if (g) return g;
      const sid = await mySupplierId();
      if (!sid) return { data: null, error: { message: "no supplier owned by this account" } };
      return sb.from("bank_accounts").select("*").eq("supplier_id", sid)
        .order("is_primary", { ascending: false }).limit(1).maybeSingle();
    },

    // ---------- Supplier: availability calendar ----------
    // Range read for the month grid. Days with no row are implicitly 'open'.
    async myAvailability(fromDay, toDay) {
      const g = guard(); if (g) return g;
      const sid = await mySupplierId();
      if (!sid) return { data: null, error: { message: "no supplier owned by this account" } };
      return sb.from("availability").select("*")
        .eq("supplier_id", sid).gte("day", fromDay).lte("day", toDay).order("day");
    },
    // Single day. Goes through the existing update_availability RPC, which
    // re-checks ownership server-side (SECURITY DEFINER) rather than trusting
    // the caller.
    async setMyDay(day, state, note) {
      const g = guard(); if (g) return g;
      const sid = await mySupplierId();
      if (!sid) return { data: null, error: { message: "no supplier owned by this account" } };
      return sb.rpc("update_availability", { p_supplier: sid, p_day: day, p_state: state, p_note: note || null });
    },
    // Bulk (drag-select a range, block a holiday week, etc). Sequential on
    // purpose: update_availability is the only path that enforces ownership,
    // and a handful of days is not worth a bespoke bulk RPC.
    async setMyDays(days, state, note) {
      const g = guard(); if (g) return g;
      for (const d of days) {
        const r = await this.setMyDay(d, state, note);
        if (r.error) return r;
      }
      return { data: { updated: days.length }, error: null };
    },

    // ---------- Supplier: enquiries + quotations ----------
    async myEnquiries() {
      const g = guard(); if (g) return g;
      const sid = await mySupplierId();
      if (!sid) return { data: null, error: { message: "no supplier owned by this account" } };
      return sb.from("quotes")
        .select("*, event_requests(*, profiles(full_name, email, phone))")
        .eq("supplier_id", sid).order("created_at", { ascending: false });
    },
    async updateQuote(quoteId, fields) {
      const g = guard(); if (g) return g;
      return sb.from("quotes").update(fields).eq("id", quoteId).select().single();
    },
    // Status moves go through RPCs (0019) so the rules live in one place:
    // a draft cannot be sent without priced line items, and an accepted
    // quote can never be pulled back out from under the customer.
    async sendQuote(quoteId)     { const g = guard(); if (g) return g; return sb.rpc("submit_quote",   { p_quote_id: quoteId }); },
    async withdrawQuote(quoteId) { const g = guard(); if (g) return g; return sb.rpc("withdraw_quote", { p_quote_id: quoteId }); },

    async quoteLineItems(quoteId) {
      const g = guard(); if (g) return g;
      return sb.from("quote_line_items").select("*").eq("quote_id", quoteId).order("sort");
    },
    // Send descriptions/qty/unit_price only - the database multiplies them out
    // and derives subtotal, tax and total, so the figure the customer is asked
    // to pay can never disagree with the lines it is built from.
    async setQuoteLineItems(quoteId, lineItems, notes, validUntil) {
      const g = guard(); if (g) return g;
      return sb.rpc("save_quote_line_items", {
        p_quote_id: quoteId,
        p_items: lineItems.map(l => ({
          description: l.description, qty: l.qty, unit_price: l.unit_price
        })),
        p_notes: notes || null,
        p_valid_until: validUntil || null
      });
    },

    // ---------- Supplier: gallery (Supabase Storage) ----------
    // Objects go under "<auth.uid()>/..." because that is exactly what the
    // storage object policies in 0006_storage.sql check.
    async uploadSupplierImage(file, category = "gallery", caption = null) {
      const g = guard(); if (g) return g;
      const id = await uid(); const sid = await mySupplierId();
      if (!id || !sid) return { data: null, error: { message: "not signed in as a supplier" } };
      const safe = String(file.name || "image").replace(/[^\w.\-]/g, "_");
      const path = `${id}/${Date.now()}_${safe}`;
      const up = await sb.storage.from("supplier-images").upload(path, file, { upsert: false });
      if (up.error) return up;
      const { data: pub } = sb.storage.from("supplier-images").getPublicUrl(path);
      return sb.from("supplier_media")
        .insert({ supplier_id: sid, category, caption, url: pub.publicUrl })
        .select().single();
    },
    async deleteSupplierImage(mediaId) {
      const g = guard(); if (g) return g;
      return sb.from("supplier_media").delete().eq("id", mediaId);
    },

    // Portfolio assets beyond photos. Each kind has its own bucket (0025) with
    // its own size cap and MIME allow-list, enforced server-side by Storage -
    // so a 400 MB "video" or a renamed .exe is refused by the platform, not
    // just by this function. All land in supplier_media, which is what the
    // public pages read, so an upload is visible the moment it finishes.
    ASSET_KINDS: {
      video:    { bucket: "supplier-videos",    category: "video",    max: 100 * 1024 * 1024,
                  accept: ["video/mp4", "video/webm", "video/quicktime"], label: "video" },
      brochure: { bucket: "brochures",          category: "brochure", max: 20 * 1024 * 1024,
                  accept: ["application/pdf"], label: "brochure" },
      menu:     { bucket: "menus",              category: "menu",     max: 20 * 1024 * 1024,
                  accept: ["application/pdf"], label: "menu" },
      document: { bucket: "supplier-documents", category: "document", max: 20 * 1024 * 1024,
                  accept: ["application/pdf"], label: "document" }
    },

    async uploadSupplierAsset(kind, file, caption = null) {
      const g = guard(); if (g) return g;
      const spec = this.ASSET_KINDS[kind];
      if (!spec) return { data: null, error: { message: `unknown asset kind "${kind}"` } };

      // Checked here so the user gets a sentence rather than a raw 413/415.
      if (file.size > spec.max) {
        return { data: null, error: { message:
          `That ${spec.label} is ${(file.size / 1048576).toFixed(1)} MB. The limit is ${spec.max / 1048576} MB.` } };
      }
      if (spec.accept.indexOf(file.type) === -1) {
        return { data: null, error: { message:
          `A ${spec.label} has to be ${spec.accept.map(t => t.split("/")[1].toUpperCase()).join(" or ")}.` } };
      }

      const id = await uid(); const sid = await mySupplierId();
      if (!id || !sid) return { data: null, error: { message: "not signed in as a supplier" } };

      const safe = String(file.name || spec.label).replace(/[^\w.\-]/g, "_");
      const path = `${id}/${Date.now()}_${safe}`;
      const up = await sb.storage.from(spec.bucket).upload(path, file, { upsert: false });
      if (up.error) return up;
      const { data: pub } = sb.storage.from(spec.bucket).getPublicUrl(path);
      return sb.from("supplier_media")
        .insert({ supplier_id: sid, category: spec.category, caption: caption || file.name, url: pub.publicUrl })
        .select().single();
    },

    async myMedia(category) {
      const g = guard(); if (g) return g;
      const sid = await mySupplierId();
      if (!sid) return { data: null, error: { message: "no supplier owned by this account" } };
      let q = sb.from("supplier_media").select("*").eq("supplier_id", sid).order("sort");
      if (category) q = q.eq("category", category);
      return q;
    },

    // ---------- Onboarding ----------
    // profile_completion() returns a percentage AND the specific fields still
    // missing, so the UI can name them instead of showing a bare number.
    async profileCompletion() { const g = guard(); if (g) return g; return sb.rpc("profile_completion"); },
    async myOnboarding()      { const g = guard(); if (g) return g; return sb.rpc("my_onboarding"); },
    async dismissOnboarding() { const g = guard(); if (g) return g; return sb.rpc("dismiss_onboarding"); },
    // Flips a supplier from 'draft' to 'active'. Refuses (returning the list
    // of what is missing) until the listing is worth showing a customer.
    async publishSupplier()   { const g = guard(); if (g) return g; return sb.rpc("publish_supplier"); },
    async ensureAccountRecords() { const g = guard(); if (g) return g; return sb.rpc("ensure_account_records"); },

    // ---------- Dashboard overview ----------
    // Everything the Overview panel shows, in one round trip, aggregated in
    // the database (0020) rather than counted in the browser.
    async supplierOverview() { const g = guard(); if (g) return g; return sb.rpc("supplier_overview_stats"); },
    async customerOverview() { const g = guard(); if (g) return g; return sb.rpc("customer_overview_stats"); },
    async myPayments()       { const g = guard(); if (g) return g; return sb.rpc("my_payments"); },

    // ---------- Disputes ----------
    // One round trip: cases + nested timeline + counterpart name, already
    // scoped to the signed-in user by get_my_disputes (0018).
    async myDisputes() {
      const g = guard(); if (g) return g;
      return sb.rpc("get_my_disputes");
    },
    // Bookings the signed-in user is actually a party to - the "Raise a
    // dispute" picker, so a case can never be opened against a stranger.
    async disputableBookings() {
      const g = guard(); if (g) return g;
      return sb.rpc("disputable_bookings");
    },
    async raiseDisputeOnBooking(bookingId, kind, priority, summary) {
      const g = guard(); if (g) return g;
      return sb.rpc("raise_dispute", {
        p_booking_id: bookingId, p_kind: kind, p_priority: priority, p_summary: summary
      });
    },
    // action: 'response' | 'evidence' | 'note' | 'withdraw'. The RPC decides
    // any status move and notifies the other side - the client never does.
    async addDisputeEvent(disputeId, action, note) {
      const g = guard(); if (g) return g;
      return sb.rpc("add_dispute_event", {
        p_dispute_id: disputeId, p_action: action, p_note: note || null
      });
    },

    // ---------- Support tickets (real, look-up-able reference) ----------
    async createTicket(fields) {
      const g = guard(); if (g) return g;
      const id = await uid();
      return sb.from("support_tickets").insert({ profile_id: id, ...fields }).select().single();
    },
    async myTickets() {
      const g = guard(); if (g) return g;
      return sb.from("support_tickets").select("*").order("created_at", { ascending: false });
    }
  };

  window.EventaraAPI = API;
})();
