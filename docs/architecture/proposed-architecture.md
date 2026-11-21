# Proposed Architecture & System Design
**Project:** SplitTrip (KITH)  
**Target:** Clean, Offline-First, Single-Authoritative Cloud Architecture  
**Author:** Principal Software Architect & Staff Systems Engineer  
**Date:** 2026-11-19  

---

## 1. Architectural Vision & Core Principles

The target architecture for SplitTrip is an **Offline-First, Domain-Driven, Single-Authoritative Cloud Architecture**.

### The 5 Architectural Pillars:
1. **Single Source of Truth (SSOT)**:
   - **On Device**: Local SQLite WAL database (`LocalDatabaseService`) is the sole local storage authority. SharedPreferences is restricted purely to simple primitive UI settings (theme mode, locale string).
   - **In Cloud**: Centralized PostgreSQL / Supabase is the sole cloud storage authority. Ephemeral JSON files on the server filesystem are deprecated and removed.
2. **Unified Transport Gateway**:
   - The Flutter client interacts with the cloud through a single backend gateway (Node.js API + WebSocket Hub) that connects directly to PostgreSQL with ACID transactions and advisory locks. The client does not engage in dual writes to both PostgREST and Node.js.
3. **Decoupled Synchronization Engine**:
   - The monolithic `SyncService` is decomposed into four focused, testable modules:
     - `OutboxManager`: Enqueues and maintains crash-proof local mutations.
     - `CloudSyncTransport`: Handles HTTP/WebSocket network push/pull with backoff.
     - `MeshSyncTransport`: Handles local peer-to-peer BLE / Wi-Fi Direct sync.
     - `ReconciliationEngine`: Deterministically applies CRDT/vector clock merge logic.
4. **Clean Domain Boundaries**:
   - The unrelated IPO and stock market tracking features are physically removed from the core trip repository, eliminating schema pollution and maintenance drag.
5. **Declarative, Reactive State Pipeline**:
   - ViewModels observe local SQLite tables via reactive streams. Data modifications write exclusively to SQLite, and the UI automatically re-renders from the database stream.

---

## 2. Architecture Comparison: Current vs Proposed

### 2.1 Current Architecture (Split-Brain Dual Writes)

```
[Flutter UI]
      │
      ├───────────────────────┬────────────────────────┐
      ▼                       ▼                        ▼
[LocalStorageService]   [LocalDatabaseService]   [TripRepository Cache]
 (SharedPreferences)          (SQLite)                 (In-Memory)
      │
      ▼
[SyncService (Monolith)]
      │
      ├────────────────────────────────────────┬───────────────────────┐
      ▼                                        ▼                       ▼
[Supabase PostgREST]                 [Node.js Express API]    [P2P BLE Mesh]
  (PostgreSQL DB)                              │
                                               ▼
                                     [server/src/db/database.js]
                                       (In-Memory & JSON Files)
```

### 2.2 Proposed Target Architecture (Unified Reactive Pipeline)

```
[Flutter Presentation Layer (Views & ViewModels)]
                        ▲
                        │ Reactive Stream Observation (SELECT)
                        │
[Local SQLite Authority (WAL Mode, ACID Transactions)]
                        ▲
                        │ Atomic Mutation Write & Outbox Enqueue
                        │
[Domain Repositories (TripRepository, ExpenseRepository)]
                        │
                        ▼
             [Outbox Sync Coordinator]
                        │
         ┌──────────────┴──────────────┐
         ▼                             ▼
[Cloud Sync Gateway]         [P2P Mesh Sync Gateway]
 (TLS 1.3 / WebSockets)        (Nearby Connections)
         │
         ▼
[Unified Backend API (Node.js Express / Supabase Gateway)]
         │
         ▼ (pg_advisory_xact_lock & Monotonic kith_sync_events)
[PostgreSQL Cloud Authority (PostgreSQL 16 / Supabase)]
```

---

## 3. Layer Responsibilities & Boundaries

### 3.1 Presentation Layer (`lib/presentation/`)
- **Responsibility**: Pure UI rendering, gesture handling, animations, and user inputs.
- **Rules**:
  - Widgets contain zero business logic and zero direct database queries.
  - ViewModels expose immutable UI state and command methods.
  - ViewModels listen to Repository streams; they do not perform manual cache updates.

### 3.2 Domain Layer (`lib/domain/`)
- **Responsibility**: Business rules, validation, mathematical calculations, and pure entity definitions.
- **Engines**:
  - `BalanceEngine`: Computes net balances, creditor/debtor matrices.
  - `MoneyEngine`: Currency conversions, split validations, paise conversions.
  - `SettlementEngine`: Debt minimization algorithms.
- **Rules**:
  - Zero dependencies on Flutter UI frameworks or third-party storage libraries.
  - 100% covered by unit tests.

### 3.3 Persistence Layer (`lib/data/local/`)
- **Responsibility**: Reliable, ACID-compliant local storage.
- **Implementation**:
  - `LocalDatabaseService`: Authoritative SQLite client running with `PRAGMA journal_mode = WAL;` and foreign keys enabled.
  - Relational tables: `trips`, `trip_members`, `expenses`, `settlements`, `mutation_outbox`, `sync_events`.
- **Rules**:
  - Deprecate JSON strings in SharedPreferences.
  - All local writes occur in a single immediate transaction.

### 3.4 Synchronization Layer (`lib/data/sync/`)
- **Responsibility**: Propagating local changes to the cloud and peers, and incorporating remote changes.
- **Sub-components**:
  - `OutboxManager`: Priority-based queueing of local mutations.
  - `CloudSyncWorker`: Background worker with exponential backoff and jitter.
  - `PeerMeshWorker`: BLE / Wi-Fi Direct discovery and vector clock synchronization.
  - `ReconciliationEngine`: Non-destructive union merging with tombstone enforcement.

### 3.5 Cloud Backend Layer (`server/src/`)
- **Responsibility**: Authentication, multi-device event routing, authorization (IDOR prevention), and centralized persistence.
- **Implementation**:
  - Node.js Express REST API & WebSocket Hub.
  - Directly backed by PostgreSQL pool (`postgres_adapter.js`).
  - All mutations record an immutable event in `kith_sync_events` with monotonic sequence numbers.

---

## 4. State Management & Data Flow Strategy

### Deterministic Write Path:
```
1. User taps "Save Expense"
2. MoneyEngine validates split sum == total amount.
3. Repository begins SQLite transaction:
   a. Upserts expense row into `expenses`.
   b. Inserts mutation payload into `mutation_outbox`.
   c. Commits transaction.
4. SQLite stream triggers; UI updates optimistically with status "Saved Locally".
5. OutboxManager dispatches mutation to Cloud Sync Gateway.
6. Gateway returns HTTP 201 Created with canonical server event ID.
7. OutboxManager marks mutation ACKNOWLEDGED.
8. UI updates sync icon to "Synced".
```

### Deterministic Read Path:
```
1. ViewModel requests stream from Repository: `tripRepository.watchTrip(tripId)`
2. Repository queries local SQLite database and yields cached TripModel.
3. ViewModel emits loading/success UI state immediately (zero network wait).
4. CloudSyncWorker polls `GET /api/trips/:id/events?since_seq=N` in background.
5. Incoming delta events are reconciled and committed to SQLite in a batch.
6. SQLite table update fires reactive stream listener; ViewModel emits refreshed state.
```

---

## 5. Security & Isolation Strategy

1. **Token Hierarchy**:
   - Master account recovery key stored exclusively in **Android Keystore / iOS Keychain**.
   - Session tokens passed via HTTP Authorization header; refreshed transparently.
2. **Strict RLS & Advisory Locks**:
   - All server queries enforce tenant isolation via `trip_members` membership checks.
   - Concurrent updates to the same trip acquire statement-level transaction locks (`pg_advisory_xact_lock(hashtext(trip_id))`) to prevent balance corruption.
3. **Audit Trail**:
   - Every financial change creates an append-only row in `activity_logs` recording actor ID, timestamp, prior state, and new state.

---

## 6. High-Level Migration Strategy

- **Phase 1**: Backend Storage Unification (Migrate Node.js service layer from `database.js` JSON to `postgres_adapter.js`).
- **Phase 2**: Client Storage Consolidation (Eliminate SharedPreferences dual-write; migrate all read/write paths strictly to `LocalDatabaseService`).
- **Phase 3**: Decouple `SyncService` (Split monolithic sync into `OutboxManager`, `CloudSyncAdapter`, `PeerMeshAdapter`).
- **Phase 4**: Domain Segregation (Archive vestigial IPO system into an independent repository).
- **Phase 5**: Reactive UI Streaming (Replace manual ViewModel cache refreshes with SQLite reactive table observers).
