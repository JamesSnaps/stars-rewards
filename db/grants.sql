-- Run this AFTER restoring the Supabase data dump (the tables must exist).
-- Gives the `anon` role full read/write on every table, matching how the app
-- used the Supabase anon key. LAN-only deployment, so no row-level security.
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Apply the same grants automatically to any tables/sequences created later.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO anon;

-- Tell PostgREST to reload its schema cache.
NOTIFY pgrst, 'reload schema';
