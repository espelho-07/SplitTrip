# Kith Release & Staging Checklist

This document defines the strict, verified checklist required before deploying Kith to staging or releasing to the Google Play Store.

---

## 1. Code & Verification Checklist
- [ ] **Static Analysis**: `flutter analyze` reports 0 errors and 0 warnings.
- [ ] **Flutter Unit & Integration Tests**: All 49+ tests pass (`flutter test`).
- [ ] **Backend Tests**: All 14+ Node.js test suites pass (`npm test`).
- [ ] **CI/CD Pipeline**: GitHub Actions CI workflow passes completely on `main`.
- [ ] **Zero Floating Point Math**: All financial computations utilize integer smallest units (`paise`, `cents`, `pence`) via `MoneyEngine`.

---

## 2. Security & Credentials Checklist
- [ ] **Secret Scan**: No hardcoded API keys, JWT secrets, passwords, or recovery tokens in source code.
- [ ] **Environment Separation**:
  - `LOCAL`: Developer workstations with isolated mock storage.
  - `STAGING`: Dedicated staging server with separate session secrets and database.
  - `PRODUCTION`: Production cluster with encrypted persistence and strict CORS.
- [ ] **Android Keystore**: Release signing keys injected via GitHub Secrets / CI environment (`KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) and never checked into Git.
- [ ] **CORS Configuration**: Production backend restricts CORS to official domains (`https://kith.app`).
- [ ] **Rate Limiting**: Sliding window rate limits active on `/api/auth/recover` and authentication endpoints.

---

## 3. Backend & Infrastructure Checklist
- [ ] **Liveness Endpoint**: `GET /health` returns HTTP 200 `{ "status": "healthy" }`.
- [ ] **Readiness Endpoint**: `GET /ready` returns HTTP 200 `{ "status": "ready" }` confirming database and storage volume accessibility.
- [ ] **Structured Logging**: Request method, route, status code, and duration logged as JSON to `stdout`.
- [ ] **WebSocket Hub**: Realtime WebSocket hub active on secure `wss://` endpoint with room reconnection support.
- [ ] **Data Backup Procedure**:
  - Automated snapshot of `./data_storage` directory prior to any deployment.
  - Verification of atomic write (`.tmp` + rename) mechanism to prevent corruption on crash.

---

## 4. Android Release Package Checklist
- [ ] **Application ID**: Stable namespace `com.kith.app.kith_app`.
- [ ] **Version Bump**: `versionName` and monotonically increasing `versionCode` in `pubspec.yaml`.
- [ ] **Permissions**: Only necessary permissions requested (`CAMERA`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`, `INTERNET`).
- [ ] **Deep Links**: Custom URI (`kith://trip/join?code=...`) and App Links (`https://kith.app/join?code=...`) intent-filters active in `AndroidManifest.xml`.
- [ ] **Release Artifacts**:
  - `app-release.aab` generated for Play Store distribution.
  - `app-release.apk` generated for internal testing / QA distribution.

---

## 5. Rollback & Disaster Recovery Strategy
- **Backend Rollback**: Revert deployment container/process to previous release tag.
- **Data Restoration**: Restore timestamped backup snapshot from `./data_storage/backups/`.
- **Client Rollback**: Halt staged rollout in Google Play Console and revert active release track.
