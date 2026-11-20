import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late GuestUser testUser;
  late Trip testTrip;
  late TripMember memberA;
  late TripMember memberB;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    syncService = SyncService(storage);

    testUser = GuestUser(
      id: 'usr_alice_123',
      displayName: 'Alice',
      anonymousToken: 'anon_alice_123',
      recoveryKey: 'ALICE-RECOVERY-KEY-1234',
      createdAt: DateTime.now(),
    );

    memberA = TripMember(
      id: 'mbr_alice',
      userId: testUser.id,
      displayName: 'Alice',
      role: 'creator',
      joinedAt: DateTime.now(),
    );

    memberB = TripMember(
      id: 'mbr_bob',
      userId: 'usr_bob_456',
      displayName: 'Bob',
      role: 'member',
      joinedAt: DateTime.now(),
    );

    testTrip = Trip(
      id: 'trip_ladakh_101',
      inviteCode: 'LAD101',
      name: 'Ladakh Roadtrip',
      creatorId: testUser.id,
      currencyCode: 'INR',
      lifecycleState: TripLifecycle.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      members: [memberA, memberB],
    );

    await storage.saveTrips([testTrip.toJson()]);
    await storage.saveUser(testUser.toJson());
  });

  group('Critical Offline Trip Completion & Dependency-Aware Sync Suite', () {
    test('1. Offline Expense + Offline Complete: Trip enters completing state and completion depends on expense', () async {
      // Mock client that is unreachable / offline
      final offlineClient = MockClient((request) async {
        throw http.ClientException('Network connection failed');
      });
      final apiClient = ApiClient(httpClient: offlineClient);

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

      // 1. User adds expense offline
      final offlineExpense = Expense(
        id: 'exp_offline_petrol_1',
        tripId: testTrip.id,
        title: 'Highway Petrol',
        amountInPaise: 50000,
        paidById: memberA.id,
        category: ExpenseCategory.transport,
        splitType: SplitType.equal,
        splits: [
          ExpenseSplit(memberId: memberA.id, amountInPaise: 25000),
          ExpenseSplit(memberId: memberB.id, amountInPaise: 25000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await expenseRepo.addExpense(offlineExpense);

      // Verify expense is cached immediately
      final cachedExpenses = expenseRepo.getCachedExpenses(testTrip.id);
      expect(cachedExpenses.length, 1);
      expect(cachedExpenses.first.title, 'Highway Petrol');

      // Verify pending queue has addExpense mutation
      final pendingMutations = syncService.getPendingMutationsForTrip(testTrip.id);
      expect(pendingMutations.length, 1);
      expect(pendingMutations.first.type, MutationType.addExpense);

      // 2. User immediately taps Complete Trip while still offline
      final updatedTrip = await tripRepo.updateLifecycle(
        tripId: testTrip.id,
        newLifecycle: TripLifecycle.completed,
      );

      // The trip MUST NOT jump to completed; it enters completing ("Finishing sync")
      expect(updatedTrip.lifecycleState, TripLifecycle.completing);
      expect(updatedTrip.lifecycleState.displayName, 'Finishing sync');

      // Verify storage reflects completing state
      final cachedTrip = tripRepo.getCachedTripById(testTrip.id);
      expect(cachedTrip?.lifecycleState, TripLifecycle.completing);

      // Verify updateTripLifecycle mutation is enqueued and dependsOn the addExpense mutation
      final allPending = syncService.getPendingMutationsForTrip(testTrip.id);
      expect(allPending.length, 2);
      final completeMutation = allPending.firstWhere((m) => m.type == MutationType.updateTripLifecycle);
      expect(completeMutation.dependsOn, contains(pendingMutations.first.id));
    });

    test('2. Dependency Ordering & Execution: flushQueue executes expense first, then completion, promoting trip to COMPLETED', () async {
      final executionOrder = <String>[];

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/expenses')) {
          executionOrder.add('CREATE_EXPENSE');
          return http.Response(
            jsonEncode({
              'data': {
                'expense': {
                  'id': 'exp_offline_petrol_1',
                  'tripId': testTrip.id,
                  'title': 'Highway Petrol',
                  'amountInPaise': 50000,
                }
              }
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/lifecycle')) {
          executionOrder.add('UPDATE_LIFECYCLE');
          return http.Response(
            jsonEncode({
              'data': {
                'trip': {
                  'id': testTrip.id,
                  'lifecycleState': 'completed',
                }
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"data": {}}', 200);
      });

      final apiClient = ApiClient(httpClient: mockClient);

      // Enqueue expense mutation
      final expMutation = await syncService.enqueueMutation(
        MutationType.addExpense,
        {
          'id': 'exp_offline_petrol_1',
          'tripId': testTrip.id,
          'title': 'Highway Petrol',
          'amountInPaise': 50000,
        },
      );

      // Set trip to completing locally
      testTrip = testTrip.copyWith(lifecycleState: TripLifecycle.completing);
      await storage.saveTrips([testTrip.toJson()]);

      // Enqueue completeTrip mutation depending on expense
      await syncService.enqueueMutation(
        MutationType.updateTripLifecycle,
        {'tripId': testTrip.id, 'lifecycleState': 'completed'},
        dependsOn: [expMutation.id],
      );

      expect(syncService.getPendingMutationsForTrip(testTrip.id).length, 2);

      // Flush queue
      await syncService.flushQueue(apiClient);

      // Verify strict dependency order: expense first, then lifecycle
      expect(executionOrder, ['CREATE_EXPENSE', 'UPDATE_LIFECYCLE']);
      expect(syncService.getPendingMutationsForTrip(testTrip.id).length, 0);

      // Verify local storage trip is promoted to completed
      tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
      final finalTrip = tripRepo.getCachedTripById(testTrip.id);
      expect(finalTrip?.lifecycleState, TripLifecycle.completed);
    });

    test('3. App Restart / Cold Start Recovery: Pending mutations and completing state survive process kill', () async {
      // 1. Setup pending queue and completing state
      final expMutation = await syncService.enqueueMutation(
        MutationType.addExpense,
        {
          'id': 'exp_offline_food_2',
          'tripId': testTrip.id,
          'title': 'Dinner',
          'amountInPaise': 30000,
        },
      );

      await syncService.enqueueMutation(
        MutationType.updateTripLifecycle,
        {'tripId': testTrip.id, 'lifecycleState': 'completed'},
        dependsOn: [expMutation.id],
      );

      await storage.saveTrips([
        testTrip.copyWith(lifecycleState: TripLifecycle.completing).toJson(),
      ]);

      // 2. Simulate Cold App Restart: Re-instantiate LocalStorageService and SyncService
      final reloadedStorage = await LocalStorageService.init();
      final reloadedSyncService = SyncService(reloadedStorage);

      expect(reloadedSyncService.getPendingCountForTrip(testTrip.id), 2);
      final reloadedTrip = TripRepository(
        storage: reloadedStorage,
        syncService: reloadedSyncService,
        apiClient: ApiClient(),
      ).getCachedTripById(testTrip.id);

      expect(reloadedTrip?.lifecycleState, TripLifecycle.completing);

      // 3. Connect internet and flush
      final serverCalls = <String>[];
      final onlineMock = MockClient((request) async {
        serverCalls.add(request.url.path);
        return http.Response('{"data": {"success": true}}', 200, headers: {'content-type': 'application/json'});
      });

      await reloadedSyncService.flushQueue(ApiClient(httpClient: onlineMock));

      expect(reloadedSyncService.getPendingCountForTrip(testTrip.id), 0);
      expect(serverCalls.length, 2);
      expect(serverCalls[0].contains('/expenses'), isTrue);
      expect(serverCalls[1].contains('/lifecycle'), isTrue);
    });

    test('4. Network Flapping Safety: Interrupted sync does NOT execute completeTrip prematurely', () async {
      // Mock client that fails during expense sync
      var attempts = 0;
      final flappingClient = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          // First attempt: Network drops during expense sync
          throw http.ClientException('Connection aborted');
        }
        return http.Response('{"data": {"success": true}}', 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(httpClient: flappingClient);

      final expMutation = await syncService.enqueueMutation(
        MutationType.addExpense,
        {
          'id': 'exp_flapping_1',
          'tripId': testTrip.id,
          'title': 'Cab Ride',
          'amountInPaise': 20000,
        },
      );

      await syncService.enqueueMutation(
        MutationType.updateTripLifecycle,
        {'tripId': testTrip.id, 'lifecycleState': 'completed'},
        dependsOn: [expMutation.id],
      );

      // Attempt flush 1 (network drops)
      await syncService.flushQueue(apiClient);

      // Both mutations must remain in queue! completeTrip must not have run.
      expect(syncService.getPendingCountForTrip(testTrip.id), 2);
      expect(syncService.currentStatus, SyncStatus.offline);

      // Network returns and flush 2 succeeds (simulating reconnection or Retry Now)
      await syncService.flushQueue(apiClient, force: true);
      expect(syncService.getPendingCountForTrip(testTrip.id), 0);
    });

    test('5. Zero-Mutation Online Completion: Clean trip without pending items completes directly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': {
              'trip': {
                'id': testTrip.id,
                'lifecycleState': 'completed',
              }
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );

      expect(syncService.hasPendingMutationsForTrip(testTrip.id), isFalse);

      final completed = await tripRepo.updateLifecycle(
        tripId: testTrip.id,
        newLifecycle: TripLifecycle.completed,
      );

      // Because no pending mutations existed, directly moves to completed
      expect(completed.lifecycleState, TripLifecycle.completed);
    });

    test('6. Multi-Expense Batching: Multiple offline expenses maintain ordered execution before completion', () async {
      final processedOperations = <String>[];
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/expenses')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          processedOperations.add('EXPENSE:${body['title']}');
          return http.Response('{"data": {"expense": {"id": "${body['id']}"}}}', 201, headers: {'content-type': 'application/json'});
        } else if (request.url.path.contains('/lifecycle')) {
          processedOperations.add('LIFECYCLE:completed');
          return http.Response('{"data": {"trip": {"id": "${testTrip.id}", "lifecycleState": "completed"}}}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"data": {}}', 200);
      });

      final apiClient = ApiClient(httpClient: mockClient);

      // Add 3 offline expenses
      final exp1 = await syncService.enqueueMutation(MutationType.addExpense, {
        'id': 'exp_1',
        'tripId': testTrip.id,
        'title': 'Breakfast',
        'amountInPaise': 15000,
      });
      final exp2 = await syncService.enqueueMutation(MutationType.addExpense, {
        'id': 'exp_2',
        'tripId': testTrip.id,
        'title': 'Lunch',
        'amountInPaise': 25000,
      });
      final exp3 = await syncService.enqueueMutation(MutationType.addExpense, {
        'id': 'exp_3',
        'tripId': testTrip.id,
        'title': 'Museum Tickets',
        'amountInPaise': 10000,
      });

      // Complete trip with all 3 dependencies
      await syncService.enqueueMutation(
        MutationType.updateTripLifecycle,
        {'tripId': testTrip.id, 'lifecycleState': 'completed'},
        dependsOn: [exp1.id, exp2.id, exp3.id],
      );

      expect(syncService.getPendingCountForTrip(testTrip.id), 4);

      await syncService.flushQueue(apiClient);

      expect(syncService.getPendingCountForTrip(testTrip.id), 0);
      expect(processedOperations, [
        'EXPENSE:Breakfast',
        'EXPENSE:Lunch',
        'EXPENSE:Museum Tickets',
        'LIFECYCLE:completed',
      ]);
    });

    test('7. Guest User Parity: Guest user offline flow maintains identity and vault integrity', () async {
      final offlineClient = MockClient((request) async {
        throw http.ClientException('Network connection failed');
      });
      final apiClient = ApiClient(httpClient: offlineClient);

      final guestStorage = await LocalStorageService.init();
      await guestStorage.saveUser(testUser.toJson());
      final guestSync = SyncService(guestStorage);

      final guestTripRepo = TripRepository(
        storage: guestStorage,
        syncService: guestSync,
        apiClient: apiClient,
      );

      // Create trip offline for guest
      final guestTrip = await guestTripRepo.createTrip(
        name: 'Guest Weekend',
        creator: testUser,
      );

      expect(guestTrip.creatorId, testUser.id);
      expect(guestTrip.lifecycleState, TripLifecycle.active);

      // Add expense offline
      final guestExpenseRepo = ExpenseRepository(
        storage: guestStorage,
        syncService: guestSync,
        apiClient: apiClient,
      );

      final exp = Expense(
        id: 'exp_guest_1',
        tripId: guestTrip.id,
        title: 'Snacks',
        amountInPaise: 4000,
        paidById: guestTrip.members.first.id,
        category: ExpenseCategory.food,
        splitType: SplitType.equal,
        splits: [ExpenseSplit(memberId: guestTrip.members.first.id, amountInPaise: 4000)],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await guestExpenseRepo.addExpense(exp);

      // Complete trip offline
      final completingTrip = await guestTripRepo.updateLifecycle(
        tripId: guestTrip.id,
        newLifecycle: TripLifecycle.completed,
      );

      expect(completingTrip.lifecycleState, TripLifecycle.completing);
      expect(guestSync.getPendingCountForTrip(guestTrip.id), 3); // createTrip, addExpense, updateTripLifecycle
    });
  });
}
