/* ============================================================
   EVENTARA - Shared authentication/session module
   ------------------------------------------------------------
   Single source of truth for the signed-in state across EVERY
   page (public + dashboards). Prototype-grade: the "session" is
   a signed-shape token held in localStorage with an expiry - it
   follows real session best-practices (single store, expiry,
   guard-before-render) but is not a server-verified credential.

   Public API (window.Auth):
     Auth.login(role, info)        -> create session, returns it
     Auth.getSession()             -> session object or null (auto-expires)
     Auth.isAuthenticated()        -> boolean
     Auth.getRole()                -> 'supplier' | 'customer' | null
     Auth.dashboardUrl(role)       -> the home page for a role
     Auth.requireRole(role, url)   -> guard for protected pages (call in <head>)
     Auth.logout(redirectTo)       -> clear session + update UI + redirect
     Auth.renderNav()              -> reflect auth state in the navbar
   ============================================================ */
(function () {
  'use strict';

  var KEY = 'eventara_session';
  var TTL_MS = 12 * 60 * 60 * 1000; // 12 hours

  function now() { return Date.now(); }

  function makeToken() {
    // Opaque random token - stands in for a server-issued JWT/session id.
    return 'evt_' + Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2);
  }

  function read() {
    try { return JSON.parse(localStorage.getItem(KEY) || 'null'); }
    catch (e) { return null; }
  }

  function write(session) {
    try { localStorage.setItem(KEY, JSON.stringify(session)); } catch (e) {}
  }

  function clear() {
    try { localStorage.removeItem(KEY); } catch (e) {}
    // also clear the legacy per-tab flag so nothing lingers
    try { sessionStorage.removeItem('eventara_auth'); } catch (e) {}
  }

  function initials(name, role) {
    var src = (name || (role === 'supplier' ? 'Supplier' : 'Customer')).trim();
    var parts = src.split(/\s+/).filter(Boolean);
    var out = (parts[0] ? parts[0][0] : '') + (parts[1] ? parts[1][0] : '');
    return (out || src.slice(0, 2)).toUpperCase();
  }

  var Auth = {
    KEY: KEY,

    dashboardUrl: function (role) {
      if (role === 'supplier') return 'supplier-dashboard.html';
      if (role === 'customer') return 'customer-dashboard.html';
      return 'index.html';
    },

    login: function (role, info) {
      info = info || {};
      var session = {
        token: makeToken(),
        role: role,
        name: info.name || (role === 'supplier' ? 'Your Business' : 'Your Organisation'),
        email: info.email || '',
        iat: now(),
        exp: now() + TTL_MS
      };
      write(session);
      return session;
    },

    getSession: function () {
      var s = read();
      // Backward-compat: migrate an in-progress legacy sessionStorage login.
      if (!s) {
        var legacy = null;
        try { legacy = sessionStorage.getItem('eventara_auth'); } catch (e) {}
        if (legacy === 'supplier' || legacy === 'customer') {
          s = this.login(legacy, {});
        }
      }
      if (!s) return null;
      if (!s.exp || s.exp < now()) { clear(); return null; } // expired → graceful sign-out
      return s;
    },

    isAuthenticated: function () { return !!this.getSession(); },

    getRole: function () { var s = this.getSession(); return s ? s.role : null; },

    // Guard for protected pages. Call synchronously in <head> so it runs
    // before the body renders (no flash of protected content).
    requireRole: function (role, redirectUrl) {
      var s = this.getSession();
      if (!s || (role && s.role !== role)) {
        window.location.replace(redirectUrl || 'signin.html');
        return false;
      }
      return true;
    },

    logout: function (redirectTo) {
      clear();
      try { this.renderNav(); } catch (e) {}
      window.location.href = redirectTo || 'index.html';
    },

    // Reflect the auth state in every navbar / mobile menu on the page.
    // Idempotent: safe to call repeatedly. Renders the reusable
    // "User Profile Dropdown" (avatar + name + chevron → menu) on desktop and
    // an inline account block inside the hamburger menu on mobile. All menu
    // destinations are derived from the session role - nothing is hard-coded.
    renderNav: function () {
      var s = this.getSession();
      var dash = this.dashboardUrl(s ? s.role : null);
      var label = s ? s.name : '';
      var role = s ? s.role : null;
      var roleLabel = role === 'supplier' ? 'Business account' : 'Customer account';
      var profileHref = dash + '#profile';
      var settingsHref = dash + '#settings';

      // Shared icon set (kept tiny & inline so no extra request)
      var IC = {
        dash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>',
        user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
        gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
        out: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>',
        chev: '<svg class="account-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>'
      };

      // --- Desktop navbar: User Profile Dropdown ---
      document.querySelectorAll('.navbar-actions').forEach(function (actions) {
        var old = actions.querySelector('.account-menu');
        if (old) old.remove();
        var signin = actions.querySelector('.btn-signin');
        if (!s) { if (signin) signin.style.display = ''; return; }
        if (signin) signin.style.display = 'none';

        var ddId = 'acctDropdown_' + (++menuSeq);
        var menu = document.createElement('div');
        menu.className = 'account-menu';
        menu.innerHTML =
          '<button type="button" class="account-trigger" aria-haspopup="menu" aria-expanded="false" aria-controls="' + ddId + '">' +
            '<span class="account-avatar">' + initials(label, role) + '</span>' +
            '<span class="account-name">' + (label || roleLabel) + '</span>' + IC.chev +
          '</button>' +
          '<div class="account-dropdown" id="' + ddId + '" role="menu" aria-label="Account menu">' +
            '<div class="account-dd-head"><span class="account-avatar">' + initials(label, role) + '</span>' +
              '<span class="account-dd-id"><b>' + (label || roleLabel) + '</b><span>' + roleLabel + '</span></span></div>' +
            '<a href="' + dash + '" role="menuitem" class="account-dd-item">' + IC.dash + 'Dashboard</a>' +
            '<a href="' + profileHref + '" role="menuitem" class="account-dd-item">' + IC.user + 'My Profile</a>' +
            '<a href="' + settingsHref + '" role="menuitem" class="account-dd-item">' + IC.gear + 'Account Settings</a>' +
            '<button type="button" role="menuitem" class="account-dd-item account-dd-logout">' + IC.out + 'Log Out</button>' +
          '</div>';
        actions.appendChild(menu);
        menu.querySelector('.account-dd-logout').addEventListener('click', function () { Auth.logout('index.html'); });
        bindDropdown(menu);
      });

      // --- Mobile hamburger menu: inline account block ---
      document.querySelectorAll('.mobile-menu').forEach(function (m) {
        m.querySelectorAll('[data-auth-injected]').forEach(function (x) { x.remove(); });
        var signinLink = Array.prototype.slice.call(m.querySelectorAll('a'))
          .find(function (a) { return /^\s*sign in\s*$/i.test(a.textContent); });
        if (!s) { if (signinLink) signinLink.style.display = ''; return; }
        if (signinLink) signinLink.style.display = 'none';

        function addLink(href, text, icon) {
          var a = document.createElement('a');
          a.href = href; a.className = 'mobile-account-item'; a.setAttribute('data-auth-injected', '');
          a.innerHTML = icon + '<span>' + text + '</span>';
          m.appendChild(a); return a;
        }
        var head = document.createElement('div');
        head.className = 'mobile-account-head'; head.setAttribute('data-auth-injected', '');
        head.innerHTML = '<span class="account-avatar">' + initials(label, role) + '</span>' +
          '<span class="mobile-account-id"><b>' + (label || roleLabel) + '</b><span>' + roleLabel + '</span></span>';
        m.appendChild(head);
        addLink(dash, 'Dashboard', IC.dash);
        addLink(profileHref, 'My Profile', IC.user);
        addLink(settingsHref, 'Account Settings', IC.gear);
        var lo = addLink('#', 'Log Out', IC.out);
        lo.addEventListener('click', function (e) { e.preventDefault(); Auth.logout('index.html'); });
      });
    }
  };

  // ---- Dropdown behaviour: open/close, outside-click, ESC, arrow keys ----
  var menuSeq = 0;
  function closeAllMenus(except) {
    document.querySelectorAll('.account-menu.open').forEach(function (m) {
      if (m === except) return;
      m.classList.remove('open');
      var t = m.querySelector('.account-trigger');
      if (t) t.setAttribute('aria-expanded', 'false');
    });
  }
  function bindDropdown(menu) {
    var trigger = menu.querySelector('.account-trigger');
    var items = Array.prototype.slice.call(menu.querySelectorAll('.account-dd-item'));
    function open() {
      closeAllMenus(menu);
      menu.classList.add('open');
      trigger.setAttribute('aria-expanded', 'true');
    }
    function close(focusTrigger) {
      menu.classList.remove('open');
      trigger.setAttribute('aria-expanded', 'false');
      if (focusTrigger) trigger.focus();
    }
    trigger.addEventListener('click', function (e) {
      e.stopPropagation();
      if (menu.classList.contains('open')) { close(false); } else { open(); }
    });
    trigger.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowDown' || e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(); if (items[0]) items[0].focus(); }
    });
    menu.addEventListener('keydown', function (e) {
      var idx = items.indexOf(document.activeElement);
      if (e.key === 'Escape') { e.preventDefault(); close(true); }
      else if (e.key === 'ArrowDown') { e.preventDefault(); (items[idx + 1] || items[0]).focus(); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); (items[idx - 1] || items[items.length - 1]).focus(); }
    });
  }
  // one-time global listeners (survive repeated renderNav calls)
  if (!window.__acctMenuBound) {
    window.__acctMenuBound = true;
    document.addEventListener('click', function (e) { if (!e.target.closest('.account-menu')) closeAllMenus(null); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeAllMenus(null); });
  }

  window.Auth = Auth;

  // Auto-reflect auth state on every page that includes this script.
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { Auth.renderNav(); });
  } else {
    Auth.renderNav();
  }
})();
