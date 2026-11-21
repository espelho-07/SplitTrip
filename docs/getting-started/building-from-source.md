# Building from Source

This guide covers building debug and release binaries for Android and assembling the server.

---

## 1. Building Android Binaries

Kith uses Gradle with Kotlin DSL (`build.gradle.kts`) and requires JDK 17.

### Building Debug APK
```bash
flutter build apk --debug
```
* Output location: `build/app/outputs/flutter-apk/app-debug.apk`
* Used for: Local development, testing on physical devices, and rapid iteration.

### Installing Directly via ADB
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Building Release APK
```bash
flutter build apk --release
```
* Output location: `build/app/outputs/flutter-apk/app-release.apk`
* Note: Release builds require a configured signing keystore in `android/key.properties`. If unsigned, Flutter signs with the default debug key for local inspection.

### Building Android App Bundle (AAB) for Google Play
```bash
flutter build appbundle --release
```
* Output location: `build/app/outputs/bundle/release/app-release.aab`
* Used for: Google Play Store distribution.

---

## 2. Compiling and Verifying the Server

```bash
cd server
npm install
npm test
```
* Executes 240+ unit and integration tests verifying authentication, recovery keys, trip joining, financial split conservation, and idempotency.
