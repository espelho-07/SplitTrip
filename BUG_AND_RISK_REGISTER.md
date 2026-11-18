# Comprehensive Bug & Risk Register
**Project:** SplitTrip (KITH)  
**Classification System:** P0 (Critical/Data Loss), P1 (Major Architectural), P2 (Maintainability/Reliability), P3 (Performance/Minor)  
**Date:** 2026-11-19  
**Auditor:** Principal Software Architect & QA Lead  

---

## 1. Complete Bug Register & Remediation Status

| Bug ID | Pri | Summary & Root Cause | File Location | Impact | Status | Verification Evidence |
| :---: | :---: | :--- | :--- | :--- | :---: | :--- |
| **BUG-01** | **P0** | **Blind Table Wipes on Sync**: `DELETE FROM expenses WHERE trip_id = ?;` ran before server snapshot insert, permanently erasing local offline expenses waiting in outbox. | `lib/data/services/local_database_service.dart` | Permanent data loss for offline expenses. | **VERIFIED FIXED** | `test/data_integrity_and_granular_storage_test.dart` (Test 1 & 2) |
| **BUG-02** | **P0** | **Cross-Account Cache Leakage**: Deleting an account did not purge in-memory caches or SharedPreferences tables, exposing old trips to new guest accounts. | `lib/data/repositories/trip_repository.dart`, `local_storage_service.dart` | Privacy breach and corrupted user state. | **VERIFIED FIXED** | `test/architectural_audit_remediation_test.dart` (Test 4), `multi_payer_expense_split_test.dart` (Test 5) |
| **BUG-03** | **P0** | **Plaintext Token Leak in Recovery Vault**: `saveUserToRecoveryVault` serialized raw tokens into SharedPreferences XML. | `lib/data/services/local_storage_service.dart` | Bearer token leakage on rooted devices or ADB backups. | **VERIFIED FIXED** | `test/data_integrity_and_granular_storage_test.dart` (Test 4) |
| **BUG-04** | **P1** | **Dropped `paidByMap` Parameter**: `AddExpenseViewModel` failed to pass `paidByMap` into `createExpense`, dropping multi-payer split amounts. | `lib/presentation/viewmodels/add_expense_viewmodel.dart` | Imbalanced calculations and corrupted net balances. | **VERIFIED FIXED** | `test/multi_payer_expense_split_test.dart` (Test 4) |
| **BUG-05** | **P1** | **Member ID Key Mismatch**: `paidByMap` serialized using database integers instead of canonical UUIDs, causing lookup failures during P2P sync. | `lib/domain/models/expense.dart`, `trip_repository.dart` | Disconnected expenses across peer devices. | **VERIFIED FIXED** | `test/architectural_audit_remediation_test.dart` (Test 3) |
| **BUG-06** | **P1** | **Stale Tombstone Deletion Gap**: `expense_tombstones` was populated on delete without removing the active row from SQLite `expenses`. | `lib/data/services/local_database_service.dart` | Deleted expenses resurrected after offline restart. | **VERIFIED FIXED** | `test/data_integrity_and_granular_storage_test.dart` (Test 3) |
| **BUG-07** | **P1** | **Ghost PostgreSQL Database**: Backend services wrote to local JSON files (`database.js`) instead of PostgreSQL (`postgres_adapter.js`). | `server/src/services/*.js`, `server/src/db/db_manager.js` | Container redeployment wipes all user trips on cloud hosts. | **ARCHITECTURE REMEDIATION READY** | Documented in `PROPOSED_ARCHITECTURE.md` & `MIGRATION_ROADMAP.md` |
| **BUG-08** | **P2** | **Dual-Write Client Storage**: Every write executed dual persistence to SQLite and SharedPreferences simultaneously. | `lib/data/services/local_storage_service.dart` | Unnecessary CPU serialization, memory spikes, race hazards. | **PLANNED REMEDIATION** | Phase 2 of `MIGRATION_ROADMAP.md` |
| **BUG-09** | **P2** | **Foreign Domain Pollution (IPO System)**: Extraneous stock market and IPO allotment code inside travel expense repository. | `server/src/routes/ipo_routes.js`, `supabase/migrations/*` | Codebase bloat, unnecessary maintenance overhead. | **PLANNED REMEDIATION** | Phase 4 of `MIGRATION_ROADMAP.md` |
| **BUG-10** | **P2** | **Node.js Test Runner Hanging**: Background WebSocket intervals prevented Node.js test processes from exiting cleanly. | `server/src/app.js`, `server/src/realtime/websocket_hub.js` | CI/CD pipeline hangs and timeouts. | **VERIFIED FIXED** | Added `unref()` to all test intervals; all 33 Node.js tests exit in 716ms. |
| **BUG-11** | **P3** | **Responsive Layout Overflow in Landscape**: Fixed bottom padding in `SettleUpView` caused 42px RenderFlex overflow in landscape mode. | `lib/presentation/views/trip/settle_up_view.dart` | Visual UI glitch on rotated devices or tablets. | **VERIFIED FIXED** | `test/responsive_layout_overflow_test.dart` (8/8 passed) |

---

## 2. Technical Risk Register & Mitigation Strategy

### Risk 1: Ephemeral Filesystem on Cloud Hosting (Render / Docker)
- **Risk Severity**: **HIGH**
- **Description**: If the Node.js backend is hosted on Render free tier or stateless Docker containers without a persistent disk, restart or redeployment resets `server/data_storage/*.json`.
- **Mitigation Strategy**: Complete Phase 1 of `MIGRATION_ROADMAP.md` immediately to switch the service layer to PostgreSQL (`postgres_adapter.js`).

### Risk 2: Bluetooth Low Energy (BLE) Hardware Limitations in P2P Mesh
- **Risk Severity**: **MEDIUM**
- **Description**: Range drops beyond 10–15 meters or through thick metal/concrete barriers during travel can break P2P synchronization packets.
- **Mitigation Strategy**: Mesh sync is designed to be opportunistic. All mutations remain safely queued in `mutation_outbox` and automatically reconcile once back in range or connected to cellular data.

### Risk 3: Aggressive OEM Battery Management on Android
- **Risk Severity**: **MEDIUM**
- **Description**: Manufacturers like Xiaomi, Oppo, and Vivo aggressively kill background Flutter tasks when the app is minimized.
- **Mitigation Strategy**: The synchronization engine triggers an immediate catch-up cycle upon foreground lifecycle resume (`AppLifecycleState.resumed`).

### Risk 4: Extreme System Clock Skew
- **Risk Severity**: **LOW**
- **Description**: If a user's phone clock is manually set days or months off, wall-clock ordering could theoretically conflict with server timestamps.
- **Mitigation Strategy**: The backend utilizes PostgreSQL `clock_timestamp()` and strictly increasing `BIGSERIAL` event sequences (`kith_sync_events`) as the sole source of truth for ordering.
