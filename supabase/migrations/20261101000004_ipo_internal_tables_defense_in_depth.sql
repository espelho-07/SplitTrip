-- ==============================================================================
-- KITH DEFENSE-IN-DEPTH HARDENING FOR IPO INTERNAL TABLES
-- Migration Date: 2026-11-01 00:00:04
-- Target: KITH-STAGING (PostgreSQL 17)
-- Description: Revokes public and anonymous access to ipo_api_usage and
--              ipo_fetch_logs, and prevents mutations to ipo_master and
--              ipo_gmp_cache by unauthorized roles.
-- ==============================================================================

-- 1. Ensure RLS is active on all tables
ALTER TABLE ipo_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE ipo_gmp_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE ipo_api_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE ipo_fetch_logs ENABLE ROW LEVEL SECURITY;

-- 2. Explicitly revoke all privileges on internal logging & quota tables from public, anon, and authenticated
REVOKE ALL ON ipo_api_usage FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ipo_fetch_logs FROM PUBLIC, anon, authenticated;

-- 3. Explicitly revoke mutation privileges on public market cache tables
REVOKE INSERT, UPDATE, DELETE ON ipo_master FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON ipo_gmp_cache FROM PUBLIC, anon, authenticated;

-- 4. Preserve explicit SELECT grants for public market cache
GRANT SELECT ON ipo_master TO anon, authenticated;
GRANT SELECT ON ipo_gmp_cache TO anon, authenticated;

-- 5. Guarantee full access to postgres superuser and service_role
GRANT ALL ON ipo_master TO postgres, service_role;
GRANT ALL ON ipo_gmp_cache TO postgres, service_role;
GRANT ALL ON ipo_api_usage TO postgres, service_role;
GRANT ALL ON ipo_fetch_logs TO postgres, service_role;
