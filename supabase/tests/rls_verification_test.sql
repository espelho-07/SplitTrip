-- ==============================================================================
-- Kith Supabase Test Suite: rls_verification_test.sql
-- Empirical Verification of Hardened RLS, Role-Based Isolation & Keyset Logic
-- ==============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- PRIVILEGED FIXTURE SETUP (Executed as postgres / service_role)
-- ─────────────────────────────────────────────────────────────────────────────
RESET ROLE;

-- Clean existing test records if any
DELETE FROM personal_budgets WHERE user_id IN ('guest_alice_test', 'guest_bob_test', 'attacker_mallory');
DELETE FROM notifications WHERE user_id IN ('guest_alice_test', 'guest_bob_test', 'attacker_mallory');
DELETE FROM personal_expenses WHERE user_id IN ('guest_alice_test', 'guest_bob_test', 'attacker_mallory');
DELETE FROM personal_debts WHERE user_id IN ('guest_alice_test', 'guest_bob_test', 'attacker_mallory');
DELETE FROM settlements WHERE trip_id = 'trip_secure_test_001';
DELETE FROM expenses WHERE trip_id = 'trip_secure_test_001';
DELETE FROM trip_members WHERE trip_id = 'trip_secure_test_001';
DELETE FROM trips WHERE id = 'trip_secure_test_001';
DELETE FROM guest_sessions WHERE id IN ('guest_alice_test', 'guest_bob_test', 'guest_revoked_test', 'attacker_mallory');

-- 1. Insert Alice & Bob sessions with SHA-256 hashed session tokens
-- Alice token: 'alice_secret_token_32chars_long_123'
INSERT INTO guest_sessions (id, session_token_hash, recovery_key, anonymous_token, display_name, is_revoked)
VALUES (
    'guest_alice_test',
    encode(sha256('alice_secret_token_32chars_long_123'::bytea), 'hex'),
    encode(extensions.hmac('KITH-7X4M-9Q2P-L8VN-3R6T'::bytea, 'salt_alice_123'::bytea, 'sha256'), 'hex'),
    'salt_alice_123',
    'Alice',
    FALSE
);

-- Bob token: 'bob_secret_token_32chars_long_456'
INSERT INTO guest_sessions (id, session_token_hash, recovery_key, anonymous_token, display_name, is_revoked)
VALUES (
    'guest_bob_test',
    encode(sha256('bob_secret_token_32chars_long_456'::bytea), 'hex'),
    encode(extensions.hmac('KITH-AAAA-BBBB-CCCC-DDDD'::bytea, 'salt_bob_456'::bytea, 'sha256'), 'hex'),
    'salt_bob_456',
    'Bob',
    FALSE
);

-- Revoked token session
INSERT INTO guest_sessions (id, session_token_hash, recovery_key, anonymous_token, display_name, is_revoked)
VALUES (
    'guest_revoked_test',
    encode(sha256('revoked_secret_token_32chars_789'::bytea), 'hex'),
    encode(extensions.hmac('KITH-REV0-KEDD-TEST-KEY1'::bytea, 'salt_revoked_789'::bytea, 'sha256'), 'hex'),
    'salt_revoked_789',
    'Revoked User',
    TRUE
);

-- Insert Alice's private personal expense
INSERT INTO personal_expenses (id, user_id, title, amount_in_paise)
VALUES ('pe_alice_secret', 'guest_alice_test', 'Alice Private Flight', 2500000);

-- Insert Alice's private trip & member & expense
INSERT INTO trips (id, creator_id, name, invite_code)
VALUES ('trip_secure_test_001', 'guest_alice_test', 'Alice Private Trip', 'ALICE123TEST');

INSERT INTO trip_members (id, trip_id, user_id, display_name, role)
VALUES ('mbr_alice_01', 'trip_secure_test_001', 'guest_alice_test', 'Alice', 'admin');

INSERT INTO expenses (id, trip_id, title, amount_in_paise, paid_by_id)
VALUES ('exp_trip_alice', 'trip_secure_test_001', 'Villa Stay', 5000000, 'mbr_alice_01');

-- Insert Bob's private budget and notification
INSERT INTO personal_budgets (id, user_id, month_key, monthly_limit_in_paise, spent_in_paise)
VALUES ('budget_bob_01', 'guest_bob_test', '2026-11', 5000000, 120000);

INSERT INTO notifications (id, user_id, title, message, type)
VALUES ('notif_bob_01', 'guest_bob_test', 'Bob Alert', 'Private notification for Bob', 'general');

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 1: Identity Spoofing Attack via 'x-kith-account-id' MUST BE REJECTED
-- Executed under unprivileged role: anon
-- Attacker attempts to spoof x-kith-account-id header without valid token.
-- ─────────────────────────────────────────────────────────────────────────────
SET LOCAL ROLE anon;
SET LOCAL "request.headers" TO '{"x-kith-account-id": "guest_alice_test"}';

DO $$
DECLARE
    resolved_uid TEXT;
    accessible_rows INT;
BEGIN
    resolved_uid := kith_current_user_id();
    IF resolved_uid IS NOT NULL THEN
        RAISE EXCEPTION 'TEST 1 FAILED: kith_current_user_id() trusted unauthenticated header! Returned: %', resolved_uid;
    END IF;

    SELECT COUNT(*) INTO accessible_rows FROM personal_expenses WHERE user_id = 'guest_alice_test';
    IF accessible_rows > 0 THEN
        RAISE EXCEPTION 'TEST 1 FAILED: Attacker could read Alice personal expenses via header spoofing!';
    END IF;

    RAISE NOTICE 'TEST 1 PASSED: Header spoofing correctly rejected under anon role. kith_current_user_id() is NULL.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 2: Unauthorized Mutations (INSERT, UPDATE, DELETE) Blocked Under Anon
-- Attacker tries to insert, update, or delete Alice's records without token.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_inserted BOOLEAN := FALSE;
    v_updated INT := 0;
    v_deleted INT := 0;
BEGIN
    -- Unauthorized INSERT must fail RLS check
    BEGIN
        INSERT INTO personal_expenses (id, user_id, title, amount_in_paise)
        VALUES ('pe_malicious_insert', 'guest_alice_test', 'Malicious Expense', 999999);
        v_inserted := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_inserted := FALSE;
    END;

    IF v_inserted THEN
        RAISE EXCEPTION 'TEST 2 FAILED: Unauthorized INSERT into personal_expenses succeeded under anon!';
    END IF;

    -- Unauthorized UPDATE must affect 0 rows
    UPDATE personal_expenses SET title = 'Hacked Title' WHERE id = 'pe_alice_secret';
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated > 0 THEN
        RAISE EXCEPTION 'TEST 2 FAILED: Unauthorized UPDATE modified Alice personal expenses!';
    END IF;

    -- Unauthorized DELETE must affect 0 rows
    DELETE FROM personal_expenses WHERE id = 'pe_alice_secret';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    IF v_deleted > 0 THEN
        RAISE EXCEPTION 'TEST 2 FAILED: Unauthorized DELETE removed Alice personal expenses!';
    END IF;

    RAISE NOTICE 'TEST 2 PASSED: Unauthorized INSERT, UPDATE, and DELETE strictly blocked by RLS.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 3: Invalid, Short, and Revoked Tokens Must Return NULL
-- ─────────────────────────────────────────────────────────────────────────────
-- Case 3A: Short token (<32 chars)
SET LOCAL "request.headers" TO '{"x-kith-session-token": "too_short_token"}';
DO $$
BEGIN
    IF kith_current_user_id() IS NOT NULL THEN
        RAISE EXCEPTION 'TEST 3A FAILED: Short token was accepted!';
    END IF;
    RAISE NOTICE 'TEST 3A PASSED: Short token (<32 chars) rejected.';
END $$;

-- Case 3B: Nonexistent token
SET LOCAL "request.headers" TO '{"x-kith-session-token": "nonexistent_token_that_does_not_exist_in_db_123"}';
DO $$
BEGIN
    IF kith_current_user_id() IS NOT NULL THEN
        RAISE EXCEPTION 'TEST 3B FAILED: Nonexistent token was accepted!';
    END IF;
    RAISE NOTICE 'TEST 3B PASSED: Nonexistent token rejected.';
END $$;

-- Case 3C: Revoked token (is_revoked = TRUE)
SET LOCAL "request.headers" TO '{"x-kith-session-token": "revoked_secret_token_32chars_789"}';
DO $$
BEGIN
    IF kith_current_user_id() IS NOT NULL THEN
        RAISE EXCEPTION 'TEST 3C FAILED: Revoked token was accepted!';
    END IF;
    RAISE NOTICE 'TEST 3C PASSED: Revoked token rejected.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 4: Valid Session Token Authenticates Alice & Allows Full Ownership Access
-- ─────────────────────────────────────────────────────────────────────────────
SET LOCAL "request.headers" TO '{"x-kith-session-token": "alice_secret_token_32chars_long_123"}';

DO $$
DECLARE
    resolved_uid TEXT;
    alice_expense_count INT;
    v_updated INT;
BEGIN
    resolved_uid := kith_current_user_id();
    IF resolved_uid <> 'guest_alice_test' THEN
        RAISE EXCEPTION 'TEST 4 FAILED: Expected guest_alice_test, got %', resolved_uid;
    END IF;

    -- Alice reads her personal expenses
    SELECT COUNT(*) INTO alice_expense_count FROM personal_expenses WHERE user_id = 'guest_alice_test';
    IF alice_expense_count <> 1 THEN
        RAISE EXCEPTION 'TEST 4 FAILED: Alice could not read her own personal expenses!';
    END IF;

    -- Alice can insert her own expense
    INSERT INTO personal_expenses (id, user_id, title, amount_in_paise)
    VALUES ('pe_alice_new_02', 'guest_alice_test', 'Alice Coffee', 35000);

    -- Alice can update her own expense
    UPDATE personal_expenses SET title = 'Alice Specialty Coffee' WHERE id = 'pe_alice_new_02';
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated <> 1 THEN
        RAISE EXCEPTION 'TEST 4 FAILED: Alice could not update her own personal expense!';
    END IF;

    -- Alice can delete her new expense
    DELETE FROM personal_expenses WHERE id = 'pe_alice_new_02';

    RAISE NOTICE 'TEST 4 PASSED: Valid session token authenticated Alice with full verified ownership CRUD.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 5: Cross-Tenant Isolation (Bob Authenticated Cannot Access Alice Data)
-- ─────────────────────────────────────────────────────────────────────────────
SET LOCAL "request.headers" TO '{"x-kith-session-token": "bob_secret_token_32chars_long_456"}';

DO $$
DECLARE
    resolved_uid TEXT;
    accessible_alice_rows INT;
    accessible_trip_rows INT;
    v_inserted BOOLEAN := FALSE;
    v_updated INT := 0;
    v_deleted INT := 0;
BEGIN
    resolved_uid := kith_current_user_id();
    IF resolved_uid <> 'guest_bob_test' THEN
        RAISE EXCEPTION 'TEST 5 FAILED: Expected guest_bob_test, got %', resolved_uid;
    END IF;

    -- Bob tries to SELECT Alice's personal expenses
    SELECT COUNT(*) INTO accessible_alice_rows FROM personal_expenses WHERE user_id = 'guest_alice_test';
    IF accessible_alice_rows > 0 THEN
        RAISE EXCEPTION 'TEST 5 FAILED: Bob could read Alice personal expenses! Cross-tenant isolation broken.';
    END IF;

    -- Bob tries to SELECT Alice's private trip expenses
    SELECT COUNT(*) INTO accessible_trip_rows FROM expenses WHERE trip_id = 'trip_secure_test_001';
    IF accessible_trip_rows > 0 THEN
        RAISE EXCEPTION 'TEST 5 FAILED: Bob could read Alice private trip expenses! Non-member trip isolation broken.';
    END IF;

    -- Bob tries to INSERT into Alice's trip expenses (must fail)
    BEGIN
        INSERT INTO expenses (id, trip_id, title, amount_in_paise, paid_by_id)
        VALUES ('exp_bob_injected', 'trip_secure_test_001', 'Bob Trojan Expense', 100000, 'mbr_alice_01');
        v_inserted := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_inserted := FALSE;
    END;

    IF v_inserted THEN
        RAISE EXCEPTION 'TEST 5 FAILED: Bob was able to inject an expense into a trip he does not belong to!';
    END IF;

    -- Bob tries to UPDATE Alice's expense (must affect 0 rows)
    UPDATE expenses SET amount_in_paise = 0 WHERE id = 'exp_trip_alice';
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated > 0 THEN
        RAISE EXCEPTION 'TEST 5 FAILED: Bob was able to update Alice trip expense!';
    END IF;

    -- Bob tries to DELETE Alice's expense (must affect 0 rows)
    DELETE FROM expenses WHERE id = 'exp_trip_alice';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    IF v_deleted > 0 THEN
        RAISE EXCEPTION 'TEST 5 FAILED: Bob was able to delete Alice trip expense!';
    END IF;

    RAISE NOTICE 'TEST 5 PASSED: Cross-tenant isolation verified. Bob cannot SELECT, INSERT, UPDATE or DELETE Alice records.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 6: Trigger Function Execution Under Anon (kith_log_sync_event)
-- Verifies SECURITY DEFINER fix: an anon caller inserting their own expense
-- succeeds without RLS violation on kith_sync_events table.
-- ─────────────────────────────────────────────────────────────────────────────
SET LOCAL "request.headers" TO '{"x-kith-session-token": "alice_secret_token_32chars_long_123"}';

DO $$
DECLARE
    v_event_count INT;
BEGIN
    -- Alice inserts expense in her trip
    INSERT INTO expenses (id, trip_id, title, amount_in_paise, paid_by_id)
    VALUES ('exp_sync_trigger_test', 'trip_secure_test_001', 'Trigger Verification Expense', 420000, 'mbr_alice_01');

    -- Verify event was recorded in kith_sync_events
    SELECT COUNT(*) INTO v_event_count FROM kith_sync_events WHERE record_id = 'exp_sync_trigger_test';
    IF v_event_count < 1 THEN
        RAISE EXCEPTION 'TEST 6 FAILED: Trigger did not record event in kith_sync_events!';
    END IF;

    RAISE NOTICE 'TEST 6 PASSED: SECURITY DEFINER trigger executed successfully under anon role without RLS blockage.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 7: Secure Server-Side Account Recovery RPC
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    rec_result JSONB;
    new_token_hash TEXT;
BEGIN
    -- Valid recovery key
    new_token_hash := encode(sha256('newly_recovered_token_32chars_long'::bytea), 'hex');
    rec_result := kith_recover_guest_account(
        'KITH-7X4M-9Q2P-L8VN-3R6T',
        new_token_hash,
        'dev_recovered_phone'
    );

    IF (rec_result->>'success')::boolean <> true THEN
        RAISE EXCEPTION 'TEST 7 FAILED: Valid recovery key failed recovery RPC: %', rec_result;
    END IF;

    IF rec_result->>'id' <> 'guest_alice_test' THEN
        RAISE EXCEPTION 'TEST 7 FAILED: Recovered wrong account ID: %', rec_result;
    END IF;

    -- Verify session_token_hash was updated in database
    SELECT session_token_hash INTO new_token_hash FROM guest_sessions WHERE id = 'guest_alice_test';
    IF new_token_hash <> encode(sha256('newly_recovered_token_32chars_long'::bytea), 'hex') THEN
        RAISE EXCEPTION 'TEST 7 FAILED: session_token_hash not updated on recovered account!';
    END IF;

    -- Invalid recovery key MUST fail
    rec_result := kith_recover_guest_account(
        'KITH-WRON-GKEY-XXXX-YYYY',
        encode(sha256('dummy_token_32chars_long_12345678'::bytea), 'hex'),
        'dev_phone'
    );

    IF (rec_result->>'success')::boolean <> false THEN
        RAISE EXCEPTION 'TEST 7 FAILED: Invalid recovery key was accepted!';
    END IF;

    RAISE NOTICE 'TEST 7 PASSED: Secure server-side recovery verified.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 8: Personal Budgets & Notifications Strict Account-Level Isolation
-- Verified under Alice's authenticated session:
-- 1. Alice CANNOT read Bob's budgets or notifications.
-- 2. Alice CANNOT modify (UPDATE / DELETE) Bob's budgets or notifications.
-- 3. Alice CANNOT insert budgets or notifications targeting Bob.
-- 4. Alice CAN perform full CRUD on her own budgets and notifications.
-- ─────────────────────────────────────────────────────────────────────────────
SET LOCAL "request.headers" TO '{"x-kith-session-token": "newly_recovered_token_32chars_long"}';

DO $$
DECLARE
    v_count INT;
    v_updated INT;
    v_deleted INT;
    v_inserted BOOLEAN := FALSE;
BEGIN
    -- 1. Alice tries to SELECT Bob's budget
    SELECT COUNT(*) INTO v_count FROM personal_budgets WHERE user_id = 'guest_bob_test';
    IF v_count > 0 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice was able to read Bob personal budgets!';
    END IF;

    -- 2. Alice tries to UPDATE Bob's budget (must affect 0 rows)
    UPDATE personal_budgets SET monthly_limit_in_paise = 0 WHERE id = 'budget_bob_01';
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated > 0 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice was able to update Bob personal budget!';
    END IF;

    -- 3. Alice tries to DELETE Bob's budget (must affect 0 rows)
    DELETE FROM personal_budgets WHERE id = 'budget_bob_01';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    IF v_deleted > 0 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice was able to delete Bob personal budget!';
    END IF;

    -- 4. Alice tries to SELECT Bob's notifications
    SELECT COUNT(*) INTO v_count FROM notifications WHERE user_id = 'guest_bob_test';
    IF v_count > 0 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice was able to read Bob notifications!';
    END IF;

    -- 5. Alice tries to UPDATE Bob's notifications (must affect 0 rows)
    UPDATE notifications SET is_read = TRUE WHERE id = 'notif_bob_01';
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated > 0 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice was able to update Bob notifications!';
    END IF;

    -- 6. Alice tries to DELETE Bob's notifications (must affect 0 rows)
    DELETE FROM notifications WHERE id = 'notif_bob_01';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    IF v_deleted > 0 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice was able to delete Bob notifications!';
    END IF;

    -- 7. Alice tries to INSERT a budget for Bob (must fail with RLS violation)
    BEGIN
        INSERT INTO personal_budgets (id, user_id, month_key, monthly_limit_in_paise)
        VALUES ('budget_malicious_bob', 'guest_bob_test', '2026-11', 1000);
        v_inserted := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_inserted := FALSE;
    END;
    IF v_inserted THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice was able to insert a budget for Bob!';
    END IF;

    -- 8. Alice tries to INSERT a notification for Bob (must fail with RLS violation)
    BEGIN
        INSERT INTO notifications (id, user_id, title, message)
        VALUES ('notif_malicious_bob', 'guest_bob_test', 'Spam', 'Malicious notification');
        v_inserted := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_inserted := FALSE;
    END;
    IF v_inserted THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice was able to insert a notification targeting Bob!';
    END IF;

    -- 9. Alice can INSERT, SELECT, UPDATE, DELETE her own budget
    INSERT INTO personal_budgets (id, user_id, month_key, monthly_limit_in_paise, spent_in_paise)
    VALUES ('budget_alice_01', 'guest_alice_test', '2026-11', 10000000, 50000);

    SELECT COUNT(*) INTO v_count FROM personal_budgets WHERE id = 'budget_alice_01';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice could not read her own personal budget!';
    END IF;

    UPDATE personal_budgets SET spent_in_paise = 75000 WHERE id = 'budget_alice_01';
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated <> 1 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice could not update her own personal budget!';
    END IF;

    DELETE FROM personal_budgets WHERE id = 'budget_alice_01';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    IF v_deleted <> 1 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice could not delete her own personal budget!';
    END IF;

    -- 10. Alice can INSERT, SELECT, UPDATE, DELETE her own notification
    INSERT INTO notifications (id, user_id, title, message, type)
    VALUES ('notif_alice_01', 'guest_alice_test', 'Welcome Alice', 'Your budget is ready', 'general');

    SELECT COUNT(*) INTO v_count FROM notifications WHERE id = 'notif_alice_01';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice could not read her own notification!';
    END IF;

    UPDATE notifications SET is_read = TRUE WHERE id = 'notif_alice_01';
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated <> 1 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice could not update her own notification!';
    END IF;

    DELETE FROM notifications WHERE id = 'notif_alice_01';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    IF v_deleted <> 1 THEN
        RAISE EXCEPTION 'TEST 8 FAILED: Alice could not delete her own notification!';
    END IF;

    RAISE NOTICE 'TEST 8 PASSED: Personal budgets & notifications strict account-level isolation verified.';
END $$;

-- Roll back transaction to keep test database completely clean
ROLLBACK;
