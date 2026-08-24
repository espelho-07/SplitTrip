-- ==============================================================================
-- Kith PostgreSQL Migration: 002_personal_finance.sql
-- Personal expenses, lending/borrowing, repayments and monthly budgets
-- ==============================================================================

-- 1. Personal Expenses
CREATE TABLE IF NOT EXISTS personal_expenses (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    amount_in_paise BIGINT NOT NULL CHECK (amount_in_paise > 0),
    category VARCHAR(64) NOT NULL DEFAULT 'general',
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT,
    voice_transcript TEXT,
    receipt_url TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_personal_expenses_user_id ON personal_expenses(user_id);
CREATE INDEX IF NOT EXISTS idx_personal_expenses_date ON personal_expenses(date);
CREATE INDEX IF NOT EXISTS idx_personal_expenses_category ON personal_expenses(category);

-- 2. Personal Debts (Lending & Borrowing)
CREATE TABLE IF NOT EXISTS personal_debts (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    person_name VARCHAR(255) NOT NULL,
    debt_type VARCHAR(32) NOT NULL CHECK (debt_type IN ('lent', 'borrowed')),
    initial_amount_in_paise BIGINT NOT NULL CHECK (initial_amount_in_paise > 0),
    remaining_amount_in_paise BIGINT NOT NULL CHECK (remaining_amount_in_paise >= 0),
    description VARCHAR(255),
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_date TIMESTAMPTZ,
    is_settled BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_personal_debts_user_id ON personal_debts(user_id);
CREATE INDEX IF NOT EXISTS idx_personal_debts_person_name ON personal_debts(person_name);
CREATE INDEX IF NOT EXISTS idx_personal_debts_is_settled ON personal_debts(is_settled);

-- 3. Personal Repayments (Settlement records for debts)
CREATE TABLE IF NOT EXISTS personal_repayments (
    id VARCHAR(64) PRIMARY KEY,
    debt_id VARCHAR(64) NOT NULL REFERENCES personal_debts(id) ON DELETE CASCADE,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount_in_paise BIGINT NOT NULL CHECK (amount_in_paise > 0),
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_personal_repayments_debt_id ON personal_repayments(debt_id);
CREATE INDEX IF NOT EXISTS idx_personal_repayments_user_id ON personal_repayments(user_id);

-- 4. Personal Budgets
CREATE TABLE IF NOT EXISTS personal_budgets (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    month_year VARCHAR(7) NOT NULL, -- Format: YYYY-MM
    monthly_limit_in_paise BIGINT NOT NULL CHECK (monthly_limit_in_paise > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_month_budget UNIQUE(user_id, month_year)
);

CREATE INDEX IF NOT EXISTS idx_personal_budgets_user_month ON personal_budgets(user_id, month_year);
