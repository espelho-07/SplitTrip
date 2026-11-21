# Release Process Guide

This document describes the release engineering lifecycle for **Kith**, from version bumping to Google Play Store production deployment.

---

## 1. Semantic Versioning

Kith follows [Semantic Versioning (SemVer)](https://semver.org/): `MAJOR.MINOR.PATCH+BUILD_NUMBER`

* **MAJOR:** Significant architectural changes, backwards-incompatible database schema revisions, or major product transformations.
* **MINOR:** New user-facing features (e.g. Receipt Scanner, BLE Nearby Mesh, IPO module additions) with backward compatibility.
* **PATCH:** Bug fixes, security patches, and performance optimizations.
* **BUILD_NUMBER:** Monotonically increasing integer used by Android (`versionCode`) and iOS (`CFBundleVersion`).

---

## 2. Pre-Release Checklist

1. **Verify Static Analysis:**
   ```bash
   flutter analyze
   ```
2. **Execute Full Test Suites:**
   ```bash
   flutter test
   npm test --prefix server
   ```
3. **Update Version:**
   Update `version: x.y.z+build` in `pubspec.yaml`.
4. **Update Changelog:**
   Document all notable additions, fixes, and security improvements in [CHANGELOG.md](../../CHANGELOG.md).

---

## 3. Building Release Artifacts

### 1. Android App Bundle (AAB)
```bash
flutter build appbundle --release
```
* Output path: `build/app/outputs/bundle/release/app-release.aab`

### 2. Standalone Release APK
```bash
flutter build apk --release
```
* Output path: `build/app/outputs/flutter-apk/app-release.apk`

---

## 4. Google Play Deployment Workflow

GitHub Actions automates deployment to Google Play via `.github/workflows/release_play_store.yml`:
1. Push a release tag matching `v*` (e.g. `v2.0.26`):
   ```bash
   git tag -a v2.0.26 -m "Release v2.0.26"
   git push origin v2.0.26
   ```
2. CI builds the signed release App Bundle using secrets configured in GitHub repository settings (`PLAY_STORE_JSON_KEY`, `KEYSTORE_BASE64`).
3. Automatically publishes the bundle to the **Internal Testing Track** for reviewer verification before staged rollout to Production.
