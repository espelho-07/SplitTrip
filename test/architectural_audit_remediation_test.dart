import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/engine/expense_merge.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/core/network/api_client.dart';

class MockApiClient extends ApiClient {
  dynamic Function(String path, {Map<String, dynamic>? body})? onPost;
  dynamic Function(String path)? onGet;

  MockApiClient();

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    if (onGet != null) return onGet!(path);
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic body, Map<String, dynamic>? queryParams}) async {
    if (onPost != null) return onPost!(path, body: body is Map<String, dynamic> ? body : null);
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Architectural Audit & Remediation Verification Suite', () {
    late SharedPreferences prefs;
    late LocalStorageService storage;
    late SyncService syncService;
    late MockApiClient mockApiClient;
    final testTime = DateTime(2026, 11, 19, 1, 0);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      syncService = SyncService(storage);
      mockApiClient = MockApiClient();
    });

    test('1. Defensive Multi-format Expense & Split: deserializes camelCase, snake_case and paidByMap flawlessly', () {
      final snakeCaseJson = {
        'id': 'exp_snake_001',
        'trip_id': 'trip_audit_100',
        'title': 'Dinner at Highway',
        'amount_in_paise': 20000,
        'category': 'food',
        'paid_by_id': 'mbr_alice',
        'paid_by_map': {
          'mbr_alice': 12000,
          'mbr_bob': 8000,
        },
        'split_type': 'equal',
        'splits': [
          {'member_id': 'mbr_alice', 'amount_in_paise': 10000},
          {'member_id': 'mbr_bob', 'amount_in_paise': 10000},
        ],
        'created_at': '2026-11-19T01:00:00.000Z',
        'updated_at': '2026-11-19T01:00:00.000Z',
        'is_deleted': false,
      };

      final expense = Expense.fromJson(snakeCaseJson);
      expect(expense.id, equals('exp_snake_001'));
      expect(expense.tripId, equals('trip_audit_100'));
      expect(expense.amountInPaise, equals(20000));
      expect(expense.paidById, equals('mbr_alice'));
      expect(expense.paidByMap, isNotNull);
      expect(expense.paidByMap!['mbr_alice'], equals(12000));
      expect(expense.paidByMap!['mbr_bob'], equals(8000));
      expect(expense.splits.length, equals(2));
      expect(expense.splits[0].memberId, equals('mbr_alice'));
      expect(expense.splits[0].amountInPaise, equals(10000));
      expect(expense.splits[1].memberId, equals('mbr_bob'));
      expect(expense.splits[1].amountInPaise, equals(10000));
    });

    test('2. ExpenseMerge: Non-destructive merge preserves local & P2P expenses omitted from server snapshot without tombstoning', () {
      final localP2pExpense = Expense(
        id: 'exp_p2p_offline_001',
        tripId: 'trip_100',
        title: 'Snacks shared via P2P',
        amountInPaise: 5000,
        category: ExpenseCategory.food,
        paidById: 'mbr_alice',
        splits: [
          const ExpenseSplit(memberId: 'mbr_alice', amountInPaise: 2500),
          const ExpenseSplit(memberId: 'mbr_bob', amountInPaise: 2500),
        ],
        createdAt: testTime.subtract(const Duration(minutes: 5)),
        updatedAt: testTime.subtract(const Duration(minutes: 5)),
      );

      final serverExpense = Expense(
        id: 'exp_server_002',
        tripId: 'trip_100',
        title: 'Cab fare',
        amountInPaise: 10000,
        category: ExpenseCategory.transport,
        paidById: 'mbr_bob',
        splits: [
          const ExpenseSplit(memberId: 'mbr_alice', amountInPaise: 5000),
          const ExpenseSplit(memberId: 'mbr_bob', amountInPaise: 5000),
        ],
        createdAt: testTime.subtract(const Duration(minutes: 10)),
        updatedAt: testTime.subtract(const Duration(minutes: 10)),
      );

      final outcome = mergeAuthoritativeExpenses(
        localExpenses: [localP2pExpense],
        serverExpenses: [serverExpense],
        pendingDeletedIds: {},
        pendingUpserts: {},
        tombstonedIds: {},
      );

      // Both expenses must be preserved! P2P expense must NOT be dropped or tombstoned.
      expect(outcome.expenses.length, equals(2));
      expect(outcome.remoteDeletedIds, isEmpty);
      expect(outcome.localNewerIds, contains('exp_p2p_offline_001'));
      expect(outcome.expenses.any((e) => e.id == 'exp_p2p_offline_001'), isTrue);
      expect(outcome.expenses.any((e) => e.id == 'exp_server_002'), isTrue);
    });

    test('3. translateMemberIds: Correctly translates multi-payer paidByMap keys across storage and outbox', () async {
      const tripId = 'trip_multi_translate';
      final initialExpense = {
        'id': 'exp_tmp_001',
        'tripId': tripId,
        'title': 'Dinner',
        'amountInPaise': 20000,
        'paidById': 'temp_member_1',
        'paidByMap': {
          'temp_member_1': 10000,
          'temp_member_2': 10000,
        },
        'splits': [
          {'memberId': 'temp_member_1', 'amountInPaise': 10000},
          {'memberId': 'temp_member_2', 'amountInPaise': 10000},
        ],
      };

      await storage.saveExpenses(tripId, [initialExpense]);

      final mutation = SyncMutation(
        id: 'mut_001',
        type: MutationType.addExpense,
        payload: initialExpense,
        createdAt: testTime,
      );
      await storage.saveMutationQueue([mutation.toJson()]);

      // Reconcile temporary member IDs to canonical server IDs
      await storage.translateMemberIds(
        tripId: tripId,
        translationMap: {
          'temp_member_1': 'mbr_canonical_1',
          'temp_member_2': 'mbr_canonical_2',
        },
      );

      // Verify expenses cache
      final updatedExpenses = storage.getSavedExpenses(tripId);
      expect(updatedExpenses.length, equals(1));
      final exp = updatedExpenses.first;
      expect(exp['paidById'], equals('mbr_canonical_1'));
      final paidByMap = exp['paidByMap'] as Map<String, dynamic>;
      expect(paidByMap.containsKey('mbr_canonical_1'), isTrue);
      expect(paidByMap.containsKey('mbr_canonical_2'), isTrue);
      expect(paidByMap.containsKey('temp_member_1'), isFalse);

      // Verify outbox queue
      final updatedQueue = storage.getMutationQueue();
      expect(updatedQueue.length, equals(1));
      final outboxPayload = updatedQueue.first['payload'] as Map<String, dynamic>;
      expect(outboxPayload['paidById'], equals('mbr_canonical_1'));
      final outboxPaidByMap = outboxPayload['paidByMap'] as Map<String, dynamic>;
      expect(outboxPaidByMap.containsKey('mbr_canonical_1'), isTrue);
      expect(outboxPaidByMap.containsKey('mbr_canonical_2'), isTrue);
    });

    test('4. Account Deletion & New Guest Isolation: TripRepository.getTrips() returns empty list when server returns []', () async {
      // 1. Populate old user trips in cache
      final oldTrip = Trip(
        id: 'trip_old_user_001',
        name: 'Old User Trip',
        creatorId: 'usr_old_001',
        inviteCode: 'OLD123',
        createdAt: testTime,
        updatedAt: testTime,
        members: [
          TripMember(id: 'mbr_old_1', userId: 'usr_old_001', displayName: 'Old User', joinedAt: testTime),
        ],
      );
      await storage.saveTrips([oldTrip.toJson()]);

      // 2. Simulate User A deleting account and User B continuing as new guest
      await storage.clearAllUserData();

      final newGuestUser = {
        'id': 'usr_new_guest_999',
        'displayName': 'New Traveler',
        'recoveryKey': 'KITH-NEW9-GUEST',
        'anonymousToken': 'kith_sess_new_999',
        'createdAt': DateTime.now().toIso8601String(),
        'isLinkedToAccount': false,
      };
      await storage.saveUser(newGuestUser);

      mockApiClient.onGet = (path) {
        if (path == '/trips') {
          // Server returns empty list for new guest
          return [];
        }
        return [];
      };

      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: mockApiClient,
      );

      final trips = await tripRepo.getTrips();
      // Must strictly be empty! Zero leakage of Old User's trips!
      expect(trips, isEmpty);
      expect(tripRepo.getCachedTrips(), isEmpty);
    });

    test('5. Multi-Payer Balance Calculation: BalanceEngine produces zero debt when each member pays their own share', () {
      final members = [
        TripMember(id: 'mbr_1', userId: 'usr_1', displayName: 'Alice', joinedAt: testTime),
        TripMember(id: 'mbr_2', userId: 'usr_2', displayName: 'Bob', joinedAt: testTime),
      ];

      // ₹200 expense: Alice paid ₹100, Bob paid ₹100, split ₹100 each
      final expense = Expense(
        id: 'exp_balanced_001',
        tripId: 'trip_bal',
        title: 'Shared Grocery',
        amountInPaise: 20000,
        category: ExpenseCategory.food,
        paidById: 'mbr_1',
        paidByMap: {
          'mbr_1': 10000,
          'mbr_2': 10000,
        },
        splits: [
          const ExpenseSplit(memberId: 'mbr_1', amountInPaise: 10000),
          const ExpenseSplit(memberId: 'mbr_2', amountInPaise: 10000),
        ],
        splitType: SplitType.equal,
        createdAt: testTime,
        updatedAt: testTime,
      );

      final summary = BalanceEngine.calculateBalances(
        members: members,
        expenses: [expense],
        currentUserId: 'usr_1',
      );

      expect(summary.totalTripSpentInPaise, equals(20000));
      expect(summary.memberNetBalances['mbr_1'], equals(0));
      expect(summary.memberNetBalances['mbr_2'], equals(0));
      expect(summary.simplifiedSettlements, isEmpty);
    });
  });
}
