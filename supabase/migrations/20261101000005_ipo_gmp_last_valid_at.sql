-- ==============================================================================
-- KITH FINANCIAL MODE: DEDICATED GMP FRESHNESS TRACKING (gmp_last_valid_at)
-- Migration Date: 2026-11-01 00:00:05
-- Target: KITH-STAGING (PostgreSQL 17)
-- Description: Adds gmp_last_valid_at to ipo_master and ipo_gmp_cache so the
--              24-hour cache preservation window is measured strictly from the
--              last time a valid GMP was received, rather than fetched_at.
-- ==============================================================================

ALTER TABLE ipo_master 
    ADD COLUMN IF NOT EXISTS gmp_last_valid_at TIMESTAMPTZ;

ALTER TABLE ipo_gmp_cache 
    ADD COLUMN IF NOT EXISTS gmp_last_valid_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_ipo_master_gmp_last_valid_at ON ipo_master(gmp_last_valid_at);
CREATE INDEX IF NOT EXISTS idx_ipo_gmp_cache_gmp_last_valid_at ON ipo_gmp_cache(gmp_last_valid_at);
