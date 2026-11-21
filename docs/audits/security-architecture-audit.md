# Security Architecture & Threat Model Audit
**Project:** SplitTrip (KITH)  
**Security Scope:** End-to-End Cryptography, Device Keystore, Cloud RLS, API IDOR, Logging  
**Auditor:** Principal Security Engineer & Database Security Architect  
**Date:** 2026-11-19  

---

## 1. Threat Model & Asset Classification

SplitTrip processes and stores personal financial data, expense amounts, debt obligations, UPI IDs, and collaborative group travel rosters.

### Asset Sensitivity Tiers:
| Tier | Asset | Confidentiality Impact | Integrity Impact | Storage Location |
| :---: | :--- | :---: | :---: | :--- |
| **Tier 1 (Critical)** | Master Account Recovery Key, Session Bearer Tokens | Catastrophic (Account Takeover) | Catastrophic | Android Keystore / iOS Keychain (`SecureIdService`) |
| **Tier 2 (High)** | Financial Balances, Expenses, Debt Settlements, UPI IDs | High (Financial Privacy Leak) | High (Fraudulent Balances) | SQLite WAL (`kith_production_v2.db`), PostgreSQL |
| **Tier 3 (Medium)** | Trip Names, Invite Codes, Member Avatars, Moment Photos | Medium (Social Travel Privacy) | Medium (Vandalism) | SQLite, PostgreSQL, Cloud Storage |
| **Tier 4 (Low)** | Theme Preference, Locale Setting, UI State | Negligible | Low | SharedPreferences (`kith_storage.xml`) |

---

## 2. Cryptographic Storage & Key Anchoring

### 2.1 Hardware-Backed Keystore
Master recovery keys and session authentication tokens are anchored using platform hardware security modules:
- **Android**: `AndroidKeyStore` provider utilizing **AES-256-GCM** encryption with `EncryptedSharedPreferences`.
- **iOS**: Apple Keychain Services with accessibility policy `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

### 2.2 SharedPreferences Secret Sanitization
A critical vulnerability previously existed where `saveUserToRecoveryVault` serialized raw user objects containing `sessionToken`, `token`, and `anonymousToken` directly into plaintext XML (`kith_storage.xml`).
- **Remediation**:
  ```dart
  final sanitized = Map<String, dynamic>.from(userJson);
  sanitized.remove('anonymousToken');
  sanitized.remove('token');
  sanitized.remove('sessionToken');
  vault[normalized] = sanitized;
  ```
  Plaintext XML files now contain strictly non-sensitive identity metadata; all authentication secrets are exclusively anchored in hardware-backed storage.

---

## 3. Cloud Authorization & Insecure Direct Object Reference (IDOR) Defense

### 3.1 Defense-in-Depth Layer 1: Node.js API Middleware
Every mutating route on the backend independently validates caller membership before executing business logic:
```javascript
// Example from expense_service.js:
const authMember = db.findOne('trip_members', (m) => m.tripId === tripId && m.userId === user.id);
if (!authMember) {
  throw AppError.forbidden('You are not a member of this trip');
}
```
If an authenticated user attempts to read or mutate a trip they are not a member of by guessing or brute-forcing a UUID, the server immediately rejects the request with `HTTP 403 Forbidden`.

### 3.2 Defense-in-Depth Layer 2: PostgreSQL Row-Level Security (RLS)
Every database table in Supabase enforces tenant isolation via RLS policies:
```sql
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enforce trip member access on expenses"
ON public.expenses
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.trip_members
    WHERE trip_members.trip_id = expenses.trip_id
      AND trip_members.user_id = auth.uid()
  )
);
```

---

## 4. Zero-Secret Diagnostic Logging

Logging is essential for troubleshooting offline synchronization and payment confirmation errors, but naive logging frequently leaks sensitive credentials into terminal output, crash reports, or cloud logs.

### Implementation (`DiagnosticLogger`):
1. **In-Memory Ring Buffer**: Retains a maximum of 500 log events in volatile memory; zero disk persistence.
2. **Deterministic Regex Masking**:
   - JWT Tokens: `eyJ[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+` $\rightarrow$ `[REDACTED_JWT]`
   - Session Tokens: `sess_[a-fA-F0-9]{32,}` $\rightarrow$ `[REDACTED_SESSION_TOKEN]`
   - Recovery Keys: `[a-z]{3,12}(-[a-z]{3,12}){11}` $\rightarrow$ `[REDACTED_RECOVERY_KEY]`
   - Passwords & UPI PINs: Sanitized automatically.

---

## 5. Network & Transport Security

- **Enforced Protocols**: All communication mandates **TLS 1.3** / HTTPS and secure WebSockets (`wss://`).
- **Certificate Pinning Ready**: Cloud endpoints terminate at trusted public certificate authorities; plain HTTP is completely disabled in Android network security configuration (`android:usesCleartextTraffic="false"`).
- **Rate Limiting**: Tiered rate limits protect against denial-of-service and brute-force attacks:
  - Auth Endpoints (`/api/auth/*`): 10 requests / minute.
  - Mutation Endpoints (`/api/trips/*`): 60 requests / minute.
  - Sync Endpoints (`/api/sync/*`): 120 requests / minute.

---

## 6. Security Vulnerability & Remediation Summary

| ID | Vulnerability | Severity | Status | Verification |
| :---: | :--- | :---: | :---: | :--- |
| **SEC-01** | Plaintext session token storage in SharedPreferences | **HIGH** | **REMEDIATED** | Verified by `test/data_integrity_and_granular_storage_test.dart` (Suite 2, Test 4). |
| **SEC-02** | Bearer credentials exposed in diagnostic logs | **HIGH** | **REMEDIATED** | Verified by `test/diagnostic_logger_security_test.dart` (Suite 3, Test 1). |
| **SEC-03** | IDOR vulnerability on trip expense retrieval | **CRITICAL**| **REMEDIATED** | Verified by `test/cloud_staging_e2e.test.js` (Test 8, HTTP 403 enforced). |
| **SEC-04** | Cross-account cache leakage after account deletion | **HIGH** | **REMEDIATED** | Verified by `test/architectural_audit_remediation_test.dart` (Test 4). |
| **SEC-05** | Fallback to production Supabase in development | **MEDIUM** | **REMEDIATED** | Verified by fail-closed `SupabaseConfig.isConfigured` check. |
