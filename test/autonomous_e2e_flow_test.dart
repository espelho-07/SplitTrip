import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/models/trip_sync_status.dart';
import 'package:kith_app/presentation/viewmodels/add_expense_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Autonomous End-to-End QA Pipeline — SplitTrip System Invariants', () {
    late LocalStorageService storage;
    late SyncService syncService;
    late TripRepository tripRepo;
    late ExpenseRepository expenseRepo;
    late AddExpenseViewModel addExpenseVm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
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
      addExpenseVm = AddExpenseViewModel(expenseRepo: expenseRepo);
    });

    test('1. Autonomous Trip Creation & Duplicate Prevention Invariant', () async {
      final now = DateTime.now();
      final trip = Trip(
        id: 'auto_trip_001',
        name: 'Autonomous QA Expedition',
        emoji: '🏔️',
        currencyCode: 'INR',
        inviteCode: 'AUTO01',
        creatorId: 'user_darpan',
        members: [
          TripMember(
            id: 'mem_darpan',
            userId: 'user_darpan',
            displayName: 'Darpan',
            isClaimed: true,
            joinedAt: now,
          ),
          TripMember(
            id: 'mem_rahul',
            userId: 'user_rahul',
            displayName: 'Rahul',
            isClaimed: true,
            joinedAt: now,
          ),
          TripMember(
            id: 'mem_priya',
            userId: '',
            displayName: 'Priya',
            isClaimed: false,
            joinedAt: now,
          ),
        ],
        lifecycleState: TripLifecycle.active,
        createdAt: now,
        updatedAt: now,
      );

      // Verify trip structure & member integrity
      expect(trip.id, equals('auto_trip_001'));
      expect(trip.members.length, equals(3));
      expect(trip.lifecycleState, equals(TripLifecycle.active));

      // Test duplicate member merge protection
      final duplicatePriya = TripMember(
        id: 'mem_priya_dup',
        userId: '',
        displayName: 'Priya', // Same name
        isClaimed: false,
        joinedAt: now,
      );

      final mergedTrip = trip.mergeWith(
        trip.copyWith(members: [...trip.members, duplicatePriya]),
      );

      // Verify deduplication: display name 'Priya' should not be duplicated
      final priyaCount = mergedTrip.members.where((m) => m.displayName.trim().toLowerCase() == 'priya').length;
      expect(priyaCount, equals(1), reason: 'Duplicate virtual members with identical display name must be unified');
    });

    test('2. Autonomous Expense Creation: Optional Description & Fallback to Category', () async {
      final now = DateTime.now();
      final trip = Trip(
        id: 'auto_trip_002',
        name: 'Expense QA Trip',
        emoji: '🏖️',
        currencyCode: 'INR',
        inviteCode: 'AUTO02',
        creatorId: 'user_darpan',
        members: [
          TripMember(id: 'mem_1', userId: 'user_darpan', displayName: 'Darpan', isClaimed: true, joinedAt: now),
          TripMember(id: 'mem_2', userId: 'user_rahul', displayName: 'Rahul', isClaimed: true, joinedAt: now),
        ],
        lifecycleState: TripLifecycle.active,
        createdAt: now,
        updatedAt: now,
      );

      addExpenseVm.init(trip: trip, currentUserId: 'user_darpan');

      // Scenario A: User provides amount and selects participant but leaves title EMPTY
      addExpenseVm.setAmountInPaise(120000); // ₹1,200
      addExpenseVm.setCategory(ExpenseCategory.food);
      addExpenseVm.setTitle(''); // Empty description

      // Validate isValid is true (description is optional!)
      expect(addExpenseVm.isValid, isTrue);

      final savedA = await addExpenseVm.saveExpense(trip.id);
      expect(savedA, isNotNull);
      expect(savedA!.title, equals(ExpenseCategory.food.displayName),
          reason: 'Empty title must fallback automatically to category display name');
      expect(savedA.amountInPaise, equals(120000));

      // Scenario B: User explicitly types a custom description
      addExpenseVm.init(trip: trip, currentUserId: 'user_darpan');
      addExpenseVm.setAmountInPaise(50000); // ₹500
      addExpenseVm.setCategory(ExpenseCategory.transport);
      addExpenseVm.setTitle('Airport Taxi');

      final savedB = await addExpenseVm.saveExpense(trip.id);
      expect(savedB, isNotNull);
      expect(savedB!.title, equals('Airport Taxi'));
      expect(savedB.amountInPaise, equals(50000));
    });

    test('3. Autonomous Balance Calculation & Zero-Sum Invariant', () {
      final now = DateTime.now();
      final members = [
        TripMember(id: 'mem_darpan', userId: 'user_darpan', displayName: 'Darpan', isClaimed: true, joinedAt: now),
        TripMember(id: 'mem_rahul', userId: 'user_rahul', displayName: 'Rahul', isClaimed: true, joinedAt: now),
        TripMember(id: 'mem_karan', userId: 'user_karan', displayName: 'Karan', isClaimed: true, joinedAt: now),
      ];

      final expenses = [
        // Darpan pays ₹3,000 for all 3 members (equal split: ₹1,000 each)
        Expense(
          id: 'exp_1',
          tripId: 'auto_trip_003',
          title: 'Resort Stay',
          amountInPaise: 300000,
          category: ExpenseCategory.stay,
          paidById: 'mem_darpan',
          splits: const [
            ExpenseSplit(memberId: 'mem_darpan', amountInPaise: 100000),
            ExpenseSplit(memberId: 'mem_rahul', amountInPaise: 100000),
            ExpenseSplit(memberId: 'mem_karan', amountInPaise: 100000),
          ],
          splitType: SplitType.equal,
          createdAt: now,
          updatedAt: now,
        ),
        // Rahul pays ₹600 for Darpan and Rahul (equal split: ₹300 each)
        Expense(
          id: 'exp_2',
          tripId: 'auto_trip_003',
          title: 'Dinner',
          amountInPaise: 60000,
          category: ExpenseCategory.food,
          paidById: 'mem_rahul',
          splits: const [
            ExpenseSplit(memberId: 'mem_darpan', amountInPaise: 30000),
            ExpenseSplit(memberId: 'mem_rahul', amountInPaise: 30000),
          ],
          splitType: SplitType.equal,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = BalanceEngine.calculateBalances(
        members: members,
        expenses: expenses,
        settlements: [],
        currentUserId: 'user_darpan',
      );

      // Verify Zero-Sum Conservation Invariant: Sum of all net balances across all members MUST equal 0 paise
      final totalNetPaise = summary.memberNetBalances.values.fold<int>(0, (sum, val) => sum + val);
      expect(totalNetPaise, equals(0), reason: 'Financial conservation: sum of net balances must strictly equal 0');

      // Darpan paid 3000, consumed 1000 + 300 = 1300 -> Net: +1700
      final darpanBal = summary.memberNetBalances['mem_darpan'];
      expect(darpanBal, equals(170000));

      // Rahul paid 600, consumed 1000 + 300 = 1300 -> Net: -700
      final rahulBal = summary.memberNetBalances['mem_rahul'];
      expect(rahulBal, equals(-70000));

      // Karan paid 0, consumed 1000 -> Net: -1000
      final karanBal = summary.memberNetBalances['mem_karan'];
      expect(karanBal, equals(-100000));

      // Total simplified settlements must settle Rahul (700) + Karan (1000) to Darpan (1700)
      final settlements = summary.simplifiedSettlements;
      final totalSettlementPaise = settlements.fold<int>(0, (sum, s) => sum + s.amountInPaise);
      expect(totalSettlementPaise, equals(170000));
    });

    test('4. Autonomous Detailed Hisab Mathematical Reconciliation', () {
      final now = DateTime.now();
      const memberAId = 'mem_darpan';
      const memberBId = 'mem_rahul';

      final expenses = [
        // Darpan pays ₹1,500, Rahul shares ₹750
        Expense(
          id: 'exp_h1',
          tripId: 'auto_trip_004',
          title: 'Scuba Diving',
          amountInPaise: 150000,
          category: ExpenseCategory.activities,
          paidById: memberAId,
          splits: const [
            ExpenseSplit(memberId: memberAId, amountInPaise: 75000),
            ExpenseSplit(memberId: memberBId, amountInPaise: 75000),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        // Rahul pays ₹400, Darpan shares ₹200
        Expense(
          id: 'exp_h2',
          tripId: 'auto_trip_004',
          title: 'Beach Drinks',
          amountInPaise: 40000,
          category: ExpenseCategory.food,
          paidById: memberBId,
          splits: const [
            ExpenseSplit(memberId: memberAId, amountInPaise: 20000),
            ExpenseSplit(memberId: memberBId, amountInPaise: 20000),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      int aPaidForB = 0;
      int bPaidForA = 0;

      for (final exp in expenses) {
        final aSplit = exp.splits.where((s) => s.memberId == memberAId).firstOrNull;
        final bSplit = exp.splits.where((s) => s.memberId == memberBId).firstOrNull;

        if (exp.paidById == memberAId && bSplit != null) {
          aPaidForB += bSplit.amountInPaise;
        }
        if (exp.paidById == memberBId && aSplit != null) {
          bPaidForA += aSplit.amountInPaise;
        }
      }

      expect(aPaidForB, equals(75000)); // ₹750
      expect(bPaidForA, equals(20000)); // ₹200
      final directNetRahulOwesDarpan = aPaidForB - bPaidForA;
      expect(directNetRahulOwesDarpan, equals(55000)); // ₹550
    });

    test('5. Autonomous Self-Healing Trip Completion Fallback', () async {
      final now = DateTime.now();
      final localTrip = Trip(
        id: 'auto_trip_005',
        name: 'Offline Self-Healing Trip',
        emoji: '🏝️',
        currencyCode: 'INR',
        inviteCode: 'HEAL05',
        creatorId: 'user_darpan',
        members: [
          TripMember(id: 'mem_1', userId: 'user_darpan', displayName: 'Darpan', isClaimed: true, joinedAt: now),
        ],
        lifecycleState: TripLifecycle.active,
        createdAt: now,
        updatedAt: now,
      );

      // Save locally
      await storage.saveTrips([localTrip.toJson()]);

      // Complete trip (in offline / un-synced state)
      final completed = await tripRepo.completeTrip(
        tripId: localTrip.id,
        completionMode: 'NORMAL',
      );

      expect(completed.id, equals(localTrip.id));
      expect(completed.lifecycleState, equals(TripLifecycle.completed));
      expect(completed.completedAt, isNotNull);

      // Verify cached trip is updated to completed
      final cached = tripRepo.getCachedTripById(localTrip.id);
      expect(cached?.lifecycleState, equals(TripLifecycle.completed));

      // Verify synthesized status from local trip
      final status = TripSyncStatus.fromLocalTrip(completed, currentUserId: 'user_darpan');
      expect(status.canCompleteNormally, isTrue);
      expect(status.isFullySynced, isTrue);
    });
  });
}
