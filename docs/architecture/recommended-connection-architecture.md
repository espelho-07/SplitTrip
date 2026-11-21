# Recommended Connection Architecture: Unified Enterprise Integration Standard

**Project:** SplitTrip (`kith_app`)  
**Package:** `com.nirniq.kith`  
**Version:** 1.0.0+1  
**Audit Date:** 2026-11-19  

---

## 1. Architectural Philosophy & Guiding Principles

To resolve the 10 critical integration problems and eliminate technical debt across the 406 classes in the codebase, the application architecture must adhere to five non-negotiable principles:

1. **Unidirectional Data Flow (UDF):** State flows down; events flow up. ViewModels emit immutable UI state; Views never orchestrate multi-repository mutations.
2. **Unified Inversion of Control (IoC):** Zero widget-level instantiations (`new Service()`). All services and repositories are injected via top-level Providers.
3. **Single Source of Truth (SSOT):** Local SQLite is the sole runtime source of truth. Remote APIs (Node.js & Supabase) serve as synchronization endpoints.
4. **Declarative Navigation Exclusivity:** All screen routes, dialogs, and modal transitions are declared in `AppRouter` with type-safe parameters.
5. **Decoupled Cross-ViewModel Reactive Messaging:** Cross-feature updates (e.g., adding an expense updating the home dashboard) communicate via an asynchronous, typed `AppEventBus`.

---

## 2. Inversion of Control & Dependency Injection Topology

Currently, services such as `PaymentService` and `FinanceExportBridgeService` are instantiated directly inside widgets, breaking testability and shared state.

### Standardized `MultiProvider` Registration Tree:
```dart
// lib/app_providers.dart
class AppProviders {
  static List<SingleChildWidget> get providers => [
    // 1. Core Services (Singletons / Low-Level IO)
    Provider<LocalStorageService>.value(value: localStorageService),
    Provider<DatabaseHelper>.value(value: databaseHelper),
    Provider<FlutterSecureStorage>.value(value: secureStorage),
    Provider<ApiClient>.value(value: apiClient),
    Provider<SupabaseCloudSync>.value(value: supabaseCloudSync),
    Provider<RealtimeClient>.value(value: realtimeClient),
    Provider<P2PSyncService>.value(value: p2pSyncService),
    
    // 2. Event Bus for Cross-ViewModel Decoupled Communication
    Provider<AppEventBus>(create: (_) => AppEventBus()),

    // 3. Application State Services (ChangeNotifiers)
    ChangeNotifierProvider<PaymentService>(create: (_) => PaymentService()),
    ChangeNotifierProvider<SyncService>(
      create: (ctx) => SyncService(
        db: ctx.read<DatabaseHelper>(),
        cloudSync: ctx.read<SupabaseCloudSync>(),
        eventBus: ctx.read<AppEventBus>(),
      ),
    ),
    Provider<FinanceExportBridgeService>(
      create: (ctx) => FinanceExportBridgeService(storage: ctx.read<LocalStorageService>()),
    ),

    // 4. Repositories
    ProxyProvider3<ApiClient, DatabaseHelper, SyncService, UserRepository>(
      update: (_, api, db, sync, __) => UserRepository(apiClient: api, db: db, syncService: sync),
    ),
    ProxyProvider3<ApiClient, DatabaseHelper, SyncService, TripRepository>(
      update: (_, api, db, sync, __) => TripRepository(apiClient: api, db: db, syncService: sync),
    ),
    ProxyProvider3<ApiClient, DatabaseHelper, SyncService, ExpenseRepository>(
      update: (_, api, db, sync, __) => ExpenseRepository(apiClient: api, db: db, syncService: sync),
    ),

    // 5. Feature ViewModels
    ChangeNotifierProxyProvider<UserRepository, AuthViewModel>(
      create: (ctx) => AuthViewModel(userRepository: ctx.read<UserRepository>()),
      update: (_, repo, vm) => vm!..updateRepository(repo),
    ),
    ChangeNotifierProxyProvider2<TripRepository, AppEventBus, HomeViewModel>(
      create: (ctx) => HomeViewModel(
        tripRepository: ctx.read<TripRepository>(),
        eventBus: ctx.read<AppEventBus>(),
      ),
      update: (_, repo, bus, vm) => vm!..updateDependencies(repo, bus),
    ),
    ChangeNotifierProxyProvider2<ExpenseRepository, AppEventBus, TripDetailViewModel>(
      create: (ctx) => TripDetailViewModel(
        expenseRepository: ctx.read<ExpenseRepository>(),
        eventBus: ctx.read<AppEventBus>(),
      ),
      update: (_, repo, bus, vm) => vm!..updateDependencies(repo, bus),
    ),
  ];
}
```

---

## 3. Decoupled Reactive Event Bus (`AppEventBus`)

To permanently eliminate stale UI issues like **Issue 13 (HomeViewModel not updating when expense added)** and **Issue 15 (HomeViewModel not updating when trip created)**, all state-altering repository operations must emit typed events.

```dart
// lib/core/events/app_events.dart
abstract class AppEvent {
  final DateTime timestamp = DateTime.now();
}

class ExpenseCreatedEvent extends AppEvent {
  final String tripId;
  final Expense expense;
  ExpenseCreatedEvent({required this.tripId, required this.expense});
}

class ExpenseUpdatedEvent extends AppEvent {
  final String tripId;
  final Expense expense;
  ExpenseUpdatedEvent({required this.tripId, required this.expense});
}

class ExpenseDeletedEvent extends AppEvent {
  final String tripId;
  final String expenseId;
  ExpenseDeletedEvent({required this.tripId, required this.expenseId});
}

class TripCreatedEvent extends AppEvent {
  final Trip trip;
  TripCreatedEvent({required this.trip});
}

class SettlementRecordedEvent extends AppEvent {
  final String tripId;
  final Settlement settlement;
  SettlementRecordedEvent({required this.tripId, required this.settlement});
}

// lib/core/events/app_event_bus.dart
class AppEventBus {
  final StreamController<AppEvent> _controller = StreamController<AppEvent>.broadcast();

  Stream<T> on<T extends AppEvent>() => _controller.stream.where((e) => e is T).cast<T>();

  void emit(AppEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() => _controller.close();
}
```

### Consumption in `HomeViewModel`:
```dart
class HomeViewModel extends ChangeNotifier {
  final TripRepository _tripRepository;
  final AppEventBus _eventBus;
  StreamSubscription? _sub;

  HomeViewModel({required TripRepository tripRepository, required AppEventBus eventBus})
      : _tripRepository = tripRepository,
        _eventBus = eventBus {
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _sub = _eventBus.on<AppEvent>().listen((event) {
      if (event is ExpenseCreatedEvent || event is ExpenseDeletedEvent || event is SettlementRecordedEvent) {
        // Automatically recalculate aggregate spending across all trips
        recalculateTotals();
        notifyListeners();
      } else if (event is TripCreatedEvent) {
        // Automatically insert new trip into home list
        _trips.insert(0, event.trip);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

---

## 4. Elimination of Supabase / Node.js Dual-Backend Split Brain

### Problem
Writes are pushed to both Node.js and Supabase, but reads only hit Node.js. If Node.js is unavailable, queries fail even though Supabase is up.

### Solution: Resilient Failover Repository Pattern
```dart
class ResilientTripDataSource {
  final ApiClient _nodeApi;
  final SupabaseCloudSync _supabase;
  final DatabaseHelper _localDb;

  Future<TripData> getTripDetails(String tripId) async {
    // 1. Return cached local data immediately (Offline-First)
    final localTrip = await _localDb.getTrip(tripId);

    // 2. Attempt primary Node.js REST API
    try {
      final remoteData = await _nodeApi.get('/trips/$tripId');
      await _localDb.upsertTrip(remoteData);
      return remoteData;
    } on NetworkException catch (e) {
      debugPrint('[TripDataSource] Node.js API failed ($e). Attempting Supabase fallback...');
      
      // 3. Fallback to Supabase PostgREST
      try {
        final supaData = await _supabase.fetchTrip(tripId);
        if (supaData != null) {
          await _localDb.upsertTrip(supaData);
          return supaData;
        }
      } catch (supaErr) {
        debugPrint('[TripDataSource] Supabase fallback also failed: $supaErr');
      }
    }

    // 4. Return local offline cache if all networks fail
    if (localTrip != null) return localTrip;
    throw ServerUnavailableException('Unable to load trip from any cloud source.');
  }
}
```

---

## 5. Encapsulated Account Lifecycle & Purge Pipeline

### Problem (Issue 25)
Logout and Account Deletion orchestration is currently executed directly in `ProfileHomeTab` widget button handlers:
```dart
// BAD: Leaked in UI callback
storage.clearAllUserData();
homeVm.clearData();
sqlite.clearAll();
authVm.deleteAccount();
```

### Solution: Atomic Repository Operation
```dart
// lib/domain/repositories/user_repository.dart
class UserRepository {
  Future<void> purgeAllUserDataLocallyAndRemotely() async {
    final currentUserId = await _getCurrentUserId();
    
    // 1. Remote Account Deletion
    if (currentUserId != null) {
      try {
        await _apiClient.delete('/auth/account');
      } catch (_) {}
      try {
        await _supabaseCloudSync.deleteAccount(currentUserId);
      } catch (_) {}
    }

    // 2. Wipe SQLite Financial Tables
    await _databaseHelper.clearAllTables();

    // 3. Wipe Secure Credentials
    await _secureStorage.deleteAll();

    // 4. Wipe Local Preferences
    await _localStorageService.clearAllUserData();

    // 5. Reset In-Memory Sync Queue
    _syncService.resetQueue();
  }
}

// lib/presentation/viewmodels/auth_viewmodel.dart
class AuthViewModel extends ChangeNotifier {
  Future<void> deleteAccountAndPurgeData() async {
    _setLoading(true);
    try {
      await _userRepository.purgeAllUserDataLocallyAndRemotely();
      _currentUser = null;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }
}

// lib/presentation/views/profile/profile_home_tab.dart
// CLEAN: Single call from UI
void _onDeleteAccountTapped() async {
  final confirmed = await showConfirmDialog(context);
  if (confirmed && context.mounted) {
    await context.read<AuthViewModel>().deleteAccountAndPurgeData();
    if (context.mounted) context.go('/onboarding');
  }
}
```

---

## 6. Declarative Route Normalization

All imperative `Navigator.push` calls must be migrated to declarative GoRouter definitions.

### Sub-Route Registration for `ManageMembersView`:
```dart
// lib/presentation/router/app_router.dart
GoRoute(
  path: '/trip/:id',
  builder: (context, state) => TripDetailView(tripId: state.pathParameters['id']!),
  routes: [
    GoRoute(
      path: 'members/manage',
      builder: (context, state) => ManageMembersView(tripId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: 'settle',
      builder: (context, state) => SettleUpView(tripId: state.pathParameters['id']!),
    ),
  ],
),
```
Usage in UI:
```dart
// Before: Navigator.push(context, ManageMembersView.route(trip.id));
// After:
context.push('/trip/${trip.id}/members/manage');
```

---

## 7. App Lifecycle Background Sync Integration

### Root Observer Implementation:
```dart
// lib/app.dart
class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[AppLifecycle] Resumed - Flushing pending offline mutations...');
      context.read<SyncService>().flushQueue(context.read<ApiClient>(), force: true);
    } else if (state == AppLifecycleState.paused) {
      debugPrint('[AppLifecycle] Paused - Finalizing pending queue write-ahead logs...');
      context.read<SyncService>().persistQueue();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```
