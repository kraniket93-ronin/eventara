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
      if (role === 'supplier') return 'dashboard.html';
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
    // Idempotent: safe to call repeatedly.
    renderNav: function () {
      var s = this.getSession();
      var dash = this.dashboardUrl(s ? s.role : null);
      var label = s ? s.name : '';
      var dashLabel = s && s.role === 'supplier' ? 'Supplier Portal' : 'My Account';

      // --- Desktop navbar actions ---
      document.querySelectorAll('.navbar-actions').forEach(function (actions) {
        var old = actions.querySelector('.account-menu');
        if (old) old.remove();
        var signin = actions.querySelector('.btn-signin');
        if (s) {
          if (signin) signin.style.display = 'none';
          var menu = document.createElement('div');
          menu.className = 'account-menu';
          menu.innerHTML =
            '<a href="' + dash + '" class="account-chip" title="Go to your dashboard">' +
              '<span class="account-avatar">' + initials(label, s.role) + '</span>' +
              '<span class="account-name">' + (label || dashLabel) + '</span>' +
            '</a>' +
            '<button type="button" class="account-logout">Log out</button>';
          menu.querySelector('.account-logout').addEventListener('click', function () { Auth.logout('index.html'); });
          actions.appendChild(menu);
        } else {
          if (signin) signin.style.display = '';
        }
      });

      // --- Mobile menu ---
      document.querySelectorAll('.mobile-menu').forEach(function (m) {
        m.querySelectorAll('[data-auth-injected]').forEach(function (x) { x.remove(); });
        var signinLink = Array.prototype.slice.call(m.querySelectorAll('a'))
          .find(function (a) { return /^\s*sign in\s*$/i.test(a.textContent); });
        if (s) {
          if (signinLink) signinLink.style.display = 'none';
          var dl = document.createElement('a');
          dl.href = dash; dl.textContent = dashLabel; dl.setAttribute('data-auth-injected', '');
          var lo = document.createElement('a');
          lo.href = '#'; lo.textContent = 'Log out'; lo.setAttribute('data-auth-injected', '');
          lo.addEventListener('click', function (e) { e.preventDefault(); Auth.logout('index.html'); });
          m.appendChild(dl); m.appendChild(lo);
        } else {
          if (signinLink) signinLink.style.display = '';
        }
      });
    }
  };

  window.Auth = Auth;

  // Auto-reflect auth state on every page that includes this script.
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { Auth.renderNav(); });
  } else {
    Auth.renderNav();
  }
})();
