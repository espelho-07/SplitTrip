# Architecture Decision Records (ADR)
**Project:** SplitTrip (KITH)  
**Status:** Approved & Production-Hardened  
**Date:** 2026-11-19  

---

## ADR-001: SQLite WAL Mode as Sole Client Storage Authority

### Status
Accepted

### Context
Historically, the client stored trips, expenses, and user sessions as serialized JSON strings in `SharedPreferences`. As trips grew to dozens of expenses and members, encoding/decoding massive JSON strings on every mutation caused UI thread stalls, memory spikes, and occasional corruption during unexpected app terminations. Additionally, a dual-write architecture was introduced where both SQLite and SharedPreferences were updated simultaneously, creating race conditions.

### Decision
Elevate SQLite with Write-Ahead Logging (`PRAGMA journal_mode = WAL;`) and `PRAGMA synchronous = NORMAL;` via `LocalDatabaseService` as the sole authoritative local database. Completely deprecate storing trip and expense JSON blobs in SharedPreferences. Use SharedPreferences exclusively for lightweight scalar preferences (such as selected theme mode or language code).

### Consequences
- **Positive**: True ACID transactions, sub-millisecond query latency, zero memory serialization bottlenecks, and guaranteed crash resistance.
- **Negative**: Requires maintaining SQLite schema migrations on client app upgrades.

---

## ADR-002: PostgreSQL as Sole Cloud Storage Authority

### Status
Accepted

### Context
The backend currently runs on Node.js with an in-memory `Map` backed by atomic `.json` file rewrites (`server/src/db/database.js`). Although a PostgreSQL connection pool (`postgres_adapter.js`) exists and runs migration DDL, the service layer bypasses PostgreSQL and writes to disk files. In containerized cloud environments (e.g. Render, Docker, Kubernetes), container restarts or scaling to multiple instances results in lost or desynchronized data.

### Decision
Migrate all backend service operations (`TripService`, `ExpenseService`, `SettlementService`, `AuthService`) to use `PostgresAdapter` as the single authoritative persistence engine. Deprecate and remove `database.js` file storage.

### Consequences
- **Positive**: Persistent storage that survives container redeployments, horizontal scalability across multiple server instances, relational integrity constraints, and transactional consistency.
- **Negative**: Requires persistent PostgreSQL connection pool tuning and connection health monitoring.

---

## ADR-003: Single Cloud Ingestion Gateway via Node.js API

### Status
Accepted

### Context
The client previously engaged in dual cloud writes: writing directly to Supabase PostgREST tables via `SupabaseCloudSync` while simultaneously sending HTTP mutations to the Node.js API. However, the client read path queried only the Node.js API. This split-brain architecture caused data divergence between Supabase and the Node.js backend.

### Decision
Route all client mutations and queries through the unified Node.js API gateway. The Node.js gateway handles authentication, IDOR checks, PostgreSQL transactions, and realtime WebSocket event broadcasts. Direct client-to-PostgREST communication is eliminated.

### Consequences
- **Positive**: Single source of truth, simplified client networking, centralized rate limiting, and elimination of client-side secret exposure.
- **Negative**: The Node.js API must maintain high availability as the primary gateway.

---

## ADR-004: Monotonic Sequence Numbering (`kith_sync_events`) for Delta Sync

### Status
Accepted

### Context
Previous sync attempts fetched entire trip objects or compared timestamps across devices. Clock skew on client devices (e.g. manual time settings) caused newer edits to be overwritten by older edits or changes to be missed entirely.

### Decision
Implement an append-only change log table in PostgreSQL: `kith_sync_events(seq BIGSERIAL PRIMARY KEY, trip_id UUID, entity_type, entity_id, action, payload, created_at)`. Clients track `last_synced_seq` and fetch incremental deltas (`WHERE trip_id = ? AND seq > last_synced_seq`).

### Consequences
- **Positive**: Deterministic, strictly ordered change streams; immune to client clock drift; minimizes network bandwidth by only transmitting delta changes.
- **Negative**: Requires periodic retention and compaction policies for historical events.

---

## ADR-005: Client-Generated UUID v4 with Idempotency Keys

### Status
Accepted

### Context
When mobile devices operate on flaky networks, network dropouts during HTTP POST requests cause clients to retry requests whose server execution was already successful, creating duplicate expenses or trips.

### Decision
Every trip, expense, and settlement is assigned a UUID v4 on the client prior to local persistence. All outgoing mutations contain an `idempotency_key` and SHA-256 payload checksum. The backend checks for existing IDs and returns the existing resource with HTTP 200/201 without creating duplicate rows.

### Consequences
- **Positive**: Complete elimination of duplicate transactions on network retries.
- **Negative**: Client must handle UUID generation properly.

---

## ADR-006: Non-Destructive Union Merging with Tombstones

### Status
Accepted

### Context
Earlier sync implementations performed blind table wipes (`DELETE FROM expenses WHERE trip_id = ?;`) when receiving server snapshots. If an incoming sync omitted expenses created offline on the local device or via P2P mesh, those expenses were permanently deleted. Conversely, deleting an expense on one device would often cause it to be resurrected by other offline devices.

### Decision
Implement non-destructive union merging (`ExpenseMerge.merge()`). When an expense is deleted, write a permanent tombstone (`expense_tombstones`) with the deletion timestamp. Deleted items are never resurrected by older replicas, and local un-synced items are never purged during sync snapshots.

### Consequences
- **Positive**: Zero silent data loss and reliable propagation of deletions across mesh and cloud.
- **Negative**: Requires tombstone storage retention management.

---

## ADR-007: Domain Segregation & Archival of Extraneous IPO Codebase

### Status
Accepted

### Context
The repository currently contains an unrelated stock market IPO tracking subsystem across Supabase migrations, backend routes, services, and tests. This introduces severe domain pollution, increases maintenance burden, and confuses architectural boundaries.

### Decision
Physically decouple and archive the IPO subsystem from the SplitTrip repository into a dedicated service repository.

### Consequences
- **Positive**: Clean domain focus, smaller bundle and container sizes, reduced attack surface, and simplified test suites.
- **Negative**: One-time git/directory cleanup.

---

## ADR-008: Zero-Secret In-Memory Circular Diagnostic Logging

### Status
Accepted

### Context
Debugging synchronization and payment issues requires detailed operation logging, but standard console logs risk leaking sensitive session tokens, recovery keys, and user credentials into log aggregators or device bug reports.

### Decision
Implement `DiagnosticLogger` with a bounded in-memory circular buffer (500 entries) and regex-based automatic secret redaction for JWTs, session tokens, and recovery phrases.

### Consequences
- **Positive**: High observability without privacy violations or security leaks.
- **Negative**: Logs are in-memory and must be explicitly exported by the user for diagnostics.

---

## ADR-009: Strongly Typed `ApplicationError` & `OperationResult` System

### Status
Accepted

### Context
Error handling previously relied on ad-hoc exception strings or generic catch blocks, displaying ambiguous messages (e.g. "An error occurred") without informing the user whether their data was saved locally or needs manual intervention.

### Decision
Establish a strongly typed `ApplicationError` hierarchy and an `OperationResult<T>` wrapper. Every error classifies `isSavedLocally`, `isReachedServer`, `isOutcomeUnknown`, `isRetrySafe`, and provides actionable recovery suggestions.

### Consequences
- **Positive**: Transparent user experience, accurate UI sync indicators, and testable failure modes.
- **Negative**: Requires strict error wrapping across all repository and service calls.

---

## ADR-010: Pure Financial Calculation Engines Independent of UI/DB

### Status
Accepted

### Context
Embedding financial math or currency conversion inside UI widgets or database queries leads to rounding errors, inconsistent debt calculations across screens, and difficulty testing edge cases.

### Decision
Retain `BalanceEngine`, `MoneyEngine`, and `SettlementEngine` as pure Dart classes with zero dependencies on Flutter UI or database frameworks. All financial calculations occur in smallest integer currency units (paise/cents).

### Consequences
- **Positive**: 100% deterministic, ultra-fast, zero-dependency unit testing, and perfect balance consistency across platforms.
- **Negative**: Amounts must be explicitly converted to/from display units when rendering UI.
