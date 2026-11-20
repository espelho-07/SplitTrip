-- ==============================================================================
-- KITH SUPABASE MIGRATION: 20261120000004_smart_trip_completion_and_member_consent.sql
-- Description: Smart Trip Completion & Member Consent System
-- Authoritative presence tracking, consent requests, reopening workflow,
-- and lifecycle history audit log.
-- ==============================================================================

-- 1. Extend trip_members with heartbeat tracking
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS last_heartbeat_at TIMESTAMPTZ;

-- 2. Extend trips with completion metadata if missing
ALTER TABLE trips ADD COLUMN IF NOT EXISTS completion_mode VARCHAR(64) DEFAULT 'normal';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS completed_by VARCHAR(64);

-- 3. Table: trip_completion_requests
CREATE TABLE IF NOT EXISTS trip_completion_requests (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    member_id VARCHAR(64) NOT NULL REFERENCES trip_members(id) ON DELETE CASCADE,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    requested_by VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'CONFIRMED_AVAILABLE', 'UNAVAILABLE', 'EXPIRED', 'CANCELLED')),
    response VARCHAR(16) CHECK (response IN ('YES', 'NO')),
    response_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
    responded_at TIMESTAMPTZ,
    version INT NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_completion_req_trip ON trip_completion_requests(trip_id);
CREATE INDEX IF NOT EXISTS idx_completion_req_member ON trip_completion_requests(member_id);
CREATE INDEX IF NOT EXISTS idx_completion_req_user ON trip_completion_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_completion_req_status ON trip_completion_requests(status);

-- 4. Table: trip_reopening_requests
CREATE TABLE IF NOT EXISTS trip_reopening_requests (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    requested_by VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason_category VARCHAR(32) NOT NULL CHECK (reason_category IN ('MISSING_EXPENSE', 'INCORRECT_PAYER', 'WRONG_SPLIT', 'PAYMENT_DISPUTE', 'OTHER')),
    note TEXT,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
    reviewed_by VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    review_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reopening_req_trip ON trip_reopening_requests(trip_id);
CREATE INDEX IF NOT EXISTS idx_reopening_req_user ON trip_reopening_requests(requested_by);

-- 5. Table: trip_lifecycle_history
CREATE TABLE IF NOT EXISTS trip_lifecycle_history (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    previous_status VARCHAR(32) NOT NULL,
    new_status VARCHAR(32) NOT NULL,
    changed_by VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT,
    related_request_id VARCHAR(64),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lifecycle_history_trip ON trip_lifecycle_history(trip_id);

-- 6. Enable Row Level Security
ALTER TABLE trip_completion_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_reopening_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_lifecycle_history ENABLE ROW LEVEL SECURITY;

-- 7. RLS Policies for trip_completion_requests
DROP POLICY IF EXISTS "trip_completion_requests_select" ON trip_completion_requests;
CREATE POLICY "trip_completion_requests_select" ON trip_completion_requests
    FOR SELECT TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM trip_members tm
            WHERE tm.trip_id = trip_completion_requests.trip_id
            AND tm.user_id = kith_current_user_id()
        )
    );

DROP POLICY IF EXISTS "trip_completion_requests_insert" ON trip_completion_requests;
CREATE POLICY "trip_completion_requests_insert" ON trip_completion_requests
    FOR INSERT TO anon, authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM trips t
            WHERE t.id = trip_completion_requests.trip_id
            AND t.creator_id = kith_current_user_id()
        )
    );

DROP POLICY IF EXISTS "trip_completion_requests_update" ON trip_completion_requests;
CREATE POLICY "trip_completion_requests_update" ON trip_completion_requests
    FOR UPDATE TO anon, authenticated
    USING (
        trip_completion_requests.user_id = kith_current_user_id()
        OR EXISTS (
            SELECT 1 FROM trips t
            WHERE t.id = trip_completion_requests.trip_id
            AND t.creator_id = kith_current_user_id()
        )
    );

-- 8. RLS Policies for trip_reopening_requests
DROP POLICY IF EXISTS "trip_reopening_requests_select" ON trip_reopening_requests;
CREATE POLICY "trip_reopening_requests_select" ON trip_reopening_requests
    FOR SELECT TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM trip_members tm
            WHERE tm.trip_id = trip_reopening_requests.trip_id
            AND tm.user_id = kith_current_user_id()
        )
    );

DROP POLICY IF EXISTS "trip_reopening_requests_insert" ON trip_reopening_requests;
CREATE POLICY "trip_reopening_requests_insert" ON trip_reopening_requests
    FOR INSERT TO anon, authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM trip_members tm
            WHERE tm.trip_id = trip_reopening_requests.trip_id
            AND tm.user_id = kith_current_user_id()
        )
    );

DROP POLICY IF EXISTS "trip_reopening_requests_update" ON trip_reopening_requests;
CREATE POLICY "trip_reopening_requests_update" ON trip_reopening_requests
    FOR UPDATE TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM trips t
            WHERE t.id = trip_reopening_requests.trip_id
            AND t.creator_id = kith_current_user_id()
        )
    );

-- 9. RLS Policies for trip_lifecycle_history
DROP POLICY IF EXISTS "trip_lifecycle_history_select" ON trip_lifecycle_history;
CREATE POLICY "trip_lifecycle_history_select" ON trip_lifecycle_history
    FOR SELECT TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM trip_members tm
            WHERE tm.trip_id = trip_lifecycle_history.trip_id
            AND tm.user_id = kith_current_user_id()
        )
    );

-- 10. Authoritative Presence & Heartbeat RPC
CREATE OR REPLACE FUNCTION kith_record_member_heartbeat(
    p_trip_id VARCHAR(64)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid VARCHAR(64);
    v_now TIMESTAMPTZ := NOW();
BEGIN
    v_uid := kith_current_user_id();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authenticated user required for heartbeat';
    END IF;

    UPDATE trip_members
    SET last_heartbeat_at = v_now,
        last_seen_at = v_now
    WHERE trip_id = p_trip_id AND user_id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'trip_id', p_trip_id,
        'user_id', v_uid,
        'heartbeat_at', v_now
    );
END;
$$;

-- 11. Authoritative Request Trip Completion Consent RPC
CREATE OR REPLACE FUNCTION kith_request_trip_completion_consent(
    p_trip_id VARCHAR(64),
    p_member_id VARCHAR(64)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid VARCHAR(64);
    v_trip trips%ROWTYPE;
    v_member trip_members%ROWTYPE;
    v_req_id VARCHAR(64);
    v_now TIMESTAMPTZ := NOW();
BEGIN
    v_uid := kith_current_user_id();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authenticated user required';
    END IF;

    SELECT * INTO v_trip FROM trips WHERE id = p_trip_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trip not found';
    END IF;

    IF v_trip.creator_id <> v_uid THEN
        RAISE EXCEPTION 'Forbidden: only the trip owner can initiate completion or request consent';
    END IF;

    SELECT * INTO v_member FROM trip_members WHERE id = p_member_id AND trip_id = p_trip_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target member not found in trip';
    END IF;

    IF v_member.user_id = v_uid THEN
        RAISE EXCEPTION 'Cannot request consent from trip owner';
    END IF;

    -- Expire any previous pending request for this member
    UPDATE trip_completion_requests
    SET status = 'CANCELLED'
    WHERE trip_id = p_trip_id AND member_id = p_member_id AND status = 'PENDING';

    v_req_id := 'tcr_' || encode(gen_random_bytes(12), 'hex');

    INSERT INTO trip_completion_requests (
        id, trip_id, member_id, user_id, requested_by, status, created_at, expires_at, version
    ) VALUES (
        v_req_id, p_trip_id, p_member_id, v_member.user_id, v_uid, 'PENDING', v_now, v_now + INTERVAL '24 hours', 1
    );

    -- Move trip state to completing if active
    IF v_trip.lifecycle_state = 'active' THEN
        UPDATE trips SET lifecycle_state = 'completing', updated_at = v_now WHERE id = p_trip_id;
        INSERT INTO trip_lifecycle_history (
            id, trip_id, previous_status, new_status, changed_by, reason, related_request_id, created_at
        ) VALUES (
            'tlh_' || encode(gen_random_bytes(12), 'hex'),
            p_trip_id, 'active', 'completing', v_uid,
            'Owner initiated completion consent verification',
            v_req_id, v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'request_id', v_req_id,
        'trip_id', p_trip_id,
        'member_id', p_member_id,
        'user_id', v_member.user_id,
        'status', 'PENDING',
        'created_at', v_now
    );
END;
$$;

-- 12. Authoritative Respond Trip Completion Consent RPC
CREATE OR REPLACE FUNCTION kith_respond_trip_completion_consent(
    p_request_id VARCHAR(64),
    p_response VARCHAR(16),
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid VARCHAR(64);
    v_req trip_completion_requests%ROWTYPE;
    v_member trip_members%ROWTYPE;
    v_new_status VARCHAR(32);
    v_now TIMESTAMPTZ := NOW();
BEGIN
    v_uid := kith_current_user_id();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authenticated user required';
    END IF;

    IF p_response NOT IN ('YES', 'NO') THEN
        RAISE EXCEPTION 'Invalid response: must be YES or NO';
    END IF;

    SELECT * INTO v_req FROM trip_completion_requests WHERE id = p_request_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Completion request not found';
    END IF;

    IF v_req.status <> 'PENDING' THEN
        RAISE EXCEPTION 'Request is already finalized (%s)', v_req.status;
    END IF;

    IF v_now > v_req.expires_at THEN
        UPDATE trip_completion_requests SET status = 'EXPIRED' WHERE id = p_request_id;
        RAISE EXCEPTION 'Request has expired';
    END IF;

    -- Verify responder identity
    SELECT * INTO v_member FROM trip_members WHERE id = v_req.member_id;
    IF v_member.user_id <> v_uid AND v_req.user_id <> v_uid THEN
        RAISE EXCEPTION 'Forbidden: you are not authorized to respond for this member';
    END IF;

    v_new_status := CASE WHEN p_response = 'YES' THEN 'CONFIRMED_AVAILABLE' ELSE 'UNAVAILABLE' END;

    UPDATE trip_completion_requests
    SET status = v_new_status,
        response = p_response,
        response_note = p_note,
        responded_at = v_now,
        version = version + 1
    WHERE id = p_request_id;

    -- If member says NO, revert trip lifecycle to 'active' because completion was blocked
    IF p_response = 'NO' THEN
        UPDATE trips SET lifecycle_state = 'active', updated_at = v_now WHERE id = v_req.trip_id;
        INSERT INTO trip_lifecycle_history (
            id, trip_id, previous_status, new_status, changed_by, reason, related_request_id, created_at
        ) VALUES (
            'tlh_' || encode(gen_random_bytes(12), 'hex'),
            v_req.trip_id, 'completing', 'active', v_uid,
            'Member rejected completion: ' || COALESCE(p_note, 'Marked unavailable'),
            p_request_id, v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'request_id', p_request_id,
        'trip_id', v_req.trip_id,
        'status', v_new_status,
        'response', p_response,
        'responded_at', v_now
    );
END;
$$;

-- 13. Authoritative Reopen Trip Request RPC
CREATE OR REPLACE FUNCTION kith_request_trip_reopening(
    p_trip_id VARCHAR(64),
    p_reason_category VARCHAR(32),
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid VARCHAR(64);
    v_trip trips%ROWTYPE;
    v_is_member BOOLEAN;
    v_req_id VARCHAR(64);
    v_now TIMESTAMPTZ := NOW();
BEGIN
    v_uid := kith_current_user_id();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authenticated user required';
    END IF;

    IF p_reason_category NOT IN ('MISSING_EXPENSE', 'INCORRECT_PAYER', 'WRONG_SPLIT', 'PAYMENT_DISPUTE', 'OTHER') THEN
        RAISE EXCEPTION 'Invalid reason category';
    END IF;

    SELECT * INTO v_trip FROM trips WHERE id = p_trip_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trip not found';
    END IF;

    IF v_trip.lifecycle_state <> 'completed' AND v_trip.lifecycle_state <> 'completed_with_pending_changes' AND v_trip.lifecycle_state <> 'settled' THEN
        RAISE EXCEPTION 'Only completed or settled trips can be requested for reopening';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM trip_members WHERE trip_id = p_trip_id AND user_id = v_uid
    ) INTO v_is_member;

    IF NOT v_is_member THEN
        RAISE EXCEPTION 'Forbidden: you must be a member of this trip to request reopening';
    END IF;

    v_req_id := 'trr_' || encode(gen_random_bytes(12), 'hex');

    INSERT INTO trip_reopening_requests (
        id, trip_id, requested_by, reason_category, note, status, created_at
    ) VALUES (
        v_req_id, p_trip_id, v_uid, p_reason_category, p_note, 'PENDING', v_now
    );

    RETURN jsonb_build_object(
        'request_id', v_req_id,
        'trip_id', p_trip_id,
        'status', 'PENDING',
        'reason_category', p_reason_category,
        'created_at', v_now
    );
END;
$$;

-- 14. Authoritative Review Reopening RPC (Owner Only)
CREATE OR REPLACE FUNCTION kith_review_trip_reopening(
    p_request_id VARCHAR(64),
    p_action VARCHAR(16),
    p_review_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid VARCHAR(64);
    v_req trip_reopening_requests%ROWTYPE;
    v_trip trips%ROWTYPE;
    v_now TIMESTAMPTZ := NOW();
    v_new_status VARCHAR(32);
BEGIN
    v_uid := kith_current_user_id();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authenticated user required';
    END IF;

    IF p_action NOT IN ('APPROVE', 'REJECT') THEN
        RAISE EXCEPTION 'Invalid action: must be APPROVE or REJECT';
    END IF;

    SELECT * INTO v_req FROM trip_reopening_requests WHERE id = p_request_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reopening request not found';
    END IF;

    IF v_req.status <> 'PENDING' THEN
        RAISE EXCEPTION 'Request is already reviewed (%s)', v_req.status;
    END IF;

    SELECT * INTO v_trip FROM trips WHERE id = v_req.trip_id;
    IF v_trip.creator_id <> v_uid THEN
        RAISE EXCEPTION 'Forbidden: only the trip creator can review reopening requests';
    END IF;

    v_new_status := CASE WHEN p_action = 'APPROVE' THEN 'APPROVED' ELSE 'REJECTED' END;

    UPDATE trip_reopening_requests
    SET status = v_new_status,
        reviewed_by = v_uid,
        reviewed_at = v_now,
        review_note = p_review_note
    WHERE id = p_request_id;

    IF p_action = 'APPROVE' THEN
        UPDATE trips
        SET lifecycle_state = 'active',
            updated_at = v_now,
            revision = COALESCE(revision, 1) + 1
        WHERE id = v_req.trip_id;

        INSERT INTO trip_lifecycle_history (
            id, trip_id, previous_status, new_status, changed_by, reason, related_request_id, created_at
        ) VALUES (
            'tlh_' || encode(gen_random_bytes(12), 'hex'),
            v_req.trip_id, v_trip.lifecycle_state, 'active', v_uid,
            'Owner approved reopening request: ' || v_req.reason_category || COALESCE(' - ' || v_req.note, ''),
            p_request_id, v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'request_id', p_request_id,
        'trip_id', v_req.trip_id,
        'action', p_action,
        'status', v_new_status,
        'reviewed_at', v_now
    );
END;
$$;
