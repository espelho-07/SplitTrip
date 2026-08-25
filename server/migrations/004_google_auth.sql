-- ==============================================================================
-- Kith PostgreSQL Migration: 004_google_auth.sql
-- Google OAuth identity, google_id unique index, and optional recovery key for cloud users
-- ==============================================================================

ALTER TABLE users ALTER COLUMN recovery_key_hash DROP NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255);
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
