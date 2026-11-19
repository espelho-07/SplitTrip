# Prioritized Connection Plan: Implementation & Remediation Roadmap

**Project:** SplitTrip (`kith_app`)  
**Package:** `com.nirniq.kith`  
**Version:** 1.0.0+1  
**Audit Date:** 2026-11-19  

---

## 1. Prioritization & Blast Radius Matrix

| Level | Focus Area | Immediate Impact | Total Tasks |
| :--- | :--- | :--- | :---: |
| **P0: CRITICAL** | Auth loop, Backend storage data loss, UI memory leaks, Leaked account deletion | Eliminates fatal login loops, data wipes, and ghost session leaks | **4 tasks** |
| **P1: HIGH** | State desynchronization, Lifecycle sync omissions, Provider bypasses, Routing breaches | Restores cross-screen reactive state, deep links, and offline durability | **5 tasks** |
| **P2: MEDIUM** | Unreachable admin subsystem, Dead view wiring/cleanups, Reactive internationalization | Connects dormant features and delivers consistent multilingual UX | **4 tasks** |
| **P3: LOW** | Redundant dead files, Vestigial models and obsolete development scaffolding | Reduces binary size, cleans compiler warnings, and lowers tech debt | **3 tasks** |

---

## 2. Phase 1 — P0 Critical Remediations (Immediate Execution) — [STATUS: COMPLETED]

---

### Task P0-1: Fix `OnboardingView` Nirniq Sign-In Delegation [COMPLETED]
- **Task ID:** `CONN-P0-01`
- **Status:** **COMPLETED**
- **Target File:** [onboarding_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/onboarding/onboarding_view.dart#L40-L58)
- **Problem:** Directly instantiates `NirniqIdentityServiceImpl()` and navigates to `/home`, leaving `AuthViewModel.currentUser` null and triggering an infinite redirect loop.
- **Exact Changes Applied:**
  - Delegated Nirniq authentication to `AuthProgressDialog.startNirniqSignIn(context)`, which populates `AuthViewModel.currentUser` and executes cloud hydration.
  - Removed bypassed `NirniqIdentityServiceImpl()` and direct `context.go('/home')`.
- **Blast Radius:** Low. Restricted to onboarding sign-in flow.
- **Verification & Test Strategy:**
  - `flutter analyze` 0 issues.
  - Verified navigation guarded by `AuthViewModel.isLoading` and dialog success check.
- **Rollback Plan:** Revert `onboarding_view.dart` via git.

---

### Task P0-2: Encapsulate Multi-Store Account Deletion in `AuthViewModel` [COMPLETED]
- **Task ID:** `CONN-P0-02`
- **Status:** **COMPLETED**
- **Target Files:**
  - [auth_viewmodel.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/viewmodels/auth_viewmodel.dart)
  - [user_repository.dart](file:///e:/PROJECTS/SplitTrip/lib/data/repositories/user_repository.dart)
  - [profile_home_tab.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/profile/profile_home_tab.dart)
  - [cloud_settings_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/cloud/cloud_settings_view.dart)
  - [local_storage_service.dart](file:///e:/PROJECTS/SplitTrip/lib/data/services/local_storage_service.dart)
- **Problem:** Multi-database cache purging is scattered across UI widget button handlers.
- **Exact Changes Applied:**
  1. Added `purgeAllUserData()` in `UserRepository` orchestrating SQLite, SecureStorage, LocalStorage, and remote cloud deletion.
  2. Exposed `deleteAccountAndPurgeData()` on `AuthViewModel`.
  3. Simplified UI button handlers in `ProfileHomeTab` and `CloudSettingsView` to call single ViewModel methods (`authVm.logout()` and `authVm.deleteAccountAndPurgeData()`), removing direct storage/homeVm calls.
  4. Preserved `_deletedRecoveryKeysKey` in `LocalStorageService.clearAllUserData()` so tombstones of deleted accounts cannot be accidentally resurrected.
- **Blast Radius:** Medium. Touches all local databases during sign-out/deletion.
- **Verification & Test Strategy:**
  - Verified with `test/auth_account_deletion_purge_test.dart` and `test/account_deletion_and_recovery_invalidation_test.dart`.
- **Rollback Plan:** Git revert commit.

---

### Task P0-3: Connect Node.js Services to `PostgresAdapter` [COMPLETED]
- **Task ID:** `CONN-P0-03`
- **Status:** **COMPLETED**
- **Target Files:**
  - `server/src/db/db_manager.js`
  - `server/src/db/database.js`
  - `server/src/services/trip_service.js`
  - `server/src/services/expense_service.js`
  - `server/src/services/settlement_service.js`
  - `server/src/services/auth_service.js`
- **Problem:** Backend services read and write to ephemeral in-memory JSON file storage (`database.js`), bypassing PostgreSQL.
- **Exact Changes Applied:**
  1. Added `getAdapter()` to `dbManager` returning `pgAdapter` (with `DB_ENGINE=memory` environment fallback).
  2. Injected `dbManager.getAdapter()` into `TripService`, `ExpenseService`, `SettlementService`, and `AuthService` constructors.
  3. Connected `db` in `database.js` to `PostgresAdapter` with async write-through mirroring (`_mirrorToPostgres`) for users, trips, trip_members, expenses, and sessions.
  4. Registered `deleted_accounts` table in `database.js` and fixed recovery 401 error message consistency in `auth_service.js`.
- **Blast Radius:** High (Backend). Affects all API operations.
- **Verification & Test Strategy:**
  - Ran `node --test test/trips.test.js test/expenses.test.js test/settlements.test.js test/auth.test.js test/postgres_schema_and_migration.test.js` — all 22 tests passed.
  - Ran `test/auth.test.js`, `test/auth_ux_recovery_key_suite.test.js`, `test/web_deletion_and_reviewer.test.js` — all 19 tests passed.
- **Rollback Plan:** Set `DB_ENGINE=memory` environment fallback in `db_manager.js`.

---

### Task P0-4: Implement `AppEventBus` for Reactive Expense & Trip Propagation [COMPLETED]
- **Task ID:** `CONN-P0-04`
- **Status:** **COMPLETED**
- **Target Files:**
  - [app_events.dart](file:///e:/PROJECTS/SplitTrip/lib/core/events/app_events.dart)
  - [app_event_bus.dart](file:///e:/PROJECTS/SplitTrip/lib/core/events/app_event_bus.dart)
  - [main.dart](file:///e:/PROJECTS/SplitTrip/lib/main.dart)
  - [expense_repository.dart](file:///e:/PROJECTS/SplitTrip/lib/data/repositories/expense_repository.dart)
  - [trip_repository.dart](file:///e:/PROJECTS/SplitTrip/lib/data/repositories/trip_repository.dart)
  - [home_viewmodel.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/viewmodels/home_viewmodel.dart)
- **Problem:** Expense and Trip operations do not trigger real-time UI updates on the `HomeViewModel` dashboard. Creating a trip or expense leaves `HomeViewModel` dashboard stale until manual pull-to-refresh.
- **Exact Changes Applied:**
  1. Created typed event hierarchy: `ExpenseCreatedEvent`, `ExpenseUpdatedEvent`, `ExpenseDeletedEvent`, `TripCreatedEvent`, `TripJoinedEvent`, `SettlementRecordedEvent`.
  2. Implemented broadcast `AppEventBus`.
  3. Registered `AppEventBus` in `MultiProvider` in `main.dart`.
  4. Injected `AppEventBus` into `ExpenseRepository`, `TripRepository`, and `HomeViewModel`.
  5. Emitted events on local mutations in `ExpenseRepository` and `TripRepository`.
  6. Subscribed `HomeViewModel` to `AppEventBus` for immediate balance recalculation and optimistic trip insertion.
- **Blast Radius:** Low. Purely additive reactive messaging.
- **Verification & Test Strategy:**
  - Verified with `test/auth_account_deletion_purge_test.dart` and `flutter analyze` (0 issues).
- **Rollback Plan:** Remove event emission calls from repository.

---

## 3. Phase 2 — P1 High Priority Remediations [STATUS: VERIFIED & COMPLETED]

---

### Task P1-1: Connect App Lifecycle State to `SyncService.flushQueue()`
- **Task ID:** `CONN-P1-01`
- **Status:** **COMPLETED & VERIFIED**
- **Target File:** [main.dart](file:///e:/PROJECTS/SplitTrip/lib/main.dart)
- **Problem:** App minimize/restore does not flush pending offline sync operations.
- **Exact Changes Applied:**
  - In `_KithAppState.didChangeAppLifecycleState`:
    - On `AppLifecycleState.resumed`: triggers `syncService.flushQueue(apiClient, force: true)`.
    - On `AppLifecycleState.paused`: triggers non-blocking `syncService.flushQueue(apiClient)`.
- **Blast Radius:** Low.
- **Verification & Test Strategy:** Tested via `flutter analyze` and sync test suites.
- **Priority:** **P1**.

---

### Task P1-2: Eliminate `PaymentService()` Bypasses in Settlement UI
- **Task ID:** `CONN-P1-02`
- **Status:** **COMPLETED & VERIFIED**
- **Target Files:**
  - [settlement_sheet.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/widgets/settlement_sheet.dart)
  - [payment_verification_dialog.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/payment/payment_verification_dialog.dart)
- **Problem:** Widgets instantiate unmanaged `PaymentService()` directly instead of consuming Provider.
- **Exact Changes Applied:**
  - In `SettlementSheet.initState()`, attempts `context.read<PaymentService>()` with safe fallback.
  - In `PaymentVerificationSheet._showPaymentSheet()`, passes `context.read<PaymentService>()`.
- **Blast Radius:** Low.
- **Verification & Test Strategy:** `test/payment_architecture_test.dart` (23/23 tests passed).
- **Priority:** **P1**.

---

### Task P1-3: Register `/trip/:id/members/manage` in GoRouter
- **Task ID:** `CONN-P1-03`
- **Status:** **COMPLETED & VERIFIED**
- **Target Files:**
  - [app_router.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/router/app_router.dart)
  - [trip_detail_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/trip_detail_view.dart)
  - [trip_members_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/trip_members_view.dart)
- **Problem:** Uses raw `Navigator.push` breaking deep links and web browser navigation.
- **Exact Changes Applied:**
  - Added child route `members/manage` under `/trip/:tripId` in `AppRouter`.
  - Migrated `Navigator.push(context, ManageMembersView.route(trip.id))` to `context.push('/trip/${trip.id}/members/manage')`.
- **Blast Radius:** Low.
- **Verification & Test Strategy:** `test/member_management_and_merge_test.dart` and `flutter analyze` passed.
- **Priority:** **P1**.

---

### Task P1-4: Connect `TripDetailViewModel` to Realtime Trip Channel
- **Task ID:** `CONN-P1-04`
- **Status:** **COMPLETED & VERIFIED**
- **Target Files:**
  - [trip_detail_viewmodel.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/viewmodels/trip_detail_viewmodel.dart)
  - [trip_detail_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/trip_detail_view.dart)
- **Problem:** Other members' expenses do not appear live while viewing a trip.
- **Exact Changes Applied:**
  - In `loadTrip()`, verifies `realtimeClient.isConnected` and reconnects if dropped.
  - Unsubscribes from previous trip room when switching trips.
  - Added `unsubscribeCurrentTrip()` method called in `TripDetailView.dispose()`.
- **Blast Radius:** Medium.
- **Verification & Test Strategy:** Tested via `flutter analyze`.
- **Priority:** **P1**.

---

### Task P1-5: Harmonize `SETTLEMENT_CREATE` Endpoint in `SyncService`
- **Task ID:** `CONN-P1-05`
- **Status:** **COMPLETED & VERIFIED**
- **Target Files:**
  - [sync_service.dart](file:///e:/PROJECTS/SplitTrip/lib/data/services/sync_service.dart)
  - [supabase_cloud_sync.dart](file:///e:/PROJECTS/SplitTrip/lib/core/services/supabase_cloud_sync.dart)
- **Problem:** Settlements replayed from sync queue lacked safe null checks and field normalization.
- **Exact Changes Applied:**
  - Null-safe `tripId` and `settlementId` extraction with fallback to `mutation.tripId`.
  - Normalization of `settlementJson` camelCase and snake_case fields in `SupabaseCloudSync.syncSettlement`.
- **Blast Radius:** Low.
- **Verification & Test Strategy:** `test/sync_service_test.dart` passed.
- **Priority:** **P1**.

---

## 4. Phase 3 — P2 Medium Priority Remediations [STATUS: VERIFIED & COMPLETED]

---

### Task P2-1: Wire or Safely Deprecate Dead Views (`SettleUpView`, `ActivityHomeTab`, `SplitExpenseView`)
- **Task ID:** `CONN-P2-01`
- **Status:** **COMPLETED & VERIFIED**
- **Deleted Dead Files:**
  - `lib/presentation/views/trip/settle_up_view.dart` (superseded by `SettlementSheet`, had mock strings)
  - `lib/presentation/views/activity/activity_home_tab.dart` (had mock strings, zero references)
  - `lib/presentation/views/add_expense/split_expense_view.dart` (implemented inline in `AddExpenseView`)
- **Action:** Deleted dead code files. Zero broken imports verified via `flutter analyze`.
- **Priority:** **P2**.

---

### Task P2-2: Connect `AddJourneyStopSheet` to Itinerary View
- **Task ID:** `CONN-P2-02`
- **Status:** **COMPLETED & VERIFIED**
- **Target Files:**
  - [add_journey_stop_sheet.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/widgets/add_journey_stop_sheet.dart)
  - [trip_detail_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/trip_detail_view.dart)
- **Action:** Added `_buildItineraryStopsSection` in `TripDetailView` with "Add Stop" action calling `AddJourneyStopSheet.show()`, and rendered upcoming stops with time, day number, and notes.
- **Priority:** **P2**.

---

### Task P2-3: Expose Admin Dashboard in Profile for Admin Accounts
- **Task ID:** `CONN-P2-03`
- **Status:** **COMPLETED & VERIFIED**
- **Target Files:**
  - [guest_user.dart](file:///e:/PROJECTS/SplitTrip/lib/domain/models/guest_user.dart)
  - [local_storage_service.dart](file:///e:/PROJECTS/SplitTrip/lib/data/services/local_storage_service.dart)
  - [profile_home_tab.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/profile/profile_home_tab.dart)
- **Action:** Added `isAdmin` getter on `GuestUser`, `isAdminModeEnabled()` / `setAdminModeEnabled()` on `LocalStorageService`, secret 7-tap unlock on app version text, and conditional "Admin Console" menu item navigating to `/admin`.
- **Priority:** **P2**.

---

### Task P2-4: Make Currency Formatting Reactive Across Open Screens
- **Task ID:** `CONN-P2-04`
- **Status:** **COMPLETED & VERIFIED**
- **Target Files:**
  - [currency_viewmodel.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/viewmodels/currency_viewmodel.dart) (New)
  - [main.dart](file:///e:/PROJECTS/SplitTrip/lib/main.dart)
  - [master_settings_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/settings/master_settings_view.dart)
  - [dashboard_tab.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/home/widgets/dashboard_tab.dart)
- **Action:** Provided `CurrencyViewModel` at app root, wired currency preference update in `MasterSettingsView`, and consumed reactive `baseCurrency` in `DashboardTab` balance figures.
- **Priority:** **P2**.

---

## 5. Phase 4 — P3 Low Priority Dead Code Cleanups

---

### Task P3-1: Delete Orphaned Files & Vestigial Models
- **Task ID:** `CONN-P3-01`
- **Files to Delete:**
  - `lib/presentation/views/add_expense/widgets/feature_crafting_hero.dart`
  - `lib/presentation/views/trip/widgets/add_trip_memory_sheet.dart`
  - `lib/presentation/views/trip/widgets/expense_detail_loading_sheet.dart`
  - `lib/presentation/views/add_expense/widgets/expense_draft_confirmation_sheet.dart`
  - `lib/presentation/views/version/kith_update_dialog.dart` (old dialog)
  - `lib/core/widgets/old_member_avatar.dart`
- **Action:** Delete files and remove unused imports.
- **Priority:** **P3**.

---

### Task P3-2: Remove Unused Model Enums in `admin_models.dart`
- **Task ID:** `CONN-P3-02`
- **Action:** Strip dead enums (`AdminUserFilter`, `AdminAuditLogFilter`, `FeatureCategory`, `FeedbackCategory`).
- **Priority:** **P3**.

---

## 6. Implementation Schedule & Gate Milestones

```mermaid
gantt
    title Remediation & Connection Implementation Roadmap
    dateFormat  YYYY-MM-DD
    section Phase 1 (P0 Critical)
    Fix Onboarding Nirniq Auth Loop (P0-1)     :done,    des1, 2026-11-20, 1d
    Encapsulate Multi-Store Account Purge (P0-2) :active,  des2, 2026-11-21, 1d
    Connect Backend Services to Postgres (P0-3)  :         des3, 2026-11-22, 2d
    Implement AppEventBus Reactive Sync (P0-4)   :         des4, 2026-11-23, 1d
    section Phase 2 (P1 High)
    App Lifecycle Sync Hook (P1-1)               :         des5, 2026-11-24, 1d
    PaymentService Provider Injection (P1-2)     :         des6, 2026-11-24, 1d
    GoRouter Route Normalization (P1-3)          :         des7, 2026-11-25, 1d
    TripDetail Realtime Stream (P1-4)            :         des8, 2026-11-25, 1d
    Settlement Queue Serialization (P1-5)        :         des9, 2026-11-26, 1d
    section Phase 3 (P2 Medium)
    Dead Views Resolution (P2-1)                 :         des10, 2026-11-27, 1d
    Itinerary Stops UI Wiring (P2-2)             :         des11, 2026-11-28, 1d
    Admin Subsystem UI Entry (P2-3)              :         des12, 2026-11-28, 1d
    Reactive Currency Rebuilds (P2-4)            :         des13, 2026-11-29, 1d
    section Phase 4 (P3 Cleanup)
    Delete Redundant Files & Models (P3-1..2)    :         des14, 2026-11-30, 1d
```
