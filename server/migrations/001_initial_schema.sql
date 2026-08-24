-- ==============================================================================
-- Kith PostgreSQL Migration: 001_initial_schema.sql
-- Strictly enforces integer smallest-unit money (BIGINT), relational foreign keys,
-- cascade constraints, and query indexes.
-- ==============================================================================

-- 1. Users & Guest Identity
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    display_name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    recovery_key_hash VARCHAR(64) NOT NULL,
    is_guest BOOLEAN NOT NULL DEFAULT TRUE,
    email VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_recovery_hash ON users(recovery_key_hash);

-- 2. Sessions
CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(64) PRIMARY KEY,
    token VARCHAR(255) NOT NULL UNIQUE,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);

-- 3. Trips
CREATE TABLE IF NOT EXISTS trips (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    emoji VARCHAR(32) DEFAULT '✈️',
    cover_gradient_index INT DEFAULT 0,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'INR',
    creator_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invite_code VARCHAR(12) NOT NULL UNIQUE,
    lifecycle_state VARCHAR(32) NOT NULL DEFAULT 'active' CHECK (lifecycle_state IN ('active', 'completed', 'settling', 'settled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trips_invite_code ON trips(invite_code);
CREATE INDEX IF NOT EXISTS idx_trips_creator_id ON trips(creator_id);
CREATE INDEX IF NOT EXISTS idx_trips_lifecycle ON trips(lifecycle_state);

-- 4. Trip Members
CREATE TABLE IF NOT EXISTS trip_members (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    role VARCHAR(32) NOT NULL DEFAULT 'member' CHECK (role IN ('creator', 'admin', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_trip_member UNIQUE(trip_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_trip_members_trip_id ON trip_members(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_members_user_id ON trip_members(user_id);

-- 5. Expenses
CREATE TABLE IF NOT EXISTS expenses (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    amount_in_paise BIGINT NOT NULL CHECK (amount_in_paise > 0),
    category VARCHAR(64) NOT NULL DEFAULT 'general',
    paid_by_id VARCHAR(64) NOT NULL REFERENCES trip_members(id) ON DELETE CASCADE,
    split_type VARCHAR(32) NOT NULL DEFAULT 'equal' CHECK (split_type IN ('equal', 'shares', 'percentage', 'custom')),
    voice_transcript TEXT,
    receipt_url TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    created_by_id VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expenses_trip_id ON expenses(trip_id);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON expenses(paid_by_id);
CREATE INDEX IF NOT EXISTS idx_expenses_created_at ON expenses(created_at);

-- 6. Expense Participant Splits
CREATE TABLE IF NOT EXISTS expense_splits (
    id VARCHAR(64) PRIMARY KEY,
    expense_id VARCHAR(64) NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    member_id VARCHAR(64) NOT NULL REFERENCES trip_members(id) ON DELETE CASCADE,
    amount_in_paise BIGINT NOT NULL CHECK (amount_in_paise >= 0),
    shares INT,
    percentage INT,
    CONSTRAINT uq_expense_split UNIQUE(expense_id, member_id)
);

CREATE INDEX IF NOT EXISTS idx_expense_splits_expense_id ON expense_splits(expense_id);
CREATE INDEX IF NOT EXISTS idx_expense_splits_member_id ON expense_splits(member_id);

-- 7. Settlements
CREATE TABLE IF NOT EXISTS settlements (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    from_member_id VARCHAR(64) NOT NULL REFERENCES trip_members(id) ON DELETE CASCADE,
    to_member_id VARCHAR(64) NOT NULL REFERENCES trip_members(id) ON DELETE CASCADE,
    amount_in_paise BIGINT NOT NULL CHECK (amount_in_paise > 0),
    payment_reference TEXT,
    note TEXT,
    is_settled BOOLEAN NOT NULL DEFAULT TRUE,
    recorded_by_id VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settled_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_settlements_trip_id ON settlements(trip_id);
CREATE INDEX IF NOT EXISTS idx_settlements_from_member ON settlements(from_member_id);
CREATE INDEX IF NOT EXISTS idx_settlements_to_member ON settlements(to_member_id);
