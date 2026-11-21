# Kith (SplitTrip) Documentation Index

Welcome to the comprehensive technical documentation for **Kith (SplitTrip)**—an offline-first, high-performance group travel and expense sharing system designed for zero-connectivity environments, exact integer paise arithmetic, and Indian IPO intelligence.

---

## Documentation Directory

### 🚀 Getting Started
* [Installation Guide](getting-started/installation.md): Prerequisites, Flutter SDK, Android SDK, and Node.js setup.
* [Development Setup](getting-started/development-setup.md): Local environment configuration, environment variables, emulator and physical device setup.
* [Building from Source](getting-started/building-from-source.md): Complete instructions for compiling debug and release APKs, app bundles, and running the backend server.

### 🏛 Architecture & Design
* [System Architecture Overview](architecture/overview.md): High-level system topology, clean architecture layers, data flow, and state management.
* [Bluetooth Low Energy & P2P Mesh](architecture/ble-p2p-mesh.md): Zero-connectivity discovery, hybrid multi-transport synchronization, and payload security.
* [Sync Architecture](architecture/sync-architecture.md): Offline outbox, mutation queuing, and deterministic conflict resolution.
* [Database Architecture](architecture/database-architecture.md): Dual-tier local persistence (SQLite via Drift + Hive KV store) and schema design.
* [Complete Data Flow](architecture/complete-data-flow.md): End-to-end data pipelines from user interaction to local storage and remote replication.
* [Architecture Decision Records (ADR)](architecture/architecture-decision-records.md): Historical record of major architectural choices and rationale.

### 💻 Development & Engineering Standards
* [Coding Guidelines](development/coding-guidelines.md): Clean Architecture patterns, exact integer paise arithmetic, and style guide.
* [Testing Strategy](development/testing-strategy.md): Unit tests, widget tests, integration tests, and multi-device QA protocols.
* [Git Workflow](development/git-workflow.md): Branching conventions, atomic commits, and pull request lifecycles.
* [Error Handling Matrix](development/error-handling-matrix.md): Client-server status code mapping, network resilience, and recovery mechanisms.

### 📦 Releases & Deployment
* [Release Process](releases/release-process.md): Release workflows, semantic versioning, and build artifact management.
* [Play Store Readiness](releases/play-store-readiness.md): Google Play console compliance, permissions declaration, and release checklist.
* [Store Listing](releases/store-listing.md): App metadata, screenshots, and promotional copy.

### 🛡 Security, Audits & Quality Registers
* [Android Security Audit](audits/android-security-audit.md): Cryptographic security, keystore integration, and storage encryption.
* [Android Permission Audit](audits/android-permission-audit.md): Contextual permissions across Android 12+ (API 31+) and legacy versions.
* [Android Performance Audit](audits/android-performance-audit.md): Memory consumption, frame rates, and battery optimization.
* [Bug & Risk Register](audits/bug-and-risk-register.md): Prioritized tracking of known technical risks and mitigation status.

### 🔧 Maintenance
* [Repository Guidelines](maintenance/repository-guidelines.md): Dependency management, CI pipelines, and repository hygiene.
