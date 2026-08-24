# Kith Release & Staging Checklist

This document tracks the verified status required before deploying Kith to staging or releasing to the Google Play Store.

---

## 1. Code & Verification Status
- [x] **Static Analysis (PASS)**: `flutter analyze` reports 0 errors and 0 warnings.
- [x] **Flutter Unit & Integration Tests (PASS)**: All 49+ tests pass (`flutter test`).
- [x] **Backend Tests (PASS)**: All 16+ Node.js test suites pass (`npm test`).
- [x] **CI/CD Pipeline (PASS)**: GitHub Actions CI workflow configured for analyze, tests, and artifact builds on `main`.
- [x] **Zero Floating Point Math (PASS)**: All financial computations utilize integer smallest units (`paise`, `cents`, `pence`) via `MoneyEngine`.

---

## 2. Security & Credentials Status
- [x] **Secret Scan (PASS)**: No hardcoded API keys, JWT secrets, passwords, or recovery tokens in source code.
- [x] **Environment Separation (PASS)**:
  - `LOCAL`: Developer workstations with isolated mock storage.
  - `STAGING`: Dedicated staging server config with separate session secrets and database.
  - `PRODUCTION`: Production cluster specification with strict CORS and token encryption.
- [x] **Android Keystore (READY)**: Release signing configured for secret injection via CI environment / `key.properties` (`KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) with safe debug fallback.
- [x] **CORS Configuration (PASS)**: Production backend restricts CORS to official domains (`https://kith.app`).
- [x] **Rate Limiting (PASS)**: Sliding window rate limits active on `/api/auth/recover` and authentication endpoints.

---

## 3. Backend & Infrastructure Status
- [x] **Liveness Endpoint (PASS)**: `GET /health` returns HTTP 200 `{ "status": "healthy" }`.
- [x] **Readiness Endpoint (PASS)**: `GET /ready` returns HTTP 200 `{ "status": "ready" }` confirming database and storage volume accessibility.
- [x] **Structured Logging (PASS)**: Request method, route, status code, and duration logged as JSON to `stdout`.
- [x] **WebSocket Hub (PASS)**: Realtime WebSocket hub active with room reconnection support.
- [x] **Data Backup Procedure (IMPLEMENTED & TESTED)**:
  - `BackupManager` snapshot of `./data_storage` directory prior to deployments.
  - Atomic write (`.tmp` + rename) mechanism prevents corruption on process crashes.

---

## 4. Android Release Package Status
- [x] **Application ID (PASS)**: Stable namespace `com.kith.app.kith_app`.
- [x] **Version Bump (PASS)**: `versionName` (1.0.0) and monotonically increasing `versionCode` (1) in `pubspec.yaml`.
- [x] **Permissions (PASS)**: Only necessary permissions requested (`CAMERA`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`, `INTERNET`).
- [x] **Deep Links (PASS)**: Custom URI (`kith://trip/join?code=...`) and App Links (`https://kith.app/join?code=...`) intent-filters active in `AndroidManifest.xml`.
- [x] **Beta Feedback (PASS)**: In-app `BetaFeedbackSheet` for non-invasive user feedback tagging.

---

## 5. Rollback & Disaster Recovery Strategy
- **Backend Rollback**: Revert deployment container/process to previous release tag.
- **Data Restoration**: `BackupManager.restoreBackup` restores timestamped backup snapshot from `./data_storage/backups/`.
- **Client Rollback**: Halt staged rollout in Google Play Console and revert active release track.
