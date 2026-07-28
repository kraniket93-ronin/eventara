/* ============================================================
   Eventara - Supabase connection config
   ------------------------------------------------------------
   Fill these two values from your Supabase project:
     Project Settings > API  ->  Project URL  and  anon public key
   The anon key is SAFE to expose in the browser: Row-Level
   Security (see supabase/migrations/0002_rls.sql) is what
   actually protects the data, not this key.

   While these are blank, the app stays in offline demo mode
   (localStorage) so nothing breaks before you connect.
   ============================================================ */
window.EVENTARA_SUPABASE = {
  url:     "https://jqqliblliwluzdjcmcgz.supabase.co",
  anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxcWxpYmxsaXdsdXpkamNtY2d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3MzMzNjUsImV4cCI6MjEwMDMwOTM2NX0.TOZrzu7qOcElO2vZxQmVxBVNyNUImB75Vc4obGTtHfg"
};
