# Contributing to Kith (SplitTrip)

Thank you for your interest in contributing to **Kith (SplitTrip)**! We welcome contributions from developers of all skill levels to help make offline-first group travel, expense sharing, and financial intelligence seamless and reliable.

---

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to `security@nirniq.com` or via GitHub private vulnerability reports.

---

## Getting Started

### Prerequisites

To work on Kith, ensure you have the following installed:

1. **Flutter SDK:** Version `3.24.0` or higher (Channel stable).
2. **Dart SDK:** Included with Flutter (`>=3.5.0 <4.0.0`).
3. **Android SDK & Build Tools:**
   - Android SDK Platform `34` (or `35`)
   - Android NDK `28.2.13676358`
   - Java Development Kit (JDK) 17
4. **Node.js & npm:**
   - Node.js `18.x` or `20.x` LTS
   - npm `9.x` or higher
5. **Git:** Version `2.30+`

### Repository Setup

1. Fork the repository on GitHub: [https://github.com/espelho-07/SplitTrip](https://github.com/espelho-07/SplitTrip)
2. Clone your fork locally:
   ```bash
   git clone https://github.com/<your-username>/SplitTrip.git
   cd SplitTrip
   ```
3. Set up the upstream remote:
   ```bash
   git remote add upstream https://github.com/espelho-07/SplitTrip.git
   ```
4. Install Flutter client dependencies:
   ```bash
   flutter pub get
   ```
5. Install backend dependencies:
   ```bash
   cd server && npm install && cd ..
   ```

---

## Development Workflow

### 1. Branching Strategy

- Always create a new branch from `develop` (or `feature/airbnb-level-ui-ux-overhaul` depending on current active development branch):
  ```bash
  git checkout -b feature/my-new-feature
  # or
  git checkout -b fix/issue-description
  ```
- Keep branches atomic, focused on a single responsibility.

### 2. Running Locally

#### Client (Flutter):
```bash
# Verify attached devices or emulator
flutter devices

# Run on Android device or emulator
flutter run -d <device-id>
```

#### Backend (Node.js API & Real-time Hub):
```bash
cd server
npm start
# Server starts on port 3000 (HTTP and WebSocket)
```

---

## Testing & Verification Guidelines

Every contribution must be empirically verified before submitting a pull request. We enforce a strict **zero-regression** standard:

### 1. Flutter Static Analysis
```bash
flutter analyze
```
*Requirement:* Must output `No issues found! (0 errors, 0 warnings)`.

### 2. Client Unit & Widget Tests
```bash
flutter test
```
*Requirement:* All unit tests across domain, services, and repositories must pass.

### 3. Backend Test Suite
```bash
npm test --prefix server
```
*Requirement:* All 240+ integration and security tests must pass.

### 4. Android Build Verification
```bash
flutter build apk --debug
```
*Requirement:* Gradle assembly must succeed without compilation or resource errors.

---

## Coding Standards

### Clean Architecture & Layering
Kith follows Clean Architecture with strict separation of concerns:
- `lib/core/`: Network clients, error handlers, theme, constants.
- `lib/domain/`: Pure Dart domain models (`Trip`, `Expense`, `TripMember`), financial calculation engines, business rules.
- `lib/data/`: Concrete repositories (`TripRepository`, `ExpenseRepository`), local storage (`LocalStorageService`, SQLite/Hive), background sync (`SyncService`, `P2PSyncService`, `BleDiscoveryService`).
- `lib/presentation/`: Views, view models (`ChangeNotifier` / Provider / Riverpod), UI components following Airbnb-grade design guidelines.

### Financial Precision Rule
- **Never use floating-point numbers (`double`) for currency arithmetic.**
- All monetary values must be represented and computed as **integer paise** (`int amountInPaise`).
- Display formatting must use `CurrencyFormatter.formatPaise(...)`.

### Git Commit Conventions
We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:
- `feat(...)`: A new user-facing feature
- `fix(...)`: A bug fix
- `docs(...)`: Documentation changes
- `refactor(...)`: Code refactoring without behavior change
- `test(...)`: Adding or updating tests
- `chore(...)`: Maintenance, build scripts, dependency updates

Example:
```bash
git commit -m "feat(p2p): implement background BLE discovery watchdog"
```

---

## Pull Request Process

1. Rebase your branch against the latest upstream:
   ```bash
   git fetch upstream
   git rebase upstream/develop
   ```
2. Ensure all tests and static analysis pass cleanly.
3. Open a Pull Request on GitHub against `develop`.
4. Fill out the [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md) completely, including:
   - Detailed description of changes.
   - Root cause (for bug fixes).
   - Verification commands and CLI output evidence.
   - UI screenshots (before and after) for any visual updates.
5. Address review feedback promptly.

---

## Reporting Issues

- **Bug Reports:** Please use our [Bug Report Template](.github/ISSUE_TEMPLATE/bug_report.yml). Provide exact reproduction steps, device model, Android version, and logs.
- **Feature Requests:** Please use our [Feature Request Template](.github/ISSUE_TEMPLATE/feature_request.yml). Explain the problem your feature solves and proposed alternatives.
- **Security Vulnerabilities:** Follow the instructions in [SECURITY.md](SECURITY.md). Do not report security flaws via public GitHub issues.
