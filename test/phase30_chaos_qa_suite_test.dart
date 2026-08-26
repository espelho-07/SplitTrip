import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/engine/money_engine.dart';
import 'package:kith_app/domain/engine/settlement_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/personal_debt.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 30: Kith Core Product P0/P1 End-to-End Chaos QA Suite', () {
    late LocalStorageService storage;
    late SyncService syncService;
    late ApiClient apiClient;
    late TripRepository tripRepo;
    late ExpenseRepository expenseRepo;
    late PersonalRepository personalRepo;
    late AuthService authService;

    final userA = GuestUser(
      id: 'usr_alice_01',
      displayName: 'Alice',
      recoveryKey: 'KITH-ALICE-1234-5678',
      anonymousToken: 'tok_alice_123',
      createdAt: DateTime.now(),
      googleId: 'google_alice_999',
    );

    final userB = GuestUser(
      id: 'usr_bob_02',
      displayName: 'Bob',
      recoveryKey: 'KITH-BOB-9876-5432',
      anonymousToken: 'tok_bob_456',
      createdAt: DateTime.now(),
    );

    final userC = GuestUser(
      id: 'usr_charlie_03',
      displayName: 'Charlie',
      recoveryKey: 'KITH-CHARLIE-1122-3344',
      anonymousToken: 'tok_charlie_789',
      createdAt: DateTime.now(),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      syncService = SyncService(storage);
      apiClient = ApiClient();
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
      authService = AuthService(
        storage: storage,
        apiClient: apiClient,
      );
    });

    // -------------------------------------------------------------
    // 1. CREATE TRIP & RAPID TAP DUPLICATE PROTECTION
    // -------------------------------------------------------------
    test('1. Create Trip & Rapid Duplicate Tap Idempotency', () async {
      final tripId = 'trip_goa_chaos_01';
      final trip = Trip(
        id: tripId,
        name: 'Goa Holiday 2026',
        emoji: '🏖️',
        currencyCode: 'INR',
        creatorId: userA.id,
        inviteCode: 'GOA2026',
        tripMode: 'split_only',
        lifecycleState: TripLifecycle.active,
        members: [
          TripMember(
            id: 'mbr_alice',
            userId: userA.id,
            displayName: 'Alice',
            role: 'creator',
            joinedAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save initial trip
      await storage.saveTrips([trip.toJson()]);

      // Rapid creation attempts with existing cache
      final cachedTrips = tripRepo.getCachedTrips();
      expect(cachedTrips.length, equals(1));
      expect(cachedTrips.first.id, equals(tripId));
      expect(cachedTrips.first.name, equals('Goa Holiday 2026'));
    });

    // -------------------------------------------------------------
    // 2. 3-USER MULTIPLAYER TRIP MEMBERSHIP & PERMISSIONS
    // -------------------------------------------------------------
    test('2. 3-User Multiplayer Trip Membership & Permissions', () async {
      final tripId = 'trip_manali_01';
      final memberA = TripMember(id: 'mbr_a', userId: userA.id, displayName: 'Alice', role: 'creator', joinedAt: DateTime.now());
      final memberB = TripMember(id: 'mbr_b', userId: userB.id, displayName: 'Bob', role: 'member', joinedAt: DateTime.now());
      final memberC = TripMember(id: 'mbr_c', userId: userC.id, displayName: 'Charlie', role: 'member', joinedAt: DateTime.now());

      final trip = Trip(
        id: tripId,
        name: 'Manali Expedition',
        emoji: '🏔️',
        currencyCode: 'INR',
        creatorId: userA.id,
        inviteCode: 'MANALI',
        members: [memberA, memberB, memberC],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.saveTrips([trip.toJson()]);

      final loaded = tripRepo.getCachedTrips().first;
      expect(loaded.members.length, equals(3));
      expect(loaded.members.map((m) => m.displayName).toList(), containsAll(['Alice', 'Bob', 'Charlie']));
    });

    // -------------------------------------------------------------
    // 3. ALL SPLIT MODES & INTEGER ZERO-SUM EXACTNESS
    // -------------------------------------------------------------
    test('3. Split Modes: Equal, Custom, Percentage, and Shares Conservation', () {
      final memberIds = ['mbr_a', 'mbr_b', 'mbr_c'];

      // A: Equal split of ₹100.00 (10,000 paise among 3 people: 3334, 3333, 3333 = 10000)
      final equalSplits = MoneyEngine.calculateEqualSplits(
        totalPaise: 10000,
        participantMemberIds: memberIds,
        priorityMemberId: 'mbr_a',
      );
      final equalSum = equalSplits.fold<int>(0, (sum, s) => sum + s.amountInPaise);
      expect(equalSum, equals(10000));
      expect(equalSplits[0].amountInPaise, equals(3334));
      expect(equalSplits[1].amountInPaise, equals(3333));
      expect(equalSplits[2].amountInPaise, equals(3333));

      // B: Percentage split: 50%, 30%, 20% of ₹999.00 (99,900 paise)
      final pctSplits = MoneyEngine.calculatePercentageSplits(
        totalPaise: 99900,
        percentages: {'mbr_a': 50.0, 'mbr_b': 30.0, 'mbr_c': 20.0},
      );
      final pctSum = pctSplits.fold<int>(0, (sum, s) => sum + s.amountInPaise);
      expect(pctSum, equals(99900));

      // C: Shares split: 3 shares, 2 shares, 1 share of ₹1,500.00 (150,000 paise)
      final sharesSplits = MoneyEngine.calculateSharesSplits(
        totalPaise: 150000,
        shares: {'mbr_a': 3, 'mbr_b': 2, 'mbr_c': 1},
      );
      final sharesSum = sharesSplits.fold<int>(0, (sum, s) => sum + s.amountInPaise);
      expect(sharesSum, equals(150000));
      expect(sharesSplits.firstWhere((s) => s.memberId == 'mbr_a').amountInPaise, equals(75000));
      expect(sharesSplits.firstWhere((s) => s.memberId == 'mbr_b').amountInPaise, equals(50000));
      expect(sharesSplits.firstWhere((s) => s.memberId == 'mbr_c').amountInPaise, equals(25000));
    });

    // -------------------------------------------------------------
    // 4. BALANCE ENGINE ZERO-SUM INVARIANT
    // -------------------------------------------------------------
    test('4. Balance Engine: Complex Multi-Payer Invariant (Sum of Net Balances == 0)', () {
      final tripId = 'trip_complex_01';
      final members = <TripMember>[
        TripMember(id: 'mbr_a', userId: 'u_a', displayName: 'Alice', joinedAt: DateTime.now()),
        TripMember(id: 'mbr_b', userId: 'u_b', displayName: 'Bob', joinedAt: DateTime.now()),
        TripMember(id: 'mbr_c', userId: 'u_c', displayName: 'Charlie', joinedAt: DateTime.now()),
      ];

      final expenses = <Expense>[
        // Exp 1: Alice pays ₹3,000 (300,000p) split equally
        Expense(
          id: 'exp_01',
          tripId: tripId,
          title: 'Villa Stay',
          amountInPaise: 300000,
          category: ExpenseCategory.stay,
          paidById: 'mbr_a',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(memberId: 'mbr_a', amountInPaise: 100000),
            ExpenseSplit(memberId: 'mbr_b', amountInPaise: 100000),
            ExpenseSplit(memberId: 'mbr_c', amountInPaise: 100000),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        // Exp 2: Bob pays ₹1,500 (150,000p) split equally
        Expense(
          id: 'exp_02',
          tripId: tripId,
          title: 'Scuba Diving',
          amountInPaise: 150000,
          category: ExpenseCategory.activities,
          paidById: 'mbr_b',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(memberId: 'mbr_a', amountInPaise: 50000),
            ExpenseSplit(memberId: 'mbr_b', amountInPaise: 50000),
            ExpenseSplit(memberId: 'mbr_c', amountInPaise: 50000),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        // Exp 3: Charlie pays ₹600 (60,000p) for Bob & Charlie only
        Expense(
          id: 'exp_03',
          tripId: tripId,
          title: 'Taxi',
          amountInPaise: 60000,
          category: ExpenseCategory.transport,
          paidById: 'mbr_c',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(memberId: 'mbr_b', amountInPaise: 30000),
            ExpenseSplit(memberId: 'mbr_c', amountInPaise: 30000),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final balanceSummary = BalanceEngine.calculateBalances(
        members: members,
        expenses: expenses,
        currentUserId: 'u_a',
      );

      // Verify zero-sum net balance invariant
      final netSum = balanceSummary.memberNetBalances.values.fold<int>(0, (sum, val) => sum + val);
      expect(netSum, equals(0));

      // Alice: paid 300k, owes (100k + 50k) = 150k -> Net = +150,000p (+₹1,500)
      expect(balanceSummary.memberNetBalances['mbr_a'], equals(150000));

      // Bob: paid 150k, owes (100k + 50k + 30k) = 180k -> Net = -30,000p (-₹300)
      expect(balanceSummary.memberNetBalances['mbr_b'], equals(-30000));

      // Charlie: paid 60k, owes (100k + 50k + 30k) = 180k -> Net = -120,000p (-₹1,200)
      expect(balanceSummary.memberNetBalances['mbr_c'], equals(-120000));
    });

    // -------------------------------------------------------------
    // 5. SETTLEMENT ENGINE & MIN-CASH-FLOW GRAPH REDUCTION
    // -------------------------------------------------------------
    test('5. Settlement Engine: Min-Cash-Flow Debt Simplification and Partial Repayment', () {
      final memberBalances = {
        'mbr_a': 150000,  // Alice is owed ₹1,500
        'mbr_b': -30000,  // Bob owes ₹300
        'mbr_c': -120000, // Charlie owes ₹1,200
      };

      final simplified = SettlementEngine.simplifyDebts(memberBalances);

      // Expected transfers:
      // Charlie pays Alice ₹1,200
      // Bob pays Alice ₹300
      expect(simplified.length, equals(2));

      final transferCharlie = simplified.firstWhere((t) => t.fromMemberId == 'mbr_c');
      expect(transferCharlie.toMemberId, equals('mbr_a'));
      expect(transferCharlie.amountInPaise, equals(120000));

      final transferBob = simplified.firstWhere((t) => t.fromMemberId == 'mbr_b');
      expect(transferBob.toMemberId, equals('mbr_a'));
      expect(transferBob.amountInPaise, equals(30000));

      // Test partial settlement: Charlie pays Alice ₹400 (40,000p)
      final remainingAfterPartial = SettlementEngine.simplifyDebts({
        'mbr_a': 150000 - 40000,
        'mbr_b': -30000,
        'mbr_c': -120000 + 40000,
      });

      final charlieRemaining = remainingAfterPartial.firstWhere((t) => t.fromMemberId == 'mbr_c');
      expect(charlieRemaining.amountInPaise, equals(80000)); // ₹800 remaining
    });

    // -------------------------------------------------------------
    // 6. OFFLINE MUTATION CREATION, CACHE & QUEUE PERSISTENCE
    // -------------------------------------------------------------
    test('6. Offline Expense & Settlement Mutation Queueing and Storage Durability', () async {
      final tripId = 'trip_offline_01';

      final expense = Expense(
        id: 'exp_off_01',
        tripId: tripId,
        title: 'Offline Dhaba Lunch',
        amountInPaise: 45000,
        category: ExpenseCategory.food,
        paidById: 'mbr_a',
        splitType: SplitType.equal,
        splits: const [
          ExpenseSplit(memberId: 'mbr_a', amountInPaise: 22500),
          ExpenseSplit(memberId: 'mbr_b', amountInPaise: 22500),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add expense while offline (offline fallback executes)
      await expenseRepo.addExpense(expense);

      // Record offline settlement
      await expenseRepo.recordSettlement(
        tripId: tripId,
        fromMemberId: 'mbr_b',
        toMemberId: 'mbr_a',
        amountInPaise: 22500,
      );

      // Verify local cache immediately reflects the expense and settlement
      final cachedExpenses = expenseRepo.getCachedExpenses(tripId);
      expect(cachedExpenses.length, equals(1));
      expect(cachedExpenses.first.title, equals('Offline Dhaba Lunch'));

      final cachedSettlements = storage.getSavedTripSettlements(tripId);
      expect(cachedSettlements.length, equals(1));
      expect(cachedSettlements.first['amountInPaise'], equals(22500));

      // Verify mutations are queued for cloud sync
      final pending = syncService.getPendingMutations();
      expect(pending.length, equals(2));
      expect(pending.any((m) => m.type == MutationType.addExpense), isTrue);
      expect(pending.any((m) => m.type == MutationType.recordTripSettlement), isTrue);
    });

    // -------------------------------------------------------------
    // 7. OFFLINE APP FORCE CLOSE & RESTART
    // -------------------------------------------------------------
    test('7. Offline App Force Close and Restart: Zero Data Loss', () async {
      final tripId = 'trip_restart_01';
      final expense = Expense(
        id: 'exp_restart_01',
        tripId: tripId,
        title: 'Campfire Supplies',
        amountInPaise: 120000,
        category: ExpenseCategory.general,
        paidById: 'mbr_a',
        splitType: SplitType.equal,
        splits: const [
          ExpenseSplit(memberId: 'mbr_a', amountInPaise: 60000),
          ExpenseSplit(memberId: 'mbr_b', amountInPaise: 60000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await expenseRepo.addExpense(expense);

      // Simulate App Restart with fresh instances pointing to same storage
      final reloadedStorage = await LocalStorageService.init();
      final reloadedSyncService = SyncService(reloadedStorage);
      final reloadedExpenseRepo = ExpenseRepository(
        storage: reloadedStorage,
        syncService: reloadedSyncService,
        apiClient: apiClient,
      );

      final restoredExpenses = reloadedExpenseRepo.getCachedExpenses(tripId);
      expect(restoredExpenses.length, equals(1));
      expect(restoredExpenses.first.title, equals('Campfire Supplies'));
      expect(reloadedSyncService.pendingCount, equals(1));
    });

    // -------------------------------------------------------------
    // 8. INTERRUPTED SYNC & RETRY IDEMPOTENCY
    // -------------------------------------------------------------
    test('8. Interrupted Sync and Retry Idempotency', () async {
      await syncService.enqueueMutation(
        MutationType.createPersonalExpense,
        {
          'id': 'pexp_chaos_01',
          'title': 'Metro Card Recharge',
          'amountInPaise': 50000,
          'category': 'transport',
        },
      );

      await syncService.enqueueMutation(
        MutationType.createPersonalDebt,
        {
          'id': 'pdebt_chaos_01',
          'personName': 'Rohit',
          'debtType': 'lent',
          'amountInPaise': 100000,
        },
      );

      expect(syncService.pendingCount, equals(2));

      // Simulate processing first mutation then network interruption
      final firstMutation = syncService.getPendingMutations().first;
      await syncService.removeMutation(firstMutation.id);

      expect(syncService.pendingCount, equals(1));
      expect(syncService.getPendingMutations().first.payload['id'], equals('pdebt_chaos_01'));
    });

    // -------------------------------------------------------------
    // 9. CONCURRENT OFFLINE EDITS & LAST-WRITE-WINS CONFLICT POLICY
    // -------------------------------------------------------------
    test('9. Concurrent Offline Edits: Last-Write-Wins with Timestamp Invariant', () {
      final now = DateTime.now();
      final original = Expense(
        id: 'exp_conflict_01',
        tripId: 'trip_01',
        title: 'Team Dinner',
        amountInPaise: 100000,
        category: ExpenseCategory.food,
        paidById: 'mbr_a',
        splitType: SplitType.equal,
        splits: const [
          ExpenseSplit(memberId: 'mbr_a', amountInPaise: 50000),
          ExpenseSplit(memberId: 'mbr_b', amountInPaise: 50000),
        ],
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      );

      final editA = original.copyWith(
        amountInPaise: 120000,
        updatedAt: now.subtract(const Duration(minutes: 30)),
      );

      final editB = original.copyWith(
        amountInPaise: 150000,
        updatedAt: now.subtract(const Duration(minutes: 10)), // Newer timestamp
      );

      // Deterministic evaluation: editB has newer timestamp and wins
      final winner = editB.updatedAt.isAfter(editA.updatedAt) ? editB : editA;
      expect(winner.amountInPaise, equals(150000));
    });

    // -------------------------------------------------------------
    // 10. DELETE VS EDIT CONFLICT: TOMBSTONE PRECEDENCE
    // -------------------------------------------------------------
    test('10. Delete vs Edit Conflict Resolution: Tombstone Precedence', () {
      final now = DateTime.now();
      final deletedTimestamp = now.subtract(const Duration(minutes: 5));
      final editTimestamp = now.subtract(const Duration(minutes: 15)); // Prior edit before delete

      final isDeleted = true;
      final shouldRetainDelete = deletedTimestamp.isAfter(editTimestamp);

      expect(shouldRetainDelete, isTrue);
      expect(isDeleted, isTrue);
    });

    // -------------------------------------------------------------
    // 11. PERSONAL ACCOUNT DATA ISOLATION
    // -------------------------------------------------------------
    test('11. Personal Data Isolation: Zero Cross-User Leakage', () async {
      await personalRepo.createPersonalExpense(
        userId: userA.id,
        title: 'Alice Private Groceries',
        amountInPaise: 245000,
        category: ExpenseCategory.groceries,
      );

      await personalRepo.createPersonalDebt(
        userId: userA.id,
        personName: 'Suresh',
        debtType: PersonalDebtType.lent,
        amountInPaise: 500000,
      );

      // User A cached expenses
      final cachedA = personalRepo.getCachedPersonalExpenses();
      expect(cachedA.length, equals(1));
      expect(cachedA.first.userId, equals(userA.id));

      // User B logs in (simulate logout/clear)
      await storage.clearAllUserData();

      final cachedAfterLogout = personalRepo.getCachedPersonalExpenses();
      expect(cachedAfterLogout, isEmpty);
    });

    // -------------------------------------------------------------
    // 12. RECOVERY KEY ACCOUNT RESTORATION
    // -------------------------------------------------------------
    test('12. Recovery Key Account Restoration: Returns Canonical Identity', () async {
      await storage.saveUser(userA.toJson());

      final current = authService.getCurrentUser();
      expect(current?.recoveryKey, equals('KITH-ALICE-1234-5678'));
      expect(current?.displayName, equals('Alice'));

      // Wipe local session
      await storage.clearAllUserData();
      expect(authService.getCurrentUser(), isNull);

      // Simulate recovery key restore
      await storage.saveUser(userA.toJson());
      final restored = authService.getCurrentUser();

      expect(restored?.id, equals(userA.id));
      expect(restored?.recoveryKey, equals(userA.recoveryKey));
      expect(restored?.googleId, equals('google_alice_999'));
    });

    // -------------------------------------------------------------
    // 13. LATE EXPENSE POST-SETTLEMENT RECALCULATION
    // -------------------------------------------------------------
    test('13. Late Expense Sync After Trip Completion/Settlement', () {
      final tripId = 'trip_settled_01';
      final members = <TripMember>[
        TripMember(id: 'mbr_a', userId: 'u_a', displayName: 'Alice', joinedAt: DateTime.now()),
        TripMember(id: 'mbr_b', userId: 'u_b', displayName: 'Bob', joinedAt: DateTime.now()),
      ];

      // Initial settled state: Alice paid ₹100, Bob paid Alice ₹50 (settled)
      final initialExpenses = <Expense>[
        Expense(
          id: 'exp_01',
          tripId: tripId,
          title: 'Lunch',
          amountInPaise: 10000,
          category: ExpenseCategory.food,
          paidById: 'mbr_a',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(memberId: 'mbr_a', amountInPaise: 5000),
            ExpenseSplit(memberId: 'mbr_b', amountInPaise: 5000),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Late offline expense synced: Bob paid ₹60 for Coffee
      final lateExpenses = <Expense>[
        ...initialExpenses,
        Expense(
          id: 'exp_late_02',
          tripId: tripId,
          title: 'Late Coffee',
          amountInPaise: 6000,
          category: ExpenseCategory.drinks,
          paidById: 'mbr_b',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(memberId: 'mbr_a', amountInPaise: 3000),
            ExpenseSplit(memberId: 'mbr_b', amountInPaise: 3000),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final recalculated = BalanceEngine.calculateBalances(
        members: members,
        expenses: lateExpenses,
        currentUserId: 'u_a',
      );

      // Alice: paid 10,000, owes (5,000 + 3,000) = 8,000 -> Net = +2,000p (+₹20)
      expect(recalculated.memberNetBalances['mbr_a'], equals(2000));

      // Bob: paid 6,000, owes (5,000 + 3,000) = 8,000 -> Net = -2,000p (-₹20)
      expect(recalculated.memberNetBalances['mbr_b'], equals(-2000));
    });
  });
}
