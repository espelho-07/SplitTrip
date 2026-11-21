# Database Integrity & Schema Audit

**Project:** SplitTrip (KITH)  
**Database Engines:** SQLite (Client) & PostgreSQL / Supabase (Server Authority)  
**Status:** Audit Completed & Hardened  

---

## 1. Local SQLite Schema & Relational Integrity

The client SQLite engine runs in **Write-Ahead Logging (WAL)** mode (`PRAGMA journal_mode = WAL;`) with `PRAGMA synchronous = NORMAL;` and foreign keys enforced (`PRAGMA foreign_keys = ON;`).

### 1.1 Tables, Keys & Constraints

| Table | Primary Key | Foreign Keys | Key Constraints & Indexes | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `trips` | `id TEXT` | None | `lifecycle_state`, `revision INTEGER` | Authoritative local trip headers |
| `trip_members` | `id TEXT` | `FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE` | `idx_trip_members_trip_id`, `idx_trip_members_user_id` | Member roster, roles, UPI IDs, virtual status |
| `expenses` | `id TEXT` | None (logical `trip_id`) | `idx_expenses_trip_id`, `idx_expenses_created_at` | Financial expense records |
| `settlements` | `id TEXT` | None (logical `trip_id`) | `idx_settlements_trip_id` | Recorded peer-to-peer debt settlements |
| `mutation_outbox` | `id TEXT` | None (logical `trip_id`) | `status TEXT DEFAULT 'pending'`, `retry_count` | Durable write queue for offline-first resilience |
| `processed_operations` | `operation_id TEXT` | None | `payload_checksum TEXT` | De-duplication filter for P2P/Server events |
| `expense_tombstones` | `(trip_id, expense_id)` | Composite PK | `PRIMARY KEY (trip_id, expense_id)` | Permanent record of deleted expenses |
| `personal_expenses` | `id TEXT` | None | `spent_at TEXT` | Non-collaborative personal finance tracker |
| `personal_debts` | `id TEXT` | None | `person_name`, `is_settled` | Personal 1-on-1 IOUs |

---

## 2. Remediation of Blind Overwrite Operations

### Audit Finding
Prior to this remediation, `LocalDatabaseService.commitAtomicMutationBatch` executed blunt table wipes:
```sql
-- DANGEROUS PREVIOUS CODE:
DELETE FROM expenses WHERE trip_id = ?;
DELETE FROM settlements WHERE trip_id = ?;
DELETE FROM personal_expenses;
DELETE FROM personal_debts;
```
If an application interrupted during batch insertions, or if a partial update arrived, un-synced local records absent from the parameter were permanently purged.

### Implemented Fix
1. **Granular Scoped Pruning with Outbox Protection:**
   Replaced blind deletion with ID-based exclusion that checks `mutation_outbox`:
   ```sql
   DELETE FROM expenses 
   WHERE trip_id = ? 
     AND id NOT IN (?1, ?2, ...)
     AND id NOT IN (SELECT json_extract(payload, '$.id') FROM mutation_outbox WHERE trip_id = ?);
   ```
   - Verifies that incoming expenses are updated or inserted via `INSERT OR REPLACE INTO expenses`.
   - Protects any local expense with an active pending outbox mutation from being deleted by remote sync.
2. **Explicit Granular Tombstone Deletion:**
   When `tombstoneToAdd` is passed, the exact expense is deleted by primary key and registered in `expense_tombstones`:
   ```sql
   INSERT OR REPLACE INTO expense_tombstones (trip_id, expense_id, deleted_at) VALUES (?, ?, ?);
   DELETE FROM expenses WHERE trip_id = ? AND id = ?;
   ```

---

## 3. Server PostgreSQL / Supabase Schema Audit

### 3.1 Constraints & Referential Integrity
- **Unique Constraints:**
  - `sessions.token`: `UNIQUE` constraint prevents session token collisions.
  - `trips.invite_code`: Indexed invite code for $O(1)$ lookups.
  - `expense_splits`: Composite primary key `(expense_id, member_id)` enforces single allocation per participant per expense.
  - `processed_operations`: Unique `operation_id` prevents duplicate replays.
- **Clock Drift & Wall-Clock Execution Safety:**
  - PostgreSQL `NOW()` / `transaction_timestamp()` returns the time of transaction start. In long-running transactions, this causes clock drift.
  - Hardened in `supabase/migrations/20261101000001_rls_security_hardening.sql`:
    ```sql
    CREATE OR REPLACE FUNCTION kith_set_updated_at()
    RETURNS TRIGGER AS $$
    BEGIN
        NEW.updated_at = clock_timestamp();
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    ```
    Executed `BEFORE INSERT OR UPDATE` across `trips`, `expenses`, `settlements`, `personal_expenses`, and `personal_debts`.

### 3.2 Monotonic Sync Sequence (`kith_sync_events`)
- Uses PostgreSQL `BIGSERIAL` sequence (`seq`) to guarantee strictly increasing change numbers.
- Clients supply `p_last_seq` to `kith_fetch_sync_events`, receiving only the exact ordered delta since their last sync cursor.

### 3.3 Deadlock Prevention
- Statement-level `pg_advisory_xact_lock` acquired `BEFORE STATEMENT` on write operations prevents row-lock interleaving deadlocks during high-concurrency multi-device synchronization.
