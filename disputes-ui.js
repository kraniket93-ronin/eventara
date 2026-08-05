/* ============================================================
   Eventara - Disputes panel (shared by BOTH dashboards)
   ------------------------------------------------------------
   The customer and supplier disputes panels show the same case
   from opposite sides, so the rendering lives here once instead
   of being copy-pasted into each dashboard. Each page calls
   DisputesUI.mount({ role: 'supplier' | 'customer' }).

   All data comes from the RPCs added in migration 0018:
     get_my_disputes()      cases + nested timeline, one round trip
     disputable_bookings()  bookings you are actually a party to
     raise_dispute()        case + opening event + notification
     add_dispute_event()    timeline entry + status move + notify

   The client never sets a dispute's status - the RPC decides.
   Business rule B19: neither side can unilaterally close a case
   and release the escrowed money; only Eventara Ops resolves.
   ============================================================ */
(function (global) {
  "use strict";

  /* ---------- small helpers (self-contained on purpose) ---------- */
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }
  function fmtDate(d) {
    if (!d) return "-";
    var dt = new Date(d);
    if (isNaN(dt)) return "-";
    return dt.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
  }
  function el(id) { return document.getElementById(id); }

  /* ---------- status vocabulary ---------- */
  // DB status -> label, pill class, and which filter tab it belongs to.
  var STATUS = {
    open:              { label: "Open",                 cls: "status-open",     bucket: "open" },
    waiting_supplier:  { label: "Waiting for Supplier", cls: "status-waiting",  bucket: "open" },
    waiting_customer:  { label: "Waiting for Customer", cls: "status-waiting",  bucket: "open" },
    under_review:      { label: "Under Review",         cls: "status-review",   bucket: "review" },
    resolved:          { label: "Resolved",             cls: "status-resolved", bucket: "resolved" },
    closed:            { label: "Closed",               cls: "status-closed",   bucket: "resolved" }
  };
  function statusOf(s) { return STATUS[s] || { label: s || "-", cls: "status-open", bucket: "open" }; }

  var ACTION_LABEL = {
    raised: "Case raised", response: "Response added", evidence: "Evidence added",
    note: "Note added", withdraw: "Case withdrawn", resolved: "Resolved by Eventara",
    under_review: "Moved to Under Review"
  };

  /* ---------- module state ---------- */
  var cfg = null;      // { role, ids… }
  var cases = [];      // last loaded payload
  var openCaseId = null;

  /* A case is "waiting on me" when its status names my side. That is the
     only signal used to decide whether Respond is the primary action. */
  function waitingOnMe(c) {
    return (cfg.role === "supplier" && c.status === "waiting_supplier") ||
           (cfg.role === "customer" && c.status === "waiting_customer");
  }
  function isClosed(c) { return c.status === "resolved" || c.status === "closed"; }

  /* Describes the case from the reader's point of view. The same row reads
     "Complaint against you" to the supplier and "Complaint you raised" to
     the customer - which is exactly the cross-platform behaviour we want. */
  function typeLabel(c) {
    var kind = c.kind === "dispute" ? "Dispute" : "Complaint";
    return kind + (c.i_raised ? " you raised" : " against you");
  }

  /* ============================================================
     RENDER: table
     ============================================================ */
  function renderTable() {
    var body = el(cfg.bodyId);
    if (!body) return;
    body.innerHTML = "";

    if (!cases.length) {
      var tr = document.createElement("tr");
      var td = document.createElement("td");
      td.colSpan = 7;
      td.className = "caption text-muted";
      td.style.padding = "var(--space-24)";
      td.style.textAlign = "center";
      td.textContent = cfg.role === "supplier"
        ? "No disputes or complaints. Keep it that way."
        : "No disputes. All your bookings are on track.";
      tr.appendChild(td);
      body.appendChild(tr);
      renderCounts();
      return;
    }

    cases.forEach(function (c) {
      var st = statusOf(c.status);
      var tr = document.createElement("tr");
      tr.setAttribute("data-status", st.bucket);
      tr.innerHTML =
        '<td><strong>#' + esc(c.ref) + '</strong></td>' +
        '<td>' + (c.booking_ref ? "#" + esc(c.booking_ref) : '<span class="text-muted">-</span>') + '</td>' +
        '<td>' + esc(typeLabel(c)) +
          '<br><span class="caption text-muted">' + esc(c.summary || "") + '</span></td>' +
        '<td><span class="priority-dot prio-' + esc(c.priority) + '"></span>' +
          esc(c.priority.charAt(0).toUpperCase() + c.priority.slice(1)) + '</td>' +
        '<td><span class="status ' + st.cls + '">' + esc(st.label) + '</span></td>' +
        '<td>' + esc(fmtDate(c.updated_at)) + '</td>';

      var actions = document.createElement("td");
      var view = document.createElement("button");
      view.className = "btn btn-secondary btn-sm";
      view.textContent = isClosed(c) ? "View outcome" : "View timeline";
      view.onclick = function () { openCase(c.id); };

      if (waitingOnMe(c)) {
        var respond = document.createElement("button");
        respond.className = "btn btn-primary btn-sm";
        respond.textContent = "Respond";
        respond.onclick = function () { openCase(c.id, "response"); };
        actions.appendChild(respond);
      }
      actions.appendChild(view);
      tr.appendChild(actions);
      body.appendChild(tr);
    });

    renderCounts();
    reapplyActiveFilter();
  }

  /* Filter tab counts come from the data, never hardcoded. */
  function renderCounts() {
    var tabs = el(cfg.tabsId);
    if (!tabs) return;
    var n = { all: cases.length, open: 0, review: 0, resolved: 0 };
    cases.forEach(function (c) { n[statusOf(c.status).bucket]++; });
    Object.keys(n).forEach(function (k) {
      var span = tabs.querySelector('[data-count="' + k + '"]');
      if (span) span.textContent = n[k];
    });
  }

  /* Re-running the render wipes the rows the active tab had hidden, so the
     current filter has to be re-applied to the freshly built rows. */
  function reapplyActiveFilter() {
    var tabs = el(cfg.tabsId);
    if (!tabs) return;
    var active = tabs.querySelector(".tab-pill.active");
    var want = active ? active.getAttribute("data-filter") : "all";
    var body = el(cfg.bodyId);
    if (!body) return;
    Array.prototype.forEach.call(body.querySelectorAll("tr[data-status]"), function (tr) {
      tr.style.display = (want === "all" || tr.getAttribute("data-status") === want) ? "" : "none";
    });
  }

  /* ============================================================
     RENDER: case detail + timeline
     ============================================================ */
  function openCase(id, focusAction) {
    openCaseId = id;
    var c = cases.filter(function (x) { return x.id === id; })[0];
    var box = el(cfg.detailId);
    if (!c || !box) return;

    var st = statusOf(c.status);
    var events = c.events || [];

    var html =
      '<div class="flex justify-between items-center" style="flex-wrap:wrap; gap:var(--space-8);">' +
        '<h3 style="margin:0;">Case #' + esc(c.ref) + ' - ' + esc(typeLabel(c)) + '</h3>' +
        '<span class="status ' + st.cls + '">' + esc(st.label) + '</span>' +
      '</div>' +
      '<p class="caption text-muted" style="margin:var(--space-8) 0 var(--space-16);">' +
        (c.booking_ref ? "Booking #" + esc(c.booking_ref) + " &middot; " : "") +
        "Other party: " + esc(c.counterpart) + " &middot; Opened " + esc(fmtDate(c.created_at)) +
      '</p>';

    if (c.resolution) {
      html += '<div class="card-flat" style="background:var(--trust-green-light); margin-bottom:var(--space-16);">' +
        '<strong>Outcome</strong><p class="body-sm" style="margin:var(--space-4) 0 0;">' +
        esc(c.resolution) + '</p></div>';
    }

    html += events.map(function (e, i) {
      var last = i === events.length - 1;
      return '<div class="timeline-item' + (last && !isClosed(c) ? "" : " done") + '">' +
        '<span class="t-dot"></span><div class="t-body">' +
        '<strong>' + esc(ACTION_LABEL[e.action] || e.action) + '</strong> - ' + esc(e.actor) +
        (e.mine ? ' <span class="caption">(you)</span>' : "") +
        (e.note ? '<br>' + esc(e.note) : "") +
        '<time>' + esc(fmtDate(e.created_at)) + '</time></div></div>';
    }).join("");

    if (!isClosed(c)) {
      html +=
        '<div class="timeline-item"><span class="t-dot"></span><div class="t-body">' +
          'Resolution decided by Eventara Ops.<time>Pending</time></div></div>' +
        '<div class="input-group" style="margin-top:var(--space-16);">' +
          '<label for="' + cfg.noteId + '">Add to this case</label>' +
          '<textarea id="' + cfg.noteId + '" class="input-field" rows="3" ' +
            'placeholder="Explain what happened, or describe the evidence you are attaching."></textarea>' +
        '</div>' +
        '<div class="flex" style="gap:var(--space-8); flex-wrap:wrap;">' +
          '<button class="btn btn-primary btn-sm" data-disp-act="response">Send response</button>' +
          '<button class="btn btn-secondary btn-sm" data-disp-act="evidence">Add evidence</button>' +
          (c.i_raised ? '<button class="btn btn-secondary btn-sm" data-disp-act="withdraw">Withdraw case</button>' : "") +
          '<button class="btn btn-secondary btn-sm" data-disp-act="close">Close</button>' +
        '</div>' +
        '<p class="caption text-muted" style="margin-top:var(--space-8);">' +
          'Evidence files are uploaded by Eventara Ops on request - this prototype records the ' +
          'written entry only.</p>';
    } else {
      html += '<div class="flex" style="gap:var(--space-8); margin-top:var(--space-16);">' +
        '<button class="btn btn-secondary btn-sm" data-disp-act="close">Close</button></div>';
    }

    box.innerHTML = html;
    box.hidden = false;

    Array.prototype.forEach.call(box.querySelectorAll("[data-disp-act]"), function (b) {
      b.onclick = function () { doAction(c, b.getAttribute("data-disp-act"), b); };
    });

    box.scrollIntoView({ behavior: "smooth", block: "nearest" });
    if (focusAction && el(cfg.noteId)) el(cfg.noteId).focus();
  }

  /* ============================================================
     ACTIONS
     ============================================================ */
  async function doAction(c, action, btn) {
    var box = el(cfg.detailId);
    if (action === "close") { if (box) { box.hidden = true; } openCaseId = null; return; }

    var note = el(cfg.noteId) ? el(cfg.noteId).value.trim() : "";
    if ((action === "response" || action === "evidence") && !note) {
      cfg.toast("Write something first - an empty entry helps nobody.");
      if (el(cfg.noteId)) el(cfg.noteId).focus();
      return;
    }
    if (action === "withdraw" &&
        !confirm("Withdraw case #" + c.ref + "? This closes it and cannot be undone.")) return;

    btn.disabled = true;
    var prev = btn.textContent;
    btn.textContent = "Saving…";
    var res = await global.EventaraAPI.addDisputeEvent(c.id, action, note);
    btn.disabled = false;
    btn.textContent = prev;

    if (res && res.error) { cfg.toast("Could not save: " + res.error.message); return; }
    cfg.toast(action === "withdraw" ? "Case withdrawn." : "Added to case #" + c.ref + ".");
    await load();
    if (action !== "withdraw" && openCaseId) openCase(openCaseId);
    else if (box) box.hidden = true;
  }

  /* ---------- raise a new case ---------- */
  async function toggleRaise(force) {
    var form = el(cfg.raiseId);
    if (!form) return;
    var show = (force === undefined) ? form.hidden : force;
    form.hidden = !show;
    if (!show) return;

    var sel = el(cfg.raiseBookingId);
    if (sel && !sel.options.length) {
      var res = await global.EventaraAPI.disputableBookings();
      var rows = (res && res.data) || [];
      if (!rows.length) {
        sel.innerHTML = '<option value="">No eligible bookings</option>';
      } else {
        sel.innerHTML = rows.map(function (b) {
          return '<option value="' + esc(b.id) + '">#' + esc(b.ref) + " - " +
                 esc(b.business_name) + " (" + esc(fmtDate(b.event_date)) + ")</option>";
        }).join("");
      }
    }
    form.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }

  async function submitRaise(btn) {
    var bookingId = el(cfg.raiseBookingId) ? el(cfg.raiseBookingId).value : "";
    var priority = el(cfg.raisePriorityId) ? el(cfg.raisePriorityId).value : "medium";
    var summary = el(cfg.raiseSummaryId) ? el(cfg.raiseSummaryId).value.trim() : "";

    if (!bookingId) { cfg.toast("Pick the booking this is about."); return; }
    if (summary.length < 15) {
      cfg.toast("Describe the problem in a bit more detail (at least 15 characters).");
      if (el(cfg.raiseSummaryId)) el(cfg.raiseSummaryId).focus();
      return;
    }

    btn.disabled = true;
    var prev = btn.textContent;
    btn.textContent = "Submitting…";
    // Suppliers raise 'dispute' against a customer; customers raise a
    // 'complaint' about service. Same table, different framing.
    var kind = cfg.role === "supplier" ? "dispute" : "complaint";
    var res = await global.EventaraAPI.raiseDisputeOnBooking(bookingId, kind, priority, summary);
    btn.disabled = false;
    btn.textContent = prev;

    if (res && res.error) { cfg.toast("Could not submit: " + res.error.message); return; }
    var ref = res && res.data ? res.data.ref : "";
    cfg.toast("Case " + (ref ? "#" + ref + " " : "") + "opened. Eventara Ops will review it.");
    if (el(cfg.raiseSummaryId)) el(cfg.raiseSummaryId).value = "";
    toggleRaise(false);
    await load();
  }

  /* ============================================================
     LOAD + MOUNT
     ============================================================ */
  async function load() {
    if (!global.EventaraAPI) return;
    var res = await global.EventaraAPI.myDisputes();
    if (res && res.error) {
      var body = el(cfg.bodyId);
      if (body) {
        body.innerHTML = "";
        var tr = document.createElement("tr");
        var td = document.createElement("td");
        td.colSpan = 7; td.className = "caption"; td.style.padding = "var(--space-24)";
        td.textContent = "Could not load your cases. " + res.error.message;
        tr.appendChild(td); body.appendChild(tr);
      }
      return;
    }
    cases = (res && res.data) || [];
    renderTable();

    // The empty-state card (customer panel) only makes sense with no open case.
    var empty = el(cfg.emptyId);
    if (empty) {
      var anyOpen = cases.some(function (c) { return !isClosed(c); });
      empty.hidden = anyOpen;
    }
  }

  function mount(options) {
    cfg = {
      role:            options.role,
      bodyId:          options.bodyId          || "dispBody",
      tabsId:          options.tabsId          || "dispTabs",
      detailId:        options.detailId        || "dispDetail",
      raiseId:         options.raiseId         || "dispRaise",
      raiseBookingId:  options.raiseBookingId  || "drBooking",
      raisePriorityId: options.raisePriorityId || "drPriority",
      raiseSummaryId:  options.raiseSummaryId  || "drSummary",
      noteId:          options.noteId          || "dispNote",
      emptyId:         options.emptyId         || null,
      toast:           options.toast || function (m) { alert(m); }
    };
    return load();
  }

  global.DisputesUI = {
    mount: mount,
    reload: load,
    toggleRaise: toggleRaise,
    submitRaise: submitRaise,
    applyFilter: reapplyActiveFilter
  };
})(window);
