# Changelog

All notable changes to the SplitTrip (KITH) application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.25] - 2026-11-19

### Fixed
- **Multi-Payer Expense Sync:** Fixed route handler parameter destructuring in `server/src/routes/expense_routes.js` and validation in `server/src/services/expense_service.js`, preventing runtime crashes and preserving `paidByMap` through cloud synchronization.
- **Member ID Translation:** Extended `translateMemberIds` in both `LocalDatabaseService` (SQLite WAL) and `LocalStorageService` to deeply translate `paidByMap` dictionary keys during offline member claim reconciliation.
- **Account Deletion & Data Isolation:** Updated `TripRepository.getTrips()` to correctly clear and isolate trip caches when an empty list `[]` is returned for new accounts, preventing historical trip leakage across accounts.
- **Non-Destructive Expense Merge:** Refactored `mergeAuthoritativeExpenses` in `ExpenseMerge` engine to prevent premature deletion and tombstoning of offline peer-to-peer (P2P Nearby Connections) expenses absent from server snapshots.
- **Defensive Multi-Format Deserialization:** Hardened `Expense.fromJson` and `ExpenseSplit.fromJson` against both snake_case (direct Supabase rows) and camelCase (Node.js API payloads) schemas.
- **ViewModel Lifecycle Safety:** Guarded `notifyListeners()` with `hasListeners` and `_isDisposed` across `AddExpenseViewModel` and `HomeViewModel` to eliminate assertion crashes during async terminations.
- **Orientation & Layout Overflows:** Eliminated RenderFlex overflows in compact landscape viewports across `KithStageProgress`, `JoinPreviewSheet`, `SettlementSheet`, and `TripCompletionVerificationSheet`.
- **Node Test Runner Lifecycle:** Unreferenced background heartbeat and allotment timers (`.unref()`) and added active socket termination to allow automated test runners to cleanly exit.

### Added
- **Architectural Remediation Test Suite:** Added `test/architectural_audit_remediation_test.dart` verifying multi-format deserialization, P2P expense retention, member ID translation, and balance calculations.
- **Multi-Payer Split Test Suite:** Added `test/multi_payer_expense_split_test.dart` verifying custom split calculations and multi-payer settlement debt minimization.
- **Contextual Error Handling:** Added `KithErrorFormatter` and comprehensive UI error states distinguishing network timeouts, offline states, and non-existent trip invite codes.
- **Maestro Autonomous E2E Flow:** Added `.maestro/autonomous_e2e_trip_flow.yaml` specification for mobile journey automation.

### Changed
- **Gitignore Hygiene:** Excluded diagnostic logs (`/*.log`, `/*.txt`, `/*.xml`), root screen captures, and temporary `scratch/` and `forensic_backups/` directories from version control.

## [2.0.0] - 2026-10-31

### Added
- Phase 2 KITH architecture with local WAL-mode SQLite database engine.
- Peer-to-peer Nearby Connections synchronization mesh.
- Dual-storage architecture with PostgreSQL/Supabase authority and local SharedPreferences fallback.
- Cryptographic guest identity recovery keys.
