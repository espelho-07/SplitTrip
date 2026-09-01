-- ==============================================================================
-- Kith Supabase Migration: 20260901_schema_baseline.sql
-- Strictly enforces integer smallest-unit money (BIGINT), relational foreign keys,
-- cascade constraints, and query indexes across all 18 Kith tables.
-- ==============================================================================

-- 1. Guest Sessions (Layer 2 Supabase Account Recovery & Metadata)
CREATE TABLE IF NOT EXISTS guest_sessions (
    id VARCHAR(64) PRIMARY KEY,
    display_name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    recovery_key_hash VARCHAR(64) NOT NULL,
    device_id VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_guest_sessions_hash ON guest_sessions(recovery_key_hash);

-- 2. Users & Google Linked Identity
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    display_name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    recovery_key_hash VARCHAR(64) NOT NULL,
    is_guest BOOLEAN NOT NULL DEFAULT TRUE,
    email VARCHAR(255),
    google_id VARCHAR(128),
    upi_id VARCHAR(128),
    upi_qr TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_users_recovery_hash ON users(recovery_key_hash);
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);

-- 3. Sessions
CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(64) PRIMARY KEY,
    token VARCHAR(255) NOT NULL UNIQUE,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);

-- 4. Devices & FCM Tokens
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    fcm_token TEXT NOT NULL,
    device_id VARCHAR(128),
    platform VARCHAR(32) DEFAULT 'android',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fcm_user_id ON user_fcm_tokens(user_id);

-- 5. Trips
CREATE TABLE IF NOT EXISTS trips (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    emoji VARCHAR(32) DEFAULT '✈️',
    cover_gradient_index INT DEFAULT 0,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'INR',
    creator_id VARCHAR(64) NOT NULL,
    invite_code VARCHAR(12) NOT NULL UNIQUE,
    lifecycle_state VARCHAR(32) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_trips_invite_code ON trips(invite_code);
CREATE INDEX IF NOT EXISTS idx_trips_creator_id ON trips(creator_id);

-- 6. Trip Members
CREATE TABLE IF NOT EXISTS trip_members (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    user_id VARCHAR(64) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    role VARCHAR(32) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_trip_members_trip_id ON trip_members(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_members_user_id ON trip_members(user_id);

-- 7. Expenses
CREATE TABLE IF NOT EXISTS expenses (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    amount_in_paise BIGINT NOT NULL CHECK (amount_in_paise >= 0),
    paid_by_id VARCHAR(64) NOT NULL REFERENCES trip_members(id) ON DELETE RESTRICT,
    category VARCHAR(64) NOT NULL DEFAULT 'general',
    split_type VARCHAR(32) NOT NULL DEFAULT 'equal',
    receipt_url TEXT,
    notes TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_expenses_trip_id ON expenses(trip_id);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON expenses(paid_by_id);

-- 8. Expense Splits
CREATE TABLE IF NOT EXISTS expense_splits (
    id VARCHAR(64) PRIMARY KEY,
    expense_id VARCHAR(64) NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    member_id VARCHAR(64) NOT NULL REFERENCES trip_members(id) ON DELETE CASCADE,
    amount_in_paise BIGINT NOT NULL CHECK (amount_in_paise >= 0),
    percentage NUMERIC(5, 2),
    shares INT,
    is_settled BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_splits_expense_id ON expense_splits(expense_id);
CREATE INDEX IF NOT EXISTS idx_splits_member_id ON expense_splits(member_id);

-- 9. Settlements
CREATE TABLE IF NOT EXISTS settlements (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    from_member_id VARCHAR(64) NOT NULL REFERENCES trip_members(id) ON DELETE RESTRICT,
    to_member_id VARCHAR(64) NOT NULL REFERENCES trip_members(id) ON DELETE RESTRICT,
    amount_in_paise BIGINT NOT NULL CHECK (amount_in_paise > 0),
    status VARCHAR(32) NOT NULL DEFAULT 'completed',
    payment_method VARCHAR(32) NOT NULL DEFAULT 'upi',
    reference_id VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_settlements_trip_id ON settlements(trip_id);

-- 10. Trip Journey Moments
CREATE TABLE IF NOT EXISTS trip_journey_moments (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    creator_id VARCHAR(64) NOT NULL,
    caption TEXT,
    location_name VARCHAR(255),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_journey_moments_trip_id ON trip_journey_moments(trip_id);

-- 11. Personal Finance (Expenses, Debts, Budgets)
CREATE TABLE IF NOT EXISTS personal_expenses (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL,
    amount_in_paise BIGINT NOT NULL,
    category VARCHAR(64) NOT NULL DEFAULT 'general',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_personal_expenses_user ON personal_expenses(user_id);

CREATE TABLE IF NOT EXISTS personal_debts (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    person_name VARCHAR(255) NOT NULL,
    amount_in_paise BIGINT NOT NULL,
    is_i_owe BOOLEAN NOT NULL DEFAULT TRUE,
    is_cleared BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_date TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_personal_debts_user ON personal_debts(user_id);

CREATE TABLE IF NOT EXISTS personal_budgets (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    month_key VARCHAR(7) NOT NULL,
    monthly_limit_in_paise BIGINT NOT NULL,
    spent_in_paise BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_personal_budgets_user ON personal_budgets(user_id, month_key);

-- 12. Notifications & Idempotency
CREATE TABLE IF NOT EXISTS notifications (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(64) NOT NULL DEFAULT 'general',
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);

CREATE TABLE IF NOT EXISTS processed_operations (
    idempotency_key VARCHAR(128) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    action_type VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
