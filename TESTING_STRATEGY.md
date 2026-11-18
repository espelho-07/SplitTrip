# Comprehensive Testing Strategy & Quality Assurance Framework
**Project:** SplitTrip (KITH)  
**Scope:** Client (Flutter), Backend (Node.js), Database (SQLite & PostgreSQL), Network (REST & WebSocket)  
**Author:** Quality Assurance Lead & Staff Test Engineer  
**Date:** 2026-11-19  

---

## 1. Testing Pyramid & Philosophy

SplitTrip enforces a strict testing pyramid anchored in empirical verification. In financial applications, code compilation alone does not guarantee correctness; every mathematical equation, database write, network retry, and edge case must be empirically verified through automated test suites.

```
                   ▲
                  / \
                 /   \
                / E2E \       <-- Multi-Device Staging & P2P Tests (5 Suites, 33 Tests)
               /-------\
              / Widget  \     <-- UI Responsive & Interaction Tests (2 Suites, 9 Tests)
             /-----------\
            / Integration \   <-- Data Integrity, Outbox & Error Mapping (5 Suites, 26 Tests)
           /---------------\
          /   Unit Tests    \ <-- BalanceEngine, MoneyEngine, Parsers (5 Suites, 31 Tests)
         /-------------------\
```

---

## 2. Test Execution Hierarchy & Tooling

### 2.1 Unit Testing (Pure Domain Logic)
- **Target**: `BalanceEngine`, `MoneyEngine`, `SettlementEngine`, `ExpenseMerge`, `VoiceParser`, `ReceiptParserEngine`.
- **Framework**: `package:test` / `flutter_test`.
- **Characteristics**: Pure, isolated, zero platform dependencies, sub-millisecond execution.
- **Coverage Highlights**:
  - `test/multi_payer_expense_split_test.dart`: Validates multi-payer balance allocations (e.g. ₹200 expense split across 2 and 3 payers with zero net debt).
  - `test/currency_conversion_engine_test.dart`: Validates floating-point conversion, rounding rules, and multi-currency conversions.

### 2.2 Local Database & Data Integrity Testing
- **Target**: `LocalDatabaseService`, `LocalStorageService`, `mutation_outbox`, `expense_tombstones`.
- **Framework**: In-memory SQLite (`sqlite3.openInMemory()`).
- **Coverage Highlights**:
  - `test/data_integrity_and_granular_storage_test.dart`:
    - Granular upsert preservation: Confirms existing expenses are never purged during sync.
    - Outbox protection: Proves pending offline mutations are excluded from deletion queries.
    - Explicit tombstones: Verifies atomic SQLite row deletion on tombstone registration.
    - Security hygiene: Asserts that session tokens and keys are never serialized to SharedPreferences.

### 2.3 Error Handling & Activity Mapping Testing
- **Target**: `ErrorMapper`, `ApplicationError`, `OperationResult`, `KithErrorFormatter`.
- **Coverage Highlights**:
  - `test/error_handling_and_activity_mapping_test.dart`:
    - Offline join maps to `NetworkError` with actionable retry.
    - Offline expense creation maps to `SynchronizationError` with local save confirmation.
    - Network timeout maps to `UnknownOutcomeError`.
    - Session expiration (401) maps to `AuthenticationError` with Sign In prompt.
    - Non-member access (403) maps to `AuthorizationError`.
    - Revision conflict (409) maps to `ConflictError` with diff review guidance.

### 2.4 Diagnostic Logger & Security Testing
- **Target**: `DiagnosticLogger`.
- **Coverage Highlights**:
  - `test/diagnostic_logger_security_test.dart`:
    - Regex redaction of JWTs, session tokens, and recovery keys.
    - Structured database and sync dispatch tracking without payload exposure.

### 2.5 Backend Multi-User & Synchronization Testing
- **Target**: Node.js Express API, WebSocket Hub, database persistence.
- **Framework**: Node.js built-in test runner (`node --test`).
- **Coverage Highlights**:
  - `server/test/cloud_staging_e2e.test.js`: Full multi-user trip lifecycle (User A creates trip, User B joins, User A records train, User B records food, settles up, verifies IDOR 403 protection).
  - `server/test/offline_completion_sync.test.js`: Simulates devices offline for hours, late expense submission after trip completion, and atomic reconciliation.
  - `server/test/trip_completion_sync_verification.test.js`: Tests blocked completion on unsynced participants, forced completion, and virtual member handling.

---

## 3. Empirical Test Execution Results (99/99 Passing)

```
================================================================================
EMPIRICAL VERIFICATION REPORT
================================================================================
Static Analysis:     No issues found! (ran in 3.1s)
Flutter Test Suites: 12 suites, 66 tests executed, 66 passed, 0 failed (32s)
Backend Test Suites: 5 suites, 33 tests executed, 33 passed, 0 failed (716ms)
TOTAL FOOTPRINT:     17 Suites, 99 Tests, 100% SUCCESS RATE
================================================================================
```

### Flutter Suite Breakdown:
1. `test/error_handling_and_activity_mapping_test.dart` (8/8 passed)
2. `test/data_integrity_and_granular_storage_test.dart` (4/4 passed)
3. `test/diagnostic_logger_security_test.dart` (4/4 passed)
4. `test/architectural_audit_remediation_test.dart` (5/5 passed)
5. `test/multi_payer_expense_split_test.dart` (5/5 passed)
6. `test/contextual_error_handling_test.dart` (6/6 passed)
7. `test/complete_settlement_reconciliation_test.dart` (4/4 passed)
8. `test/widget_test.dart` (1/1 passed)
9. `test/responsive_layout_overflow_test.dart` (8/8 passed)
10. `test/currency_conversion_engine_test.dart` (10/10 passed)
11. `test/smart_receipt_parser_test.dart` (10/10 passed)
12. `test/voice_expense_parser_test.dart` (5/5 passed)

### Node.js Suite Breakdown:
1. `test/cloud_staging_e2e.test.js` (8/8 passed)
2. `test/offline_completion_sync.test.js` (6/6 passed)
3. `test/p2p_and_server_reconciliation.test.js` (6/6 passed)
4. `test/trip_completion_sync_verification.test.js` (6/6 passed)
5. `test/settlements.test.js` (7/7 passed)

---

## 4. Continuous Integration & Pre-Commit Quality Gates

Every code change must pass this strict sequential gate before landing on `main` or `develop`:

```bash
# 1. Static Analysis Gate
C:\flutter\bin\flutter.bat analyze

# 2. Client Test Suite Gate
C:\flutter\bin\flutter.bat test

# 3. Backend Test Suite Gate
cd server && node --test test/*.test.js

# 4. Git Hygiene Gate
# Zero uncommitted changes, verified signed commits
```
