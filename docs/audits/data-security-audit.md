# Data Security, Encryption & Access Control Audit

**Project:** SplitTrip (KITH)  
**Security Standard:** Zero-Trust Cryptographic Guest & Tenant Isolation  
**Status:** Audit Completed & Hardened  

---

## 1. Cryptographic Key Management & Storage Security

### 1.1 Local Encryption Matrix

| Storage Layer | Storage Mechanism | What Is Stored | Encryption / Security Implementation |
| :--- | :--- | :--- | :--- |
| **Hardware Keystore** | `FlutterSecureStorage` (Android Keystore / iOS Keychain) | `kith_secure_guest_id`, `kith_secure_recovery_key`, `kith_secure_session_token_<acc>` | Hardware-backed AES-256 GCM (Android MasterKey / iOS Keychain `kSecAttrAccessibleAfterFirstUnlock`). Survives application reinstalls. |
| **Local Relational DB** | SQLite (`LocalDatabaseService`) in application sandbox | Structured trips, expenses, settlements, mutation outbox | Protected by Android/iOS sandboxed process UID permissions (`0600`). Sensitive token columns are strictly excluded. |
| **Local Cache** | SharedPreferences (`LocalStorageService`) | Non-sensitive UI caches, theme, active trip IDs | Sanitized: `saveUserToRecoveryVault` strips `anonymousToken`, `token`, and `sessionToken` before writing to disk. |

### 1.2 Zero Secrets Policy
- **Service Role Credentials:** The Supabase `service_role` key is strictly prohibited in Flutter. Client bundles only contain the public `anon` key.
- **Node.js Financial Boundary:** Direct write operations on financial entities are mediated by the authenticated Node.js backend.
- **Redaction Pipeline:** `DiagnosticLogger` automatically filters and redacts JWTs (`[REDACTED_JWT]`), recovery keys (`[REDACTED_RECOVERY_KEY]`), session tokens (`[REDACTED_SESSION_TOKEN]`), and passwords before logging.

---

## 2. In-Transit Network Security

- **Transport Protocol:** 100% of network traffic uses TLS 1.3 / HTTPS. Plaintext HTTP is blocked in Android network security config.
- **Authentication Header:** Requests pass cryptographic bearer tokens via `Authorization: Bearer <sessionToken>` and `x-kith-session-token`.
- **Identity Proofing:** Client-supplied user IDs in headers (e.g. `x-kith-account-id`) are **never trusted**. The server always resolves identity cryptographically by computing `SHA-256(token)` against `guest_sessions.session_token_hash`.

---

## 3. Supabase Row Level Security (RLS) Policy Audit

| Table | RLS Status | Verified Policy Enforcements |
| :--- | :---: | :--- |
| `guest_sessions` | **ENABLED** | Only the authenticated session owner can read/update their session record. Anonymous table scraping is blocked. |
| `users` | **ENABLED** | Authenticated users can read public profiles; write access is restricted to the owning account ID (`auth.uid() = id`). |
| `trips` | **ENABLED** | `kith_is_trip_member(trips.id, kith_current_user_id())` restricts reads, updates, and lifecycle mutations exclusively to joined members. Non-members receive zero rows. |
| `trip_members` | **ENABLED** | Only authorized trip members can view the member roster; non-members cannot inspect participant lists. |
| `expenses` | **ENABLED** | Mutations restricted to verified trip members. Non-members cannot read or tamper with expenses. |
| `expense_splits` | **ENABLED** | Read and write access locked to trip members associated with the parent `expense_id`. |
| `settlements` | **ENABLED** | Only trip members can record settlements; confirmation requires `to_member_id` or `from_member_id` identity. |
| `personal_expenses` | **ENABLED** | Strict tenant isolation: `user_id = kith_current_user_id()`. Zero cross-account visibility. |
| `personal_debts` | **ENABLED** | Strict tenant isolation: `user_id = kith_current_user_id()`. |
| `personal_budgets` | **ENABLED** | Strict tenant isolation: `user_id = kith_current_user_id()`. |
| `notifications` | **ENABLED** | Strict tenant isolation: `recipient_user_id = kith_current_user_id()`. |
| `kith_sync_events` | **ENABLED** | Accessible only via `kith_fetch_sync_events()` which filters events to caller's owned trips and personal records. |

---

## 4. Insecure Direct Object Reference (IDOR) Hardening

- Tested in `server/test/cloud_staging_e2e.test.js` (Test 8):
  - User C (authenticated guest with valid session) attempted to fetch `GET /api/trips/:tripId` for a private trip created by User A.
  - Server returned `HTTP 403 Forbidden` (`You do not have permission to access this trip`).
  - Proves that possession of a valid guest session does not permit access to arbitrary trip resources without membership.
