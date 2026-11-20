-- ==============================================================================
-- Kith Supabase Migration: 20261120000002_allow_unclaimed_member_spot_claim.sql
-- Enables invited users to claim their unclaimed virtual member spot when joining via QR code.
-- ==============================================================================

-- 1. Allow reading unclaimed virtual member placeholders for invite code previews
DROP POLICY IF EXISTS "trip_members_select" ON trip_members;

CREATE POLICY "trip_members_select" ON trip_members FOR SELECT
    TO anon, authenticated
    USING (
        kith_is_trip_member(trip_id, kith_current_user_id())
        OR is_claimed = false
        OR is_virtual = true
        OR status = 'unclaimed'
        OR user_id LIKE 'unclaimed_%'
    );

-- 2. Allow claiming an unclaimed virtual member placeholder
-- USING: allows targeting an existing unclaimed placeholder, or an owned record, or as creator
-- WITH CHECK: guarantees the updated row is owned by the claiming user (or creator)
DROP POLICY IF EXISTS "trip_members_update" ON trip_members;

CREATE POLICY "trip_members_update" ON trip_members FOR UPDATE
    TO anon, authenticated
    USING (
        user_id = kith_current_user_id()
        OR kith_is_trip_creator(trip_id, kith_current_user_id())
        OR is_claimed = false
        OR status = 'unclaimed'
        OR user_id LIKE 'unclaimed_%'
        OR is_virtual = true
    )
    WITH CHECK (
        user_id = kith_current_user_id()
        OR kith_is_trip_creator(trip_id, kith_current_user_id())
    );
