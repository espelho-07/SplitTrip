# Feature Integration Audit: End-to-End Capabilities & Seams

**Project:** SplitTrip (`kith_app`)  
**Package:** `com.nirniq.kith`  
**Version:** 1.0.0+1  
**Audit Date:** 2026-11-19  

---

## 1. Overview of Core Feature Matrix

| # | Feature Domain | Integration Status | Primary Seams / Missing Links |
| :--- | :--- | :--- | :--- |
| **1** | **Authentication & Identity** | **PARTIALLY BROKEN** | `OnboardingView` Nirniq SSO bypasses `AuthViewModel`. Account deletion orchestration is leaked into UI button handlers. |
| **2** | **Trip Management** | **PARTIALLY CONNECTED** | Trip creation does not trigger `HomeViewModel.loadTrips()`. `TripPreviewView` is unlinked. Itinerary stops sheet has zero callers. |
| **3** | **Participant & Device Management** | **PARTIALLY CONNECTED** | `ManageMembersView` uses raw `Navigator.push`. P2P Nearby connects locally but lacks cloud-conflict sync resolver. |
| **4** | **Expense Tracking & Splitting** | **PARTIALLY CONNECTED** | `AddExpenseView` does not propagate state updates to `HomeViewModel`. `SplitExpenseView` is dead code. |
| **5** | **Balance & Debt Simplification** | **FULLY CONNECTED** | Local balance calculations (Greedy Debt Simplifier) operate in integer paise with zero floating-point leaks. |
| **6** | **Settlements & UPI Payments** | **INCORRECTLY CONNECTED**| `SettlementSheet` instantiates unmanaged `PaymentService()`. `SettleUpView` is dead code with mock data. |
| **7** | **Offline & Sync Engine** | **PARTIALLY CONNECTED** | App lifecycle events (`resumed`/`paused`) do not trigger queue flushes. Supabase read failover path is absent. |
| **8** | **Trip Lifecycle & Closure** | **FULLY CONNECTED** | Trip archival and locking state correctly prevent new expense additions in SQLite and backend. |
| **9** | **Settings, Profile & Admin** | **PARTIALLY CONNECTED** | Admin console is completely unreachable from user UI. `FinanceExportBridgeService` is instantiated in a button handler. |

---

## 2. Deep Dive: Feature 1 — Authentication & Identity

### Architectural Stack
- **UI Entry Points:** [onboarding_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/onboarding/onboarding_view.dart), [profile_home_tab.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/profile/profile_home_tab.dart), [cloud_settings_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/settings/cloud_settings_view.dart).
- **State Controllers:** `AuthViewModel` ([auth_viewmodel.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/viewmodels/auth_viewmodel.dart)).
- **Repositories & Services:** `UserRepository`, `AuthService`, `NirniqIdentityServiceImpl`, `SupabaseCloudSync`.
- **Local Data Stores:** `FlutterSecureStorage` (JWTs & Private Keys), `DatabaseHelper` (`users` table), `LocalStorageService`.
- **Remote Endpoints:** Node.js `/api/v1/auth/*`, Supabase PostgREST `accounts`, `guest_sessions`.

### Integration Breakdown
1. **Guest Account Creation:** **FULLY CONNECTED**. Generates random UUID + anonymous token, stores cryptographic seed in secure storage, and creates initial local user record.
2. **Nirniq SSO Sign-In in `ProfileHomeTab`:** **FULLY CONNECTED**. Uses `AuthProgressDialog.startNirniqSignIn(context)` which correctly routes through `AuthViewModel`.
3. **Nirniq SSO Sign-In in `OnboardingView`:** **CRITICAL DEFECT**. Directly instantiates `NirniqIdentityServiceImpl()` and navigates to `/home` without touching `AuthViewModel`. Causes infinite redirect loop.
4. **Account Recovery via 12-Word Seed / Key:** **FULLY CONNECTED**. Salted hash lookup in Supabase securely recovers account metadata and restores trips.
5. **Sign Out & Account Deletion:** **INCORRECT SEAM**. Cache purging is split across UI event handlers in `ProfileHomeTab` and `CloudSettingsView` instead of being encapsulated in `AuthViewModel.deleteAccountAndPurgeData()`.

---

## 3. Deep Dive: Feature 2 — Trip Management

### Architectural Stack
- **UI Entry Points:** [home_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/home/home_view.dart), [create_trip_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/create_trip_view.dart), [trip_detail_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/trip_detail_view.dart), [join_trip_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/join_trip_view.dart).
- **State Controllers:** `HomeViewModel`, `CreateTripViewModel`, `TripDetailViewModel`.
- **Repositories & Services:** `TripRepository`, `SyncService`, `RealtimeClient`.
- **Local Data Stores:** SQLite tables `trips`, `trip_members`, `journey_stops`, `journey_moments`.
- **Remote Endpoints:** Node.js `/api/v1/trips/*`, Supabase PostgREST `trips`, `trip_members`.

### Integration Breakdown
1. **Trip Creation:** **PARTIAL DISCONNECT**. `CreateTripViewModel` successfully saves the trip to SQLite and enqueues sync, but does not notify `HomeViewModel`.
2. **Trip Joining via Code:** **FULLY CONNECTED**. Validates 6-character alphanumeric code, inserts membership record, and pulls trip cache.
3. **Trip Preview (`TripPreviewView`):** **ORPHANED ROUTE**. Registered in router but never triggered by join links or QR scans.
4. **Itinerary Stops (`AddJourneyStopSheet`):** **ORPHANED SHEET**. UI sheet exists but no button in `TripDetailView` calls it.
5. **Trip Archival / Deletion:** **FULLY CONNECTED**. Optimistically marks local record deleted, flushes to backend, and pops view cleanly.

---

## 4. Deep Dive: Feature 3 — Participant & Device Management

### Architectural Stack
- **UI Entry Points:** [trip_members_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/trip_members_view.dart), [manage_members_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/manage_members_view.dart), [trip_qr_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/trip_qr_view.dart).
- **State Controllers:** `TripDetailViewModel`.
- **Repositories & Services:** `TripRepository`, `P2PSyncService`.
- **Local Data Stores:** SQLite `trip_members` table.
- **Remote Endpoints:** Node.js `/api/v1/trips/:id/members/*`.

### Integration Breakdown
1. **Member Role Assignment:** **FULLY CONNECTED**. Supports Owner, Admin, and Member roles with permission checks.
2. **Member Management Navigation:** **INCORRECT CONNECTION**. `ManageMembersView` is invoked via `Navigator.push` rather than declarative `GoRouter`, breaking deep linking.
3. **QR Code Sharing:** **FULLY CONNECTED**. Renders dynamic QR containing invite deep link and one-time join secret.
4. **P2P Nearby Device Sync:** **PARTIALLY CONNECTED**. Local BLE discovery works, but when offline changes conflict with online changes, vector clock reconciliation defaults to server wins.

---

## 5. Deep Dive: Feature 4 — Expense Tracking & Splitting

### Architectural Stack
- **UI Entry Points:** [add_expense_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/add_expense/add_expense_view.dart), [expense_detail_sheet.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/widgets/expense_detail_sheet.dart).
- **State Controllers:** `TripDetailViewModel`.
- **Repositories & Services:** `ExpenseRepository`, `SyncService`.
- **Local Data Stores:** SQLite `expenses`, `expense_splits`.
- **Remote Endpoints:** Node.js `/api/v1/trips/:id/expenses/*`, Supabase PostgREST `expenses`, `expense_splits`.

### Integration Breakdown
1. **Expense Creation:** **PARTIAL DISCONNECT**. Local insert and queue sync work properly. Updates `TripDetailViewModel` on navigation pop, but `HomeViewModel` is never notified, leaving home dashboard spending stale.
2. **Splitting Mechanics:** **FULLY CONNECTED INLINE**. `AddExpenseView` supports Equal, Percentage, and Exact Paise splits.
3. **Standalone `SplitExpenseView`:** **DEAD CODE**. Complete unreferenced file.
4. **Draft Recovery Sheet (`ExpenseDraftConfirmationSheet`):** **ORPHANED**. Created to recover unsaved drafts but never invoked by `AddExpenseView`.
5. **Receipt Attachment:** **FULLY CONNECTED**. Compresses image, stores locally in app document sandbox, and enqueues background upload.

---

## 6. Deep Dive: Feature 5 — Balance & Debt Simplification

### Architectural Stack
- **Logic Core:** [debt_simplifier.dart](file:///e:/PROJECTS/SplitTrip/lib/core/utils/debt_simplifier.dart), `TripDetailViewModel.balances`.
- **Precision Standard:** All calculations operate strictly in integer `paise` ($1 = 100\text{ paise}$).
- **Integration Status:** **FULLY CONNECTED & AUDITED**.
- **Performance:** Computes minimal transactions using min-cash-flow greedy algorithm in $\mathcal{O}(N \log N)$ time with zero rounding loss.

---

## 7. Deep Dive: Feature 6 — Settlements & UPI Payments

### Architectural Stack
- **UI Entry Points:** [settlement_sheet.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/widgets/settlement_sheet.dart), [upi_payment_dialog.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/payment/upi_payment_dialog.dart), [payment_verification_dialog.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/payment/payment_verification_dialog.dart).
- **State Controllers:** `PaymentService` ([payment_service.dart](file:///e:/PROJECTS/SplitTrip/lib/core/payment/payment_service.dart)).
- **Repositories & Services:** `ExpenseRepository`, `SyncService`.
- **Local Data Stores:** SQLite `expenses` (category = 'settlement') and `settlements` table.
- **Remote Endpoints:** Node.js `/api/v1/trips/:id/settlements`.

### Integration Breakdown
1. **Provider Injection Bypass:** **INCORRECT CONNECTION**. `SettlementSheet` instantiates its own `PaymentService()` rather than reading from `context.read<PaymentService>()`.
2. **UPI Intent Deep Linking:** **FULLY CONNECTED**. Generates compliant UPI URLs (`upi://pay?pa=...&pn=...&am=...&cu=INR`).
3. **Dead Code View (`SettleUpView`):** **DEAD CODE**. Contains hardcoded dummy names (`Rohan`, `Priya`, `Karan`) and amounts.
4. **Sync Queue Endpoint Mapping:** **PARTIAL DISCONNECT**. Settlement sync operations need explicit routing to `/settlements` endpoint to avoid payload field stripping.

---

## 8. Deep Dive: Feature 7 — Offline & Sync Engine

### Architectural Stack
- **Engine Core:** [sync_service.dart](file:///e:/PROJECTS/SplitTrip/lib/data/services/sync_service.dart), [database_helper.dart](file:///e:/PROJECTS/SplitTrip/lib/data/database/database_helper.dart).
- **Transport Clients:** `ApiClient`, `SupabaseCloudSync`.
- **Local Data Stores:** SQLite `sync_queue` table with retry count, backoff timestamp, and idempotency key.

### Integration Breakdown
1. **Optimistic Local Execution:** **FULLY CONNECTED**. Every user action executes locally within $\le 16\text{ms}$ and writes to `sync_queue`.
2. **Background Periodic Flush:** **FULLY CONNECTED**. Flushes every 30 seconds when network is available.
3. **App Lifecycle Trigger:** **MISSING LINK**. Pausing or resuming the app does not trigger an immediate queue flush.
4. **Supabase Cloud Read Failover:** **MISSING LINK**. If Node.js backend experiences downtime, client does not fall back to querying Supabase PostgREST.

---

## 9. Deep Dive: Feature 8 — Trip Lifecycle & Closure

### Architectural Stack
- **UI Entry Points:** [trip_detail_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/trip/trip_detail_view.dart) Settings Sheet.
- **State Controllers:** `TripDetailViewModel`.
- **Repositories:** `TripRepository`.
- **Local Data Stores:** SQLite `trips` table (`is_archived`, `is_locked`).
- **Integration Status:** **FULLY CONNECTED**. Archiving a trip locks mutations and updates UI status badges across the application.

---

## 10. Deep Dive: Feature 9 — Settings, Profile & Administration

### Architectural Stack
- **UI Entry Points:** [master_settings_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/settings/master_settings_view.dart), [profile_home_tab.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/profile/profile_home_tab.dart), [admin_shell_view.dart](file:///e:/PROJECTS/SplitTrip/lib/presentation/views/admin/admin_shell_view.dart).
- **State Controllers:** `LocaleViewModel`, `VersionViewModel`, `AdminDashboardViewModel`.
- **Services:** `FinanceExportBridgeService`, `AdminService`, `AnalyticsService`.

### Integration Breakdown
1. **Theme & Localization:** **FULLY CONNECTED**. Seamless switching between Dark/Light mode and English/Hindi/regional locales.
2. **Finance Export:** **INCORRECT CONNECTION**. `FinanceExportBridgeService` is directly constructed inside `MasterSettingsView` instead of being injected via Provider.
3. **Admin Subsystem Reachability:** **ORPHANED ENTRY POINT**. The entire `/admin` route and all 10 admin screens have zero links in the user-facing UI.
