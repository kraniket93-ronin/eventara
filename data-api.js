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
    }
  };

  window.EventaraAPI = API;
})();
