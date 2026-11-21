# Android Permissions Audit & Google Play Policy Review
**Project:** SplitTrip (KITH)  
**File Inspected:** `android/app/src/main/AndroidManifest.xml`  
**Auditor:** Principal Android Architect & Google Play Policy Specialist  
**Date:** 2026-11-19  

---

## 1. Executive Summary & Google Play Policy Risk

An exhaustive audit of the 21 permissions declared in `AndroidManifest.xml` identified **two critical violations of Google Play Developer Program Policies**:
1. **Forbidden `SCHEDULE_EXACT_ALARM`**: Google Play strictly rejects apps declaring this permission unless the primary core functionality is an alarm clock, timer, or calendar app. SplitTrip does not schedule exact alarms and will be **immediately rejected** on submission.
2. **Redundant High-Risk `READ_CONTACTS`**: The app uses the system-managed contact picker (`Intent.ACTION_PICK`), which automatically grants one-time URI read permissions without requiring the broad `READ_CONTACTS` permission. Retaining this declaration triggers extensive Google Play Data Safety scrutiny and user trust friction.

---

## 2. Line-by-Line Permission Audit Matrix

| # | Declared Permission | Protection Level | Purpose in SplitTrip | Policy Evaluation | Recommendation |
| :-: | :--- | :---: | :--- | :---: | :--- |
| **1** | `android.permission.INTERNET` | Normal | API calls, WebSockets, Supabase sync | **ESSENTIAL** | Retain. |
| **2** | `android.permission.ACCESS_NETWORK_STATE` | Normal | Network connectivity & offline state monitoring | **ESSENTIAL** | Retain. |
| **3** | `android.permission.POST_NOTIFICATIONS` | Runtime (33+) | Transaction alerts, trip invites, settlement requests | **ESSENTIAL** | Retain; requested at runtime. |
| **4** | `android.permission.CAMERA` | Runtime | Scanning trip QR invite codes, receipt camera capture | **JUSTIFIED** | Retain; requested contextually. |
| **5** | `android.permission.RECORD_AUDIO` | Runtime | Voice expense natural language parser | **JUSTIFIED** | Retain; requested on mic tap. |
| **6** | `android.permission.USE_BIOMETRIC` | Normal | Local biometric authentication lock (fingerprint/face) | **JUSTIFIED** | Retain. |
| **7** | `android.permission.VIBRATE` | Normal | Tactile Liquid Glass haptic feedback | **JUSTIFIED** | Retain. |
| **8** | `android.permission.WAKE_LOCK` | Normal | Background FCM message handling | **JUSTIFIED** | Retain. |
| **9** | `android.permission.RECEIVE_BOOT_COMPLETED` | Normal | Re-registering native Android home screen widgets | **JUSTIFIED** | Retain. |
| **10**| `android.permission.SCHEDULE_EXACT_ALARM` | Special | **Not used anywhere in source code** | **CRITICAL VIOLATION** | **REMOVE IMMEDIATELY (P0)**. |
| **11**| `android.permission.READ_CONTACTS` | Dangerous | Contact picker for adding trip members | **POLICY VIOLATION** | **REMOVE IMMEDIATELY (P0)**. |
| **12**| `android.permission.BLUETOOTH_SCAN` | Runtime (31+) | P2P Nearby Connections offline mesh (`neverForLocation`) | **JUSTIFIED** | Retain. |
| **13**| `android.permission.BLUETOOTH_ADVERTISE` | Runtime (31+) | P2P Nearby Connections discovery broadcast | **JUSTIFIED** | Retain. |
| **14**| `android.permission.BLUETOOTH_CONNECT` | Runtime (31+) | P2P Nearby Connections peer data transfer | **JUSTIFIED** | Retain. |
| **15**| `android.permission.NEARBY_WIFI_DEVICES` | Runtime (33+) | P2P Wi-Fi Direct high-speed payload transfer | **JUSTIFIED** | Retain. |
| **16**| `android.permission.BLUETOOTH` | Normal (<=30) | Legacy Bluetooth discovery for older devices | **JUSTIFIED** | Retain (legacy). |
| **17**| `android.permission.BLUETOOTH_ADMIN` | Normal (<=30) | Legacy Bluetooth setup for older devices | **JUSTIFIED** | Retain (legacy). |
| **18**| `android.permission.ACCESS_WIFI_STATE` | Normal | P2P Wi-Fi Direct interface monitoring | **JUSTIFIED** | Retain. |
| **19**| `android.permission.CHANGE_WIFI_STATE` | Normal | P2P Wi-Fi Direct socket negotiation | **JUSTIFIED** | Retain. |
| **20**| `android.permission.CHANGE_WIFI_MULTICAST_STATE` | Normal | P2P mDNS peer discovery | **JUSTIFIED** | Retain. |
| **21**| `android.permission.ACCESS_FINE_LOCATION` | Runtime | Legacy BLE on Android 10–11 | **EVALUATE** | Guard with `android:maxSdkVersion="30"`. |

---

## 3. Deep Analysis: Why `READ_CONTACTS` Must Be Removed

### The Android Architectural Pattern:
In `android/app/src/main/kotlin/com/nirniq/kith/MainActivity.kt`:
```kotlin
val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
startActivityForResult(intent, REQUEST_CODE_PICK_CONTACT)
```
When an application dispatches `Intent.ACTION_PICK`, the system contacts application handles the UI. The user explicitly selects a contact, and the Android framework grants temporary read permission to the returning URI (`content://com.android.contacts/...`).

**The application does NOT need `android.permission.READ_CONTACTS`.**
- Declaring `READ_CONTACTS` in `AndroidManifest.xml` causes Google Play to classify the app as collecting full user contact lists.
- Removing this declaration protects user privacy, eliminates the need for a Google Play Contacts Policy declaration, and prevents app rejection.

---

## 4. Deep Analysis: Why `SCHEDULE_EXACT_ALARM` Must Be Removed

### Google Play Developer Policy (Targeting API 33+ / 34+):
> *"Apps targeting Android 13 (API 33) or higher must declare `USE_EXACT_ALARM` or `SCHEDULE_EXACT_ALARM` only if their core use case is an alarm clock, timer, or calendar app. Applications that do not qualify will be rejected from Google Play."*

- SplitTrip does not have an alarm clock or calendar scheduling engine.
- A search of the entire codebase confirms that zero exact alarms are registered in Dart or Kotlin.
- Removing this unused permission eliminates an immediate blocker for Google Play store approval.

---

## 5. Cleaned Target `AndroidManifest.xml` (Permissions Diff)

```diff
--- AndroidManifest.xml (Current)
+++ AndroidManifest.xml (Target Production)
@@ -9,4 +9,2 @@
     <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
     <uses-permission android:name="android.permission.WAKE_LOCK"/>
     <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
-    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
     <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
@@ -20,2 +18,1 @@
     <uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" android:usesPermissionFlags="neverForLocation" />
-    <uses-permission android:name="android.permission.READ_CONTACTS"/>
+    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
+    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="30" />
```
