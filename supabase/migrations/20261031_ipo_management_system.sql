-- ==============================================================================
-- KITH FINANCIAL MODE: IPO MANAGEMENT SYSTEM MIGRATION
-- Migration Date: 2026-10-31
-- Description: Creates modular tables for IPO Master data, Demat Accounts,
--              Applications, Mandates, Allotments, Refunds & Audit Logs with RLS.
-- ==============================================================================

-- 1. IPO Master Table (Public Market Feed Cache)
CREATE TABLE IF NOT EXISTS ipo_master (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    company_name TEXT,
    symbol TEXT,
    market_type TEXT NOT NULL DEFAULT 'mainboard',
    status TEXT NOT NULL DEFAULT 'upcoming',
    open_date TIMESTAMPTZ NOT NULL,
    close_date TIMESTAMPTZ NOT NULL,
    allotment_date TIMESTAMPTZ,
    refund_date TIMESTAMPTZ,
    listing_date TIMESTAMPTZ,
    min_price INTEGER NOT NULL DEFAULT 0,
    max_price INTEGER NOT NULL DEFAULT 0,
    lot_size INTEGER NOT NULL DEFAULT 1,
    issue_size_crores NUMERIC,
    fresh_issue_crores NUMERIC,
    ofs_crores NUMERIC,
    gmp INTEGER,
    subscription_overall NUMERIC,
    subscription_qib NUMERIC,
    subscription_nii NUMERIC,
    subscription_retail NUMERIC,
    last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ipo_master_status ON ipo_master(status);
CREATE INDEX IF NOT EXISTS idx_ipo_master_dates ON ipo_master(open_date, close_date);
CREATE INDEX IF NOT EXISTS idx_ipo_master_symbol ON ipo_master(symbol);

-- 2. User Demat Accounts (Multi-Account Demat Profiles)
CREATE TABLE IF NOT EXISTS user_demat_accounts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES user_accounts(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    masked_pan TEXT NOT NULL DEFAULT '',
    account_holder_name TEXT,
    upi_id TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_demat_accounts_user ON user_demat_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_demat_accounts_active ON user_demat_accounts(user_id, is_active);

-- 3. IPO Applications (Per-Account Applications)
CREATE TABLE IF NOT EXISTS ipo_applications (
    id TEXT PRIMARY KEY,
    ipo_id TEXT NOT NULL REFERENCES ipo_master(id) ON DELETE CASCADE,
    ipo_name TEXT NOT NULL,
    user_id TEXT NOT NULL REFERENCES user_accounts(id) ON DELETE CASCADE,
    application_account_id TEXT REFERENCES user_demat_accounts(id) ON DELETE SET NULL,
    account_display_name TEXT,
    account_masked_pan TEXT,
    application_number TEXT,
    registrar TEXT,
    application_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    lots_applied INTEGER NOT NULL DEFAULT 1,
    lot_size INTEGER NOT NULL DEFAULT 1,
    bid_price_in_rupees INTEGER NOT NULL,
    bid_price_type TEXT NOT NULL DEFAULT 'cutoff',
    application_amount_in_paise BIGINT NOT NULL,
    actual_submitted_amount_in_paise BIGINT,
    mandate_amount_in_paise BIGINT,
    upi_mandate_status TEXT NOT NULL DEFAULT 'pending',
    status TEXT NOT NULL DEFAULT 'planned',
    allotted_lots INTEGER DEFAULT 0,
    allotted_shares INTEGER DEFAULT 0,
    actual_invested_amount_in_paise BIGINT DEFAULT 0,
    released_amount_in_paise BIGINT DEFAULT 0,
    refund_initiated_amount_in_paise BIGINT DEFAULT 0,
    refund_initiated_date TIMESTAMPTZ,
    refund_credited_date TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ipo_applications_user ON ipo_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_ipo_applications_ipo ON ipo_applications(ipo_id);
CREATE INDEX IF NOT EXISTS idx_ipo_applications_status ON ipo_applications(status);
CREATE INDEX IF NOT EXISTS idx_ipo_applications_account ON ipo_applications(application_account_id);

-- 4. IPO Application Audit Logs
CREATE TABLE IF NOT EXISTS ipo_application_audits (
    id TEXT PRIMARY KEY,
    application_id TEXT NOT NULL REFERENCES ipo_applications(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES user_accounts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ipo_application_audits_app ON ipo_application_audits(application_id);

-- ==============================================================================
-- ROW-LEVEL SECURITY (RLS) POLICIES
-- Strict Isolation: Users can ONLY view and mutate their own demat accounts & applications.
-- ==============================================================================

ALTER TABLE ipo_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_demat_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ipo_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE ipo_application_audits ENABLE ROW LEVEL SECURITY;

-- 1. IPO Master RLS (Public read, authenticated or guest read-only)
DROP POLICY IF EXISTS "ipo_master_public_read" ON ipo_master;
CREATE POLICY "ipo_master_public_read"
    ON ipo_master FOR SELECT
    USING (true);

-- 2. User Demat Accounts RLS
DROP POLICY IF EXISTS "user_demat_accounts_select" ON user_demat_accounts;
CREATE POLICY "user_demat_accounts_select"
    ON user_demat_accounts FOR SELECT
    USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "user_demat_accounts_insert" ON user_demat_accounts;
CREATE POLICY "user_demat_accounts_insert"
    ON user_demat_accounts FOR INSERT
    WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "user_demat_accounts_update" ON user_demat_accounts;
CREATE POLICY "user_demat_accounts_update"
    ON user_demat_accounts FOR UPDATE
    USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "user_demat_accounts_delete" ON user_demat_accounts;
CREATE POLICY "user_demat_accounts_delete"
    ON user_demat_accounts FOR DELETE
    USING (user_id = auth.uid()::text);

-- 3. IPO Applications RLS
DROP POLICY IF EXISTS "ipo_applications_select" ON ipo_applications;
CREATE POLICY "ipo_applications_select"
    ON ipo_applications FOR SELECT
    USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "ipo_applications_insert" ON ipo_applications;
CREATE POLICY "ipo_applications_insert"
    ON ipo_applications FOR INSERT
    WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "ipo_applications_update" ON ipo_applications;
CREATE POLICY "ipo_applications_update"
    ON ipo_applications FOR UPDATE
    USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "ipo_applications_delete" ON ipo_applications;
CREATE POLICY "ipo_applications_delete"
    ON ipo_applications FOR DELETE
    USING (user_id = auth.uid()::text);

-- 4. IPO Application Audits RLS
DROP POLICY IF EXISTS "ipo_audits_select" ON ipo_application_audits;
CREATE POLICY "ipo_audits_select"
    ON ipo_application_audits FOR SELECT
    USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "ipo_audits_insert" ON ipo_application_audits;
CREATE POLICY "ipo_audits_insert"
    ON ipo_application_audits FOR INSERT
    WITH CHECK (user_id = auth.uid()::text);
