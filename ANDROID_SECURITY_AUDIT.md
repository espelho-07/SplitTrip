# Android Security Architecture & Threat Audit
**Project:** SplitTrip (KITH)  
**Platform:** Android (API 24 to API 35+)  
**Auditor:** Principal Android Security Architect & Penetration Tester  
**Date:** 2026-11-19  

---

## 1. Executive Security Assessment

The SplitTrip Android client implements robust security practices in key areas (hardware Keystore anchoring, zero-exposure diagnostic logging, SQLite WAL encryption readiness). However, the native Android layer exhibits two critical vulnerabilities that must be addressed prior to Google Play distribution:
1. **Incomplete Android Backup Rules**: `backup_rules.xml` and `data_extraction_rules.xml` back up SharedPreferences XML without handling SQLite database persistence or Keystore key invalidation.
2. **Exported Component & Deep Link Attack Surface**: App Widget receivers are exported to the OS; intent filters accept custom schemes that require strict parameter sanitization.

---

## 2. Component-by-Component Security Audit

### 2.1 Hardware-Backed Keystore & Token Storage
- **Mechanism**: Implemented via [SecureIdService.dart](file:///e:/PROJECTS/SplitTrip/lib/core/services/secure_id_service.dart) wrapping `flutter_secure_storage`.
- **Android Native Provider**: Uses `AndroidKeyStore` with **AES-256-GCM** master key encryption and RSA key wrapping.
- **Master Account Recovery Keys**: Stored with hardware-backed key attestation. Plaintext recovery keys are never written to disk.
- **Audit Verdict**: **PASS (Exemplary)**.

### 2.2 SharedPreferences XML Sanitization
- **Vulnerability Check**: In earlier iterations, `saveUserToRecoveryVault` serialized full user session tokens to `kith_storage.xml`.
- **Status**: **REMEDIATED**. All tokens (`token`, `sessionToken`, `anonymousToken`) are explicitly stripped prior to XML persistence. Rooted device inspections and ADB backups reveal zero bearer credentials.
- **Audit Verdict**: **PASS (Verified)**.

### 2.3 Android Auto Backup & Data Extraction Rules
- **Files**:
  - `android/app/src/main/res/xml/backup_rules.xml` (API 23–31)
  - `android/app/src/main/res/xml/data_extraction_rules.xml` (API 31+)
- **Inspection**:
  ```xml
  <full-backup-content>
      <include domain="sharedpref" path="." />
      <exclude domain="sharedpref" path="kith_fcm_token" />
  </full-backup-content>
  ```
- **Critical Architectural Defect**:
  1. **SQLite Database Missing from Backup**: The rules include `domain="sharedpref"`, but omit `domain="database"`. If a user restores from Google Drive backup onto a new device, SharedPreferences is restored with stale trip lists, but the SQLite database (`kith_production_v2.db`) is completely absent, causing foreign key and cache desynchronization.
  2. **Keystore Invalidation on Cross-Device Transfer**: Hardware Keystore keys *cannot* be restored across devices. If encrypted SharedPreferences are restored to a new phone without the master key, decryption throws `AEADBadTagException`.
- **Audit Verdict**: **PARTIAL (Action Required)**.
- **Recommended Fix**: Update rules to explicitly exclude hardware-encrypted preferences and include or exclude SQLite deterministically.

### 2.4 Exported Android Components
Audit of `AndroidManifest.xml`:

| Component | Type | Exported | Intent Filter / Action | Security Evaluation |
| :--- | :---: | :---: | :--- | :--- |
| `MainActivity` | Activity | `true` | `MAIN`, `LAUNCHER`, `VIEW (kith://, https://)` | **SECURE**: Required for launcher and deep link routing. |
| `KithSnapshotWidgetProvider` | Receiver | `true` | `APPWIDGET_UPDATE` | **SECURE**: Standard Android AppWidget requirement. Handled via system manager. |
| `QuickAddWidgetProvider` | Receiver | `true` | `APPWIDGET_UPDATE` | **SECURE**: Launches MainActivity with explicit deep link pending intent. |
| `BudgetWidgetProvider` | Receiver | `true` | `APPWIDGET_UPDATE` | **SECURE**: Read-only display of cached widget snapshot. |
| `DebtsWidgetProvider` | Receiver | `true` | `APPWIDGET_UPDATE` | **SECURE**: Read-only display of debt balances. |
| `TripWidgetProvider` | Receiver | `true` | `APPWIDGET_UPDATE` | **SECURE**: Read-only display of active trip metrics. |
| `SmartKithWidgetProvider` | Receiver | `true` | `APPWIDGET_UPDATE` | **SECURE**: Multi-view layout controller. |

*Zero unneeded broadcast receivers or content providers are exported without permission checks.*

### 2.5 Intent Filters & Deep Link Validation
- **Custom Scheme (`kith://`)**:
  - Accepted schemes: `kith://trip/:tripId`, `kith://join?code=XXXXXX`.
  - **Defensive Parsing**: `AppRouter.redirect` validates scheme and query parameters using regex. Malicious input strings are rejected without crashing.
- **Android App Links (`https://kith.app/join`)**:
  - Configured with `android:autoVerify="true"`.
  - Requires hosting `.well-known/assetlinks.json` on `https://kith.app` matching the SHA-256 fingerprint of `upload-keystore.jks`.

### 2.6 Network Security & Cleartext Traffic
- **Cleartext Traffic**: Completely disabled in production (`android:usesCleartextTraffic="false"`).
- **Transport Layer**: All outbound API calls require TLS 1.3. Plain HTTP traffic is rejected at the OS socket level.
- **Certificate Pinning Evaluation**: Not recommended for initial release due to high risk of certificate expiration lockouts during infrastructure migrations; TLS 1.3 with system CA validation provides optimal enterprise security.

---

## 3. Vulnerability & Risk Matrix

| Risk ID | Vulnerability | Severity | Impact | Remediation |
| :---: | :--- | :---: | :--- | :--- |
| **SEC-A01** | Incomplete Auto-Backup rules | **HIGH** | Corrupted state on new device restore | Refactor `backup_rules.xml` and `data_extraction_rules.xml`. |
| **SEC-A02** | Missing Network Security Config | **MEDIUM** | Inability to configure custom CA debugging in QA | Add `res/xml/network_security_config.xml`. |
| **SEC-A03** | R8 Code Obfuscation Disabled | **MEDIUM** | Reverse engineering of client business logic | Enable `isMinifyEnabled = true` with ProGuard rules. |
