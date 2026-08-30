-- ==============================================================================
-- Kith PostgreSQL Migration: 005_notifications_and_sync.sql
-- Notification dispatch, FCM tokens, durable operation idempotency, and member claims
-- ==============================================================================

-- 1. Trip Members enhancements for unclaimed members, P2P sync and UPI
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS claim_token VARCHAR(64);
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS is_claimed BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'claimed';
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS merged_into_member_id VARCHAR(64);
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS last_synced_revision INT NOT NULL DEFAULT 1;
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS pending_mutations_count INT NOT NULL DEFAULT 0;
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS upi_id VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_trip_members_claim_token ON trip_members(claim_token);
CREATE INDEX IF NOT EXISTS idx_trip_members_status ON trip_members(status);

-- 2. User FCM Push Registration Tokens
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_id VARCHAR(255),
    platform VARCHAR(32) NOT NULL DEFAULT 'android',
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON user_fcm_tokens(token);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_device_id ON user_fcm_tokens(device_id);

-- 3. Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id VARCHAR(64) PRIMARY KEY,
    recipient_user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    actor_user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    trip_id VARCHAR(64) REFERENCES trips(id) ON DELETE CASCADE,
    type VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'UNREAD' CHECK (status IN ('UNREAD', 'READ', 'ACTIONED', 'DISMISSED')),
    payment_id VARCHAR(64),
    settlement_id VARCHAR(64),
    data JSONB,
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_trip_id ON notifications(trip_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);

-- 4. Durable Operation Idempotency Registry (P2P + Server Sync)
CREATE TABLE IF NOT EXISTS processed_operations (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    operation_id VARCHAR(255) NOT NULL,
    applied_by_user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    operation_type VARCHAR(64) NOT NULL,
    result JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_trip_operation UNIQUE(trip_id, operation_id)
);

CREATE INDEX IF NOT EXISTS idx_processed_operations_trip ON processed_operations(trip_id);
CREATE INDEX IF NOT EXISTS idx_processed_operations_op_id ON processed_operations(operation_id);
