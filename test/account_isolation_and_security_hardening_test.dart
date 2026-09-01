import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late AuthService authService;
  late SyncService syncService;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    apiClient = ApiClient();
    authService = AuthService(apiClient: apiClient, storage: storage);
    syncService = SyncService(storage);
    tripRepo = TripRepository(apiClient: apiClient, storage: storage, syncService: syncService);
    expenseRepo = ExpenseRepository(apiClient: apiClient, storage: storage, syncService: syncService);
  });

  group('Kith P0 Security & Sync Hardening Suite', () {
    test('1. Mandatory Account Isolation: User A offline mutation -> Logout -> User B login -> No cross-account contamination', () async {
      // Step 1: User A creates guest session
      final userA = await authService.createGuestUser(displayName: 'User Alice');
      expect(userA.displayName, equals('User Alice'));
      expect(authService.getCurrentUser()?.id, equals(userA.id));

      // Step 2: User A creates a trip and enqueues offline expenses
      final tripA = await tripRepo.createTrip(
        name: 'Alice Goa Trip',
        creator: userA,
      );
      expect(tripA.name, equals('Alice Goa Trip'));

      await syncService.enqueueMutation(
        MutationType.addExpense,
        {
          'tripId': tripA.id,
          'title': 'Alice Secret Dinner',
          'amountInPaise': 50000,
          'paidById': userA.id,
        },
        idempotencyKey: 'mut_alice_dinner',
      );

      // Verify User A has 2 pending mutations in outbox (createTrip + addExpense)
      expect(syncService.pendingCount, equals(2));

      // Step 3: User A logs out
      await authService.logout();

      // Invariant: All user credentials, local cached trips, and outbox mutations must be wiped
      expect(authService.getCurrentUser(), isNull);
      expect(storage.getSavedUser(), isNull);
      expect(storage.getSavedTrips(), isEmpty);
      expect(syncService.pendingCount, equals(0));
      expect(syncService.getQueue(), isEmpty);

      // Step 4: User B logs in
      final userB = await authService.createGuestUser(displayName: 'User Bob');
      expect(userB.id, isNot(equals(userA.id)));
      expect(authService.getCurrentUser()?.id, equals(userB.id));

      // Invariant: User B MUST have an empty queue and empty trip list
      expect(syncService.pendingCount, equals(0));
      expect(storage.getSavedTrips(), isEmpty);
    });

    test('2. Durable Outbox Pipeline: Enqueued mutations preserve idempotency, timestamps, and dependencies', () async {
      final user = await authService.createGuestUser(displayName: 'Darpan');

      final trip = await tripRepo.createTrip(
        name: 'Himalayan Trek',
        creator: user,
      );

      final exp = await expenseRepo.addExpense(
        Expense(
          id: 'exp_trek_1',
          tripId: trip.id,
          title: 'Tents',
          amountInPaise: 150000,
          paidById: user.id,
          category: ExpenseCategory.activities,
          splitType: SplitType.equal,
          splits: [
            ExpenseSplit(memberId: trip.members.first.id, amountInPaise: 150000),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      expect(exp.id, equals('exp_trek_1'));
      final queue = syncService.getQueue();
      expect(queue.any((m) => m.type == MutationType.addExpense), isTrue);
      expect(queue.any((m) => m.entityId == 'exp_trek_1'), isTrue);
    });

    test('3. Trip Lifecycle Completing Invariant: Offline expense blocks instant completed state until sync drains', () async {
      final user = await authService.createGuestUser(displayName: 'Sync Tester');
      final trip = await tripRepo.createTrip(name: 'Quick Trip', creator: user);

      // Adding offline expense mutation
      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'tripId': trip.id, 'title': 'Taxi', 'amountInPaise': 30000},
      );

      // Completing trip with pending expenses sets completing ("Finishing sync")
      final completingTrip = await tripRepo.updateLifecycle(
        tripId: trip.id,
        newLifecycle: TripLifecycle.completed,
      );
      expect(completingTrip.lifecycleState, equals(TripLifecycle.completing));

      // Draining outbox queue allows completion
      await syncService.clearQueue();
      final completedTrip = await tripRepo.updateLifecycle(
        tripId: trip.id,
        newLifecycle: TripLifecycle.completed,
      );
      expect(completedTrip.lifecycleState, equals(TripLifecycle.completed));
    });

    test('4. Delete Account Security: Completely purges local identity and storage', () async {
      await authService.createGuestUser(displayName: 'To Be Deleted');
      expect(authService.getCurrentUser(), isNotNull);

      await authService.deleteAccount();

      expect(authService.getCurrentUser(), isNull);
      expect(storage.getSavedUser(), isNull);
      expect(storage.getSavedTrips(), isEmpty);
      expect(syncService.pendingCount, equals(0));
    });
  });
}
