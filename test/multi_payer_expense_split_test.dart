import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/add_expense_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Payer Expense & Custom Split Suite', () {
    final now = DateTime(2026, 11, 9, 12, 0);
    final memberX = TripMember(id: 'mbr_x', userId: 'usr_x', displayName: 'X', joinedAt: now);
    final memberY = TripMember(id: 'mbr_y', userId: 'usr_y', displayName: 'Y', joinedAt: now);
    final memberZ = TripMember(id: 'mbr_z', userId: 'usr_z', displayName: 'Z', joinedAt: now);
    final List<TripMember> members = [memberX, memberY, memberZ];

    final trip3Members = Trip(
      id: 'trip_3mbrs',
      name: 'Goa Trip',
      creatorId: 'usr_x',
      inviteCode: 'GOA333',
      members: members,
      createdAt: now,
      updatedAt: now,
    );

    test('1. Expense serialization and deserialization with paidByMap', () {
      final expense = Expense(
        id: 'exp_multi_1',
        tripId: 'trip_100',
        title: 'Team Dinner',
        amountInPaise: 10000, // ₹100.00
        category: ExpenseCategory.food,
        paidById: 'mbr_x',
        paidByMap: {
          'mbr_x': 5000, // ₹50
          'mbr_y': 4000, // ₹40
          'mbr_z': 1000, // ₹10
        },
        splits: [
          const ExpenseSplit(memberId: 'mbr_x', amountInPaise: 3334),
          const ExpenseSplit(memberId: 'mbr_y', amountInPaise: 3333),
          const ExpenseSplit(memberId: 'mbr_z', amountInPaise: 3333),
        ],
        splitType: SplitType.equal,
        createdAt: now,
        updatedAt: now,
      );

      final json = expense.toJson();
      expect(json['paidByMap'], isNotNull);
      expect(json['paidByMap']['mbr_x'], 5000);
      expect(json['paidByMap']['mbr_y'], 4000);
      expect(json['paidByMap']['mbr_z'], 1000);

      final decoded = Expense.fromJson(json);
      expect(decoded.id, 'exp_multi_1');
      expect(decoded.amountInPaise, 10000);
      expect(decoded.paidByMap, isNotNull);
      expect(decoded.paidByMap!['mbr_x'], 5000);
      expect(decoded.paidByMap!['mbr_y'], 4000);
      expect(decoded.paidByMap!['mbr_z'], 1000);
    });

    test('2. BalanceEngine credits each payer proportionally in multi-payer expense', () {
      final expense = Expense(
        id: 'exp_multi_1',
        tripId: 'trip_100',
        title: 'Team Dinner',
        amountInPaise: 10000,
        category: ExpenseCategory.food,
        paidById: 'mbr_x',
        paidByMap: {
          'mbr_x': 5000,
          'mbr_y': 4000,
          'mbr_z': 1000,
        },
        splits: [
          const ExpenseSplit(memberId: 'mbr_x', amountInPaise: 3334),
          const ExpenseSplit(memberId: 'mbr_y', amountInPaise: 3333),
          const ExpenseSplit(memberId: 'mbr_z', amountInPaise: 3333),
        ],
        splitType: SplitType.equal,
        createdAt: now,
        updatedAt: now,
      );

      final summary = BalanceEngine.calculateBalances(
        members: members,
        expenses: [expense],
        currentUserId: 'usr_x',
      );

      expect(summary.totalTripSpentInPaise, 10000);
      final balanceMap = summary.memberNetBalances;
      expect(balanceMap['mbr_x'], 1666);
      expect(balanceMap['mbr_y'], 667);
      expect(balanceMap['mbr_z'], -2333);

      final settlements = summary.simplifiedSettlements;
      expect(settlements.isNotEmpty, true);
      for (final s in settlements) {
        expect(s.fromMemberId, 'mbr_z');
      }
      final totalSettled = settlements.fold(0, (sum, s) => sum + s.amountInPaise);
      expect(totalSettled, 2333);
    });

    test('3. Backwards compatibility: Single payer expense without paidByMap works identically', () {
      final expense = Expense(
        id: 'exp_single_1',
        tripId: 'trip_100',
        title: 'Coffee',
        amountInPaise: 3000,
        category: ExpenseCategory.drinks,
        paidById: 'mbr_x',
        paidByMap: null,
        splits: [
          const ExpenseSplit(memberId: 'mbr_x', amountInPaise: 1000),
          const ExpenseSplit(memberId: 'mbr_y', amountInPaise: 1000),
          const ExpenseSplit(memberId: 'mbr_z', amountInPaise: 1000),
        ],
        splitType: SplitType.equal,
        createdAt: now,
        updatedAt: now,
      );

      final summary = BalanceEngine.calculateBalances(
        members: members,
        expenses: [expense],
        currentUserId: 'usr_x',
      );

      expect(summary.totalTripSpentInPaise, 3000);
      expect(summary.memberNetBalances['mbr_x'], 2000);
      expect(summary.memberNetBalances['mbr_y'], -1000);
      expect(summary.memberNetBalances['mbr_z'], -1000);
    });

    test('4. AddExpenseViewModel multi-payer allocation: ₹200 expense split across 2 then 3 payers', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final syncService = SyncService(storage);
      final apiClient = ApiClient();
      final expenseRepo = ExpenseRepository(storage: storage, syncService: syncService, apiClient: apiClient);
      final addVm = AddExpenseViewModel(expenseRepo: expenseRepo);

      // Initialize with trip and amount ₹200 (20000 paise)
      addVm.init(trip: trip3Members, currentUserId: 'usr_x');
      addVm.setAmountInPaise(20000);
      expect(addVm.amountInPaise, 20000);
      expect(addVm.isMultiplePayers, false);
      expect(addVm.paidById, 'mbr_x');

      // 1. Toggle to Multiple Payers: single payer X automatically gets ₹200
      addVm.toggleMultiplePayers(true);
      expect(addVm.isMultiplePayers, true);
      expect(addVm.payerAmountsInPaise.length, 1);
      expect(addVm.payerAmountsInPaise['mbr_x'], 20000);
      expect(addVm.isPayerAllocationBalanced, true);

      // 2. Select 2nd member Y: both X and Y now selected, amounts split equally to ₹100 each!
      addVm.togglePayerSelection('mbr_y');
      expect(addVm.payerAmountsInPaise.containsKey('mbr_x'), true);
      expect(addVm.payerAmountsInPaise.containsKey('mbr_y'), true);
      expect(addVm.payerAmountsInPaise['mbr_x'], 10000); // ₹100
      expect(addVm.payerAmountsInPaise['mbr_y'], 10000); // ₹100
      expect(addVm.totalPayerAllocatedPaise, 20000);
      expect(addVm.isPayerAllocationBalanced, true);

      // 3. Custom allocation: X paid ₹140 (14000 paise), Y paid ₹60 (6000 paise)
      addVm.setPayerAmount('mbr_x', 14000);
      addVm.setPayerAmount('mbr_y', 6000);
      expect(addVm.totalPayerAllocatedPaise, 20000);
      expect(addVm.isPayerAllocationBalanced, true);

      // 4. Select 3rd member Z: all 3 selected, auto equal split = ₹66.67, ₹66.67, ₹66.66
      addVm.togglePayerSelection('mbr_z');
      expect(addVm.payerAmountsInPaise.length, 3);
      expect(addVm.payerAmountsInPaise['mbr_x'], 6667);
      expect(addVm.payerAmountsInPaise['mbr_y'], 6667);
      expect(addVm.payerAmountsInPaise['mbr_z'], 6666);
      expect(addVm.totalPayerAllocatedPaise, 20000);
      expect(addVm.isPayerAllocationBalanced, true);

      // 5. Unselect member X: remaining members Y and Z get ₹100 each (10000 paise)
      addVm.togglePayerSelection('mbr_x');
      expect(addVm.payerAmountsInPaise.containsKey('mbr_x'), false);
      expect(addVm.payerAmountsInPaise['mbr_y'], 10000);
      expect(addVm.payerAmountsInPaise['mbr_z'], 10000);
      expect(addVm.totalPayerAllocatedPaise, 20000);
      expect(addVm.isPayerAllocationBalanced, true);

      // 6. Cannot remove last remaining payer if only 1 left
      addVm.togglePayerSelection('mbr_y'); // leaves only Z
      expect(addVm.payerAmountsInPaise.length, 1);
      expect(addVm.payerAmountsInPaise['mbr_z'], 20000);
      addVm.togglePayerSelection('mbr_z'); // attempts to remove last payer
      expect(addVm.payerAmountsInPaise.length, 1); // remains 1

      // 7. Toggle back to Single Payer: sets primary payer to Z and clears map
      addVm.toggleMultiplePayers(false);
      expect(addVm.isMultiplePayers, false);
      expect(addVm.paidById, 'mbr_z');
      expect(addVm.payerAmountsInPaise.isEmpty, true);
    });

    test('5. Account Deletion & Data Isolation: clearAllUserData wipes SQLite, SharedPreferences and Repository caches', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final syncService = SyncService(storage);
      final apiClient = ApiClient();
      final tripRepo = TripRepository(storage: storage, syncService: syncService, apiClient: apiClient);
      final expenseRepo = ExpenseRepository(storage: storage, syncService: syncService, apiClient: apiClient);

      // Populate local trip and expense cache
      await storage.saveTrips([trip3Members.toJson()]);
      await storage.saveUser({'id': 'usr_x', 'displayName': 'X', 'recoveryKey': 'KITH-XXXX-YYYY'});
      await storage.saveUserToRecoveryVault({'id': 'usr_x', 'displayName': 'X', 'recoveryKey': 'KITH-XXXX-YYYY'});
      final initialTrips = tripRepo.getCachedTrips();
      expect(initialTrips.isNotEmpty, true);
      expect(initialTrips.first.id, 'trip_3mbrs');

      // Perform complete account data purge
      await storage.clearAllUserData();

      // Verify in-memory repository caches were purged via listeners
      expect(tripRepo.getCachedTrips().isEmpty, true);
      expect(expenseRepo.getCachedExpenses('trip_3mbrs').isEmpty, true);
      expect(storage.getSavedTrips().isEmpty, true);
      expect(storage.getSavedUser(), isNull);
      expect(storage.getUserByRecoveryKey('KITH-XXXX-YYYY'), isNull);
    });
  });
}
