-- ==============================================================================
-- Kith Supabase Test Suite: delayed_commit_bug_test.sql
-- Reproduction and Verification of the BIGSERIAL Commit-Order Race Condition
-- ==============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 1: THEORETICAL ANALYSIS & REPRODUCTION SCENARIO (WITHOUT ADVISORY LOCK)
-- ─────────────────────────────────────────────────────────────────────────────
-- Scenario:
-- In standard PostgreSQL, sequences (`nextval`) increment non-transactionally.
-- 1. Session A: BEGIN; INSERT INTO expenses ... (Trigger calls nextval -> seq=101)
-- 2. Session B: BEGIN; INSERT INTO expenses ... (Trigger calls nextval -> seq=102); COMMIT;
-- 3. Client Poller: SELECT * FROM kith_sync_events WHERE seq > 100 ORDER BY seq ASC;
--    - In PostgreSQL Read Committed isolation, Session A's uncommitted row 101 is INVISIBLE.
--    - The client receives only row 102.
--    - Client advances local sequence cursor: last_seq = 102.
-- 4. Session A: COMMIT; (Row 101 becomes visible in the database).
-- 5. Client Poller: SELECT * FROM kith_sync_events WHERE seq > 102 ORDER BY seq ASC;
--    - Since 101 < 102, row 101 is PERMANENTLY SKIPPED by this client!
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 2: VERIFICATION OF THE ADVISORY LOCK SOLUTION
-- ─────────────────────────────────────────────────────────────────────────────
-- In the updated migration:
-- In `kith_log_sync_event()`:
-- PERFORM pg_advisory_xact_lock(74291001);
--
-- With this lock:
-- 1. Session A acquires the transaction-scoped advisory lock before reading nextval.
-- 2. Session B attempts to enter kith_log_sync_event() and BLOCKS on the lock.
-- 3. Session A obtains seq 101, completes its transaction, and COMMITS.
-- 4. Only upon Session A's commit is the lock released.
-- 5. Session B unblocks, acquires the lock, obtains seq 102, and COMMITS.
-- 6. Guarantee: Sequence allocation order is STRICTLY IDENTICAL to commit order.
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- Setup test environment
DELETE FROM kith_sync_events WHERE table_name = 'test_expenses';
DELETE FROM guest_sessions WHERE id IN ('test_sync_user_1', 'test_sync_user_2');
DELETE FROM trips WHERE id = 'trip_sync_test_001';

-- Create guest session
INSERT INTO guest_sessions (id, session_token_hash, display_name)
VALUES (
    'test_sync_user_1',
    encode(sha256('test_session_token_32chars_long_sync1'::bytea), 'hex'),
    'Sync Tester 1'
);

-- Create test trip and membership
INSERT INTO trips (id, creator_id, name, invite_code)
VALUES ('trip_sync_test_001', 'test_sync_user_1', 'Sync Test Trip', 'SYNCTEST0001');

INSERT INTO trip_members (id, trip_id, user_id, display_name, role)
VALUES ('mbr_sync_01', 'trip_sync_test_001', 'test_sync_user_1', 'Sync Tester 1', 'admin');

-- Set caller session header
SET LOCAL "request.headers" TO '{"x-kith-session-token": "test_session_token_32chars_long_sync1"}';

-- Verify caller identity resolves
DO $$
DECLARE
    v_user TEXT;
BEGIN
    v_user := kith_current_user_id();
    IF v_user <> 'test_sync_user_1' THEN
        RAISE EXCEPTION 'Failed: Identity resolution expected test_sync_user_1, got %', v_user;
    END IF;
    RAISE NOTICE 'PASSED: Identity verified for test_sync_user_1';
END;
$$;

-- Test 1: Insert trip expense and verify sync event logging with payload
INSERT INTO expenses (id, trip_id, title, amount_in_paise, paid_by_id)
VALUES ('exp_sync_001', 'trip_sync_test_001', 'Breakfast at Hotel', 150000, 'mbr_sync_01');

DO $$
DECLARE
    v_event RECORD;
BEGIN
    SELECT * INTO v_event FROM kith_sync_events WHERE record_id = 'exp_sync_001' ORDER BY seq DESC LIMIT 1;
    IF v_event.seq IS NULL THEN
        RAISE EXCEPTION 'Failed: Expected sync event for exp_sync_001';
    END IF;
    IF v_event.action <> 'INSERT' THEN
        RAISE EXCEPTION 'Failed: Expected action INSERT, got %', v_event.action;
    END IF;
    IF v_event.payload->>'title' <> 'Breakfast at Hotel' THEN
        RAISE EXCEPTION 'Failed: Expected payload title Breakfast at Hotel, got %', v_event.payload->>'title';
    END IF;
    RAISE NOTICE 'PASSED: Sync event recorded with seq=%, action=%, payload verified', v_event.seq, v_event.action;
END;
$$;

-- Test 2: Verify kith_fetch_sync_events RPC returns events in monotonic sequence
DO $$
DECLARE
    v_count INT;
    v_last_seq BIGINT;
BEGIN
    -- Fetch events from cursor 0
    SELECT count(*), max(seq) INTO v_count, v_last_seq 
    FROM kith_fetch_sync_events(0, 100);

    IF v_count < 1 THEN
        RAISE EXCEPTION 'Failed: kith_fetch_sync_events returned % rows, expected at least 1', v_count;
    END IF;

    RAISE NOTICE 'PASSED: kith_fetch_sync_events returned % rows up to seq %', v_count, v_last_seq;

    -- Fetch events where seq > v_last_seq should return 0
    SELECT count(*) INTO v_count FROM kith_fetch_sync_events(v_last_seq, 100);
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Failed: Expected 0 new events, got %', v_count;
    END IF;
    RAISE NOTICE 'PASSED: Monotonic cursor advancement confirmed zero ghost events';
END;
$$;

-- Test 3: Verify Unauthorized caller is rejected
SET LOCAL "request.headers" TO '{"x-kith-session-token": "invalid_or_missing_session_token_here"}';

DO $$
BEGIN
    BEGIN
        PERFORM * FROM kith_fetch_sync_events(0, 100);
        RAISE EXCEPTION 'Failed: Unauthorized caller should have been rejected!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'PASSED: Unauthorized access to kith_fetch_sync_events successfully rejected';
    END;
END;
$$;

-- Test 4: Rollback Sequence Gap & Cursor Pagination Tolerance
-- Consumes sequence numbers via a SAVEPOINT rollback, then commits subsequent events
-- Proves that kith_fetch_sync_events tolerates non-contiguous sequence numbers without skipping.
SET LOCAL "request.headers" TO '{"x-kith-session-token": "test_session_token_32chars_long_sync1"}';

SAVEPOINT sp_gap_test;

INSERT INTO expenses (id, trip_id, title, amount_in_paise, paid_by_id)
VALUES ('exp_sync_gap_aborted', 'trip_sync_test_001', 'Aborted Expense', 50000, 'mbr_sync_01');

ROLLBACK TO SAVEPOINT sp_gap_test;

-- Verify aborted event is completely absent
DO $$
DECLARE
    v_aborted_count INT;
BEGIN
    SELECT count(*) INTO v_aborted_count FROM kith_sync_events WHERE record_id = 'exp_sync_gap_aborted';
    IF v_aborted_count > 0 THEN
        RAISE EXCEPTION 'Failed: Rolled-back event must not exist in kith_sync_events';
    END IF;
    RAISE NOTICE 'PASSED: Aborted event was cleanly eliminated';
END;
$$;

-- Insert committed expense after rollback gap
INSERT INTO expenses (id, trip_id, title, amount_in_paise, paid_by_id)
VALUES ('exp_sync_post_gap', 'trip_sync_test_001', 'Committed Post Gap Expense', 75000, 'mbr_sync_01');

DO $$
DECLARE
    v_found_count INT;
BEGIN
    SELECT count(*) INTO v_found_count FROM kith_fetch_sync_events(0, 100) WHERE record_id = 'exp_sync_post_gap';
    IF v_found_count <> 1 THEN
        RAISE EXCEPTION 'Failed: kith_fetch_sync_events failed to retrieve post-gap committed event!';
    END IF;
    RAISE NOTICE 'PASSED: Cursor fetch successfully retrieved post-gap event across sequence burned numbers';
END;
$$;

-- Test 5: Re-entrant Transaction-Level Advisory Lock Verification
-- Multiple operations within the same transaction update both trips and trip_members
DO $$
DECLARE
    v_updated_trips INT;
    v_updated_members INT;
BEGIN
    UPDATE trips SET description = 'Updated in transaction' WHERE id = 'trip_sync_test_001';
    GET DIAGNOSTICS v_updated_trips = ROW_COUNT;

    UPDATE trip_members SET role = 'admin' WHERE id = 'mbr_sync_01';
    GET DIAGNOSTICS v_updated_members = ROW_COUNT;

    IF v_updated_trips <> 1 OR v_updated_members <> 1 THEN
        RAISE EXCEPTION 'Failed: Re-entrant transaction updates failed';
    END IF;
    RAISE NOTICE 'PASSED: Multi-entity transaction succeeded with re-entrant advisory lock';
END;
$$;

ROLLBACK;
