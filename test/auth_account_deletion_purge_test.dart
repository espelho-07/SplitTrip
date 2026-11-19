import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/events/app_event_bus.dart';
import 'package:kith_app/core/events/app_events.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CONN-P0-04: AppEventBus Reactive Sync Tests', () {
    late AppEventBus eventBus;

    setUp(() {
      eventBus = AppEventBus();
    });

    tearDown(() {
      eventBus.dispose();
    });

    test('1. Emits and receives ExpenseCreatedEvent on event bus', () async {
      ExpenseCreatedEvent? received;
      final sub = eventBus.on<ExpenseCreatedEvent>().listen((e) {
        received = e;
      });

      final now = DateTime.now();
      final expense = Expense(
        id: 'exp_bus_test_1',
        tripId: 'trip_bus_1',
        title: 'Dinner at Beach',
        amountInPaise: 150000,
        category: ExpenseCategory.food,
        paidById: 'mbr_1',
        splits: const [],
        createdAt: now,
        updatedAt: now,
      );

      eventBus.emit(ExpenseCreatedEvent(tripId: 'trip_bus_1', expense: expense));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(received, isNotNull);
      expect(received!.tripId, 'trip_bus_1');
      expect(received!.expense.title, 'Dinner at Beach');
      expect(received!.expense.amountInPaise, 150000);

      await sub.cancel();
    });

    test('2. Filters events correctly by type', () async {
      final receivedEvents = <AppEvent>[];
      final tripSub = eventBus.on<TripCreatedEvent>().listen(receivedEvents.add);

      eventBus.emit(SettlementRecordedEvent(tripId: 'trip_settle_1'));
      final trip = Trip(
        id: 'trip_event_1',
        name: 'Goa Holiday',
        creatorId: 'usr_creator',
        inviteCode: 'GOA123',
        members: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      eventBus.emit(TripCreatedEvent(trip: trip));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(receivedEvents.length, 1);
      expect(receivedEvents.first, isA<TripCreatedEvent>());
      expect((receivedEvents.first as TripCreatedEvent).trip.name, 'Goa Holiday');

      await tripSub.cancel();
    });
  });

  group('CONN-P0-02: Encapsulated Account Deletion & Multi-Store Purge Tests', () {
    late LocalStorageService storage;
    late AuthService authService;
    late UserRepository userRepo;
    late AuthViewModel authVm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      authService = AuthService(storage: storage, apiClient: ApiClient());
      userRepo = UserRepository(authService: authService);
      authVm = AuthViewModel(userRepo: userRepo);
    });

    test('1. AuthViewModel.deleteAccountAndPurgeData() purges all local user data and invalidates session', () async {
      final user = GuestUser(
        id: 'usr_purge_test_01',
        displayName: 'Purge User',
        recoveryKey: 'KITH-AAAA-BBBB',
        anonymousToken: 'tok_purge_1',
        createdAt: DateTime.now(),
      );

      await storage.saveUser(user.toJson());
      await authVm.initSession();
      expect(authVm.isAuthenticated, isTrue);
      expect(authVm.currentUser?.id, 'usr_purge_test_01');

      // Execute encapsulated multi-store purge
      final success = await authVm.deleteAccountAndPurgeData();
      expect(success, isTrue);

      // Verify AuthViewModel state
      expect(authVm.isAuthenticated, isFalse);
      expect(authVm.currentUser, isNull);
      expect(authVm.authState, AuthState.signedOut);

      // Verify LocalStorageService state
      expect(storage.getSavedUser(), isNull);
      expect(storage.getUserByRecoveryKey('KITH-AAAA-BBBB'), isNull);
      expect(storage.isRecoveryKeyDeleted('KITH-AAAA-BBBB'), isTrue);
    });
  });
}
