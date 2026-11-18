# Current Architecture Audit & Deep Investigation
**Project:** SplitTrip (KITH)  
**Package:** `com.nirniq.kith` (`kith_app`)  
**Target Environment:** Flutter (Mobile/Web), Node.js/Express Backend, Supabase / PostgreSQL Database, SQLite WAL Client  
**Date:** 2026-11-19  
**Auditor:** Principal Software Architect, Staff Flutter Engineer & Database Architect  

---

## 1. Executive Summary & Core Verdict

SplitTrip (branded as KITH) is a cross-platform group travel and expense-splitting application designed to support offline-first operations. However, an architectural audit of the current repository reveals a **heterogeneous, split-brain architecture** resulting from progressive layering over time without consolidating legacy implementations.

### Primary Architectural Findings:
1. **Split-Brain Backend Storage**: The Node.js Express backend (`server/src/app.js`) initializes a PostgreSQL pool and runs migrations (`dbManager.init()`), but its core service implementations (`TripService`, `ExpenseService`, `SettlementService`, `AuthService`) read and write exclusively to an in-memory `Map` backed by atomic `.json` file rewrites (`server/src/db/database.js`).
2. **Dual-Write Client Storage**: The Flutter client simultaneously maintains a SQLite database (`LocalDatabaseService` in WAL mode) and SharedPreferences (`LocalStorageService`). `LocalStorageService.saveTrips` and `saveExpenses` commit mutations to SQLite but also re-encode and write full JSON strings to SharedPreferences on every single write.
3. **Dual Cloud Ingestion Paths**: The client synchronization engine (`SyncService`) writes directly to Supabase PostgREST tables via `SupabaseCloudSync` (best-effort mirror) and sequentially pushes mutations via HTTP POST/PUT to the Node.js API (`_pushToSecondaryApi`). The read path in `TripRepository`, however, queries only the Node.js API.
4. **Domain Boundary Violations (Monolithic Entanglement)**: Both the backend codebase (`server/src/routes/ipo_routes.js`, `server/src/services/ipo/*`) and the Supabase migrations (`20261031000002_ipo_management_system.sql` through `20261101000006_ipo_atomic_upsert_and_quota_lock.sql`) contain an entire stock market / Initial Public Offering (IPO) tracking and allotment system intertwined with trip expense splitting.
5. **Multiple Sources of Truth**: A single expense can exist simultaneously in:
   - Client memory (`TripRepository._cachedTripsInMemory`)
   - Client SharedPreferences XML (`kith_storage.xml`)
   - Client SQLite tables (`kith_production_v2.db`)
   - Node.js server memory (`Database.tables.expenses`)
   - Node.js server JSON file (`server/data_storage/expenses.json`)
   - Supabase PostgreSQL cloud table (`public.expenses`)

---

## 2. Component Inventory & Topography

### 2.1 Presentation Layer (Flutter UI & ViewModels)
- **Architecture**: MVVM with `ChangeNotifier` and `ListenableBuilder`.
- **Views**:
  - `trips_home_tab.dart`, `trip_detail_view.dart`, `create_trip_view.dart`, `join_trip_view.dart`
  - `add_expense_screen.dart`, `settle_up_view.dart`, `trip_members_view.dart`
  - Custom Liquid Glass Design System (`lib/core/design_system/`)
- **ViewModels**:
  - `HomeViewModel`, `TripDetailViewModel`, `AddExpenseViewModel`, `CreateTripViewModel`, `JoinTripViewModel`, `AuthViewModel`, `ThemeViewModel`, `LocaleViewModel`
- **Audit Assessment**: ViewModels generally adhere to presentation-only logic, delegating data operations to Repositories. However, error handling was previously coupled to raw string formatting rather than structured domain exceptions.

### 2.2 Domain Layer (Financial & Calculation Engines)
- **Engines**:
  - `BalanceEngine`: Pure calculation engine computing net balances and debt simplification.
  - `MoneyEngine`: Currency formatting, paise conversion, split validation.
  - `SettlementEngine`: Minimizes debt transactions across group members.
  - `ExpenseMerge`: Non-destructive union merging of local and remote expense records.
- **Audit Assessment**: Pure, deterministic, well-tested domain logic without platform dependencies. This is one of the strongest parts of the codebase.

### 2.3 Data Layer (Client Persistence & Synchronization)
- **Repositories**: `TripRepository`, `ExpenseRepository`, `UserRepository`.
- **Services**:
  - `LocalStorageService`: Wrapper around SharedPreferences with legacy JSON serialization.
  - `LocalDatabaseService`: Authoritative SQLite WAL implementation using `package:sqlite3`.
  - `SyncService`: 1,887-line orchestrator handling `mutation_outbox`, retry backoff, P2P mesh coordination, and dual-backend dispatch.
  - `P2PSyncService`: Nearby Connections mesh broadcast for offline BLE sync.
  - `SupabaseCloudSync`: PostgREST client for direct Supabase cloud sync.
  - `ApiClient`: HTTP client targeting Node.js API with custom token headers.
  - `RealtimeClient`: WebSocket client targeting Node.js WebSocket Hub.

### 2.4 Backend Layer (Node.js & Storage)
- **Routing**: `app.js` mounting `/api/auth`, `/api/trips`, `/api/trips/:tripId/expenses`, `/api/personal`, `/api/notifications`, `/api/ipos`.
- **Database Engine**:
  - `database.js`: In-memory `Map` storage with atomic `.tmp` file writing and renaming.
  - `postgres_adapter.js`: PostgreSQL connection pool with connection timeout, SSL toggles, and transaction wrappers.
  - `migration_runner.js`: Runs DDL migrations against PostgreSQL.
- **WebSocket Hub**: `websocket_hub.js` managing room subscriptions (`trip_<id>`) and message broadcasting.

---

## 3. Deep Architectural Flaws & Anti-Patterns

### Flaw 1: God Service Anti-Pattern in `SyncService`
- **Location**: `lib/data/services/sync_service.dart` (1,887 lines)
- **Problem**: `SyncService` coordinates too many disparate concerns:
  1. SQLite mutation outbox management
  2. Direct Supabase PostgREST synchronization
  3. Node.js REST API dispatch
  4. P2P Nearby Connections mesh payload generation
  5. Backoff timers and network connectivity listeners
  6. FCM push notification registration
  7. Cross-trip reconciliation
- **Consequence**: High coupling, fragile change surface, and difficult unit test mocking.

### Flaw 2: The "Ghost" PostgreSQL Database
- **Location**: `server/src/db/db_manager.js` vs `server/src/services/*.js`
- **Problem**: The server codebase features a complete PostgreSQL adapter and runs relational schema migrations upon startup. However, none of the service routes use the PostgreSQL adapter for persistent CRUD operations. Every service imports `const { db } = require('../db/database');` which writes to JSON files.
- **Consequence**: In cloud container deployments (e.g., Render, Docker, AWS ECS) without persistent disk volumes, container restarts wipe out local JSON files, leading to catastrophic data loss despite having a connected PostgreSQL database.

### Flaw 3: Dual-Write Race Conditions on Client
- **Location**: `lib/data/services/local_storage_service.dart` (lines 307-350)
- **Problem**: Every trip and expense write is written to both SQLite and SharedPreferences. If an app termination occurs between the SQLite commit and the SharedPreferences string write, the two local datastores fall out of sync.
- **Consequence**: Cache inconsistency, redundant CPU serialization overhead on large trips, and memory spikes when encoding megabytes of JSON into SharedPreferences XML.

### Flaw 4: Entangled Foreign Domains (IPO System)
- **Location**: `server/src/routes/ipo_routes.js`, `server/src/services/ipo/*`, `supabase/migrations/20261031000002_ipo_management_system.sql`
- **Problem**: Financial IPO tracking (bidding, allotments, GMP, Registrar scrapers) exists inside the SplitTrip repository.
- **Consequence**: Bloated database schema, unnecessary maintenance overhead, security risk surface expansion, and violation of the Single Responsibility Principle.

---

## 4. Disconnected & Partially Connected Components

| Component | Path | Expected Responsibility | Actual Behavior | Disconnected From | Impact |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`PostgresAdapter`** | `server/src/db/postgres_adapter.js` | Cloud authority database for multi-user financial transactions | Only called during migration check; bypassed during all API calls | All backend CRUD services (`trip_service.js`, `expense_service.js`) | Container redeploys lose user trips if storage directory is ephemeral. |
| **`SupabaseCloudSync` (Read Path)** | `lib/core/services/supabase_cloud_sync.dart` | Read and write cloud synchronization for client | Only receives writes (best-effort mirror); read path is bypassed | `TripRepository.getTrips()`, `ExpenseRepository.getExpenses()` | Dual cloud write without read verification; split brain between Supabase and Node API. |
| **`AdminService` Supabase Direct** | `lib/data/services/admin/admin_audit_service.dart` | Admin analytics queries Supabase directly | Node backend also has admin endpoints; client chooses randomly based on `isConfigured` flag | Centralized API middleware | Inconsistent security auditing and bypass of Node.js rate limiters. |
| **`FCMService` IPO Handler** | `lib/core/services/fcm_service.dart` | Dispatches push notifications for trips | Routes `/ipo/:id` notifications that do not exist in Flutter UI navigation | Flutter UI Route Generator | Unhandled navigation exceptions on push notifications. |

---

## 5. Architectural Health Matrix

| Dimension | Rating | Description |
| :--- | :---: | :--- |
| **Separation of Concerns** | **Fair (6/10)** | Presentation and calculation engines are clean; persistence and sync services are heavily entangled. |
| **Local-First Architecture** | **Good (8/10)** | Local SQLite WAL writes are robust and immediate; outbox protects pending mutations. |
| **Data Consistency** | **Moderate (5/10)** | High risk of split brain between Supabase tables, Node.js JSON files, and SQLite caches. |
| **Security & Privacy** | **Good (8/10)** | Hardware Keystore key anchoring, zero-secret logger, TLS 1.3, RLS policies on tables. |
| **Maintainability** | **Fair (5/10)** | God classes (`SyncService`, `TripRepository`, `TripService`) exceed 1,500 lines each. |
| **Testability** | **Good (8/10)** | Pure engines and unit tests have 100% pass rate; integration testing requires complex mock setups. |
