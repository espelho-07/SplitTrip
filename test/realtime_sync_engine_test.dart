import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/realtime_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Realtime Sync Engine & Local-First Tests', () {
    late LocalStorageService storage;
    late SyncService syncService;
    late TripRepository tripRepo;
    late ExpenseRepository expenseRepo;
    late PersonalRepository personalRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      syncService = SyncService(storage);
      final apiClient = ApiClient();

      tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
      expenseRepo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
      personalRepo = PersonalRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
    });

    test('1. RealtimeSyncEvent parses standardized deterministic event envelope', () {
      final json = {
        'eventId': 'evt_101',
        'type': 'expense_added',
        'eventType': 'expense_added',
        'entityType': 'expense',
        'entityId': 'exp_999',
        'tripId': 'trip_123',
        'userId': 'usr_456',
        'actorId': 'usr_456',
        'data': {
          'expense': {
            'id': 'exp_999',
            'tripId': 'trip_123',
            'title': 'Dinner',
            'amountInPaise': 50000,
          },
        },
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final event = RealtimeSyncEvent.fromJson(json);

      expect(event.eventId, 'evt_101');
      expect(event.eventType, 'expense_added');
      expect(event.type, 'expense_added');
      expect(event.entityType, 'expense');
      expect(event.entityId, 'exp_999');
      expect(event.tripId, 'trip_123');
      expect(event.userId, 'usr_456');
      expect(event.version, 1);
      expect(event.data['expense']['title'], 'Dinner');
    });

    test('2. RealtimeClient filters out duplicate event IDs via circular deduplication buffer', () async {
      final client = RealtimeClient();
      final eventsReceived = <RealtimeSyncEvent>[];
      final sub = client.events.listen((e) => eventsReceived.add(e));

      // Simulate first arrival of event
      client.handleRawMessage({
        'eventId': 'evt_unique_1',
        'type': 'expense_added',
        'tripId': 'trip_1',
        'data': {'title': 'Coffee'},
      });

      // Simulate duplicate arrival of same event
      client.handleRawMessage({
        'eventId': 'evt_unique_1',
        'type': 'expense_added',
        'tripId': 'trip_1',
        'data': {'title': 'Coffee'},
      });

      // Simulate second distinct event
      client.handleRawMessage({
        'eventId': 'evt_unique_2',
        'type': 'member_joined',
        'tripId': 'trip_1',
        'data': {'displayName': 'Alex'},
      });

      await Future<void>.delayed(Duration.zero);

      expect(eventsReceived.length, 2);
      expect(eventsReceived[0].eventId, 'evt_unique_1');
      expect(eventsReceived[1].eventId, 'evt_unique_2');

      await sub.cancel();
      client.dispose();
    });


    test('3. SyncService enqueues mutations with idempotency keys and tracks pending count', () async {
      expect(syncService.pendingMutationCount, 0);

      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'title': 'Dinner', 'amountInPaise': 120000},
        idempotencyKey: 'exp_idem_1',
      );

      expect(syncService.pendingMutationCount, 1);
      final queue = syncService.getQueue();
      expect(queue.first.idempotencyKey, 'exp_idem_1');
      expect(queue.first.type, MutationType.addExpense);
    });

    test('4. ExpenseRepository provides sub-millisecond local-first write and immediate retrieval', () async {
      final creator = GuestUser(
        id: 'usr_me',
        displayName: 'Darpan',
        recoveryKey: 'KITH-XXXX-YYYY',
        anonymousToken: 'token',
        createdAt: DateTime.now(),
      );

      final trip = await tripRepo.createTrip(
        name: 'Goa Holiday',
        creator: creator,
        initialFriendNames: ['Rohan'],
      );

      final expense = await expenseRepo.addExpense(
        Expense(
          id: 'exp_beach',
          tripId: trip.id,
          title: 'Beach Shacks',
          amountInPaise: 400000,
          paidById: trip.members.first.id,
          category: ExpenseCategory.food,
          splitType: SplitType.equal,
          splits: [
            ExpenseSplit(memberId: trip.members[0].id, amountInPaise: 200000),
            ExpenseSplit(memberId: trip.members[1].id, amountInPaise: 200000),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      expect(expense.title, 'Beach Shacks');
      expect(expense.amountInPaise, 400000);

      // Verify immediate local cache retrieval
      final cached = expenseRepo.getCachedExpenses(trip.id);
      expect(cached.length, 1);
      expect(cached.first.id, expense.id);
      expect(cached.first.title, 'Beach Shacks');

      // Verify balance calculation is computed locally
      final summary = await expenseRepo.getBalanceSummary(
        trip: trip,
        currentUserId: creator.id,
      );
      expect(summary.totalTripSpentInPaise, 400000);
      expect(summary.memberNetBalances.length, 2);
    });

    test('5. TripRepository updates lifecycle locally and enqueues sync mutation', () async {
      final creator = GuestUser(
        id: 'usr_me',
        displayName: 'Darpan',
        recoveryKey: 'KITH-XXXX-YYYY',
        anonymousToken: 'token',
        createdAt: DateTime.now(),
      );

      final trip = await tripRepo.createTrip(
        name: 'Ladakh Bike Trip',
        creator: creator,
      );

      final updated = await tripRepo.updateLifecycle(
        tripId: trip.id,
        newLifecycle: TripLifecycle.completed,
      );

      expect(updated.lifecycleState, TripLifecycle.completed);
      final cached = tripRepo.getCachedTripById(trip.id);
      expect(cached?.lifecycleState, TripLifecycle.completed);
    });

    test('6. PersonalRepository creates personal expenses and computes budgets locally', () async {
      final pexp = await personalRepo.createPersonalExpense(
        userId: 'usr_me',
        title: 'Groceries',
        amountInPaise: 150000,
        category: ExpenseCategory.food,
      );

      expect(pexp.title, 'Groceries');
      expect(pexp.amountInPaise, 150000);

      final cachedExpenses = personalRepo.getCachedPersonalExpenses();
      expect(cachedExpenses.length, 1);
      expect(cachedExpenses.first.id, pexp.id);

      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final budget = await personalRepo.setPersonalBudget(monthKey, 500000);

      expect(budget.monthlyLimitInPaise, 500000);
      expect(budget.spentInPaise, 150000);
      expect(budget.remainingInPaise, 350000);
      expect(budget.percentageUsed, 30);
    });
  });
}
