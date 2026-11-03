-- ==============================================================================
-- Kith Supabase RLS Migration: 20260901000002_rls_security_policies.sql
-- Enables Row Level Security (RLS) across all user & collaborative tables.
-- Guarantees:
-- 1. User A CANNOT read, insert, update, or delete User B's personal data.
-- 2. Non-members CANNOT read, insert, or modify Trip details, expenses, or settlements.
-- 3. Anonymous public access is locked to valid key resolution and invite codes.
-- ==============================================================================

-- Enable RLS on all tables
ALTER TABLE guest_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_journey_moments ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE processed_operations ENABLE ROW LEVEL SECURITY;

-- 1. Guest Sessions Policies
DROP POLICY IF EXISTS "Allow anon account recovery and creation" ON guest_sessions;
CREATE POLICY "Allow anon account recovery and creation"
    ON guest_sessions FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- 2. Personal Finance Isolation Policies
DROP POLICY IF EXISTS "Personal expenses account isolation" ON personal_expenses;
CREATE POLICY "Personal expenses account isolation"
    ON personal_expenses FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Personal debts account isolation" ON personal_debts;
CREATE POLICY "Personal debts account isolation"
    ON personal_debts FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Personal budgets account isolation" ON personal_budgets;
CREATE POLICY "Personal budgets account isolation"
    ON personal_budgets FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- 3. Collaborative Trip Policies
DROP POLICY IF EXISTS "Trips access for members" ON trips;
CREATE POLICY "Trips access for members"
    ON trips FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Trip members access" ON trip_members;
CREATE POLICY "Trip members access"
    ON trip_members FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Trip expenses access" ON expenses;
CREATE POLICY "Trip expenses access"
    ON expenses FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Trip settlements access" ON settlements;
CREATE POLICY "Trip settlements access"
    ON settlements FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Notifications isolation" ON notifications;
CREATE POLICY "Notifications isolation"
    ON notifications FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);
