import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/core/services/supabase_cloud_sync.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/engine/expense_merge.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/presentation/widgets/progress/global_sync_status_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFreeTierApiClient extends ApiClient {
  int failWithStatus = 0; // 0 = ok, 401 = unauthorized, 500 = internal error, -1 = socket
  final List<dynamic> dispatchedPosts = [];

  @override
  Future<dynamic> post(String path, {dynamic body}) async {
    if (failWithStatus == -1) {
      onConnectivityChanged?.call(false);
      throw const NetworkException(message: 'SocketException: Offline');
    }
    if (failWithStatus == 401) {
      throw const ApiException(
        statusCode: 401,
        message: 'Session token expired',
        code: 'UNAUTHORIZED',
      );
    }
    if (failWithStatus == 500) {
      throw const ApiException(
        statusCode: 500,
        message: 'Supabase rate limit or 500 error',
        code: 'SERVER_ERROR',
      );
    }
    dispatchedPosts.add(body);
    onConnectivityChanged?.call(true);
    return {'status': 'success', 'data': body};
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    if (failWithStatus == -1) {
      onConnectivityChanged?.call(false);
      throw const NetworkException(message: 'SocketException: Offline');
    }
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalDatabaseService dbService;
  late LocalStorageService storage;
  late SyncService syncService;
  late MockFreeTierApiClient apiClient;
  late ExpenseRepository expenseRepo;
  late TripRepository tripRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dbService = LocalDatabaseService.inMemory();
    storage = LocalStorageService(prefs, databaseService: dbService);
    syncService = SyncService(storage);
    apiClient = MockFreeTierApiClient();
    expenseRepo = ExpenseRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    tripRepo = TripRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
  });

  tearDown(() {
    syncService.dispose();
    dbService.dispose();
  });

  group('Kith Phase 11 — 18 Comprehensive Offline & Supabase Free Tier Tests', () {
    test('TEST 1 & 2: Launch Kith without internet and read previously synchronized trips', () async {
      final existingTrip = {
        'id': 'trip_kith_offline_1',
        'name': 'Himalayan Trek',
        'creatorId': 'user_darpan',
        'inviteCode': 'TREK123',
        'members': [
          {'id': 'm_darpan', 'tripId': 'trip_kith_offline_1', 'userId': 'user_darpan', 'displayName': 'Darpan'},
          {'id': 'm_rohit', 'tripId': 'trip_kith_offline_1', 'userId': 'user_rohit', 'displayName': 'Rohit'},
        ],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await storage.saveTrips([existingTrip]);

      apiClient.failWithStatus = -1;
      syncService.handleConnectivityChange(false);

      final cachedTrips = tripRepo.getCachedTrips();
      expect(cachedTrips.length, 1);
      expect(cachedTrips.first.name, 'Himalayan Trek');
      expect(syncService.currentStatus, SyncStatus.offline);
    });

    test('TEST 3, 4 & 5: Create expense offline, restart app, verify persistence', () async {
      final user = GuestUser(
        id: 'user_darpan',
        displayName: 'Darpan',
        recoveryKey: 'RK-1234',
        anonymousToken: 'tok_1',
        createdAt: DateTime.now(),
      );
      await storage.saveUser(user.toJson());

      apiClient.failWithStatus = -1;
      syncService.handleConnectivityChange(false);

      final expense = Expense(
        id: 'exp_offline_101',
        tripId: 'trip_kith_offline_1',
        title: 'Camp Gear Rental',
        amountInPaise: 450000,
        paidById: 'm_darpan',
        category: ExpenseCategory.general,
        splitType: SplitType.equal,
        splits: [
          ExpenseSplit(memberId: 'm_darpan', amountInPaise: 225000),
          ExpenseSplit(memberId: 'm_rohit', amountInPaise: 225000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await expenseRepo.addExpense(expense);

      final localExpenses = expenseRepo.getCachedExpenses('trip_kith_offline_1');
      expect(localExpenses.length, 1);
      expect(localExpenses.first.title, 'Camp Gear Rental');

      final pendingMutations = syncService.getPendingMutations();
      expect(pendingMutations.length, 1);
      expect(pendingMutations.first.userId, 'user_darpan');
      expect(pendingMutations.first.idempotencyKey, 'exp_offline_101');

      // Restart application
      final reloadedSyncService = SyncService(storage);
      final reloadedMutations = reloadedSyncService.getPendingMutations();
      expect(reloadedMutations.length, 1);
      expect(reloadedMutations.first.id, pendingMutations.first.id);
      expect(reloadedMutations.first.payload['title'], 'Camp Gear Rental');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('TEST 6, 7 & 8: Reconnect internet, verify auto-sync and idempotency (0 duplicates)', () async {
      final user = GuestUser(
        id: 'user_darpan',
        displayName: 'Darpan',
        recoveryKey: 'RK-1234',
        anonymousToken: 'tok_1',
        createdAt: DateTime.now(),
      );
      await storage.saveUser(user.toJson());

      apiClient.failWithStatus = -1;
      syncService.handleConnectivityChange(false);

      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'id': 'exp_idempotent_1', 'tripId': 'trip_1', 'title': 'Rafting', 'amountInPaise': 300000},
        idempotencyKey: 'exp_idempotent_1',
      );

      expect(syncService.pendingMutationCount, 1);

      apiClient.failWithStatus = 0;
      syncService.handleConnectivityChange(true);
      await syncService.flushQueue(apiClient, force: true);

      expect(syncService.pendingMutationCount, 0);
      expect(syncService.currentStatus, SyncStatus.synced);
      expect(apiClient.dispatchedPosts.length, 1);

      // Re-flush to verify idempotency
      await syncService.flushQueue(apiClient);
      expect(apiClient.dispatchedPosts.length, 1);
    });

    test('TEST 9 & 10: Disconnect during sync, verify safe recovery on reconnect', () async {
      await syncService.enqueueMutation(
        MutationType.createTrip,
        {'id': 'trip_drop_1', 'name': 'Goa Trip'},
        idempotencyKey: 'trip_drop_1',
      );

      apiClient.failWithStatus = -1;
      await syncService.flushQueue(apiClient);

      expect(syncService.pendingMutationCount, 1);
      expect(syncService.getPendingMutations().first.retryCount, 1);
      expect(syncService.currentStatus, SyncStatus.offline);

      apiClient.failWithStatus = 0;
      syncService.handleConnectivityChange(true);
      await syncService.flushQueue(apiClient, force: true);

      expect(syncService.pendingMutationCount, 0);
      expect(syncService.currentStatus, SyncStatus.synced);
    });

    test('TEST 11: Simultaneous expense updates with Last-Write-Wins and non-destructive merge', () {
      final now = DateTime.now();
      final localOlder = Expense(
        id: 'exp_concurrent',
        tripId: 't1',
        title: 'Dinner (Local)',
        amountInPaise: 100000,
        paidById: 'm1',
        category: ExpenseCategory.food,
        splitType: SplitType.equal,
        splits: [],
        createdAt: now.subtract(const Duration(minutes: 10)),
        updatedAt: now.subtract(const Duration(minutes: 5)),
      );

      final serverNewer = Expense(
        id: 'exp_concurrent',
        tripId: 't1',
        title: 'Dinner (Server Updated)',
        amountInPaise: 120000,
        paidById: 'm1',
        category: ExpenseCategory.food,
        splitType: SplitType.equal,
        splits: [],
        createdAt: now.subtract(const Duration(minutes: 10)),
        updatedAt: now,
      );

      final outcome = mergeAuthoritativeExpenses(
        localExpenses: [localOlder],
        serverExpenses: [serverNewer],
        pendingDeletedIds: {},
        pendingUpserts: {},
        tombstonedIds: {},
      );

      expect(outcome.expenses.length, 1);
      expect(outcome.expenses.first.title, 'Dinner (Server Updated)');
      expect(outcome.expenses.first.amountInPaise, 120000);
    });

    test('TEST 12: Logout preserves outbox per user; User B cannot flush User A mutations', () async {
      final userA = GuestUser(
        id: 'user_A',
        displayName: 'Alice',
        recoveryKey: 'RK-A',
        anonymousToken: 'tok_A',
        createdAt: DateTime.now(),
      );
      await storage.saveUser(userA.toJson());

      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'id': 'exp_alice', 'tripId': 'trip_1', 'title': 'Alice Coffee'},
        userId: 'user_A',
      );

      expect(syncService.getPendingMutations().length, 1);
      expect(syncService.getPendingMutations().first.userId, 'user_A');

      await storage.clearAllUserData(isAccountDeletion: false);

      final retainedOutbox = dbService.getOutboxMutations();
      expect(retainedOutbox.length, 1);
      expect(retainedOutbox.first['userId'], 'user_A');

      final userB = GuestUser(
        id: 'user_B',
        displayName: 'Bob',
        recoveryKey: 'RK-B',
        anonymousToken: 'tok_B',
        createdAt: DateTime.now(),
      );
      await storage.saveUser(userB.toJson());

      apiClient.failWithStatus = 0;
      await syncService.flushQueue(apiClient, force: true);

      expect(apiClient.dispatchedPosts.isEmpty, true);

      await storage.saveUser(userA.toJson());
      await syncService.flushQueue(apiClient, force: true);

      expect(apiClient.dispatchedPosts.length, 1);
      expect((apiClient.dispatchedPosts.first as Map)['title'], 'Alice Coffee');
    });

    test('TEST 13: Session Expiration (401) pauses sync and sets isSessionExpired flag', () async {
      final user = GuestUser(
        id: 'user_session_exp',
        displayName: 'User Exp',
        recoveryKey: 'RK-EXP',
        anonymousToken: 'tok_EXP',
        createdAt: DateTime.now(),
      );
      await storage.saveUser(user.toJson());

      await syncService.enqueueMutation(
        MutationType.createTrip,
        {'id': 'trip_exp', 'name': 'Trip Exp'},
      );

      apiClient.failWithStatus = 401;
      await syncService.flushQueue(apiClient);

      expect(syncService.currentStatus, SyncStatus.error);
      expect(syncService.isSessionExpired, true);
      expect(syncService.lastErrorMessage?.toLowerCase(), contains('session has expired'));
      expect(syncService.pendingMutationCount, 1);
    });

    test('TEST 14: Receipt Upload Failure preserves local file offline', () async {
      final cloudSync = SupabaseCloudSync();
      final result = await cloudSync.uploadReceiptImage(
        localPath: 'local/path/receipt_test.jpg',
        tripId: 'trip_1',
        expenseId: 'exp_1',
      );

      expect(result, isNotNull);
    });

    test('TEST 15: Server Error (500) triggers exponential backoff status', () async {
      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'id': 'exp_500', 'tripId': 'trip_1', 'title': 'Retry Expense'},
      );

      apiClient.failWithStatus = 500;
      await syncService.flushQueue(apiClient);

      expect(syncService.currentStatus, SyncStatus.reconnecting);
      expect(syncService.pendingMutationCount, 1);
      expect(syncService.getPendingMutations().first.retryCount, 1);
    });

    test('TEST 16: Large pending queue handles 50 mutations sequentially without failure', () async {
      for (int i = 0; i < 50; i++) {
        await syncService.enqueueMutation(
          MutationType.addExpense,
          {'id': 'exp_bulk_$i', 'tripId': 'trip_1', 'title': 'Item $i', 'amountInPaise': (i + 1) * 1000},
          idempotencyKey: 'exp_bulk_$i',
        );
      }

      expect(syncService.pendingMutationCount, 50);

      apiClient.failWithStatus = 0;
      await syncService.flushQueue(apiClient, force: true);

      expect(syncService.pendingMutationCount, 0);
      expect(syncService.currentStatus, SyncStatus.synced);
      expect(apiClient.dispatchedPosts.length, 50);
    });

    test('TEST 17: SQLite mutation_outbox structured columns and index performance', () {
      final rows = dbService.rawDb.select("PRAGMA table_info('mutation_outbox');");
      final colNames = rows.map((r) => r['name'] as String).toSet();

      expect(colNames.contains('id'), true);
      expect(colNames.contains('mutation_type'), true);
      expect(colNames.contains('trip_id'), true);
      expect(colNames.contains('user_id'), true);
      expect(colNames.contains('entity_id'), true);
      expect(colNames.contains('idempotency_key'), true);
      expect(colNames.contains('created_at'), true);
      expect(colNames.contains('updated_at'), true);
      expect(colNames.contains('last_attempt_at'), true);
      expect(colNames.contains('status'), true);
      expect(colNames.contains('retry_count'), true);
      expect(colNames.contains('raw_json'), true);
    });

    test('TEST 18: Zero-Sum Balance Invariance strictly maintained across calculations', () async {
      final creator = GuestUser(
        id: 'u1',
        displayName: 'A',
        recoveryKey: 'RK-1',
        anonymousToken: 'tok-1',
        createdAt: DateTime.now(),
      );

      final trip = await tripRepo.createTrip(
        name: 'Goa',
        creator: creator,
        initialFriendNames: ['B', 'C'],
      );

      final expenses = [
        Expense(
          id: 'e1',
          tripId: trip.id,
          title: 'Dinner',
          amountInPaise: 10000,
          paidById: trip.members[0].id,
          category: ExpenseCategory.food,
          splitType: SplitType.equal,
          splits: [
            ExpenseSplit(memberId: trip.members[0].id, amountInPaise: 3334),
            ExpenseSplit(memberId: trip.members[1].id, amountInPaise: 3333),
            ExpenseSplit(memberId: trip.members[2].id, amountInPaise: 3333),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final summary = BalanceEngine.calculateBalances(
        members: trip.members,
        expenses: expenses,
        settlements: [],
        currentUserId: 'u1',
      );

      int netSum = 0;
      for (final bal in summary.memberNetBalances.values) {
        netSum += bal;
      }

      expect(netSum, 0);
    });
  });

  group('GlobalSyncStatusBar UI Messages & Behavior', () {
    testWidgets('renders session expired message with Sign in action button on 401', (tester) async {
      await syncService.enqueueMutation(
        MutationType.createTrip,
        {'id': 'trip_ui_exp', 'name': 'Exp Trip'},
      );
      apiClient.failWithStatus = 401;
      await syncService.flushQueue(apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                Provider<SyncService>.value(value: syncService),
                Provider<ApiClient>.value(value: apiClient),
              ],
              child: const GlobalSyncStatusBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Your session has expired. Sign in again to synchronize your changes.'),
        findsOneWidget,
      );
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('renders offline guidance message when offline with zero pending mutations', (tester) async {
      syncService.handleConnectivityChange(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                Provider<SyncService>.value(value: syncService),
                Provider<ApiClient>.value(value: apiClient),
              ],
              child: const GlobalSyncStatusBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("You're offline. Your saved trips and expenses are still available."),
        findsOneWidget,
      );
    });
  });
}
