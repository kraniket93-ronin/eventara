/* ============================================================
   EVENTARA - auth.js (Supabase edition)  [drop-in replacement]
   ------------------------------------------------------------
   Same public API as the original auth.js (Auth.getSession /
   getRole / requireRole / renderNav / logout / dashboardUrl),
   so every existing page keeps working. When window.sb is
   configured it uses real Supabase Auth (email/password, email
   verification, password reset, JWT sessions). When it is not,
   it falls back to the original offline localStorage behaviour
   so the demo still runs.

   Security model: the client keeps a lightweight session
   *mirror* in localStorage for a fast <head> route guard, but
   the REAL boundary is Postgres Row-Level Security (0002_rls).
   Faking the mirror grants no data - RLS returns nothing.

   To activate: include supabase(+config+client) before this,
   and replace <script src="auth.js"> with this file.
   ============================================================ */
(function () {
  'use strict';
  var KEY = 'eventara_session';
  var TTL_MS = 12 * 60 * 60 * 1000;

  function read() { try { return JSON.parse(localStorage.getItem(KEY) || 'null'); } catch (e) { return null; } }
  function write(s) { try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) {} }
  function clear() { try { localStorage.removeItem(KEY); } catch (e) {} try { sessionStorage.removeItem('eventara_auth'); } catch (e) {} }

  function initials(name, role) {
    var src = (name || (role === 'supplier' ? 'Supplier' : 'Customer')).trim();
    var p = src.split(/\s+/).filter(Boolean);
    var out = (p[0] ? p[0][0] : '') + (p[1] ? p[1][0] : '');
    return (out || src.slice(0, 2)).toUpperCase();
  }

  var LIVE = !!window.sb;

  // ---- keep a synchronous mirror in sync with the Supabase session ----
  async function refreshMirror() {
    if (!LIVE) return read();
    var res = await sb.auth.getSession();
    var s = res.data.session;
    if (!s) { clear(); return null; }
    var prof = await sb.from('profiles').select('role, full_name, email').eq('id', s.user.id).single();
    var mirror = {
      token: s.access_token, role: (prof.data && prof.data.role) || 'customer',
      name: (prof.data && prof.data.full_name) || s.user.email,
      email: s.user.email, iat: Date.now(), exp: Date.now() + TTL_MS
    };
    write(mirror);
    return mirror;
  }

  var Auth = {
    KEY: KEY,

    dashboardUrl: function (role) {
      if (role === 'supplier') return 'supplier-dashboard.html';
      if (role === 'customer') return 'customer-dashboard.html';
      return 'index.html';
    },

    // ----- LIVE auth (email/password) -----
    signIn: async function (email, password) {
      if (!LIVE) return { error: { message: 'offline demo: use Auth.login(role, info)' } };
      var r = await sb.auth.signInWithPassword({ email: email, password: password });
      if (!r.error) { var m = await refreshMirror(); this.renderNav();
        window.location.href = this.dashboardUrl(m ? m.role : null); }
      return r;
    },
    signUp: async function (email, password, role, meta) {
      if (!LIVE) return { error: { message: 'offline demo' } };
      return sb.auth.signUp({ email: email, password: password,
        options: { data: Object.assign({ role: role }, meta || {}) } });
    },
    resetPassword: async function (email) {
      if (!LIVE) return { error: { message: 'offline demo' } };
      return sb.auth.resetPasswordForEmail(email, { redirectTo: location.origin + '/signin.html' });
    },

    // ----- OFFLINE demo login (unchanged from original) -----
    login: function (role, info) {
      info = info || {};
      var s = { token: 'evt_' + Math.random().toString(36).slice(2), role: role,
        name: info.name || (role === 'supplier' ? 'Your Business' : 'Your Organisation'),
        email: info.email || '', iat: Date.now(), exp: Date.now() + TTL_MS };
      write(s); return s;
    },

    getSession: function () {           // synchronous mirror (fast; used by the guard)
      var s = read();
      if (!s) return null;
      if (!s.exp || s.exp < Date.now()) { clear(); return null; }
      return s;
    },
    isAuthenticated: function () { return !!this.getSession(); },
    getRole: function () { var s = this.getSession(); return s ? s.role : null; },

    requireRole: function (role, redirectUrl) {
      var s = this.getSession();
      if (!s || (role && s.role !== role)) { window.location.replace(redirectUrl || 'signin.html'); return false; }
      return true;                       // RLS is the real boundary server-side
    },

    logout: async function (redirectTo) {
      if (LIVE) { try { await sb.auth.signOut(); } catch (e) {} }
      clear();
      try { this.renderNav(); } catch (e) {}
      window.location.href = redirectTo || 'index.html';
    },

    // ----- Reflect auth state in the navbar (User Profile Dropdown) -----
    renderNav: function () {
      var s = this.getSession();
      var dash = this.dashboardUrl(s ? s.role : null);
      var label = s ? s.name : '';
      var role = s ? s.role : null;
      var roleLabel = role === 'supplier' ? 'Business account' : 'Customer account';
      var IC = {
        dash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>',
        user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
        gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 3v2M12 19v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M3 12h2M19 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4"/></svg>',
        out: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>',
        chev: '<svg class="account-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>'
      };
      var self = this;
      document.querySelectorAll('.navbar-actions').forEach(function (actions) {
        var old = actions.querySelector('.account-menu'); if (old) old.remove();
        var signin = actions.querySelector('.btn-signin');
        if (!s) { if (signin) signin.style.display = ''; return; }
        if (signin) signin.style.display = 'none';
        var ddId = 'acctDropdown_' + (++menuSeq);
        var menu = document.createElement('div'); menu.className = 'account-menu';
        menu.innerHTML =
          '<button type="button" class="account-trigger" aria-haspopup="menu" aria-expanded="false" aria-controls="' + ddId + '">' +
            '<span class="account-avatar">' + initials(label, role) + '</span>' +
            '<span class="account-name">' + (label || roleLabel) + '</span>' + IC.chev + '</button>' +
          '<div class="account-dropdown" id="' + ddId + '" role="menu" aria-label="Account menu">' +
            '<div class="account-dd-head"><span class="account-avatar">' + initials(label, role) + '</span>' +
              '<span class="account-dd-id"><b>' + (label || roleLabel) + '</b><span>' + roleLabel + '</span></span></div>' +
            '<a href="' + dash + '" role="menuitem" class="account-dd-item">' + IC.dash + 'Dashboard</a>' +
            '<a href="' + dash + '#profile" role="menuitem" class="account-dd-item">' + IC.user + 'My Profile</a>' +
            '<a href="' + dash + '#settings" role="menuitem" class="account-dd-item">' + IC.gear + 'Account Settings</a>' +
            '<button type="button" role="menuitem" class="account-dd-item account-dd-logout">' + IC.out + 'Log Out</button>' +
          '</div>';
        actions.appendChild(menu);
        menu.querySelector('.account-dd-logout').addEventListener('click', function () { self.logout('index.html'); });
        bindDropdown(menu);
      });
      document.querySelectorAll('.mobile-menu').forEach(function (m) {
        m.querySelectorAll('[data-auth-injected]').forEach(function (x) { x.remove(); });
        var signinLink = Array.prototype.slice.call(m.querySelectorAll('a'))
          .find(function (a) { return /^\s*sign in\s*$/i.test(a.textContent); });
        if (!s) { if (signinLink) signinLink.style.display = ''; return; }
        if (signinLink) signinLink.style.display = 'none';
        function addLink(href, text, icon) { var a = document.createElement('a');
          a.href = href; a.className = 'mobile-account-item'; a.setAttribute('data-auth-injected', '');
          a.innerHTML = icon + '<span>' + text + '</span>'; m.appendChild(a); return a; }
        var head = document.createElement('div'); head.className = 'mobile-account-head'; head.setAttribute('data-auth-injected', '');
        head.innerHTML = '<span class="account-avatar">' + initials(label, role) + '</span>' +
          '<span class="mobile-account-id"><b>' + (label || roleLabel) + '</b><span>' + roleLabel + '</span></span>';
        m.appendChild(head);
        addLink(dash, 'Dashboard', IC.dash); addLink(dash + '#profile', 'My Profile', IC.user);
        addLink(dash + '#settings', 'Account Settings', IC.gear);
        addLink('#', 'Log Out', IC.out).addEventListener('click', function (e) { e.preventDefault(); self.logout('index.html'); });
      });
    }
  };

  // dropdown behaviour (identical to the original)
  var menuSeq = 0;
  function closeAllMenus(except) {
    document.querySelectorAll('.account-menu.open').forEach(function (m) {
      if (m === except) return; m.classList.remove('open');
      var t = m.querySelector('.account-trigger'); if (t) t.setAttribute('aria-expanded', 'false');
    });
  }
  function bindDropdown(menu) {
    var trigger = menu.querySelector('.account-trigger');
    var items = Array.prototype.slice.call(menu.querySelectorAll('.account-dd-item'));
    function open() { closeAllMenus(menu); menu.classList.add('open'); trigger.setAttribute('aria-expanded', 'true'); }
    function close(f) { menu.classList.remove('open'); trigger.setAttribute('aria-expanded', 'false'); if (f) trigger.focus(); }
    trigger.addEventListener('click', function (e) { e.stopPropagation(); menu.classList.contains('open') ? close(false) : open(); });
    trigger.addEventListener('keydown', function (e) { if (e.key === 'ArrowDown' || e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(); if (items[0]) items[0].focus(); } });
    menu.addEventListener('keydown', function (e) { var i = items.indexOf(document.activeElement);
      if (e.key === 'Escape') { e.preventDefault(); close(true); }
      else if (e.key === 'ArrowDown') { e.preventDefault(); (items[i + 1] || items[0]).focus(); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); (items[i - 1] || items[items.length - 1]).focus(); } });
  }
  if (!window.__acctMenuBound) {
    window.__acctMenuBound = true;
    document.addEventListener('click', function (e) { if (!e.target.closest('.account-menu')) closeAllMenus(null); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeAllMenus(null); });
  }

  window.Auth = Auth;

  // Live: keep the mirror + navbar in sync with real auth state
  if (LIVE) {
    sb.auth.onAuthStateChange(function () { refreshMirror().then(function () { try { Auth.renderNav(); } catch (e) {} }); });
    refreshMirror().then(function () { try { Auth.renderNav(); } catch (e) {} });
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { Auth.renderNav(); });
  } else { Auth.renderNav(); }
})();
