-- ==============================================================================
-- Kith Supabase Migration: 20260901_schema_baseline.sql (Self-Healing & Idempotent)
-- Creates all tables and ensures all missing columns exist before creating indexes.
-- ==============================================================================

-- 1. Guest Sessions (Layer 2 Supabase Account Recovery & Metadata)
CREATE TABLE IF NOT EXISTS guest_sessions (
    id VARCHAR(64) PRIMARY KEY,
    display_name VARCHAR(255) NOT NULL DEFAULT 'Traveler',
    avatar_url TEXT,
    recovery_key VARCHAR(255),
    recovery_key_hash VARCHAR(64),
    anonymous_token VARCHAR(255),
    device_id VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure columns exist if table was already created in earlier migration
ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS display_name VARCHAR(255) DEFAULT 'Traveler';
ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS recovery_key VARCHAR(255);
ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS recovery_key_hash VARCHAR(64);
ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS anonymous_token VARCHAR(255);
ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS device_id VARCHAR(128);
ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE guest_sessions ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_guest_sessions_key ON guest_sessions(recovery_key);
CREATE INDEX IF NOT EXISTS idx_guest_sessions_hash ON guest_sessions(recovery_key_hash);

-- 2. Users & Google Linked Identity
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    display_name VARCHAR(255) NOT NULL DEFAULT 'Traveler',
    avatar_url TEXT,
    recovery_key VARCHAR(255),
    recovery_key_hash VARCHAR(64),
    is_guest BOOLEAN NOT NULL DEFAULT TRUE,
    email VARCHAR(255),
    google_id VARCHAR(128),
    upi_id VARCHAR(128),
    upi_qr TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure columns exist if table was already created
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name VARCHAR(255) DEFAULT 'Traveler';
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS recovery_key VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS recovery_key_hash VARCHAR(64);
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_guest BOOLEAN DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(128);
ALTER TABLE users ADD COLUMN IF NOT EXISTS upi_id VARCHAR(128);
ALTER TABLE users ADD COLUMN IF NOT EXISTS upi_qr TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_users_recovery_key ON users(recovery_key);
CREATE INDEX IF NOT EXISTS idx_users_recovery_hash ON users(recovery_key_hash);
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);

-- 3. Sessions
CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(64) PRIMARY KEY,
    token VARCHAR(255) NOT NULL UNIQUE,
    user_id VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days')
);

ALTER TABLE sessions ADD COLUMN IF NOT EXISTS token VARCHAR(255);
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS user_id VARCHAR(64);
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days');

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

ALTER TABLE user_fcm_tokens ADD COLUMN IF NOT EXISTS user_id VARCHAR(64);
ALTER TABLE user_fcm_tokens ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE user_fcm_tokens ADD COLUMN IF NOT EXISTS device_id VARCHAR(128);
ALTER TABLE user_fcm_tokens ADD COLUMN IF NOT EXISTS platform VARCHAR(32) DEFAULT 'android';
ALTER TABLE user_fcm_tokens ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

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

ALTER TABLE trips ADD COLUMN IF NOT EXISTS name VARCHAR(255);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS emoji VARCHAR(32) DEFAULT '✈️';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS cover_gradient_index INT DEFAULT 0;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3) DEFAULT 'INR';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS creator_id VARCHAR(64);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS invite_code VARCHAR(12);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS lifecycle_state VARCHAR(32) DEFAULT 'active';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE trips ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_trips_invite_code ON trips(invite_code);
CREATE INDEX IF NOT EXISTS idx_trips_creator_id ON trips(creator_id);

-- 6. Trip Members
CREATE TABLE IF NOT EXISTS trip_members (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL,
    user_id VARCHAR(64) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    role VARCHAR(32) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS trip_id VARCHAR(64);
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS user_id VARCHAR(64);
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS display_name VARCHAR(255);
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS role VARCHAR(32) DEFAULT 'member';
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS joined_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_trip_members_trip_id ON trip_members(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_members_user_id ON trip_members(user_id);

-- 7. Expenses
CREATE TABLE IF NOT EXISTS expenses (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL,
    amount_in_paise BIGINT NOT NULL DEFAULT 0,
    paid_by_id VARCHAR(64) NOT NULL,
    category VARCHAR(64) NOT NULL DEFAULT 'general',
    split_type VARCHAR(32) NOT NULL DEFAULT 'equal',
    receipt_url TEXT,
    notes TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE expenses ADD COLUMN IF NOT EXISTS trip_id VARCHAR(64);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS title VARCHAR(255);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS amount_in_paise BIGINT DEFAULT 0;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS paid_by_id VARCHAR(64);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS category VARCHAR(64) DEFAULT 'general';
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS split_type VARCHAR(32) DEFAULT 'equal';
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS receipt_url TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_expenses_trip_id ON expenses(trip_id);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON expenses(paid_by_id);

-- 8. Expense Splits
CREATE TABLE IF NOT EXISTS expense_splits (
    id VARCHAR(64) PRIMARY KEY,
    expense_id VARCHAR(64) NOT NULL,
    member_id VARCHAR(64) NOT NULL,
    amount_in_paise BIGINT NOT NULL DEFAULT 0,
    percentage NUMERIC(5, 2),
    shares INT,
    is_settled BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE expense_splits ADD COLUMN IF NOT EXISTS expense_id VARCHAR(64);
ALTER TABLE expense_splits ADD COLUMN IF NOT EXISTS member_id VARCHAR(64);
ALTER TABLE expense_splits ADD COLUMN IF NOT EXISTS amount_in_paise BIGINT DEFAULT 0;
ALTER TABLE expense_splits ADD COLUMN IF NOT EXISTS percentage NUMERIC(5, 2);
ALTER TABLE expense_splits ADD COLUMN IF NOT EXISTS shares INT;
ALTER TABLE expense_splits ADD COLUMN IF NOT EXISTS is_settled BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_splits_expense_id ON expense_splits(expense_id);
CREATE INDEX IF NOT EXISTS idx_splits_member_id ON expense_splits(member_id);

-- 9. Settlements
CREATE TABLE IF NOT EXISTS settlements (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL,
    from_member_id VARCHAR(64) NOT NULL,
    to_member_id VARCHAR(64) NOT NULL,
    amount_in_paise BIGINT NOT NULL DEFAULT 0,
    status VARCHAR(32) NOT NULL DEFAULT 'completed',
    payment_method VARCHAR(32) NOT NULL DEFAULT 'upi',
    reference_id VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ
);

ALTER TABLE settlements ADD COLUMN IF NOT EXISTS trip_id VARCHAR(64);
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS from_member_id VARCHAR(64);
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS to_member_id VARCHAR(64);
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS amount_in_paise BIGINT DEFAULT 0;
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'completed';
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS payment_method VARCHAR(32) DEFAULT 'upi';
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS reference_id VARCHAR(128);
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_settlements_trip_id ON settlements(trip_id);

-- 10. Trip Journey Moments
CREATE TABLE IF NOT EXISTS trip_journey_moments (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL,
    creator_id VARCHAR(64) NOT NULL,
    caption TEXT,
    location_name VARCHAR(255),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE trip_journey_moments ADD COLUMN IF NOT EXISTS trip_id VARCHAR(64);
ALTER TABLE trip_journey_moments ADD COLUMN IF NOT EXISTS creator_id VARCHAR(64);
ALTER TABLE trip_journey_moments ADD COLUMN IF NOT EXISTS caption TEXT;
ALTER TABLE trip_journey_moments ADD COLUMN IF NOT EXISTS location_name VARCHAR(255);
ALTER TABLE trip_journey_moments ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE trip_journey_moments ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE trip_journey_moments ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_journey_moments_trip_id ON trip_journey_moments(trip_id);

-- 11. Personal Finance (Expenses, Debts, Budgets)
CREATE TABLE IF NOT EXISTS personal_expenses (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL,
    amount_in_paise BIGINT NOT NULL DEFAULT 0,
    category VARCHAR(64) NOT NULL DEFAULT 'general',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE personal_expenses ADD COLUMN IF NOT EXISTS user_id VARCHAR(64);
ALTER TABLE personal_expenses ADD COLUMN IF NOT EXISTS title VARCHAR(255);
ALTER TABLE personal_expenses ADD COLUMN IF NOT EXISTS amount_in_paise BIGINT DEFAULT 0;
ALTER TABLE personal_expenses ADD COLUMN IF NOT EXISTS category VARCHAR(64) DEFAULT 'general';
ALTER TABLE personal_expenses ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE personal_expenses ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE personal_expenses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_personal_expenses_user ON personal_expenses(user_id);

CREATE TABLE IF NOT EXISTS personal_debts (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    person_name VARCHAR(255) NOT NULL,
    amount_in_paise BIGINT NOT NULL DEFAULT 0,
    is_i_owe BOOLEAN NOT NULL DEFAULT TRUE,
    is_cleared BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_date TIMESTAMPTZ
);

ALTER TABLE personal_debts ADD COLUMN IF NOT EXISTS user_id VARCHAR(64);
ALTER TABLE personal_debts ADD COLUMN IF NOT EXISTS person_name VARCHAR(255);
ALTER TABLE personal_debts ADD COLUMN IF NOT EXISTS amount_in_paise BIGINT DEFAULT 0;
ALTER TABLE personal_debts ADD COLUMN IF NOT EXISTS is_i_owe BOOLEAN DEFAULT TRUE;
ALTER TABLE personal_debts ADD COLUMN IF NOT EXISTS is_cleared BOOLEAN DEFAULT FALSE;
ALTER TABLE personal_debts ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE personal_debts ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE personal_debts ADD COLUMN IF NOT EXISTS due_date TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_personal_debts_user ON personal_debts(user_id);

CREATE TABLE IF NOT EXISTS personal_budgets (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    month_key VARCHAR(7) NOT NULL,
    monthly_limit_in_paise BIGINT NOT NULL DEFAULT 0,
    spent_in_paise BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE personal_budgets ADD COLUMN IF NOT EXISTS user_id VARCHAR(64);
ALTER TABLE personal_budgets ADD COLUMN IF NOT EXISTS month_key VARCHAR(7);
ALTER TABLE personal_budgets ADD COLUMN IF NOT EXISTS monthly_limit_in_paise BIGINT DEFAULT 0;
ALTER TABLE personal_budgets ADD COLUMN IF NOT EXISTS spent_in_paise BIGINT DEFAULT 0;
ALTER TABLE personal_budgets ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE personal_budgets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

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

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS user_id VARCHAR(64);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS title VARCHAR(255);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS type VARCHAR(64) DEFAULT 'general';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS payload JSONB DEFAULT '{}'::jsonb;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);

CREATE TABLE IF NOT EXISTS processed_operations (
    idempotency_key VARCHAR(128) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    action_type VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE processed_operations ADD COLUMN IF NOT EXISTS user_id VARCHAR(64);
ALTER TABLE processed_operations ADD COLUMN IF NOT EXISTS action_type VARCHAR(64);
ALTER TABLE processed_operations ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
