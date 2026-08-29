import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late ExpenseRepository expenseRepo;

  final memberA = TripMember(
    id: 'mem_a',
    userId: 'user_a',
    displayName: 'Aarav',
    joinedAt: DateTime.now(),
  );

  final memberB = TripMember(
    id: 'mem_b',
    userId: 'user_b',
    displayName: 'Bhavna',
    joinedAt: DateTime.now(),
  );

  final testTrip = Trip(
    id: 'trip_settle_test',
    name: 'Goa Weekend',
    emoji: '🌴',
    creatorId: 'user_a',
    inviteCode: 'GOA123',
    members: [memberA, memberB],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    syncService = SyncService(storage);
    apiClient = ApiClient();
    expenseRepo = ExpenseRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
  });

  group('Settlement "Mark as Paid" Real-Time Clearing Tests', () {
    test('1. BalanceEngine nets out debts to 0 immediately when a paid settlement is supplied', () {
      // Expense: Aarav pays ₹1,000 split equally (₹500 each)
      final expense1 = Expense(
        id: 'exp_1',
        tripId: testTrip.id,
        paidById: memberA.id,
        amountInPaise: 100000,
        title: 'Dinner',
        category: ExpenseCategory.food,
        splits: [
          const ExpenseSplit(memberId: 'mem_a', amountInPaise: 50000),
          const ExpenseSplit(memberId: 'mem_b', amountInPaise: 50000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Before settlement: Bhavna owes Aarav ₹500
      final summaryBefore = BalanceEngine.calculateBalances(
        members: testTrip.members,
        expenses: [expense1],
        currentUserId: 'user_b',
      );

      expect(summaryBefore.currentUserNetBalanceInPaise, -50000);
      expect(summaryBefore.simplifiedSettlements.length, 1);
      expect(summaryBefore.simplifiedSettlements.first.fromMemberId, 'mem_b');
      expect(summaryBefore.simplifiedSettlements.first.toMemberId, 'mem_a');
      expect(summaryBefore.simplifiedSettlements.first.amountInPaise, 50000);
      expect(summaryBefore.debtsToPay.length, 1);

      // Bhavna marks as paid / settles ₹500
      final settlement = {
        'id': 'stl_1',
        'tripId': testTrip.id,
        'fromMemberId': 'mem_b',
        'toMemberId': 'mem_a',
        'amountInPaise': 50000,
        'status': 'paid',
        'isSettled': true,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // After settlement: Both net balances become 0, debts are completely cleared in 1 shot
      final summaryAfter = BalanceEngine.calculateBalances(
        members: testTrip.members,
        expenses: [expense1],
        settlements: [settlement],
        currentUserId: 'user_b',
      );

      expect(summaryAfter.currentUserNetBalanceInPaise, 0);
      expect(summaryAfter.simplifiedSettlements, isEmpty);
      expect(summaryAfter.debtsToPay, isEmpty);
      expect(summaryAfter.debtsToReceive, isEmpty);
    });

    test('2. Partial settlement reduces remaining debt accurately', () {
      // Aarav pays ₹1,000 for both (₹500 each)
      final expense1 = Expense(
        id: 'exp_2',
        tripId: testTrip.id,
        paidById: memberA.id,
        amountInPaise: 100000,
        title: 'Cab',
        category: ExpenseCategory.transport,
        splits: [
          const ExpenseSplit(memberId: 'mem_a', amountInPaise: 50000),
          const ExpenseSplit(memberId: 'mem_b', amountInPaise: 50000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Bhavna pays partial ₹200
      final partialSettlement = {
        'id': 'stl_partial',
        'tripId': testTrip.id,
        'fromMemberId': 'mem_b',
        'toMemberId': 'mem_a',
        'amountInPaise': 20000,
        'status': 'paid',
        'isSettled': true,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final summary = BalanceEngine.calculateBalances(
        members: testTrip.members,
        expenses: [expense1],
        settlements: [partialSettlement],
        currentUserId: 'user_b',
      );

      expect(summary.currentUserNetBalanceInPaise, -30000); // Only ₹300 remaining
      expect(summary.simplifiedSettlements.length, 1);
      expect(summary.simplifiedSettlements.first.amountInPaise, 30000);
      expect(summary.debtsToPay.first.amountInPaise, 30000);
    });

    test('3. ExpenseRepository.recordSettlement persists and getBalanceSummary reflects cleared state', () async {
      final expense1 = Expense(
        id: 'exp_3',
        tripId: testTrip.id,
        paidById: memberA.id,
        amountInPaise: 200000,
        title: 'Hotel',
        category: ExpenseCategory.stay,
        splits: [
          const ExpenseSplit(memberId: 'mem_a', amountInPaise: 100000),
          const ExpenseSplit(memberId: 'mem_b', amountInPaise: 100000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.saveExpenses(testTrip.id, [expense1.toJson()]);

      // Verify before
      final before = await expenseRepo.getBalanceSummary(trip: testTrip, currentUserId: 'user_b');
      expect(before.simplifiedSettlements.length, 1);
      expect(before.simplifiedSettlements.first.amountInPaise, 100000);

      // Record Settlement
      await expenseRepo.recordSettlement(
        tripId: testTrip.id,
        fromMemberId: 'mem_b',
        toMemberId: 'mem_a',
        amountInPaise: 100000,
        fromName: 'Bhavna',
        toName: 'Aarav',
        paymentStatus: 'paid',
      );

      // Verify after
      final after = await expenseRepo.getBalanceSummary(trip: testTrip, currentUserId: 'user_b');
      expect(after.simplifiedSettlements, isEmpty);
      expect(after.currentUserNetBalanceInPaise, 0);
    });
  });
}
