# Migration Roadmap & Architectural Transformation Plan
**Project:** SplitTrip (KITH)  
**Strategy:** Phased, Non-Destructive, Zero-Downtime Incremental Evolution  
**Author:** Principal Software Architect & DevOps Engineer  
**Date:** 2026-11-19  

---

## 1. Roadmap Overview & Timeline

The transformation from the current heterogeneous architecture to the target unified architecture follows a strict 5-phase sequential plan. Each phase is self-contained, fully tested, and preserves all existing user data.

```
[Phase 1: Backend Storage Unification]
  └─ Migrate Node.js services from JSON files to PostgreSQL adapter.
     ▼
[Phase 2: Client Storage Consolidation]
  └─ Eliminate SharedPreferences dual-write; elevate SQLite WAL as SSOT.
     ▼
[Phase 3: Decouple SyncService]
  └─ Split 1,887-line monolith into Outbox, Cloud, Mesh, and Reconcile modules.
     ▼
[Phase 4: Domain Segregation & Cleanup]
  └─ Extract and archive vestigial IPO subsystem from trip repository.
     ▼
[Phase 5: Reactive UI Streaming]
  └─ Bind ViewModels to reactive SQLite stream observers.
```

---

## 2. Phase-by-Phase Execution Details

### Phase 1: Backend Storage Unification (P0 Priority)
- **Goal**: Make PostgreSQL the sole cloud authority and eliminate reliance on ephemeral JSON files.
- **Tasks**:
  1. Review `server/src/db/postgres_adapter.js` connection pooling and statement timeouts.
  2. Refactor `TripService`, `ExpenseService`, and `SettlementService` to execute queries via `postgres_adapter.js`.
  3. Run `server/scripts/migrate_json_to_pg.js` to transfer existing JSON records into PostgreSQL tables.
  4. Verify relational integrity with foreign keys and unique constraints.
- **Testing**:
  - Run all 33 Node.js test suites against live PostgreSQL instance: `node --test test/*.test.js`.
- **Rollback Plan**: In the event of PostgreSQL connection failure, `db_manager.js` retains fallback to local disk storage.

---

### Phase 2: Client Storage Consolidation (P1 Priority)
- **Goal**: Eliminate client-side dual-write race conditions and elevate SQLite WAL as the single source of truth.
- **Tasks**:
  1. In `LocalStorageService.saveTrips` and `saveExpenses`, remove `_prefs.setString(_tripsKey...)` and `_prefs.setString(_expensesPrefix...)`.
  2. Verify that `LocalDatabaseService.isMigratedFromSharedPreferences()` returns `true` for all migrated clients.
  3. Ensure `clearAllUserData()` purges SQLite tables and invalidates `TripRepository` in-memory caches.
- **Testing**:
  - Run `test/data_integrity_and_granular_storage_test.dart` and `test/architectural_audit_remediation_test.dart`.
- **Rollback Plan**: SharedPreferences XML backup remains retained for 30 days if rollback is necessary.

---

### Phase 3: Decouple `SyncService` (P1 Priority)
- **Goal**: Break the 1,887-line `SyncService` god class into cohesive, single-responsibility modules.
- **Modules Created**:
  - `lib/data/sync/outbox_manager.dart`: Manages `mutation_outbox` priority queue and state transitions.
  - `lib/data/sync/cloud_transport.dart`: Handles HTTP POST/PUT/DELETE and WebSocket event streams with backoff.
  - `lib/data/sync/mesh_transport.dart`: Manages BLE / Wi-Fi Direct Nearby Connections mesh synchronization.
  - `lib/data/sync/reconciliation_engine.dart`: Executes non-destructive merging and conflict detection.
- **Testing**:
  - Execute full offline, P2P mesh, and cloud reconciliation test suites.

---

### Phase 4: Domain Segregation & IPO Archival (P2 Priority)
- **Goal**: Remove non-core stock market IPO code from SplitTrip.
- **Tasks**:
  1. Archive `server/src/routes/ipo_routes.js` and `server/src/services/ipo/*` into an external repository.
  2. Remove IPO cron jobs from `supabase/cron/setup_ipo_cron.sql`.
  3. Remove deprecated IPO references from `lib/core/config/app_config.dart` and `lib/core/services/fcm_service.dart`.
  4. Run database migration to drop orphaned IPO tables.
- **Testing**:
  - Verify `flutter analyze` has zero warnings and all trip splitting tests pass.

---

### Phase 5: Reactive UI Streaming (P2 Priority)
- **Goal**: Replace manual polling and cache invalidation with real-time SQLite table observation.
- **Tasks**:
  1. Add reactive stream methods to `LocalDatabaseService`:
     ```dart
     Stream<Trip> watchTrip(String tripId);
     Stream<List<Expense>> watchExpenses(String tripId);
     ```
  2. Update `TripDetailViewModel` to listen to `watchTrip` stream instead of manually calling `invalidateCache()`.
  3. Background sync updates to SQLite automatically trigger UI re-renders with zero latency.
- **Testing**:
  - Run Flutter widget tests to verify instant UI updates on incoming background mutations.

---

## 3. Rollout & Release Strategy

1. **Internal Staging (Week 1)**:
   - Deploy unified backend to staging environment; run continuous multi-user simulated stress tests (`test/multiplayer_5_users.test.js`).
2. **Beta Flight / Closed Testing (Week 2)**:
   - Release Flutter client build to internal testers (100 users, 20 active trips).
   - Monitor `DiagnosticLogger` metrics for conflict rates, outbox queue latency, and zero exceptions.
3. **Phased Production Rollout (Weeks 3–4)**:
   - 10% $\rightarrow$ 25% $\rightarrow$ 50% $\rightarrow$ 100% staged Google Play / TestFlight rollout.
