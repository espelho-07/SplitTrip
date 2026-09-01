import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSyncHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  MockSyncHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final res = await handler(req);
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
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

  group('P0 Critical Sync Invariant & Reconciliation Tests', () {
    test('1. Offline Deleted Expense is NEVER Resurrected by Stale Server Response', () async {
      const tripId = 'trip_goa_101';
      final exp1 = Expense(
        id: 'exp_hotel_1',
        tripId: tripId,
        title: 'Hotel',
        amountInPaise: 500000,
        category: ExpenseCategory.stay,
        paidById: 'usr_alice',
        splits: [ExpenseSplit(memberId: 'usr_alice', amountInPaise: 500000)],
        createdAt: DateTime(2026, 8, 30, 10, 0),
        updatedAt: DateTime(2026, 8, 30, 10, 0),
      );
      final exp2 = Expense(
        id: 'exp_dinner_2',
        tripId: tripId,
        title: 'Dinner',
        amountInPaise: 120000,
        category: ExpenseCategory.food,
        paidById: 'usr_alice',
        splits: [ExpenseSplit(memberId: 'usr_alice', amountInPaise: 120000)],
        createdAt: DateTime(2026, 8, 30, 12, 0),
        updatedAt: DateTime(2026, 8, 30, 12, 0),
      );

      // Pre-populate local cache with both expenses
      await storage.saveExpenses(tripId, [exp1.toJson(), exp2.toJson()]);

      // User deletes exp1 locally while offline
      final mockClient = MockSyncHttpClient((req) async {
        if (req.url.path.endsWith('/expenses')) {
          // Server still has both expenses (hasn't received delete yet)
          return http.Response(jsonEncode([exp1.toJson(), exp2.toJson()]), 200);
        }
        return http.Response('{}', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final repo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );

      // Delete exp1
      await repo.deleteExpense(tripId: tripId, expenseId: 'exp_hotel_1');

      // Verify mutation is in pending outbox
      final pending = syncService.getPendingMutationsForTrip(tripId);
      expect(pending.length, equals(1));
      expect(pending.first.type, equals(MutationType.deleteExpense));

      // Now call getExpenses() which pulls from server
      final reconciledExpenses = await repo.getExpenses(tripId);

      // exp1 must NOT be resurrected
      expect(reconciledExpenses.any((e) => e.id == 'exp_hotel_1'), isFalse);
      expect(reconciledExpenses.length, equals(1));
      expect(reconciledExpenses.first.id, equals('exp_dinner_2'));
    });

    test('2. Offline Updated Expense is NEVER Overwritten by Stale Server Version', () async {
      const tripId = 'trip_goa_101';
      final originalExp = Expense(
        id: 'exp_scooter_1',
        tripId: tripId,
        title: 'Scooter Rental',
        amountInPaise: 80000,
        category: ExpenseCategory.transport,
        paidById: 'usr_alice',
        splits: [ExpenseSplit(memberId: 'usr_alice', amountInPaise: 80000)],
        createdAt: DateTime(2026, 8, 30, 10, 0),
        updatedAt: DateTime(2026, 8, 30, 10, 0),
      );

      await storage.saveExpenses(tripId, [originalExp.toJson()]);

      // Server still has the old ₹800 version
      final mockClient = MockSyncHttpClient((req) async {
        if (req.url.path.endsWith('/expenses')) {
          return http.Response(jsonEncode([originalExp.toJson()]), 200);
        }
        return http.Response('{}', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final repo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );

      // User edits amount to ₹1,000 offline
      final updatedExp = originalExp.copyWith(
        amountInPaise: 100000,
        splits: [ExpenseSplit(memberId: 'usr_alice', amountInPaise: 100000)],
        updatedAt: DateTime(2026, 8, 30, 15, 0),
      );
      await repo.updateExpense(updatedExp);

      // Pull from server
      final reconciledExpenses = await repo.getExpenses(tripId);

      // Must preserve the local edited ₹1,000 version
      expect(reconciledExpenses.length, equals(1));
      expect(reconciledExpenses.first.amountInPaise, equals(100000));
    });

    test('3. Server 500 / Network Failure NEVER Drops Pending Mutations from Queue', () async {
      const tripId = 'trip_goa_101';
      final exp = Expense(
        id: 'exp_fail_test',
        tripId: tripId,
        title: 'Snacks',
        amountInPaise: 30000,
        category: ExpenseCategory.food,
        paidById: 'usr_alice',
        splits: [ExpenseSplit(memberId: 'usr_alice', amountInPaise: 30000)],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Server returns 500 Internal Server Error
      final mockClient = MockSyncHttpClient((req) async {
        return http.Response(jsonEncode({'error': {'message': 'Database connection failed'}}), 500);
      });

      final apiClient = ApiClient(httpClient: mockClient);

      await syncService.enqueueMutation(
        MutationType.addExpense,
        exp.toJson(),
        idempotencyKey: 'exp_fail_test',
      );

      // Flush queue against failing server
      await syncService.flushQueue(apiClient, force: true);

      // Mutation MUST remain in queue with retry count incremented and error message saved
      final pending = syncService.getPendingMutations();
      expect(pending.length, equals(1));
      expect(pending.first.idempotencyKey, equals('exp_fail_test'));
      expect(pending.first.retryCount, equals(1));
      expect(pending.first.lastError, isNotNull);
    });

    test('4. Trip Balance Summary Strictly Derives from Canonical Local Expenses & Settlements', () async {
      const tripId = 'trip_goa_101';
      final now = DateTime.now();
      final memberAlice = TripMember(id: 'mbr_alice', userId: 'usr_alice', displayName: 'Alice', joinedAt: now);
      final memberBob = TripMember(id: 'mbr_bob', userId: 'usr_bob', displayName: 'Bob', joinedAt: now);

      final trip = Trip(
        id: tripId,
        name: 'Goa Weekend',
        creatorId: 'usr_alice',
        inviteCode: 'GOA26',
        members: [memberAlice, memberBob],
        createdAt: now,
        updatedAt: now,
      );

      // Alice paid ₹2,000 split equally: Alice ₹1,000, Bob ₹1,000
      final exp = Expense(
        id: 'exp_dinner_split',
        tripId: tripId,
        title: 'Seafood Feast',
        amountInPaise: 200000,
        category: ExpenseCategory.food,
        paidById: 'mbr_alice',
        splits: [
          ExpenseSplit(memberId: 'mbr_alice', amountInPaise: 100000),
          ExpenseSplit(memberId: 'mbr_bob', amountInPaise: 100000),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await storage.saveExpenses(tripId, [exp.toJson()]);

      final repo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: ApiClient(httpClient: MockSyncHttpClient((_) async => http.Response('{}', 200))),
      );

      final summary = await repo.getBalanceSummary(trip: trip, currentUserId: 'usr_alice');

      // Total trip spent must equal ₹2,000 (200000 paise)
      expect(summary.totalTripSpentInPaise, equals(200000));
      // Alice is owed ₹1,000 (100000 paise)
      expect(summary.currentUserNetBalanceInPaise, equals(100000));
      // Exactly 1 simplified settlement: Bob owes Alice ₹1,000
      expect(summary.simplifiedSettlements.length, equals(1));
      expect(summary.simplifiedSettlements.first.fromMemberId, equals('mbr_bob'));
      expect(summary.simplifiedSettlements.first.toMemberId, equals('mbr_alice'));
      expect(summary.simplifiedSettlements.first.amountInPaise, equals(100000));
    });
  });
}
