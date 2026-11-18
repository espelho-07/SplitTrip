# Database Architecture & Schema Review
**Project:** SplitTrip (KITH)  
**Database Engines:** SQLite 3.45+ (Local Client) & PostgreSQL 16 / Supabase (Cloud Backend)  
**Author:** Principal Database Architect & Backend Systems Engineer  
**Date:** 2026-11-19  

---

## 1. Executive Database Assessment

SplitTrip operates a hybrid dual-database model:
1. **Local Edge (Client)**: SQLite running in Write-Ahead Logging (WAL) mode via `LocalDatabaseService`.
2. **Cloud Authority (Server)**: PostgreSQL 16 hosted on Supabase, accessed via `postgres_adapter.js`.

### Key Findings & Historical Anomalies:
- **Redundant JSON Storage on Server**: The backend contains a robust PostgreSQL schema but historically bypassed it in favor of writing JSON files in `server/data_storage/`.
- **Foreign Domain Contamination**: The database schema currently contains 6 migrations dedicated to stock market Initial Public Offerings (IPOs) (`ipo_applications`, `ipo_allotment_records`, `ipo_gmp_records`, etc.), completely unrelated to travel expense splitting.
- **Relational vs Document Hybrid**: Both local SQLite and cloud PostgreSQL store key relational columns (e.g. `id`, `trip_id`, `amount`, `title`) while concurrently persisting a `raw_json` column. While this provides rapid schema evolution, it introduces redundancy and potential desynchronization if columns and JSON diverge.

---

## 2. Complete Relational Schema Specifications

### 2.1 Local Client Schema (`LocalDatabaseService` — SQLite WAL)

```sql
-- Pragmas for High Concurrency and Integrity
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;

-- 1. Trips Table
CREATE TABLE IF NOT EXISTS trips (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    emoji TEXT NOT NULL DEFAULT '✈️',
    cover_gradient_index INTEGER NOT NULL DEFAULT 0,
    currency_code TEXT NOT NULL DEFAULT 'INR',
    creator_id TEXT NOT NULL,
    lifecycle_state TEXT NOT NULL DEFAULT 'active',
    invite_code TEXT NOT NULL UNIQUE,
    p2p_trip_secret TEXT,
    trip_mode TEXT NOT NULL DEFAULT 'split_only',
    revision INTEGER NOT NULL DEFAULT 1,
    completion_mode TEXT,
    started_at TEXT NOT NULL,
    completed_at TEXT,
    completed_by TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    raw_json TEXT NOT NULL
);

-- 2. Trip Members Table
CREATE TABLE IF NOT EXISTS trip_members (
    id TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'member',
    upi_id TEXT,
    is_claimed INTEGER NOT NULL DEFAULT 1,
    is_virtual INTEGER NOT NULL DEFAULT 0,
    status TEXT,
    claim_token TEXT,
    merged_into_member_id TEXT,
    joined_at TEXT NOT NULL,
    raw_json TEXT NOT NULL,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
);

-- 3. Expenses Table
CREATE TABLE IF NOT EXISTS expenses (
    id TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL,
    title TEXT NOT NULL,
    amount REAL NOT NULL,
    currency TEXT NOT NULL DEFAULT 'INR',
    category TEXT NOT NULL DEFAULT 'general',
    paid_by_member_id TEXT NOT NULL,
    split_type TEXT NOT NULL DEFAULT 'equal',
    split_mode TEXT NOT NULL DEFAULT 'default',
    receipt_url TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 1,
    raw_json TEXT NOT NULL,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
);

-- 4. Settlements Table
CREATE TABLE IF NOT EXISTS settlements (
    id TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL,
    from_member_id TEXT NOT NULL,
    to_member_id TEXT NOT NULL,
    amount REAL NOT NULL,
    currency TEXT NOT NULL DEFAULT 'INR',
    is_settled INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    raw_json TEXT NOT NULL,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
);

-- 5. Mutation Outbox Table (Durable Queue)
CREATE TABLE IF NOT EXISTS mutation_outbox (
    id TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL,
    action TEXT NOT NULL,
    payload TEXT NOT NULL,
    idempotency_key TEXT UNIQUE NOT NULL,
    retry_count INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    last_attempt TEXT,
    status TEXT DEFAULT 'pending'
);

-- 6. Expense Tombstones Table (Deletion Synchronization)
CREATE TABLE IF NOT EXISTS expense_tombstones (
    trip_id TEXT NOT NULL,
    expense_id TEXT NOT NULL,
    deleted_at TEXT NOT NULL,
    synced INTEGER DEFAULT 0,
    PRIMARY KEY (trip_id, expense_id)
);

-- Indexes for Fast Local Queries
CREATE INDEX IF NOT EXISTS idx_trip_members_trip ON trip_members(trip_id);
CREATE INDEX IF NOT EXISTS idx_expenses_trip ON expenses(trip_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_settlements_trip ON settlements(trip_id);
CREATE INDEX IF NOT EXISTS idx_outbox_trip_status ON mutation_outbox(trip_id, status);
CREATE INDEX IF NOT EXISTS idx_tombstones_synced ON expense_tombstones(synced);
```

---

### 2.2 Cloud Authority Schema (`PostgreSQL 16 / Supabase`)

```sql
-- 1. Trips Table
CREATE TABLE IF NOT EXISTS public.trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    emoji VARCHAR(16) NOT NULL DEFAULT '✈️',
    cover_gradient_index SMALLINT NOT NULL DEFAULT 0,
    currency_code VARCHAR(8) NOT NULL DEFAULT 'INR',
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    lifecycle_state VARCHAR(32) NOT NULL DEFAULT 'active',
    invite_code VARCHAR(16) NOT NULL UNIQUE,
    trip_mode VARCHAR(32) NOT NULL DEFAULT 'split_only',
    revision INTEGER NOT NULL DEFAULT 1,
    started_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    completed_at TIMESTAMPTZ,
    completed_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- 2. Trip Members Table
CREATE TABLE IF NOT EXISTS public.trip_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name VARCHAR(128) NOT NULL,
    avatar_url TEXT,
    role VARCHAR(32) NOT NULL DEFAULT 'member',
    upi_id VARCHAR(128),
    is_claimed BOOLEAN NOT NULL DEFAULT true,
    is_virtual BOOLEAN NOT NULL DEFAULT false,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT unq_trip_member UNIQUE (trip_id, user_id)
);

-- 3. Expenses Table (Relational with JSON Split Breakdown)
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    amount_in_paise BIGINT NOT NULL CHECK (amount_in_paise > 0),
    currency_code VARCHAR(8) NOT NULL DEFAULT 'INR',
    category VARCHAR(64) NOT NULL DEFAULT 'general',
    paid_by_member_id UUID NOT NULL REFERENCES public.trip_members(id),
    paid_by_map JSONB, -- Multi-payer support { "memberId": paiseAmount }
    split_type VARCHAR(32) NOT NULL DEFAULT 'equal',
    splits JSONB NOT NULL, -- Array of { "memberId": "uuid", "amountInPaise": 5000 }
    receipt_url TEXT,
    revision INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- 4. Settlements Table
CREATE TABLE IF NOT EXISTS public.settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    from_member_id UUID NOT NULL REFERENCES public.trip_members(id),
    to_member_id UUID NOT NULL REFERENCES public.trip_members(id),
    amount_in_paise BIGINT NOT NULL CHECK (amount_in_paise > 0),
    currency_code VARCHAR(8) NOT NULL DEFAULT 'INR',
    is_settled BOOLEAN NOT NULL DEFAULT false,
    settled_at TIMESTAMPTZ,
    proof_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- 5. Monotonic Change Log for Delta Sync
CREATE TABLE IF NOT EXISTS public.kith_sync_events (
    seq BIGSERIAL PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    entity_type VARCHAR(32) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(16) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    payload JSONB NOT NULL,
    actor_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- PostgreSQL Performance Indexes
CREATE INDEX IF NOT EXISTS idx_pg_trip_members_trip ON public.trip_members(trip_id);
CREATE INDEX IF NOT EXISTS idx_pg_expenses_trip_created ON public.expenses(trip_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pg_settlements_trip ON public.settlements(trip_id);
CREATE INDEX IF NOT EXISTS idx_pg_sync_events_trip_seq ON public.kith_sync_events(trip_id, seq);
```

---

## 3. Database Triggers & Concurrency Controls

### Wall-Clock Timestamp Enforcer
Client system clocks can be inaccurate. The database guarantees monotonic, authoritative time using `clock_timestamp()`:

```sql
CREATE OR REPLACE FUNCTION public.kith_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = clock_timestamp();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_trips_updated_at
BEFORE UPDATE ON public.trips
FOR EACH ROW EXECUTE FUNCTION public.kith_set_updated_at();

CREATE OR REPLACE TRIGGER trg_expenses_updated_at
BEFORE UPDATE ON public.expenses
FOR EACH ROW EXECUTE FUNCTION public.kith_set_updated_at();
```

### Statement-Level Advisory Lock for Concurrent Expenses
To prevent race conditions when two members add expenses to the same trip at the exact same millisecond:

```sql
-- In Node.js backend prior to expense insert:
-- SELECT pg_advisory_xact_lock(hashtext(trip_id::text));
```

---

## 4. Row-Level Security (RLS) Policy Matrix

| Table | Permitted Action | Policy Condition |
| :--- | :---: | :--- |
| `trips` | SELECT | `EXISTS (SELECT 1 FROM trip_members WHERE trip_members.trip_id = trips.id AND trip_members.user_id = auth.uid())` |
| `trips` | UPDATE | `trips.creator_id = auth.uid() OR EXISTS (SELECT 1 FROM trip_members WHERE trip_members.trip_id = trips.id AND trip_members.user_id = auth.uid() AND trip_members.role = 'admin')` |
| `trip_members` | SELECT | `EXISTS (SELECT 1 FROM trip_members tm WHERE tm.trip_id = trip_members.trip_id AND tm.user_id = auth.uid())` |
| `expenses` | ALL | `EXISTS (SELECT 1 FROM trip_members WHERE trip_members.trip_id = expenses.trip_id AND trip_members.user_id = auth.uid())` |
| `settlements` | ALL | `EXISTS (SELECT 1 FROM trip_members WHERE trip_members.trip_id = settlements.trip_id AND trip_members.user_id = auth.uid())` |
| `kith_sync_events` | SELECT | `EXISTS (SELECT 1 FROM trip_members WHERE trip_members.trip_id = kith_sync_events.trip_id AND trip_members.user_id = auth.uid())` |

---

## 5. Proposed Zero-Downtime Migration Strategy

1. **Phase 1: Backend Connection Switch**:
   Update `server/src/services/*.js` to execute queries against `dbManager.pgAdapter` instead of `db.insert`/`db.get` from `database.js`.
2. **Phase 2: One-Time Data Hydration**:
   Execute `server/scripts/migrate_json_to_pg.js` to transfer existing JSON files into PostgreSQL with conflict resolution (`ON CONFLICT (id) DO NOTHING`).
3. **Phase 3: Client Dual-Write Elimination**:
   Remove `_prefs.setString(_expensesPrefix...)` from `LocalStorageService`, leaving SQLite as the sole local store.
4. **Phase 4: Schema Pruning**:
   Drop unused IPO tables (`DROP TABLE IF EXISTS ipo_applications, ipo_allotment_records, ipo_gmp_records;`) via an explicit migration.
