-- ==============================================================================
-- Kith Supabase Migration: 20261031_virtual_members_and_data_integrity.sql
-- Fixes Data Integrity, Virtual Member Persistence, and Sync Field Invariants
-- ==============================================================================

-- 1. Ensure trip_members supports both Registered Users and Virtual Participants
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS is_virtual BOOLEAN DEFAULT FALSE;
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS is_claimed BOOLEAN DEFAULT TRUE;
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS claim_token VARCHAR(255);
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'claimed';
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS merged_into_member_id VARCHAR(64);
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS upi_id VARCHAR(128);
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE trip_members ADD COLUMN IF NOT EXISTS last_synced_revision INT DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_trip_members_virtual ON trip_members(is_virtual);
CREATE INDEX IF NOT EXISTS idx_trip_members_status ON trip_members(status);
CREATE INDEX IF NOT EXISTS idx_trip_members_claim_token ON trip_members(claim_token);

-- 2. Ensure expenses table has all fields utilized by SupabaseCloudSync
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS paid_by_member_id VARCHAR(64);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS paid_by_user_id VARCHAR(64);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS splits JSONB DEFAULT '[]'::jsonb;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS location VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_expenses_paid_by_member ON expenses(paid_by_member_id);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by_user ON expenses(paid_by_user_id);

-- Backward-compatibility backfill: ensure paid_by_id and paid_by_member_id match
UPDATE expenses 
SET paid_by_member_id = paid_by_id 
WHERE paid_by_member_id IS NULL AND paid_by_id IS NOT NULL;

UPDATE expenses 
SET paid_by_id = paid_by_member_id 
WHERE paid_by_id IS NULL AND paid_by_member_id IS NOT NULL;
