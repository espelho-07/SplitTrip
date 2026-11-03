-- ==============================================================================
-- KITH FINANCIAL MODE: CENTRALIZED IPO GURU V2 CACHE & INGESTION GOVERNANCE
-- Migration Date: 2026-11-01 00:00:03
-- Target: KITH-STAGING (PostgreSQL 17)
-- Description: Creates persistent cache tables for IPO Guru v2 data, rate limit
--              and quota governance (10 req/day, 1 req/min), fetch audit logs,
--              and strictly configured RLS policies.
-- ==============================================================================

-- 1. Enhance ipo_master with tracking & slug columns
ALTER TABLE ipo_master 
    ADD COLUMN IF NOT EXISTS slug TEXT UNIQUE,
    ADD COLUMN IF NOT EXISTS source_updated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS is_stale BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_ipo_master_slug ON ipo_master(slug);
CREATE INDEX IF NOT EXISTS idx_ipo_master_is_stale ON ipo_master(is_stale);

-- 2. Dedicated IPO GMP Cache Table
CREATE TABLE IF NOT EXISTS ipo_gmp_cache (
    id TEXT PRIMARY KEY,
    ipo_id TEXT REFERENCES ipo_master(id) ON DELETE CASCADE,
    slug TEXT NOT NULL UNIQUE,
    ipo_name TEXT NOT NULL,
    price_band_min INTEGER NOT NULL DEFAULT 0,
    price_band_max INTEGER NOT NULL DEFAULT 0,
    gmp_raw INTEGER, -- NULL means unquoted; 0 means flat
    estimated_listing_price NUMERIC,
    estimated_gain_percentage NUMERIC,
    source_updated_at TIMESTAMPTZ,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    is_stale BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ipo_gmp_cache_slug ON ipo_gmp_cache(slug);
CREATE INDEX IF NOT EXISTS idx_ipo_gmp_cache_ipo_id ON ipo_gmp_cache(ipo_id);
CREATE INDEX IF NOT EXISTS idx_ipo_gmp_cache_stale ON ipo_gmp_cache(is_stale, expires_at);

-- 3. API Usage Governor Table (Enforces 10 req/day and 60-second cooldown in IST)
CREATE TABLE IF NOT EXISTS ipo_api_usage (
    date_ist DATE PRIMARY KEY,
    daily_request_count INTEGER NOT NULL DEFAULT 0,
    max_daily_requests INTEGER NOT NULL DEFAULT 10,
    last_request_at TIMESTAMPTZ,
    cooldown_seconds INTEGER NOT NULL DEFAULT 60,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Ingestion Fetch Audit Log Table
CREATE TABLE IF NOT EXISTS ipo_fetch_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    endpoint TEXT NOT NULL,
    http_status INTEGER NOT NULL,
    record_count INTEGER NOT NULL DEFAULT 0,
    error_message TEXT,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ipo_fetch_logs_created ON ipo_fetch_logs(created_at DESC);

-- ==============================================================================
-- DATABASE FUNCTIONS FOR QUOTA GOVERNANCE & STALENESS
-- ==============================================================================

-- 5. Atomic Usage Tracking & Lock Function (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION kith_record_ipo_api_request()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_today_ist DATE;
    v_usage RECORD;
    v_now TIMESTAMPTZ := NOW();
    v_allowed BOOLEAN := FALSE;
    v_reason TEXT := '';
BEGIN
    -- Compute current date in Indian Standard Time (UTC+05:30)
    v_today_ist := (v_now AT TIME ZONE 'Asia/Kolkata')::DATE;

    -- Upsert daily record and lock row
    INSERT INTO ipo_api_usage (date_ist, daily_request_count, last_request_at, updated_at)
    VALUES (v_today_ist, 0, NULL, v_now)
    ON CONFLICT (date_ist) DO NOTHING;

    SELECT * INTO v_usage
    FROM ipo_api_usage
    WHERE date_ist = v_today_ist
    FOR UPDATE;

    IF v_usage.daily_request_count >= v_usage.max_daily_requests THEN
        v_allowed := FALSE;
        v_reason := 'DAILY_QUOTA_EXHAUSTED';
    ELSIF v_usage.last_request_at IS NOT NULL AND (v_now - v_usage.last_request_at) < (v_usage.cooldown_seconds || ' seconds')::INTERVAL THEN
        v_allowed := FALSE;
        v_reason := 'COOLDOWN_ACTIVE';
    ELSE
        UPDATE ipo_api_usage
        SET daily_request_count = daily_request_count + 1,
            last_request_at = v_now,
            updated_at = v_now
        WHERE date_ist = v_today_ist;
        
        v_allowed := TRUE;
        v_reason := 'ALLOWED';
    END IF;

    RETURN jsonb_build_object(
        'allowed', v_allowed,
        'reason', v_reason,
        'current_count', CASE WHEN v_allowed THEN v_usage.daily_request_count + 1 ELSE v_usage.daily_request_count END,
        'max_requests', v_usage.max_daily_requests,
        'date_ist', v_today_ist
    );
END;
$$;

-- 6. Cache Staleness Maintenance Function
CREATE OR REPLACE FUNCTION kith_mark_stale_ipo_cache()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_updated_count INTEGER := 0;
BEGIN
    UPDATE ipo_master
    SET is_stale = TRUE
    WHERE NOW() > (fetched_at + INTERVAL '24 hours') AND is_stale = FALSE;

    UPDATE ipo_gmp_cache
    SET is_stale = TRUE
    WHERE NOW() > expires_at AND is_stale = FALSE;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RETURN v_updated_count;
END;
$$;

-- ==============================================================================
-- ROW-LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE ipo_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE ipo_gmp_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE ipo_api_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE ipo_fetch_logs ENABLE ROW LEVEL SECURITY;

-- ipo_master: Public Read-Only Policy
DROP POLICY IF EXISTS "ipo_master_public_read" ON ipo_master;
CREATE POLICY "ipo_master_public_read"
    ON ipo_master FOR SELECT
    USING (true);

-- ipo_gmp_cache: Public Read-Only Policy
DROP POLICY IF EXISTS "ipo_gmp_cache_public_read" ON ipo_gmp_cache;
CREATE POLICY "ipo_gmp_cache_public_read"
    ON ipo_gmp_cache FOR SELECT
    USING (true);

-- ipo_api_usage & ipo_fetch_logs: NO policies for anon or authenticated
-- Writable and readable exclusively by service_role and SECURITY DEFINER functions.

-- ==============================================================================
-- PERMISSIONS & PRIVILEGES
-- ==============================================================================

GRANT SELECT ON ipo_master TO anon, authenticated;
GRANT SELECT ON ipo_gmp_cache TO anon, authenticated;

-- Restrict execution of quota recording function to service_role only
REVOKE EXECUTE ON FUNCTION kith_record_ipo_api_request() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION kith_record_ipo_api_request() TO service_role;

REVOKE EXECUTE ON FUNCTION kith_mark_stale_ipo_cache() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION kith_mark_stale_ipo_cache() TO service_role;
