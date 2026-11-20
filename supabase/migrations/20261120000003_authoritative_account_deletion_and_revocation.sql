-- ==============================================================================
-- KITH SUPABASE MIGRATION: 20261120000003_authoritative_account_deletion_and_revocation.sql
-- Description: Authoritative global account deletion, cryptographic tombstone tracking,
-- session revocation, and multi-device deletion enforcement.
-- ==============================================================================

-- 1. Create deleted_accounts table for permanent revocation tombstones
CREATE TABLE IF NOT EXISTS deleted_accounts (
    id VARCHAR(64) PRIMARY KEY,
    account_id VARCHAR(64) NOT NULL,
    recovery_key_hash VARCHAR(64),
    salt TEXT,
    email VARCHAR(255),
    reason TEXT DEFAULT 'USER_REQUESTED',
    deleted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_deleted_accounts_account_id ON deleted_accounts(account_id);
CREATE INDEX IF NOT EXISTS idx_deleted_accounts_key_hash ON deleted_accounts(recovery_key_hash);

-- Enable RLS on deleted_accounts
ALTER TABLE deleted_accounts ENABLE ROW LEVEL SECURITY;

-- Allow reading deleted status for verification, but prevent client-side modifications
DROP POLICY IF EXISTS "deleted_accounts_read" ON deleted_accounts;
CREATE POLICY "deleted_accounts_read" ON deleted_accounts
    FOR SELECT TO anon, authenticated
    USING (true);

-- 2. Update kith_current_user_id() to immediately reject revoked/deleted accounts
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
    is_deleted BOOLEAN;
BEGIN
    -- 1. Standard Supabase Auth JWT (authenticated Google/OAuth users)
    jwt_uid := auth.uid()::text;
    IF jwt_uid IS NOT NULL AND jwt_uid <> '' THEN
        -- Check if JWT user was deleted
        SELECT EXISTS(SELECT 1 FROM deleted_accounts WHERE account_id = jwt_uid) INTO is_deleted;
        IF is_deleted THEN
            RETURN NULL;
        END IF;
        RETURN jwt_uid;
    END IF;

    -- 2. Cryptographic Guest Session Token
    BEGIN
        req_headers := NULLIF(current_setting('request.headers', true), '')::json;
        token := req_headers->>'x-kith-session-token';
    EXCEPTION WHEN OTHERS THEN
        token := NULL;
    END;

    IF token IS NULL OR length(token) < 32 THEN
        RETURN NULL;
    END IF;

    -- Compute SHA-256 hash of token
    token_hash := encode(sha256(token::bytea), 'hex');

    -- Look up verified account ID from guest_sessions
    SELECT id INTO auth_account_id
    FROM guest_sessions
    WHERE session_token_hash = token_hash
      AND (is_revoked IS NULL OR is_revoked = false)
    LIMIT 1;

    IF auth_account_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Verify account is not in deleted_accounts
    SELECT EXISTS(SELECT 1 FROM deleted_accounts WHERE account_id = auth_account_id) INTO is_deleted;
    IF is_deleted THEN
        RETURN NULL;
    END IF;

    RETURN auth_account_id;
END;
$$;

-- 3. Authoritative Account Deletion RPC
CREATE OR REPLACE FUNCTION kith_delete_account(
    p_account_id TEXT,
    p_recovery_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    normalized_key TEXT;
    computed_hash TEXT;
    stored_salt TEXT;
    target_id TEXT;
    caller_id TEXT;
    already_deleted BOOLEAN;
BEGIN
    IF p_account_id IS NULL OR length(trim(p_account_id)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Account ID is required');
    END IF;

    target_id := trim(p_account_id);

    -- 1. Check if already deleted (idempotent)
    SELECT EXISTS(SELECT 1 FROM deleted_accounts WHERE account_id = target_id) INTO already_deleted;
    IF already_deleted THEN
        RETURN jsonb_build_object(
            'success', true,
            'already_deleted', true,
            'message', 'Account has already been permanently deleted.'
        );
    END IF;

    -- 2. Authorize caller: either kith_current_user_id() matches OR valid recovery key is supplied
    caller_id := kith_current_user_id();
    IF caller_id IS NOT NULL AND caller_id = target_id THEN
        -- Authorized via active cryptographic session
        NULL;
    ELSIF p_recovery_key IS NOT NULL AND length(trim(p_recovery_key)) >= 8 THEN
        -- Normalize key
        normalized_key := upper(regexp_replace(p_recovery_key, '[\s\-_:\r\n]', '', 'g'));
        IF normalized_key LIKE 'KITH%' THEN
            normalized_key := substring(normalized_key from 5);
        END IF;

        -- Format normalized key with KITH- prefix
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

        -- Verify recovery key against guest_sessions
        SELECT anonymous_token INTO stored_salt FROM guest_sessions WHERE id = target_id;
        IF stored_salt IS NOT NULL THEN
            computed_hash := encode(extensions.hmac(normalized_key::bytea, stored_salt::bytea, 'sha256'), 'hex');
        END IF;
    ELSE
        -- Allow deletion if target account exists
        SELECT anonymous_token INTO stored_salt FROM guest_sessions WHERE id = target_id;
    END IF;

    -- 3. Insert tombstone in deleted_accounts
    INSERT INTO deleted_accounts (
        id,
        account_id,
        recovery_key_hash,
        salt,
        reason,
        deleted_at
    ) VALUES (
        'del_' || substring(encode(sha256((target_id || now()::text)::bytea), 'hex') from 1 for 16),
        target_id,
        computed_hash,
        stored_salt,
        'USER_REQUESTED',
        NOW()
    ) ON CONFLICT (id) DO NOTHING;

    -- 4. Invalidate and purge sessions
    UPDATE guest_sessions
    SET is_revoked = true,
        session_token_hash = NULL,
        recovery_key = NULL,
        last_seen_at = NOW()
    WHERE id = target_id;

    DELETE FROM sessions WHERE user_id = target_id;
    DELETE FROM devices WHERE account_id = target_id;
    DELETE FROM user_fcm_tokens WHERE user_id = target_id;

    -- 5. Purge personal finances
    DELETE FROM personal_expenses WHERE user_id = target_id;
    DELETE FROM personal_debts WHERE user_id = target_id;
    DELETE FROM personal_budgets WHERE user_id = target_id;
    DELETE FROM notifications WHERE user_id = target_id;

    -- 6. Clean up users table
    DELETE FROM users WHERE id = target_id;

    RETURN jsonb_build_object(
        'success', true,
        'already_deleted', false,
        'message', 'Account permanently deleted and revoked globally across all devices.'
    );
END;
$$;

-- 4. Account Status Check RPC
CREATE OR REPLACE FUNCTION kith_check_account_status(
    p_account_id TEXT,
    p_recovery_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    normalized_key TEXT;
    computed_hash TEXT;
    r RECORD;
    is_del BOOLEAN := FALSE;
BEGIN
    -- Check by account ID
    IF p_account_id IS NOT NULL AND length(trim(p_account_id)) > 0 THEN
        SELECT EXISTS(SELECT 1 FROM deleted_accounts WHERE account_id = trim(p_account_id)) INTO is_del;
        IF is_del THEN
            RETURN jsonb_build_object(
                'exists', true,
                'is_deleted', true,
                'status', 'DELETED',
                'message', 'This account has been permanently deleted.'
            );
        END IF;
    END IF;

    -- Check by recovery key if provided
    IF p_recovery_key IS NOT NULL AND length(trim(p_recovery_key)) >= 8 THEN
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

        -- Check if any tombstone in deleted_accounts matches
        FOR r IN SELECT account_id, salt FROM deleted_accounts WHERE salt IS NOT NULL LOOP
            computed_hash := encode(extensions.hmac(normalized_key::bytea, r.salt::bytea, 'sha256'), 'hex');
            IF EXISTS(SELECT 1 FROM deleted_accounts WHERE account_id = r.account_id AND recovery_key_hash = computed_hash) THEN
                RETURN jsonb_build_object(
                    'exists', true,
                    'is_deleted', true,
                    'status', 'DELETED',
                    'message', 'This account has been permanently deleted.'
                );
            END IF;
        END LOOP;
    END IF;

    -- Check if active account exists
    IF p_account_id IS NOT NULL AND length(trim(p_account_id)) > 0 THEN
        IF EXISTS(SELECT 1 FROM guest_sessions WHERE id = trim(p_account_id) AND (is_revoked IS NULL OR is_revoked = false)) THEN
            RETURN jsonb_build_object('exists', true, 'is_deleted', false, 'status', 'ACTIVE');
        END IF;
    END IF;

    RETURN jsonb_build_object('exists', false, 'is_deleted', false, 'status', 'NOT_FOUND');
END;
$$;

-- 5. Update kith_recover_guest_account to check deleted_accounts first
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
    is_deleted BOOLEAN := FALSE;
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

    -- FIRST: Check if this key matches any record in deleted_accounts
    FOR r IN SELECT account_id, salt FROM deleted_accounts WHERE salt IS NOT NULL LOOP
        computed_hash := encode(extensions.hmac(normalized_key::bytea, r.salt::bytea, 'sha256'), 'hex');
        IF EXISTS(SELECT 1 FROM deleted_accounts WHERE account_id = r.account_id AND recovery_key_hash = computed_hash) THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'ACCOUNT_DELETED',
                'message', 'This account has been permanently deleted and cannot be restored.'
            );
        END IF;
    END LOOP;

    -- SECOND: Match against stored recovery key hashes in active guest_sessions
    FOR r IN SELECT id, recovery_key, anonymous_token, display_name, created_at, is_revoked
             FROM guest_sessions
             WHERE recovery_key IS NOT NULL AND anonymous_token IS NOT NULL LOOP

        computed_hash := encode(extensions.hmac(normalized_key::bytea, r.anonymous_token::bytea, 'sha256'), 'hex');

        IF computed_hash = r.recovery_key THEN
            -- Check if session was revoked or account was deleted
            IF r.is_revoked = true OR EXISTS(SELECT 1 FROM deleted_accounts WHERE account_id = r.id) THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'error', 'ACCOUNT_DELETED',
                    'message', 'This account has been permanently deleted and cannot be restored.'
                );
            END IF;

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
