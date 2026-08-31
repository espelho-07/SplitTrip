-- Migration 006: Guest Sessions for Cross-Reinstall Recovery
-- Stores anonymous guest account metadata in Supabase to provide
-- a reliable secondary recovery layer if local SharedPreferences are cleared.

CREATE TABLE IF NOT EXISTS public.guest_sessions (
    id TEXT PRIMARY KEY,
    recovery_key TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL DEFAULT 'Traveler',
    anonymous_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indices for fast lookups
CREATE INDEX IF NOT EXISTS idx_guest_sessions_recovery_key ON public.guest_sessions(recovery_key);
CREATE INDEX IF NOT EXISTS idx_guest_sessions_last_seen ON public.guest_sessions(last_seen_at);

-- Row Level Security (RLS)
ALTER TABLE public.guest_sessions ENABLE ROW LEVEL SECURITY;

-- Allow anonymous users to upsert and query their own session by ID or recovery key
CREATE POLICY "Allow anon select guest session" ON public.guest_sessions
    FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Allow anon upsert guest session" ON public.guest_sessions
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

CREATE POLICY "Allow anon update guest session" ON public.guest_sessions
    FOR UPDATE
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);
