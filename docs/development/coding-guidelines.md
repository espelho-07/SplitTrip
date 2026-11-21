# Kith Engineering & Coding Guidelines

## 1. Clean Architecture Principles

Kith strictly separates business logic, data persistence, and UI rendering:

- **Domain Layer (`lib/domain/`):** Pure Dart with zero Flutter dependencies. Houses business models, mathematical split algorithms, and conflict-resolution rules.
- **Data Layer (`lib/data/`):** Implements domain repository interfaces. Handles local storage (SQLite/Hive), REST networking, and P2P mesh synchronization.
- **Presentation Layer (`lib/presentation/`):** Flutter widgets, reactive ViewModels, design tokens, and platform bridges.

---

## 2. The Strict Financial Precision Rule

Financial accuracy is the core foundation of Kith:

1. **Floating-Point Ban:** Never use `double` for storing, adding, subtracting, or splitting money.
2. **Integer Arithmetic:** All currency values must be stored and computed as **integer paise** (`int amountInPaise`), where `₹1.00 = 100 paise`.
3. **Deterministic Remainder Allocation:** When splitting amounts that do not divide evenly (e.g., ₹100 split 3 ways = 33.333...):
   - Floor the division: `baseSplit = totalPaise ~/ count` (3333 paise).
   - Compute remainder: `remainder = totalPaise - (baseSplit * count)` (1 paise).
   - Distribute the remainder deterministically based on lexicographically sorted member IDs.
   - Result: 3334, 3333, 3333 -> Sum is exactly 10000 paise. Zero currency lost.

---

## 3. Immutability & Model Integrity

- Models must be immutable and provide `copyWith(...)`, `toJson()`, and `fromJson(...)`.
- Always implement defensive copying when dealing with collections:
  ```dart
  List<TripMember> get members => List.unmodifiable(_members);
  ```
- Use factories for consistent JSON parsing with sensible fallbacks.

---

## 4. Error Handling & User Feedback

- Never swallow exceptions silently in `catch (_) {}` blocks unless explicitly marked with a comment explaining why it is harmless (e.g. non-critical network cleanup).
- Wrap network and database exceptions in domain-level `AppException` types (`NetworkException`, `ConflictException`, `NotFoundException`, `UnauthorizedException`).
- Surface clean, friendly error messages to users via `KithErrorFormatter.format(e)` and haptic feedback via `HapticHelper`.

---

## 5. Flutter Performance Standards

- Prefer `const` constructors everywhere applicable to minimize widget rebuilds.
- Avoid heavy computation inside `build(BuildContext context)` methods. Offload parsing, filtering, or balance calculations to ViewModels or background isolates.
- Keep list views performant by leveraging `ListView.builder` or `CustomScrollView` with `SliverList`.
