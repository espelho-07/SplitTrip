-- ==============================================================================
-- KITH FINANCIAL MODE: ATOMIC IPO BATCH UPSERT & FIRST-ROW QUOTA CONCURRENCY
-- Migration Date: 2026-11-01 00:00:06
-- Target: KITH-STAGING (PostgreSQL 17)
-- Description:
--   1. Provides kith_upsert_ipo_batch(p_payload JSONB) for atomic dual-table
--      upserts of ipo_master and ipo_gmp_cache with full transaction rollback,
--      strict 24h freshness preservation, and listed-IPO zeroing.
--   2. Hardens kith_record_ipo_api_request() with transaction-level advisory
--      locking to guarantee safe initialization on the very first request
--      of the day when no row exists in ipo_api_usage, and returns
--      accurate retry_after_seconds.
-- ==============================================================================

-- ==============================================================================
-- 1. HARDENED QUOTA RESERVATION FUNCTION WITH ADVISORY LOCKING
-- ==============================================================================
CREATE OR REPLACE FUNCTION kith_record_ipo_api_request()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_now TIMESTAMPTZ := CLOCK_TIMESTAMP();
    v_today_ist DATE;
    v_usage RECORD;
    v_allowed BOOLEAN := FALSE;
    v_reason TEXT := '';
    v_retry_after INTEGER := 0;
    v_cooldown_interval INTERVAL;
BEGIN
    -- 1. Compute current date in Indian Standard Time (UTC+05:30)
    v_today_ist := (v_now AT TIME ZONE 'Asia/Kolkata')::DATE;

    -- 2. Transaction-scoped advisory lock on the date hash to serialize first-row initialization
    -- and prevent race conditions when today's row does not yet exist.
    PERFORM pg_advisory_xact_lock(hashtext('kith_ipo_quota_' || v_today_ist::text));

    -- 3. Concurrency-safe initialization: insert default row for today if missing
    INSERT INTO ipo_api_usage (
        date_ist, daily_request_count, max_daily_requests, last_request_at, cooldown_seconds, created_at, updated_at
    ) VALUES (
        v_today_ist, 0, 10, NULL, 60, v_now, v_now
    )
    ON CONFLICT (date_ist) DO NOTHING;

    -- 4. Acquire exclusive row lock on today's usage row
    SELECT * INTO v_usage
    FROM ipo_api_usage
    WHERE date_ist = v_today_ist
    FOR UPDATE;

    v_cooldown_interval := (v_usage.cooldown_seconds || ' seconds')::INTERVAL;

    -- 5. Evaluate daily quota and 60-second cooldown limits
    IF v_usage.daily_request_count >= v_usage.max_daily_requests THEN
        v_allowed := FALSE;
        v_reason := 'DAILY_QUOTA_EXHAUSTED';
        -- Seconds until next IST calendar day (midnight IST)
        v_retry_after := GREATEST(1, CEIL(EXTRACT(EPOCH FROM (
            (((v_today_ist + 1)::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE 'Asia/Kolkata') - v_now
        ))))::INTEGER;
    ELSIF v_usage.last_request_at IS NOT NULL AND (v_now - v_usage.last_request_at) < v_cooldown_interval THEN
        v_allowed := FALSE;
        v_reason := 'COOLDOWN_ACTIVE';
        -- Exact seconds remaining in 60-second cooldown window
        v_retry_after := GREATEST(1, CEIL(EXTRACT(EPOCH FROM (
            (v_usage.last_request_at + v_cooldown_interval) - v_now
        ))))::INTEGER;
    ELSE
        -- Quota reservation granted: atomically increment count and update last_request_at
        UPDATE ipo_api_usage
        SET daily_request_count = daily_request_count + 1,
            last_request_at = v_now,
            updated_at = v_now
        WHERE date_ist = v_today_ist;

        v_allowed := TRUE;
        v_reason := 'ALLOWED';
        v_retry_after := 0;
    END IF;

    RETURN jsonb_build_object(
        'allowed', v_allowed,
        'reason', v_reason,
        'current_count', CASE WHEN v_allowed THEN v_usage.daily_request_count + 1 ELSE v_usage.daily_request_count END,
        'max_requests', v_usage.max_daily_requests,
        'retry_after_seconds', v_retry_after,
        'date_ist', v_today_ist
    );
END;
$$;

-- Revoke public access, grant strictly to service_role
REVOKE EXECUTE ON FUNCTION kith_record_ipo_api_request() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION kith_record_ipo_api_request() TO service_role;


-- ==============================================================================
-- 2. ATOMIC BATCH UPSERT FUNCTION (ipo_master & ipo_gmp_cache)
-- ==============================================================================
CREATE OR REPLACE FUNCTION kith_upsert_ipo_batch(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_items JSONB;
    v_item JSONB;
    v_now TIMESTAMPTZ := NOW();
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '6 hours';
    v_today_ist DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
    v_count INTEGER := 0;

    -- Item fields
    v_id TEXT;
    v_name TEXT;
    v_company_name TEXT;
    v_symbol TEXT;
    v_market_type TEXT;
    v_status TEXT;
    v_open_date TIMESTAMPTZ;
    v_close_date TIMESTAMPTZ;
    v_allotment_date TIMESTAMPTZ;
    v_listing_date TIMESTAMPTZ;
    v_min_price INTEGER;
    v_max_price INTEGER;
    v_lot_size INTEGER;
    v_issue_size_crores NUMERIC;
    v_fresh_issue_crores NUMERIC;
    v_ofs_crores NUMERIC;
    v_incoming_gmp INTEGER;
    v_slug TEXT;
    v_source_updated_at TIMESTAMPTZ;
    v_is_listed BOOLEAN;

    -- Master upsert resolved return values
    v_effective_gmp INTEGER;
    v_effective_gmp_valid_at TIMESTAMPTZ;
    v_effective_min_p INTEGER;
    v_effective_max_p INTEGER;
    v_effective_name TEXT;
    v_est_listing NUMERIC;
    v_est_gain NUMERIC;
BEGIN
    -- 1. Validate payload structure
    IF p_payload IS NULL THEN
        RAISE EXCEPTION 'Invalid payload: p_payload cannot be null';
    END IF;

    IF jsonb_typeof(p_payload) = 'array' THEN
        v_items := p_payload;
    ELSIF jsonb_typeof(p_payload) = 'object' AND p_payload ? 'items' AND jsonb_typeof(p_payload->'items') = 'array' THEN
        v_items := p_payload->'items';
    ELSE
        RAISE EXCEPTION 'Invalid payload: expected JSON array of IPO records or object with "items" array';
    END IF;

    -- If empty array, return 0 processed
    IF jsonb_array_length(v_items) = 0 THEN
        RETURN jsonb_build_object('success', true, 'record_count', 0, 'updated_at', v_now);
    END IF;

    -- 2. Iterate each IPO record in the payload within the single atomic transaction
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
    LOOP
        -- Extract and validate required id
        v_id := TRIM(COALESCE(v_item->>'id', ''));
        IF v_id = '' THEN
            RAISE EXCEPTION 'Malformed record: missing required "id" in payload element';
        END IF;

        -- Extract and validate required name
        v_name := TRIM(COALESCE(v_item->>'name', ''));
        IF v_name = '' THEN
            RAISE EXCEPTION 'Malformed record: missing required "name" for IPO id "%"', v_id;
        END IF;

        v_company_name := TRIM(COALESCE(v_item->>'company_name', v_item->>'companyName', v_name));
        v_symbol := TRIM(COALESCE(v_item->>'symbol', ''));
        v_market_type := LOWER(TRIM(COALESCE(v_item->>'market_type', v_item->>'marketType', 'mainboard')));
        v_status := LOWER(TRIM(COALESCE(v_item->>'status', 'upcoming')));
        
        -- Dates
        v_open_date := CASE 
            WHEN NULLIF(TRIM(COALESCE(v_item->>'open_date', v_item->>'openDate')), '') IS NOT NULL 
            THEN (COALESCE(v_item->>'open_date', v_item->>'openDate'))::TIMESTAMPTZ 
            ELSE v_now 
        END;
        v_close_date := CASE 
            WHEN NULLIF(TRIM(COALESCE(v_item->>'close_date', v_item->>'closeDate')), '') IS NOT NULL 
            THEN (COALESCE(v_item->>'close_date', v_item->>'closeDate'))::TIMESTAMPTZ 
            ELSE v_now 
        END;
        v_allotment_date := CASE 
            WHEN NULLIF(TRIM(COALESCE(v_item->>'allotment_date', v_item->>'allotmentDate')), '') IS NOT NULL 
            THEN (COALESCE(v_item->>'allotment_date', v_item->>'allotmentDate'))::TIMESTAMPTZ 
            ELSE NULL 
        END;
        v_listing_date := CASE 
            WHEN NULLIF(TRIM(COALESCE(v_item->>'listing_date', v_item->>'listingDate')), '') IS NOT NULL 
            THEN (COALESCE(v_item->>'listing_date', v_item->>'listingDate'))::TIMESTAMPTZ 
            ELSE NULL 
        END;

        -- Prices and sizes
        v_min_price := COALESCE(NULLIF(TRIM(COALESCE(v_item->>'min_price', v_item->>'minPrice')), '')::NUMERIC::INTEGER, 0);
        v_max_price := COALESCE(NULLIF(TRIM(COALESCE(v_item->>'max_price', v_item->>'maxPrice')), '')::NUMERIC::INTEGER, 0);
        v_lot_size := GREATEST(1, COALESCE(NULLIF(TRIM(COALESCE(v_item->>'lot_size', v_item->>'lotSize')), '')::NUMERIC::INTEGER, 1));
        v_issue_size_crores := NULLIF(TRIM(COALESCE(v_item->>'issue_size_crores', v_item->>'issueSizeCrores')), '')::NUMERIC;
        v_fresh_issue_crores := NULLIF(TRIM(COALESCE(v_item->>'fresh_issue_crores', v_item->>'freshIssueCrores')), '')::NUMERIC;
        v_ofs_crores := NULLIF(TRIM(COALESCE(v_item->>'ofs_crores', v_item->>'ofsCrores')), '')::NUMERIC;

        -- GMP extraction: distinguish explicit 0 (flat/par) from null/unquoted
        IF v_item ? 'gmp' AND jsonb_typeof(v_item->'gmp') != 'null' AND NULLIF(TRIM(v_item->>'gmp'), '') IS NOT NULL THEN
            v_incoming_gmp := (v_item->>'gmp')::NUMERIC::INTEGER;
        ELSE
            v_incoming_gmp := NULL;
        END IF;

        -- Slug resolution
        v_slug := COALESCE(NULLIF(TRIM(COALESCE(v_item->>'slug', '')), ''), v_id);

        -- Source updated at
        v_source_updated_at := CASE 
            WHEN NULLIF(TRIM(COALESCE(v_item->>'source_updated_at', v_item->>'lastUpdated')), '') IS NOT NULL 
            THEN (COALESCE(v_item->>'source_updated_at', v_item->>'lastUpdated'))::TIMESTAMPTZ 
            ELSE v_now 
        END;

        -- Listed status determination
        v_is_listed := (v_status = 'listed' OR (v_listing_date IS NOT NULL AND (v_listing_date AT TIME ZONE 'Asia/Kolkata')::DATE <= v_today_ist));

        -- 3. Upsert ipo_master
        INSERT INTO ipo_master (
            id, name, company_name, symbol, market_type, status,
            open_date, close_date, allotment_date, listing_date,
            min_price, max_price, lot_size, issue_size_crores,
            fresh_issue_crores, ofs_crores,
            gmp, gmp_last_valid_at, slug, source_updated_at, fetched_at, is_stale, last_updated
        ) VALUES (
            v_id, v_name, v_company_name, v_symbol, v_market_type, v_status,
            v_open_date, v_close_date, v_allotment_date, v_listing_date,
            v_min_price, v_max_price, v_lot_size, v_issue_size_crores,
            v_fresh_issue_crores, v_ofs_crores,
            CASE WHEN v_is_listed THEN NULL ELSE v_incoming_gmp END,
            CASE WHEN v_is_listed OR v_incoming_gmp IS NULL THEN NULL ELSE v_now END,
            v_slug, v_source_updated_at, v_now, false, v_now
        )
        ON CONFLICT (id) DO UPDATE SET
            name = COALESCE(NULLIF(EXCLUDED.name, ''), ipo_master.name),
            company_name = COALESCE(NULLIF(EXCLUDED.company_name, ''), ipo_master.company_name),
            symbol = COALESCE(NULLIF(EXCLUDED.symbol, ''), ipo_master.symbol),
            market_type = COALESCE(NULLIF(EXCLUDED.market_type, ''), ipo_master.market_type),
            status = EXCLUDED.status,
            open_date = COALESCE(EXCLUDED.open_date, ipo_master.open_date),
            close_date = COALESCE(EXCLUDED.close_date, ipo_master.close_date),
            allotment_date = COALESCE(EXCLUDED.allotment_date, ipo_master.allotment_date),
            listing_date = COALESCE(EXCLUDED.listing_date, ipo_master.listing_date),
            min_price = CASE WHEN EXCLUDED.min_price > 0 THEN EXCLUDED.min_price ELSE ipo_master.min_price END,
            max_price = CASE WHEN EXCLUDED.max_price > 0 THEN EXCLUDED.max_price ELSE ipo_master.max_price END,
            lot_size = CASE WHEN EXCLUDED.lot_size > 0 THEN EXCLUDED.lot_size ELSE ipo_master.lot_size END,
            issue_size_crores = COALESCE(EXCLUDED.issue_size_crores, ipo_master.issue_size_crores),
            fresh_issue_crores = COALESCE(EXCLUDED.fresh_issue_crores, ipo_master.fresh_issue_crores),
            ofs_crores = COALESCE(EXCLUDED.ofs_crores, ipo_master.ofs_crores),
            gmp = CASE 
                WHEN EXCLUDED.status = 'listed' OR ipo_master.status = 'listed' OR v_is_listed THEN NULL
                WHEN EXCLUDED.gmp IS NOT NULL THEN EXCLUDED.gmp
                WHEN ipo_master.gmp_last_valid_at IS NOT NULL AND ipo_master.gmp_last_valid_at >= (NOW() - INTERVAL '24 hours') THEN ipo_master.gmp
                ELSE NULL
            END,
            gmp_last_valid_at = CASE
                WHEN EXCLUDED.status = 'listed' OR ipo_master.status = 'listed' OR v_is_listed THEN NULL
                WHEN EXCLUDED.gmp IS NOT NULL THEN EXCLUDED.gmp_last_valid_at
                WHEN ipo_master.gmp_last_valid_at IS NOT NULL AND ipo_master.gmp_last_valid_at >= (NOW() - INTERVAL '24 hours') THEN ipo_master.gmp_last_valid_at
                ELSE NULL
            END,
            slug = COALESCE(NULLIF(EXCLUDED.slug, ''), ipo_master.slug),
            source_updated_at = COALESCE(EXCLUDED.source_updated_at, ipo_master.source_updated_at),
            fetched_at = EXCLUDED.fetched_at,
            is_stale = false,
            last_updated = EXCLUDED.last_updated
        RETURNING gmp, gmp_last_valid_at, min_price, max_price, name
        INTO v_effective_gmp, v_effective_gmp_valid_at, v_effective_min_p, v_effective_max_p, v_effective_name;

        -- 4. Calculate projections for ipo_gmp_cache
        v_est_listing := CASE 
            WHEN v_effective_gmp IS NOT NULL AND v_effective_max_p > 0 
            THEN (v_effective_max_p + v_effective_gmp) 
            ELSE NULL 
        END;

        v_est_gain := CASE 
            WHEN v_effective_gmp IS NOT NULL AND v_effective_max_p > 0 
            THEN ROUND(((v_effective_gmp::NUMERIC / v_effective_max_p::NUMERIC) * 100), 2) 
            ELSE NULL 
        END;

        -- 5. Upsert ipo_gmp_cache in the exact same transaction
        INSERT INTO ipo_gmp_cache (
            id, ipo_id, slug, ipo_name,
            price_band_min, price_band_max, gmp_raw, gmp_last_valid_at,
            estimated_listing_price, estimated_gain_percentage,
            source_updated_at, fetched_at, expires_at, is_stale, updated_at
        ) VALUES (
            'gmp_' || v_slug, v_id, v_slug, v_effective_name,
            v_effective_min_p, v_effective_max_p, v_effective_gmp, v_effective_gmp_valid_at,
            v_est_listing, v_est_gain,
            v_source_updated_at, v_now, v_expires_at, false, v_now
        )
        ON CONFLICT (slug) DO UPDATE SET
            ipo_id = EXCLUDED.ipo_id,
            ipo_name = EXCLUDED.ipo_name,
            price_band_min = EXCLUDED.price_band_min,
            price_band_max = EXCLUDED.price_band_max,
            gmp_raw = EXCLUDED.gmp_raw,
            gmp_last_valid_at = EXCLUDED.gmp_last_valid_at,
            estimated_listing_price = EXCLUDED.estimated_listing_price,
            estimated_gain_percentage = EXCLUDED.estimated_gain_percentage,
            source_updated_at = EXCLUDED.source_updated_at,
            fetched_at = EXCLUDED.fetched_at,
            expires_at = EXCLUDED.expires_at,
            is_stale = false,
            updated_at = EXCLUDED.updated_at;

        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'record_count', v_count,
        'updated_at', v_now
    );
END;
$$;

-- Restrict batch execution strictly to service_role
REVOKE EXECUTE ON FUNCTION kith_upsert_ipo_batch(JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION kith_upsert_ipo_batch(JSONB) TO service_role;
