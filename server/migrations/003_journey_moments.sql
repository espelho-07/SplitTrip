-- ==============================================================================
-- Kith PostgreSQL Migration: 003_journey_moments.sql
-- Relational Journey Moments & Photo references with cascade constraints
-- ==============================================================================

CREATE TABLE IF NOT EXISTS trip_journey_moments (
    id VARCHAR(64) PRIMARY KEY,
    trip_id VARCHAR(64) NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    created_by VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    place_name VARCHAR(255),
    note TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    day_index INT NOT NULL DEFAULT 1,
    expense_id VARCHAR(64) REFERENCES expenses(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_moments_trip_id ON trip_journey_moments(trip_id);
CREATE INDEX IF NOT EXISTS idx_moments_day_index ON trip_journey_moments(day_index);
CREATE INDEX IF NOT EXISTS idx_moments_occurred_at ON trip_journey_moments(occurred_at);

CREATE TABLE IF NOT EXISTS journey_moment_photos (
    id VARCHAR(64) PRIMARY KEY,
    moment_id VARCHAR(64) NOT NULL REFERENCES trip_journey_moments(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    caption TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_moment_photos_moment_id ON journey_moment_photos(moment_id);
