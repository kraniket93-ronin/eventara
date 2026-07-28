/* ============================================================
   Eventara - Supabase client bootstrap
   ------------------------------------------------------------
   Creates window.sb (the Supabase client) IF a URL + anon key
   are configured in supabase-config.js. Otherwise window.sb is
   null and the app runs in offline demo mode.

   Load order on every page (before auth.js / data-api.js):
     <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
     <script src="supabase-config.js"></script>
     <script src="supabase-client.js"></script>
   ============================================================ */
(function () {
  var cfg = window.EVENTARA_SUPABASE || {};
  var ready = cfg.url && cfg.anonKey && window.supabase && window.supabase.createClient;
  window.sb = ready
    ? window.supabase.createClient(cfg.url, cfg.anonKey, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
      })
    : null;
  window.EVENTARA_LIVE = !!window.sb;   // true once connected to a real backend
  if (!window.sb) {
    console.info("[Eventara] Supabase not configured - running in offline demo mode. " +
                 "Fill supabase-config.js to go live.");
  }
})();
