# Google Play Store Release Readiness & Compliance Specification
**Project:** SplitTrip (KITH)  
**Package:** `com.nirniq.kith`  
**Target API:** Android 15 (API level 35)  
**Release Specialist:** Principal Google Play Release Engineer & Privacy Compliance Lead  
**Date:** 2026-11-19  

---

## 1. Google Play Policy Compliance Scorecard

```
================================================================================
GOOGLE PLAY RELEASE READINESS
================================================================================
Target API Level (API 34/35 Required)    | PASS (Target SDK 35 configured)
Android App Bundle (.aab Format)         | PASS (AAB build pipeline functional)
Play App Signing (Keystore Verified)     | PASS (upload-keystore.jks configured)
Privacy Policy Verification              | PASS (In-app & web privacy policy)
Account Deletion Compliance              | PASS (In-app + web URL deletion)
Data Safety Form Preparation             | PASS (Full declaration matrix below)
Sensitive Permission Justification       | ACTION REQUIRED (Remove SCHEDULE_EXACT_ALARM)
Store Listing Assets (Icon, Screenshots) | PASS (Assets prepared in assets/ & STORE_LISTING.md)
================================================================================
```

---

## 2. Technical Release Requirements

### 2.1 Target API Level Policy
- **Google Play Requirement**: As of August 2026, all new app submissions and updates must target **Android 14 (API level 34) or Android 15 (API level 35)**.
- **SplitTrip Configuration**: `targetSdk = 35` and `compileSdk = 35` in `android/app/build.gradle.kts`. **Fully Compliant**.

### 2.2 Android App Bundle (.aab) & 64-bit Architecture
- **Packaging**: Built via `flutter build appbundle --release`.
- **Architectures Supported**: `arm64-v8a` (64-bit ARM), `armeabi-v7a` (32-bit ARM), and `x86_64` (64-bit Intel/AMD). Fully compliant with Google Play's 64-bit requirement.

### 2.3 Play App Signing & Keystore
- **Upload Key**: `upload-keystore.jks` configured with alias `upload`.
- **Google Play App Signing**: Configured in Google Play Console. Google re-signs the app bundle with the master app signing key before distributing APKs to end users.
- **Certificate Fingerprint**: Exported in `upload_certificate.pem` for verification and App Links SHA-256 verification.

---

## 3. Data Safety Form Preparation Matrix

Google Play requires developers to accurately complete the **Data Safety form**. Below is the exact declaration required for SplitTrip:

### 3.1 Data Collection & Usage Declaration

| Data Category | Data Type | Collected? | Shared? | Handled Ephemerally? | Purpose |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Personal Info** | Name / Display Name | **YES** | **NO** | No | App functionality (trip member identification) |
| **Personal Info** | Email address | **YES** | **NO** | No | Account management & cloud sync recovery |
| **Financial Info** | User payment info (UPI ID) | **YES** | **NO** | No | App functionality (peer-to-peer settlement routing) |
| **Financial Info** | Purchase history (Expenses) | **YES** | **NO** | No | Core app functionality (expense splitting & calculation) |
| **Photos & Videos** | Photos (Receipt images) | **YES** | **NO** | No | App functionality (receipt attachment to expenses) |
| **Audio Files** | Voice recordings | **YES** | **NO** | **YES** | Core app functionality (voice expense input parsing; processed ephemerally, not stored) |
| **Device or other IDs**| FCM registration token | **YES** | **NO** | No | Push notifications for trip updates & payment requests |

### 3.2 Security Practices
- **Data Encrypted in Transit**: **YES** (All data transferred over TLS 1.3 / HTTPS).
- **Data Deletion Request Mechanism**: **YES** (Users can delete all account data and trips in-app and via web URL).

---

## 4. Google Play Account Deletion Policy Compliance

Google Play requires that if an app allows account creation, it must also provide an in-app and external web mechanism to delete the account and associated data:
1. **In-App Deletion**:
   - Implemented in `MasterSettingsView` $\rightarrow$ "Delete Account & Data".
   - Executes `clearAllUserData()`, wipes local SQLite tables, deletes SharedPreferences, and issues `DELETE /api/auth/account` to the backend.
2. **Web-Based Deletion URL**:
   - Hosted at: `https://splittrip-4es6.onrender.com/account/delete`
   - Allows users to submit their email or account recovery key to permanently purge all server-side records without reinstalling the app.

---

## 5. Store Listing Assets & Metadata

- **App Title**: Kith — Split Trips & Expenses
- **Short Description (80 chars)**: Offline-first group travel expense splitting, smart splits & UPI settlements.
- **Full Description**: Complete 4,000-character description documented in [STORE_LISTING.md](file:///e:/PROJECTS/SplitTrip/STORE_LISTING.md).
- **App Icon**: 512x512 32-bit PNG (`assets/icons/app_icon.png`).
- **Feature Graphic**: 1024x500 JPEG/PNG.
- **Screenshots Prepared**:
  - `home_screen.png`: Active trips, net balance hero card.
  - `kith_screen.png`: Liquid glass expense detail view.
  - `tap_after.png`: Multi-payer split allocation screen.

---

## 6. Pre-Launch Checklist Before Google Play Console Upload

- [x] Version code incremented (`flutterVersionCode = 2025`).
- [ ] Remove `SCHEDULE_EXACT_ALARM` from `AndroidManifest.xml` (Must fix before upload).
- [ ] Remove `READ_CONTACTS` from `AndroidManifest.xml` (Must fix before upload).
- [ ] Enable ProGuard/R8 code shrinking in `build.gradle.kts` to reduce AAB from 161 MB to ~38 MB.
- [x] Verify Privacy Policy URL is live and accessible.
- [x] Verify Account Deletion URL is live and accessible.
- [x] Run full automated test suite (100% passing).
