# Installation Guide

This guide walks you through setting up your development environment to build, run, and test Kith locally.

---

## 1. Prerequisites

### Operating System Support
- **Windows:** Windows 10/11 64-bit with PowerShell 7+
- **macOS:** macOS Sonoma (14.x) or newer (Apple Silicon or Intel)
- **Linux:** Ubuntu 22.04 LTS or equivalent modern distribution

### Required Tools & SDKs

| Tool | Recommended Version | Purpose |
| :--- | :--- | :--- |
| **Flutter** | `3.24.x` (Channel stable) | Cross-platform UI toolkit |
| **Dart** | `>=3.5.0 <4.0.0` | Core language runtime |
| **Android Studio / SDK** | Android SDK 34 / 35 | Native Android compilation |
| **Android NDK** | `28.2.13676358` | Native C++/JNI bindings |
| **Java JDK** | OpenJDK 17 | Gradle build runtime |
| **Node.js & npm** | Node `18.x` or `20.x` LTS | Backend server runtime |
| **Git** | `2.30+` | Source control |

---

## 2. Setting Up Flutter & Android SDK

1. Install Flutter following the official guide: [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install).
2. Verify your installation by running:
   ```bash
   flutter doctor -v
   ```
   Ensure Android toolchain, Java, and connected devices report green checkmarks.
3. Accept Android licenses if prompted:
   ```bash
   flutter doctor --android-licenses
   ```

---

## 3. Cloning & Installing Dependencies

1. Clone the repository:
   ```bash
   git clone https://github.com/espelho-07/SplitTrip.git
   cd SplitTrip
   ```
2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```
3. Set up backend server dependencies:
   ```bash
   cd server
   npm install
   cd ..
   ```

---

## 4. Verifying Installation

Run the project verification commands:

```bash
# Verify client static analysis
flutter analyze

# Run unit tests
flutter test

# Run backend tests
npm test --prefix server
```
If all commands succeed with zero failures, your development environment is fully prepared.
