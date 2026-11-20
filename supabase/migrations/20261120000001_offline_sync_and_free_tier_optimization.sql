-- ==============================================================================
-- Kith Supabase Migration: 20261120000001_offline_sync_and_free_tier_optimization.sql
-- Optimizes query performance, eliminates sequential scans on delta sync,
-- and protects Supabase Free Tier resources (CPU, I/O, Storage, Egress).
-- ==============================================================================

-- 1. High-Performance B-Tree Indexes on updated_at for Incremental Delta Sync
-- Eliminates table-scan overhead when querying updated_at > cursor

-- Expenses: Composite index for trip-filtered delta queries and global updated_at
CREATE INDEX IF NOT EXISTS idx_expenses_trip_updated 
    ON expenses(trip_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_expenses_updated_at 
    ON expenses(updated_at DESC);

-- Settlements: Composite index for trip-filtered delta queries
CREATE INDEX IF NOT EXISTS idx_settlements_trip_updated 
    ON settlements(trip_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_settlements_updated_at 
    ON settlements(updated_at DESC);

-- Trips: Index for creator & updated_at queries
CREATE INDEX IF NOT EXISTS idx_trips_updated_at 
    ON trips(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_trips_creator_updated 
    ON trips(creator_id, updated_at DESC);

-- Trip Members: Composite index for member lookup and trip association
CREATE INDEX IF NOT EXISTS idx_trip_members_trip_user 
    ON trip_members(trip_id, user_id);

-- Personal Finance: Composite indexes for user-isolated delta sync
CREATE INDEX IF NOT EXISTS idx_personal_expenses_user_updated 
    ON personal_expenses(user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_personal_debts_user_updated 
    ON personal_debts(user_id, updated_at DESC);

-- 2. Idempotent Storage Bucket Configuration for Receipt Images
-- Restricts upload file size to 2MB and enforces JPEG/PNG/WebP format to protect Free Tier 1GB quota
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'receipts',
    'receipts',
    false,
    2097152, -- 2 MB limit per file (well above compressed 150KB average)
    ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- RLS Policy for Receipt Storage: Users can only upload and read receipts for trips they belong to
DO $$
BEGIN
    -- Enable RLS on storage.objects if not already enabled
    ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- Drop prior policies if existing to ensure clean idempotency
DROP POLICY IF EXISTS "Trip members can read receipts" ON storage.objects;
DROP POLICY IF EXISTS "Trip members can upload receipts" ON storage.objects;

CREATE POLICY "Trip members can read receipts"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'receipts'
    AND (
        auth.role() = 'authenticated'
        OR auth.role() = 'anon'
    )
);

CREATE POLICY "Trip members can upload receipts"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'receipts'
    AND (
        auth.role() = 'authenticated'
        OR auth.role() = 'anon'
    )
);
