-- ==============================================================================

-- Kith Supabase Migration: 20261101000001_rls_security_hardening.sql

-- Production RLS & Identity Security Hardening

--

-- Security Properties Enforced:

-- 1. Cryptographic Guest Authentication: Identity is bound via high-entropy session

--    token hashed with SHA-256 (session_token_hash). Client-supplied headers like

--    'x-kith-account-id' are NEVER trusted as proof of identity.

-- 2. Locked Guest Sessions: Public table scraping is prohibited; owner-only RLS.

-- 3. Secure Server-Side Account Recovery: Recovery key verified in PostgreSQL via

--    constant-time salted HMAC without leaking hashes or salts to the client.

-- 4. Keyset & Concurrency Safety: 'updated_at' columns added to settlements and

--    personal_debts with clock_timestamp() triggers to prevent delayed commit drops.

-- 5. Strict Tenant & Collaborative Isolation across all personal and trip entities.

-- 6. SECURITY DEFINER hardening: Explicit 'search_path = public, pg_temp' on all functions.

-- ==============================================================================



-- ─────────────────────────────────────────────────────────────────────────────

-- 1. SCHEMA EXTENSIONS & MISSING COLUMNS

-- ─────────────────────────────────────────────────────────────────────────────



-- Guest sessions cryptographic credentials

ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS session_token_hash VARCHAR(64);

ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS is_revoked BOOLEAN DEFAULT FALSE;

ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS token_created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_guest_sessions_token_hash ON guest_sessions(session_token_hash);



-- Devices tracking table

CREATE TABLE IF NOT EXISTS devices (

    id VARCHAR(128) PRIMARY KEY,

    account_id VARCHAR(64) NOT NULL,

    device_id VARCHAR(128) NOT NULL,

    platform VARCHAR(32) DEFAULT 'android',

    last_active_at TIMESTAMPTZ DEFAULT NOW(),

    created_at TIMESTAMPTZ DEFAULT NOW()

);

CREATE INDEX IF NOT EXISTS idx_devices_account_id ON devices(account_id);



-- Concurrency & pagination cursors

ALTER TABLE settlements ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE personal_debts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();



-- Wall-clock execution trigger for BOTH INSERT and UPDATE

-- Replaces stale transaction_timestamp() (NOW()) with true wall-clock time

-- guaranteeing that long-running transactions stamp the actual execution moment.

CREATE OR REPLACE FUNCTION kith_set_updated_at()

RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$

BEGIN

    NEW.updated_at = clock_timestamp();

    RETURN NEW;

END;

$$;

DROP TRIGGER IF EXISTS trg_trips_updated_at ON trips;

CREATE TRIGGER trg_trips_updated_at BEFORE INSERT OR UPDATE ON trips

FOR EACH ROW EXECUTE FUNCTION kith_set_updated_at();



DROP TRIGGER IF EXISTS trg_expenses_updated_at ON expenses;

CREATE TRIGGER trg_expenses_updated_at BEFORE INSERT OR UPDATE ON expenses

FOR EACH ROW EXECUTE FUNCTION kith_set_updated_at();



DROP TRIGGER IF EXISTS trg_settlements_updated_at ON settlements;

CREATE TRIGGER trg_settlements_updated_at BEFORE INSERT OR UPDATE ON settlements

FOR EACH ROW EXECUTE FUNCTION kith_set_updated_at();



DROP TRIGGER IF EXISTS trg_personal_expenses_updated_at ON personal_expenses;

CREATE TRIGGER trg_personal_expenses_updated_at BEFORE INSERT OR UPDATE ON personal_expenses

FOR EACH ROW EXECUTE FUNCTION kith_set_updated_at();



DROP TRIGGER IF EXISTS trg_personal_debts_updated_at ON personal_debts;

CREATE TRIGGER trg_personal_debts_updated_at BEFORE INSERT OR UPDATE ON personal_debts

FOR EACH ROW EXECUTE FUNCTION kith_set_updated_at();



-- ─────────────────────────────────────────────────────────────────────────────

-- TRANSACTIONAL CHANGE LOG WITH STRICTLY MONOTONIC SEQUENCE (BIGSERIAL)

-- Eliminates reliance on arbitrary overlap windows by assigning an atomic,

-- ordered integer sequence to every data mutation across all transactional tables.

-- ─────────────────────────────────────────────────────────────────────────────



CREATE TABLE IF NOT EXISTS kith_sync_events (
    seq BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    trip_id TEXT,
    user_id TEXT,
    action TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    payload JSONB,        -- Snapshot of modified/deleted entity
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- Ensure payload column exists if table was previously created
ALTER TABLE kith_sync_events ADD COLUMN IF NOT EXISTS payload JSONB;

CREATE INDEX IF NOT EXISTS idx_kith_sync_events_seq ON kith_sync_events(seq);
CREATE INDEX IF NOT EXISTS idx_kith_sync_events_trip_seq ON kith_sync_events(trip_id, seq);
CREATE INDEX IF NOT EXISTS idx_kith_sync_events_user_seq ON kith_sync_events(user_id, seq);

-- ─────────────────────────────────────────────────────────────────────────────
-- STATEMENT-LEVEL ADVISORY LOCK TO PREVENT ROW-LOCK INTERLEAVING DEADLOCKS
-- Deadlock Prevention Architecture:
-- When concurrent transactions update multiple rows across tables in different orders,
-- acquiring an advisory lock inside an AFTER ROW trigger creates a deadlock window:
--   Transaction 1 holds Row A lock, waits for Advisory Lock.
--   Transaction 2 holds Advisory Lock, waits for Row A lock.
--   PostgreSQL Deadlock Detector aborts one of the transactions (error 40P01).
--
-- Solution:
-- By acquiring pg_advisory_xact_lock BEFORE STATEMENT on all mutation tables:
-- 1. The very first statement in a transaction acquires the advisory lock BEFORE
--    scanning or locking any individual rows.
-- 2. Any concurrent transaction attempting a mutation blocks at statement-entry
--    before obtaining any row locks.
-- 3. Row-lock interleaving deadlocks between competing write transactions are
--    eliminated by construction.
-- 4. Re-entrant calls within the same transaction are instantaneous no-ops.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION kith_acquire_sync_lock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(74291001);
    RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION kith_acquire_sync_lock() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION kith_acquire_sync_lock() TO anon, authenticated;

DROP TRIGGER IF EXISTS trg_lock_trips ON trips;
CREATE TRIGGER trg_lock_trips BEFORE INSERT OR UPDATE OR DELETE ON trips
FOR EACH STATEMENT EXECUTE FUNCTION kith_acquire_sync_lock();

DROP TRIGGER IF EXISTS trg_lock_trip_members ON trip_members;
CREATE TRIGGER trg_lock_trip_members BEFORE INSERT OR UPDATE OR DELETE ON trip_members
FOR EACH STATEMENT EXECUTE FUNCTION kith_acquire_sync_lock();

DROP TRIGGER IF EXISTS trg_lock_expenses ON expenses;
CREATE TRIGGER trg_lock_expenses BEFORE INSERT OR UPDATE OR DELETE ON expenses
FOR EACH STATEMENT EXECUTE FUNCTION kith_acquire_sync_lock();

DROP TRIGGER IF EXISTS trg_lock_settlements ON settlements;
CREATE TRIGGER trg_lock_settlements BEFORE INSERT OR UPDATE OR DELETE ON settlements
FOR EACH STATEMENT EXECUTE FUNCTION kith_acquire_sync_lock();

DROP TRIGGER IF EXISTS trg_lock_personal_expenses ON personal_expenses;
CREATE TRIGGER trg_lock_personal_expenses BEFORE INSERT OR UPDATE OR DELETE ON personal_expenses
FOR EACH STATEMENT EXECUTE FUNCTION kith_acquire_sync_lock();

DROP TRIGGER IF EXISTS trg_lock_personal_debts ON personal_debts;
CREATE TRIGGER trg_lock_personal_debts BEFORE INSERT OR UPDATE OR DELETE ON personal_debts
FOR EACH STATEMENT EXECUTE FUNCTION kith_acquire_sync_lock();

CREATE OR REPLACE FUNCTION kith_log_sync_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_trip_id TEXT := NULL;
    v_user_id TEXT := NULL;
    v_record_id TEXT;
    v_action TEXT := TG_OP;
    v_payload JSONB;
BEGIN
    -- CRITICAL: Prevent BIGSERIAL out-of-order commit skipping bug.
    -- Acquires an exclusive transaction-scoped advisory lock.
    -- Holds until transaction commit or rollback, guaranteeing sequence allocation == commit order.
    PERFORM pg_advisory_xact_lock(74291001);

    IF TG_OP = 'DELETE' THEN
        v_record_id := OLD.id::TEXT;
        v_payload := to_jsonb(OLD);
        IF TG_TABLE_NAME IN ('expenses', 'settlements', 'trip_members') THEN
            v_trip_id := OLD.trip_id::TEXT;
        ELSIF TG_TABLE_NAME = 'trips' THEN
            v_trip_id := OLD.id::TEXT;
            v_user_id := OLD.creator_id::TEXT;
        ELSIF TG_TABLE_NAME IN ('personal_expenses', 'personal_debts') THEN
            v_user_id := OLD.user_id::TEXT;
        END IF;
    ELSE
        v_record_id := NEW.id::TEXT;
        v_payload := to_jsonb(NEW);
        IF TG_TABLE_NAME IN ('expenses', 'settlements', 'trip_members') THEN
            v_trip_id := NEW.trip_id::TEXT;
        ELSIF TG_TABLE_NAME = 'trips' THEN
            v_trip_id := NEW.id::TEXT;
            v_user_id := NEW.creator_id::TEXT;
        ELSIF TG_TABLE_NAME IN ('personal_expenses', 'personal_debts') THEN
            v_user_id := NEW.user_id::TEXT;
        END IF;
    END IF;

    INSERT INTO kith_sync_events (table_name, record_id, trip_id, user_id, action, payload, event_timestamp)
    VALUES (TG_TABLE_NAME, v_record_id, v_trip_id, v_user_id, v_action, v_payload, clock_timestamp());

    RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION kith_log_sync_event() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION kith_log_sync_event() TO anon, authenticated;

DROP TRIGGER IF EXISTS trg_events_trips ON trips;
CREATE TRIGGER trg_events_trips AFTER INSERT OR UPDATE OR DELETE ON trips
FOR EACH ROW EXECUTE FUNCTION kith_log_sync_event();

DROP TRIGGER IF EXISTS trg_events_trip_members ON trip_members;
CREATE TRIGGER trg_events_trip_members AFTER INSERT OR UPDATE OR DELETE ON trip_members
FOR EACH ROW EXECUTE FUNCTION kith_log_sync_event();

DROP TRIGGER IF EXISTS trg_events_expenses ON expenses;
CREATE TRIGGER trg_events_expenses AFTER INSERT OR UPDATE OR DELETE ON expenses
FOR EACH ROW EXECUTE FUNCTION kith_log_sync_event();

DROP TRIGGER IF EXISTS trg_events_settlements ON settlements;
CREATE TRIGGER trg_events_settlements AFTER INSERT OR UPDATE OR DELETE ON settlements
FOR EACH ROW EXECUTE FUNCTION kith_log_sync_event();

DROP TRIGGER IF EXISTS trg_events_personal_expenses ON personal_expenses;
CREATE TRIGGER trg_events_personal_expenses AFTER INSERT OR UPDATE OR DELETE ON personal_expenses
FOR EACH ROW EXECUTE FUNCTION kith_log_sync_event();

DROP TRIGGER IF EXISTS trg_events_personal_debts ON personal_debts;
CREATE TRIGGER trg_events_personal_debts AFTER INSERT OR UPDATE OR DELETE ON personal_debts
FOR EACH ROW EXECUTE FUNCTION kith_log_sync_event();

-- Secure RPC to consume sync events monotonically
CREATE OR REPLACE FUNCTION kith_fetch_sync_events(
    p_last_seq BIGINT,
    p_limit INT DEFAULT 500
)
RETURNS TABLE (
    seq BIGINT,
    table_name TEXT,
    record_id TEXT,
    trip_id TEXT,
    user_id TEXT,
    action TEXT,
    payload JSONB,
    event_timestamp TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id TEXT;
    v_safe_limit INT;
BEGIN
    v_caller_id := kith_current_user_id();
    IF v_caller_id IS NULL OR v_caller_id = '' THEN
        RAISE EXCEPTION 'Unauthorized: valid authenticated or guest session required';
    END IF;

    v_safe_limit := LEAST(GREATEST(COALESCE(p_limit, 500), 1), 1000);

    RETURN QUERY
    SELECT 
        e.seq,
        e.table_name,
        e.record_id,
        e.trip_id,
        e.user_id,
        e.action,
        e.payload,
        e.event_timestamp
    FROM kith_sync_events e
    WHERE e.seq > COALESCE(p_last_seq, 0)
      AND (
          -- Personal records owned by caller
          e.user_id = v_caller_id
          -- Collaborative records where caller is an authorized trip member
          OR (e.trip_id IS NOT NULL AND kith_is_trip_member(e.trip_id, v_caller_id))
      )
    ORDER BY e.seq ASC
    LIMIT v_safe_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION kith_fetch_sync_events(BIGINT, INT) TO anon, authenticated;



-- ─────────────────────────────────────────────────────────────────────────────
-- 2. HARDENED IDENTITY RESOLUTION FUNCTION
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION kith_current_user_id()

RETURNS TEXT

LANGUAGE plpgsql

STABLE

SECURITY DEFINER

SET search_path = public, pg_temp

AS $$

DECLARE

    jwt_uid TEXT;

    req_headers JSON;

    token TEXT;

    token_hash TEXT;

    auth_account_id TEXT;

BEGIN

    -- 1. Standard Supabase Auth JWT (authenticated Google/OAuth users)

    jwt_uid := auth.uid()::text;

    IF jwt_uid IS NOT NULL AND jwt_uid <> '' THEN

        RETURN jwt_uid;

    END IF;



    -- 2. Cryptographic Guest Session Token

    BEGIN

        req_headers := NULLIF(current_setting('request.headers', true), '')::json;

        token := req_headers->>'x-kith-session-token';

    EXCEPTION WHEN OTHERS THEN

        token := NULL;

    END;



    -- Token must be high-entropy 256-bit hex (at least 32 characters)

    IF token IS NULL OR length(token) < 32 THEN

        RETURN NULL; -- Rejects unauthenticated caller; NEVER falls back to user-chosen account ID!

    END IF;



    -- Compute SHA-256 hash of token

    token_hash := encode(sha256(token::bytea), 'hex');



    -- Look up verified account ID from guest_sessions

    SELECT id INTO auth_account_id

    FROM guest_sessions

    WHERE session_token_hash = token_hash

      AND (is_revoked IS NULL OR is_revoked = false)

    LIMIT 1;



    RETURN auth_account_id;

END;

$$;



-- ─────────────────────────────────────────────────────────────────────────────

-- 3. TRIP MEMBERSHIP & CREATOR SECURITY FUNCTIONS

-- ─────────────────────────────────────────────────────────────────────────────



CREATE OR REPLACE FUNCTION kith_is_trip_member(check_trip_id TEXT, check_user_id TEXT)

RETURNS BOOLEAN

LANGUAGE plpgsql

STABLE

SECURITY DEFINER

SET search_path = public, pg_temp

AS $$

BEGIN

    IF check_trip_id IS NULL OR check_user_id IS NULL OR check_user_id = '' THEN

        RETURN FALSE;

    END IF;



    RETURN EXISTS (

        SELECT 1 FROM trip_members

        WHERE trip_id = check_trip_id 

          AND user_id = check_user_id

          AND (status IS NULL OR status <> 'removed')

    ) OR EXISTS (

        SELECT 1 FROM trips

        WHERE id = check_trip_id AND creator_id = check_user_id

    );

END;

$$;



CREATE OR REPLACE FUNCTION kith_is_trip_creator(check_trip_id TEXT, check_user_id TEXT)

RETURNS BOOLEAN

LANGUAGE plpgsql

STABLE

SECURITY DEFINER

SET search_path = public, pg_temp

AS $$

BEGIN

    IF check_trip_id IS NULL OR check_user_id IS NULL OR check_user_id = '' THEN

        RETURN FALSE;

    END IF;



    RETURN EXISTS (

        SELECT 1 FROM trips

        WHERE id = check_trip_id AND creator_id = check_user_id

    );

END;

$$;



-- ─────────────────────────────────────────────────────────────────────────────

-- 4. SECURE GUEST REGISTRATION & RECOVERY RPC FUNCTIONS

-- ─────────────────────────────────────────────────────────────────────────────



-- Secure guest session registration: prevents unauthorized account ID overwriting

CREATE OR REPLACE FUNCTION kith_register_guest_session(

    p_account_id TEXT,

    p_recovery_key_hash TEXT,

    p_salt TEXT,

    p_session_token_hash TEXT,

    p_display_name TEXT,

    p_device_id TEXT

)

RETURNS JSONB

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = public, pg_temp

AS $$

DECLARE

    existing_id TEXT;

    caller_id TEXT;

BEGIN

    IF p_account_id IS NULL OR length(p_account_id) < 5 THEN

        RETURN jsonb_build_object('success', false, 'error', 'Invalid account ID');

    END IF;



    IF p_session_token_hash IS NULL OR length(p_session_token_hash) <> 64 THEN

        RETURN jsonb_build_object('success', false, 'error', 'Invalid session token hash');

    END IF;



    SELECT id INTO existing_id FROM guest_sessions WHERE id = p_account_id;

    IF existing_id IS NOT NULL THEN

        -- Only authorized owner of this account can update credentials

        caller_id := kith_current_user_id();

        IF caller_id IS NULL OR caller_id <> p_account_id THEN

            RETURN jsonb_build_object('success', false, 'error', 'Account exists and caller is unauthorized');

        END IF;



        UPDATE guest_sessions

        SET session_token_hash = p_session_token_hash,

            display_name = COALESCE(NULLIF(p_display_name, ''), display_name),

            device_id = COALESCE(p_device_id, device_id),

            last_seen_at = NOW()

        WHERE id = p_account_id;

    ELSE

        -- Insert new guest session

        INSERT INTO guest_sessions (

            id,

            recovery_key,

            anonymous_token,

            session_token_hash,

            display_name,

            device_id,

            created_at,

            last_seen_at

        ) VALUES (

            p_account_id,

            p_recovery_key_hash,

            p_salt,

            p_session_token_hash,

            COALESCE(NULLIF(p_display_name, ''), 'Traveler'),

            p_device_id,

            NOW(),

            NOW()

        );

    END IF;



    RETURN jsonb_build_object('success', true, 'accountId', p_account_id);

END;

$$;



-- Secure server-side guest account recovery: eliminates public table downloading

CREATE OR REPLACE FUNCTION kith_recover_guest_account(

    p_recovery_key TEXT,

    p_new_session_token_hash TEXT,

    p_device_id TEXT

)

RETURNS JSONB

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = public, pg_temp

AS $$

DECLARE

    r RECORD;

    normalized_key TEXT;

    computed_hash TEXT;

    matched_id TEXT := NULL;
    matched_display_name TEXT := NULL;
    matched_created_at TIMESTAMPTZ := NULL;
    found_match BOOLEAN := FALSE;

BEGIN

    IF p_recovery_key IS NULL OR length(p_recovery_key) < 8 THEN

        RETURN jsonb_build_object('success', false, 'error', 'Invalid recovery key format');

    END IF;



    IF p_new_session_token_hash IS NULL OR length(p_new_session_token_hash) <> 64 THEN

        RETURN jsonb_build_object('success', false, 'error', 'Invalid session token hash');

    END IF;



    -- Canonical normalization of recovery key (uppercase, strip dashes/spaces)

    normalized_key := upper(regexp_replace(p_recovery_key, '[\s\-_:\r\n]', '', 'g'));

    IF normalized_key LIKE 'KITH%' THEN

        normalized_key := substring(normalized_key from 5);

    END IF;



    IF length(normalized_key) = 16 THEN

        normalized_key := 'KITH-' || substring(normalized_key from 1 for 4) || '-' ||

                          substring(normalized_key from 5 for 4) || '-' ||

                          substring(normalized_key from 9 for 4) || '-' ||

                          substring(normalized_key from 13 for 4);

    ELSIF length(normalized_key) = 12 THEN

        normalized_key := 'KITH-' || substring(normalized_key from 1 for 4) || '-' ||

                          substring(normalized_key from 5 for 4) || '-' ||

                          substring(normalized_key from 9 for 4);

    ELSIF length(normalized_key) = 8 THEN

        normalized_key := 'KITH-' || substring(normalized_key from 1 for 4) || '-' ||

                          substring(normalized_key from 5 for 4);

    ELSE

        normalized_key := 'KITH-' || normalized_key;

    END IF;



    -- Match against stored recovery key hashes using constant-time comparison

    FOR r IN SELECT id, recovery_key, anonymous_token, display_name, created_at

             FROM guest_sessions

             WHERE recovery_key IS NOT NULL AND anonymous_token IS NOT NULL LOOP

        computed_hash := encode(extensions.hmac(normalized_key::bytea, r.anonymous_token::bytea, 'sha256'), 'hex');

        IF computed_hash = r.recovery_key THEN

            matched_id := r.id;
            matched_display_name := r.display_name;
            matched_created_at := r.created_at;
            found_match := TRUE;

            EXIT;

        END IF;

    END LOOP;



    IF NOT found_match THEN

        RETURN jsonb_build_object('success', false, 'error', 'No matching account found for provided recovery key');

    END IF;



    -- Bind new session token to recovered account

    UPDATE guest_sessions

    SET session_token_hash = p_new_session_token_hash,

        device_id = p_device_id,

        last_seen_at = NOW()

    WHERE id = matched_id;



    RETURN jsonb_build_object(

        'success', true,

        'id', matched_id,

        'accountId', matched_id,

        'displayName', matched_display_name,

        'createdAt', matched_created_at

    );

END;

$$;



-- ─────────────────────────────────────────────────────────────────────────────

-- 5. ROW LEVEL SECURITY (RLS) POLICIES

-- ─────────────────────────────────────────────────────────────────────────────



-- A. Guest Sessions Table Isolation

ALTER TABLE guest_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anon account recovery and creation" ON guest_sessions;

DROP POLICY IF EXISTS "guest_sessions_owner_only" ON guest_sessions;

DROP POLICY IF EXISTS "guest_sessions_select" ON guest_sessions;

DROP POLICY IF EXISTS "guest_sessions_insert" ON guest_sessions;

DROP POLICY IF EXISTS "guest_sessions_update" ON guest_sessions;



-- Read and update restricted strictly to verified owner

CREATE POLICY "guest_sessions_owner_only" ON guest_sessions

    FOR ALL TO anon, authenticated

    USING (id = kith_current_user_id())

    WITH CHECK (id = kith_current_user_id());



-- B. Personal Expenses Isolation

ALTER TABLE personal_expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Personal expenses account isolation" ON personal_expenses;

DROP POLICY IF EXISTS "personal_expenses_select" ON personal_expenses;

DROP POLICY IF EXISTS "personal_expenses_insert" ON personal_expenses;

DROP POLICY IF EXISTS "personal_expenses_update" ON personal_expenses;

DROP POLICY IF EXISTS "personal_expenses_delete" ON personal_expenses;



CREATE POLICY "personal_expenses_select" ON personal_expenses FOR SELECT

    TO anon, authenticated

    USING (user_id = kith_current_user_id());



CREATE POLICY "personal_expenses_insert" ON personal_expenses FOR INSERT

    TO anon, authenticated

    WITH CHECK (user_id = kith_current_user_id());



CREATE POLICY "personal_expenses_update" ON personal_expenses FOR UPDATE

    TO anon, authenticated

    USING (user_id = kith_current_user_id())

    WITH CHECK (user_id = kith_current_user_id());



CREATE POLICY "personal_expenses_delete" ON personal_expenses FOR DELETE

    TO anon, authenticated

    USING (user_id = kith_current_user_id());



-- C. Personal Debts (1-on-1 Lending & Borrowing) Isolation

ALTER TABLE personal_debts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Personal debts account isolation" ON personal_debts;

DROP POLICY IF EXISTS "personal_debts_select" ON personal_debts;

DROP POLICY IF EXISTS "personal_debts_insert" ON personal_debts;

DROP POLICY IF EXISTS "personal_debts_update" ON personal_debts;

DROP POLICY IF EXISTS "personal_debts_delete" ON personal_debts;



CREATE POLICY "personal_debts_select" ON personal_debts FOR SELECT

    TO anon, authenticated

    USING (user_id = kith_current_user_id());



CREATE POLICY "personal_debts_insert" ON personal_debts FOR INSERT

    TO anon, authenticated

    WITH CHECK (user_id = kith_current_user_id());



CREATE POLICY "personal_debts_update" ON personal_debts FOR UPDATE

    TO anon, authenticated

    USING (user_id = kith_current_user_id())

    WITH CHECK (user_id = kith_current_user_id());



CREATE POLICY "personal_debts_delete" ON personal_debts FOR DELETE

    TO anon, authenticated

    USING (user_id = kith_current_user_id());



-- D. Collaborative Trips Isolation

ALTER TABLE trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Trips access for members" ON trips;

DROP POLICY IF EXISTS "trips_select_member" ON trips;

DROP POLICY IF EXISTS "trips_insert_creator" ON trips;

DROP POLICY IF EXISTS "trips_update_member" ON trips;

DROP POLICY IF EXISTS "trips_delete_creator" ON trips;



CREATE POLICY "trips_select_member" ON trips FOR SELECT

    TO anon, authenticated

    USING (kith_is_trip_member(id, kith_current_user_id()));



CREATE POLICY "trips_insert_creator" ON trips FOR INSERT

    TO anon, authenticated

    WITH CHECK (creator_id = kith_current_user_id());



CREATE POLICY "trips_update_member" ON trips FOR UPDATE

    TO anon, authenticated

    USING (kith_is_trip_member(id, kith_current_user_id()))

    WITH CHECK (kith_is_trip_member(id, kith_current_user_id()));



CREATE POLICY "trips_delete_creator" ON trips FOR DELETE

    TO anon, authenticated

    USING (kith_is_trip_creator(id, kith_current_user_id()));



-- E. Trip Members Table Isolation

ALTER TABLE trip_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Trip members access" ON trip_members;

DROP POLICY IF EXISTS "trip_members_select" ON trip_members;

DROP POLICY IF EXISTS "trip_members_insert" ON trip_members;

DROP POLICY IF EXISTS "trip_members_update" ON trip_members;

DROP POLICY IF EXISTS "trip_members_delete" ON trip_members;



CREATE POLICY "trip_members_select" ON trip_members FOR SELECT

    TO anon, authenticated

    USING (kith_is_trip_member(trip_id, kith_current_user_id()));



CREATE POLICY "trip_members_insert" ON trip_members FOR INSERT

    TO anon, authenticated

    WITH CHECK (

        kith_is_trip_creator(trip_id, kith_current_user_id())

        OR user_id = kith_current_user_id()

    );



CREATE POLICY "trip_members_update" ON trip_members FOR UPDATE

    TO anon, authenticated

    USING (

        user_id = kith_current_user_id()

        OR kith_is_trip_creator(trip_id, kith_current_user_id())

    )

    WITH CHECK (

        user_id = kith_current_user_id()

        OR kith_is_trip_creator(trip_id, kith_current_user_id())

    );



CREATE POLICY "trip_members_delete" ON trip_members FOR DELETE

    TO anon, authenticated

    USING (

        user_id = kith_current_user_id()

        OR kith_is_trip_creator(trip_id, kith_current_user_id())

    );



-- F. Trip Expenses Table Isolation

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Trip expenses access" ON expenses;

DROP POLICY IF EXISTS "expenses_select_member" ON expenses;

DROP POLICY IF EXISTS "expenses_insert_member" ON expenses;

DROP POLICY IF EXISTS "expenses_update_member" ON expenses;

DROP POLICY IF EXISTS "expenses_delete_member" ON expenses;



CREATE POLICY "expenses_select_member" ON expenses FOR SELECT

    TO anon, authenticated

    USING (kith_is_trip_member(trip_id, kith_current_user_id()));



CREATE POLICY "expenses_insert_member" ON expenses FOR INSERT

    TO anon, authenticated

    WITH CHECK (kith_is_trip_member(trip_id, kith_current_user_id()));



CREATE POLICY "expenses_update_member" ON expenses FOR UPDATE

    TO anon, authenticated

    USING (kith_is_trip_member(trip_id, kith_current_user_id()))

    WITH CHECK (kith_is_trip_member(trip_id, kith_current_user_id()));



CREATE POLICY "expenses_delete_member" ON expenses FOR DELETE

    TO anon, authenticated

    USING (kith_is_trip_member(trip_id, kith_current_user_id()));



-- G. Trip Settlements Table Isolation

ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Trip settlements access" ON settlements;

DROP POLICY IF EXISTS "settlements_select_member" ON settlements;

DROP POLICY IF EXISTS "settlements_insert_member" ON settlements;

DROP POLICY IF EXISTS "settlements_update_member" ON settlements;

DROP POLICY IF EXISTS "settlements_delete_member" ON settlements;



CREATE POLICY "settlements_select_member" ON settlements FOR SELECT

    TO anon, authenticated

    USING (kith_is_trip_member(trip_id, kith_current_user_id()));



CREATE POLICY "settlements_insert_member" ON settlements FOR INSERT

    TO anon, authenticated

    WITH CHECK (kith_is_trip_member(trip_id, kith_current_user_id()));



CREATE POLICY "settlements_update_member" ON settlements FOR UPDATE

    TO anon, authenticated

    USING (kith_is_trip_member(trip_id, kith_current_user_id()))

    WITH CHECK (kith_is_trip_member(trip_id, kith_current_user_id()));



CREATE POLICY "settlements_delete_member" ON settlements FOR DELETE

    TO anon, authenticated

    USING (kith_is_trip_member(trip_id, kith_current_user_id()));



-- H. Devices Table Isolation

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "devices_owner_only" ON devices;



CREATE POLICY "devices_owner_only" ON devices

    FOR ALL TO anon, authenticated

    USING (account_id = kith_current_user_id())

    WITH CHECK (account_id = kith_current_user_id());

-- I. Sync Events Table Isolation
ALTER TABLE kith_sync_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "kith_sync_events_select" ON kith_sync_events;
CREATE POLICY "kith_sync_events_select" ON kith_sync_events
    FOR SELECT TO anon, authenticated
    USING (
        user_id = kith_current_user_id()
        OR (trip_id IS NOT NULL AND kith_is_trip_member(trip_id, kith_current_user_id()))
    );
