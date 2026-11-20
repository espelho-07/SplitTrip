import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/engine/money_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/widgets/progress/global_sync_status_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailingMockApiClient extends ApiClient {
  int failWithStatus = 0; // 0 = SocketException, 500 = Internal Server Error, 401 = Unauthorized
  final List<Map<String, dynamic>> receivedPosts = [];

  FailingMockApiClient({this.failWithStatus = 0});

  @override
  Future<dynamic> post(String path, {dynamic body}) async {
    if (failWithStatus == 0) {
      onConnectivityChanged?.call(false);
      throw const NetworkException(message: 'Unable to reach server. Operating in offline mode.');
    } else if (failWithStatus == 500) {
      throw ApiException(message: 'Internal Server Error', statusCode: 500, code: 'SERVER_ERROR');
    } else if (failWithStatus == 401) {
      throw const UnauthorizedException(message: 'Session token expired');
    }
    receivedPosts.add({'path': path, 'body': body});
    onConnectivityChanged?.call(true);
    return {'id': 'ok', 'status': 'success'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalStorageService storage;
  late SyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
  });

  group('Offline-First Architecture & Network Failure Tests', () {
    test('Scenario A: Complete internet loss — Offline Trip & Expense creation with zero data loss', () async {
      final mockClient = FailingMockApiClient(failWithStatus: 0);
      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: mockClient,
      );
      final expenseRepo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: mockClient,
      );

      final creator = GuestUser(
        id: 'usr_alice123',
        displayName: 'Alice',
        recoveryKey: 'test-key',
        anonymousToken: 'tok-123',
        createdAt: DateTime.now(),
        isLinkedToAccount: false,
      );

      // 1. Create trip completely offline
      final trip = await tripRepo.createTrip(
        name: 'Goa Weekend',
        creator: creator,
        initialFriendNames: ['Bob', 'Charlie'],
      );

      expect(trip.name, 'Goa Weekend');
      expect(trip.members.length, 3);
      // Trip is immediately persisted in local storage
      final cachedTrips = tripRepo.getCachedTrips();
      expect(cachedTrips.any((t) => t.id == trip.id), isTrue);

      // Mutation is queued in SyncService outbox
      expect(syncService.pendingMutationCount, 1);
      expect(syncService.getPendingMutations().first.type, MutationType.createTrip);

      // 2. Add an expense offline with equal split
      final splitA = ExpenseSplit(memberId: trip.members[0].id, amountInPaise: 3334);
      final splitB = ExpenseSplit(memberId: trip.members[1].id, amountInPaise: 3333);
      final splitC = ExpenseSplit(memberId: trip.members[2].id, amountInPaise: 3333);

      final expense = Expense(
        id: 'exp_dinner_1',
        tripId: trip.id,
        title: 'Seafood Dinner',
        amountInPaise: 10000,
        category: ExpenseCategory.food,
        paidById: trip.members[0].id,
        splitType: SplitType.equal,
        splits: [splitA, splitB, splitC],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await expenseRepo.addExpense(expense);

      // Verify cached expenses in local storage
      final cachedExpenses = expenseRepo.getCachedExpenses(trip.id);
      expect(cachedExpenses.length, 1);
      expect(cachedExpenses.first.title, 'Seafood Dinner');
      expect(cachedExpenses.first.amountInPaise, 10000);

      // Outbox now holds both trip creation and expense addition
      expect(syncService.pendingMutationCount, 2);

      // 3. Verify zero-sum financial balance calculation offline
      final summary = BalanceEngine.calculateBalances(
        members: trip.members,
        expenses: cachedExpenses,
        settlements: [],
        currentUserId: creator.id,
      );

      int totalNetBalances = 0;
      for (final val in summary.memberNetBalances.values) {
        totalNetBalances += val;
      }
      expect(totalNetBalances, 0, reason: 'Zero-sum balance invariant must hold strictly offline');
      expect(summary.currentUserNetBalanceInPaise, 6666); // Alice paid 10000, owes 3334 -> net +6666
    });

    test('Scenario B: Mid-operation network drop retains outbox mutation without creating duplicates', () async {
      final mockClient = FailingMockApiClient(failWithStatus: 0);

      final mutation = await syncService.enqueueMutation(
        MutationType.addExpense,
        {'id': 'exp_lunch', 'amountInPaise': 5000, 'tripId': 'trip_1'},
        idempotencyKey: 'exp_lunch',
      );

      expect(syncService.pendingMutationCount, 1);
      expect(mutation.idempotencyKey, 'exp_lunch');

      // Attempt flush under network failure
      await syncService.flushQueue(mockClient);

      // Mutation is NOT discarded; retry count increments; status is offline
      expect(syncService.pendingMutationCount, 1);
      expect(syncService.currentStatus, SyncStatus.offline);
      expect(syncService.getPendingMutations().first.retryCount, 1);
    });

    test('Scenario D: Server HTTP 500 triggers exponential backoff and leaves mutation safe in outbox', () async {
      final mockClient = FailingMockApiClient(failWithStatus: 500);

      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'id': 'exp_hotel', 'amountInPaise': 25000, 'tripId': 'trip_1'},
        idempotencyKey: 'exp_hotel',
      );

      await syncService.flushQueue(mockClient, force: true);

      expect(syncService.pendingMutationCount, 1);
      expect(syncService.currentStatus, SyncStatus.reconnecting);
      final pending = syncService.getPendingMutations().first;
      expect(pending.lastError, contains('500'));
    });

    test('Scenario D: Session Expiration (HTTP 401) pauses sync queue and sets status to error', () async {
      final mockClient = FailingMockApiClient(failWithStatus: 401);

      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'id': 'exp_fuel', 'amountInPaise': 4000, 'tripId': 'trip_1'},
        idempotencyKey: 'exp_fuel',
      );

      await syncService.flushQueue(mockClient, force: true);

      expect(syncService.pendingMutationCount, 1);
      expect(syncService.currentStatus, SyncStatus.error);
      final pending = syncService.getPendingMutations().first;
      expect(pending.lastError, contains('Session expired'));
    });

    test('Scenario E: Internet restoration automatically flushes pending mutations', () async {
      final successClient = FailingMockApiClient(failWithStatus: -1); // -1 = Success

      syncService.startPeriodicSync(successClient, interval: const Duration(seconds: 1));

      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'id': 'exp_cafe', 'amountInPaise': 1200, 'tripId': 'trip_1'},
        idempotencyKey: 'exp_cafe',
      );

      // Signal connectivity restored
      syncService.handleConnectivityChange(true);
      await syncService.flushQueue(successClient);

      expect(syncService.pendingMutationCount, 0);
      expect(syncService.currentStatus, SyncStatus.synced);
      expect(successClient.receivedPosts.length, 1);
    });

    test('Scenario F: Application restart reloads pending mutations from persistent storage', () async {
      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'id': 'exp_persisted', 'amountInPaise': 8000, 'tripId': 'trip_1'},
        idempotencyKey: 'exp_persisted',
      );

      // Simulate app kill & cold boot with same SharedPreferences
      final reloadedStorage = LocalStorageService(prefs);
      final reloadedSyncService = SyncService(reloadedStorage);

      expect(reloadedSyncService.pendingMutationCount, 1);
      final pending = reloadedSyncService.getPendingMutations().first;
      expect(pending.idempotencyKey, 'exp_persisted');
      expect(pending.payload['amountInPaise'], 8000);
    });

    test('Scenario G: Multi-user protection prevents syncing User A mutations under User B session', () async {
      await storage.saveUser({'id': 'usr_userA', 'displayName': 'User A'});

      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'id': 'exp_userA_only', 'amountInPaise': 5000, 'tripId': 'trip_1'},
        idempotencyKey: 'exp_userA_only',
      );

      // User A logs out and User B logs in
      await storage.saveUser({'id': 'usr_userB', 'displayName': 'User B'});

      final mockClient = FailingMockApiClient(failWithStatus: -1);
      await syncService.flushQueue(mockClient);

      // The mutation belonging to User A was skipped and not sent to server under User B
      expect(mockClient.receivedPosts.isEmpty, isTrue);
      expect(syncService.pendingMutationCount, 1);
    });
  });

  group('GlobalSyncStatusBar Widget Tests', () {
    testWidgets('renders Offline status pill when sync service is offline', (tester) async {
      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'id': 'exp_offline', 'amountInPaise': 1000},
      );
      syncService.handleConnectivityChange(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                Provider<SyncService>.value(value: syncService),
                Provider<ApiClient>.value(value: FailingMockApiClient()),
              ],
              child: const Column(
                children: [
                  GlobalSyncStatusBar(),
                  Text('Content Area'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline'), findsOneWidget);
      expect(find.textContaining('1 change saved locally'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
    });

    testWidgets('hides completely when synced with zero pending changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                Provider<SyncService>.value(value: syncService),
                Provider<ApiClient>.value(value: FailingMockApiClient()),
              ],
              child: const Column(
                children: [
                  GlobalSyncStatusBar(),
                  Text('Content Area'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline'), findsNothing);
      expect(find.text('Content Area'), findsOneWidget);
    });
  });
}
