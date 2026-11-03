-- ==============================================================================
-- Kith Supabase Migration: 20261101000002_harden_budgets_and_notifications_rls.sql
-- Hardens Row Level Security (RLS) for personal_budgets and notifications.
-- Replaces open placeholder USING (true) policies with strict cryptographic
-- account-level isolation.
-- ==============================================================================

-- 1. Personal Budgets Table Hardening
ALTER TABLE personal_budgets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Personal budgets account isolation" ON personal_budgets;
DROP POLICY IF EXISTS "personal_budgets_select" ON personal_budgets;
DROP POLICY IF EXISTS "personal_budgets_insert" ON personal_budgets;
DROP POLICY IF EXISTS "personal_budgets_update" ON personal_budgets;
DROP POLICY IF EXISTS "personal_budgets_delete" ON personal_budgets;

CREATE POLICY "personal_budgets_select" ON personal_budgets
    FOR SELECT TO anon, authenticated
    USING (user_id = kith_current_user_id());

CREATE POLICY "personal_budgets_insert" ON personal_budgets
    FOR INSERT TO anon, authenticated
    WITH CHECK (user_id = kith_current_user_id());

CREATE POLICY "personal_budgets_update" ON personal_budgets
    FOR UPDATE TO anon, authenticated
    USING (user_id = kith_current_user_id())
    WITH CHECK (user_id = kith_current_user_id());

CREATE POLICY "personal_budgets_delete" ON personal_budgets
    FOR DELETE TO anon, authenticated
    USING (user_id = kith_current_user_id());

-- 2. Notifications Table Hardening
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Notifications isolation" ON notifications;
DROP POLICY IF EXISTS "notifications_select" ON notifications;
DROP POLICY IF EXISTS "notifications_insert" ON notifications;
DROP POLICY IF EXISTS "notifications_update" ON notifications;
DROP POLICY IF EXISTS "notifications_delete" ON notifications;

CREATE POLICY "notifications_select" ON notifications
    FOR SELECT TO anon, authenticated
    USING (user_id = kith_current_user_id());

CREATE POLICY "notifications_insert" ON notifications
    FOR INSERT TO anon, authenticated
    WITH CHECK (user_id = kith_current_user_id());

CREATE POLICY "notifications_update" ON notifications
    FOR UPDATE TO anon, authenticated
    USING (user_id = kith_current_user_id())
    WITH CHECK (user_id = kith_current_user_id());

CREATE POLICY "notifications_delete" ON notifications
    FOR DELETE TO anon, authenticated
    USING (user_id = kith_current_user_id());
