<div align="center">

  <img src="assets/images/app_logo.png" alt="Kith Logo" width="128" height="128" style="border-radius: 28px;" />

  # Kith (SplitTrip)

  ### High-Performance, Offline-First Group Travel & Expense Sharing Engine

  [![Flutter](https://img.shields.io/badge/Flutter-3.24.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Android](https://img.shields.io/badge/Android-API_24+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
  [![Node.js](https://img.shields.io/badge/Backend-Node.js_20_LTS-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org)
  [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=for-the-badge)](LICENSE)
  [![CI](https://img.shields.io/badge/CI-Passing-brightgreen?style=for-the-badge&logo=githubactions&logoColor=white)](.github/workflows/ci.yml)

  <p align="center">
    <b>Zero-connectivity peer-to-peer mesh sync</b> &bull;
    <b>100% exact integer paise arithmetic</b> &bull;
    <b>On-device 2D spatial receipt scanner</b> &bull;
    <b>Airbnb-level design system</b>
  </p>

</div>

---

## 📖 Overview

**Kith (SplitTrip)** is a production-grade, offline-first mobile application built with Flutter, native Android Kotlin subsystems, and a real-time Node.js backend. Engineered specifically for real-world group travel where cellular connectivity is frequently unstable or completely unavailable (e.g. high-altitude treks, national parks, remote road trips), Kith enables groups of friends to track expenses, split bills with mathematical precision, and synchronize ledgers across devices without requiring an active internet connection.

---

## ✨ Key Features

### 🏔 Zero-Connectivity BLE & Wi-Fi Mesh Sync
* **Native Android BLE Discovery:** Nearby trip members detect each other via Bluetooth Low Energy (BLE) using privacy-preserving 18-byte service beacons (`tripTokenHash`, `deviceIdHash`, `userIdHash`), without broadcasting personal names or financial data.
* **Hybrid Mesh Synchronization:** Instant transition from BLE proximity detection to local hotspot/Wi-Fi HTTP transactional synchronization for high-throughput ledger replication.
* **Self-Healing Outbox:** Robust client mutation queue that handles exponential backoff, automatically self-heals missing records upon 404 responses, and prevents outbox blocking.

### 💰 Exact Integer (Paise) Financial Precision
* **Zero Rounding Drift:** Floating-point currency arithmetic is strictly banned. All monetary calculations are performed in **integer paise** (`int amountInPaise`), where `₹1.00 = 100 paise`.
* **Fair Penny Remainder Allocation:** Odd divisions (e.g. ₹100 split 3 ways) allocate remainders deterministically based on sorted member IDs, guaranteeing that $\sum \text{splits} \equiv \text{total}$ to the exact paise.
* **Optimal Debt Minimization:** Graph-based settlement algorithm simplifies complex multi-member debts into the minimum possible number of direct repayment transactions.

### 🧾 On-Device AI Receipt Scanner & Voice Expense Input
* **2D Spatial Reconstruction:** Leverages Google ML Kit with 2D bounding-box spatial clustering to reconstruct multi-column grocery and restaurant bills with exact line items.
* **Indian GST & HSN Intelligence:** Automatically recognizes CGST, SGST, IGST, service charges, discounts, and round-offs.
* **Voice Expense Input:** Speech-to-text natural language parser extracting expense title, total amount, payer, and split categories in real time.

### 📈 Indian IPO & Portfolio Intelligence
* **Live Market Schedules:** Track upcoming, active, and recently listed Indian Initial Public Offerings (IPOs) with verified dates, price bands, lot sizes, and issue amounts.
* **Indicative Grey Market Premium (GMP):** Integrated GMP metrics and subscription rates provided via [IPO Guru](https://ipoguru.in).
* **Multi-Account Allotment Tracking:** Manage multiple family Demat accounts and check allotment statuses directly.

### 🎨 Airbnb-Grade Interaction & Design System
* **Fluid 60 FPS Micro-Interactions:** Smooth spring physics, staggered entry transitions, tactile haptic feedback (`HapticHelper`), and responsive typography.
* **Dark / Light Adaptive Theme:** Built with semantic color palettes, accessible contrast ratios, and edge-to-edge Android system navigation.

---

## 🏛 System Architecture

Kith follows **Clean Architecture** principles with strict modular boundaries:

```
lib/
├── core/                  # Network client, theme, haptics, error formatters
├── domain/                # Pure Dart models, math engines, 3-way merge algorithms
│   ├── engine/            # Exact paise calculation and debt settlement engines
│   └── models/            # Trip, Expense, TripMember, GuestUser
├── data/                  # Repositories, local persistence, background synchronization
│   ├── repositories/      # TripRepository, ExpenseRepository, IpoRepository
│   └── services/          # SyncService, P2PSyncService, BleDiscoveryService, LocalStorage
└── presentation/          # Views, ViewModels, Airbnb-grade UI components
    ├── views/trip/        # Dashboard, settlement sheet, nearby radar sheet
    └── widgets/           # Reusable cards, avatars, badges, animated buttons
```

```
android/
├── app/src/main/kotlin/   # Native Kotlin integration
│   ├── KithBleManager.kt  # Native Android BLE Advertiser & Scanner
│   └── MainActivity.kt    # MethodChannel bridges and lifecycle hooks
server/
├── src/services/          # Node.js backend services (Trip, Expense, Auth, Notification)
└── test/                  # 240+ automated integration and security test suites
```

For comprehensive architectural details and sequence diagrams, see:
* [Architecture Overview](docs/architecture/overview.md)
* [Bluetooth Low Energy & P2P Mesh](docs/architecture/ble-p2p-mesh.md)
* [Sync Engine & Outbox Architecture](docs/architecture/sync-architecture.md)

---

## 📱 Supported Android Platforms

* **Minimum SDK:** Android 7.0 (API Level 24)
* **Target SDK:** Android 14 / 15 (API Level 34 / 35)
* **Architecture:** `arm64-v8a`, `armeabi-v7a`, `x86_64`
* **Permissions Model:** Granular contextual permissions adhering to Android 12+ (`BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` with `neverForLocation` flag).

---

## 🚀 Quick Start & Building from Source

### Prerequisites
* **Flutter SDK:** Version `3.24.0+`
* **Java Development Kit (JDK):** Version 17
* **Android SDK:** Platform 34 or 35
* **Node.js:** Version `18.x` or `20.x` LTS

### 1. Clone the Repository
```bash
git clone https://github.com/espelho-07/SplitTrip.git
cd SplitTrip
```

### 2. Install Dependencies
```bash
# Install Flutter packages
flutter pub get

# Install backend dependencies
cd server && npm install && cd ..
```

### 3. Verify Code Quality & Tests
```bash
# Run client static analysis
flutter analyze

# Run Flutter unit and P2P mesh tests
flutter test

# Run backend integration tests
npm test --prefix server
```

### 4. Build and Run
```bash
# Start backend server locally
cd server && npm start

# In a new terminal, build and run on your connected Android device
flutter run
```

To build a standalone debug APK:
```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

---

## 🔒 Security & Privacy

* **Cryptographic Session Recovery:** Guest users authenticate via cryptographic 12-word recovery keys, enabling seamless identity restoration across devices without mandatory email sign-in.
* **Zero Financial Data Over the Air:** Bluetooth Low Energy discovery broadcasts only salted SHA-256 hashes of the trip token and device ID. No names, amounts, or financial details are ever exposed via BLE.
* **Deterministic Access Control:** Trips and expenses are scoped by membership authorization tokens. Non-members cannot view, query, or mutate trip ledgers.

For vulnerability disclosure guidelines, review [SECURITY.md](SECURITY.md).

---

## 🤝 Contributing

We welcome community contributions! Please read our [Contributing Guidelines](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md) before submitting pull requests.

### Pull Request Checklist
1. All changes must be covered by automated tests.
2. `flutter analyze` must report `No issues found! (0 errors, 0 warnings)`.
3. Currency amounts must strictly use `int amountInPaise`.

---

## 📜 Documentation Hub

Visit our [Documentation Directory](docs/README.md) for full technical guides:
* [Installation Guide](docs/getting-started/installation.md)
* [Development Setup](docs/getting-started/development-setup.md)
* [Building from Source](docs/getting-started/building-from-source.md)
* [BLE & P2P Mesh Architecture](docs/architecture/ble-p2p-mesh.md)
* [Coding & Mathematical Guidelines](docs/development/coding-guidelines.md)
* [Play Store Release Process](docs/releases/release-process.md)

---

## ⚖️ License

Kith is released under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for complete details.

---

## 💖 Acknowledgements & Data Attribution

* **Market & Financial Data:** All Indian Initial Public Offering (IPO) schedules, GMP metrics, and issue details are provided by [IPO Guru](https://ipoguru.in).
* **Machine Learning:** On-device OCR powered by Google ML Kit Text Recognition.
* **Icons & Typography:** Google Fonts (Plus Jakarta Sans) and Material Symbols.
