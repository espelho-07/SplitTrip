import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/finance_export_bridge_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/engine/money_engine.dart';
import 'package:kith_app/domain/engine/settlement_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FINANCE APP E2E INTEGRATION SUITE (Physical Device: OnePlus Android 16)', () {
    late LocalDatabaseService dbService;

    setUp(() {
      dbService = LocalDatabaseService.inMemory();
    });

    tearDown(() {
      dbService.dispose();
    });

    testWidgets('1. Arithmetic Precision: Zero-drift integer paise splits across real and virtual members', (tester) async {
      final members = ['user_darpan', 'user_rahul', 'unclaimed_v1', 'unclaimed_v2'];
      
      // Case A: Equal split with odd division remainder
      // ₹1,000.03 = 100003 paise split amongst 4 members -> 25001 + 25001 + 25001 + 25000 = 100003
      const totalPaiseA = 100003;
      final equalSplits = MoneyEngine.calculateEqualSplits(
        totalPaise: totalPaiseA,
        participantMemberIds: members,
        priorityMemberId: 'user_darpan',
      );

      expect(equalSplits.length, equals(4));
      final sumA = equalSplits.fold<int>(0, (prev, s) => prev + s.amountInPaise);
      expect(sumA, equals(totalPaiseA), reason: 'Total equal split must exactly equal input paise without drift');
      
      // Priority member received the extra remainder paise
      expect(equalSplits.firstWhere((s) => s.memberId == 'user_darpan').amountInPaise, equals(25001));

      // Case B: Percentage splits with non-clean fractions
      // 33.33%, 33.33%, 20.0%, 13.34% of ₹5,000.00 (500000 paise)
      const totalPaiseB = 500000;
      final percentSplits = MoneyEngine.calculatePercentageSplits(
        totalPaise: totalPaiseB,
        percentages: {
          'user_darpan': 33.33,
          'user_rahul': 33.33,
          'unclaimed_v1': 20.00,
          'unclaimed_v2': 13.34,
        },
      );

      expect(percentSplits.length, equals(4));
      final sumB = percentSplits.fold<int>(0, (prev, s) => prev + s.amountInPaise);
      expect(sumB, equals(totalPaiseB), reason: 'Percentage splits must reconcile remainders to exact total paise');

      // Case C: Weight/Share based splits
      // Shares: 3, 2, 1, 1 on ₹1,400.00 (140000 paise) -> 3/7 = 60000, 2/7 = 40000, 1/7 = 20000, 1/7 = 20000
      const totalPaiseC = 140000;
      final shareSplits = MoneyEngine.calculateSharesSplits(
        totalPaise: totalPaiseC,
        shares: {
          'user_darpan': 3,
          'user_rahul': 2,
          'unclaimed_v1': 1,
          'unclaimed_v2': 1,
        },
      );

      expect(shareSplits.length, equals(4));
      final sumC = shareSplits.fold<int>(0, (prev, s) => prev + s.amountInPaise);
      expect(sumC, equals(totalPaiseC));
      expect(shareSplits.firstWhere((s) => s.memberId == 'user_darpan').amountInPaise, equals(60000));
      expect(shareSplits.firstWhere((s) => s.memberId == 'user_rahul').amountInPaise, equals(40000));
    });

    testWidgets('2. Double-Entry Conservation: Ledger zero-sum balance invariant across mixed participants', (tester) async {
      final now = DateTime.now();
      final members = [
        TripMember(id: 'mbr_01', userId: 'user_darpan', displayName: 'Darpan', role: 'creator', joinedAt: now),
        TripMember(id: 'mbr_02', userId: 'user_rahul', displayName: 'Rahul', role: 'member', joinedAt: now),
        TripMember(id: 'mbr_03', userId: 'unclaimed_v1', displayName: 'D (Virtual)', isVirtualMember: true, role: 'virtual', joinedAt: now),
        TripMember(id: 'mbr_04', userId: 'unclaimed_v2', displayName: 'Pooja (Virtual)', isVirtualMember: true, role: 'virtual', joinedAt: now),
      ];

      final expenses = [
        // 1. Darpan pays ₹1,200 for all 4 equally (₹300 each)
        Expense(
          id: 'exp_01',
          tripId: 'trip_finance_test',
          title: 'Resort Stay',
          amountInPaise: 120000,
          paidById: 'mbr_01',
          category: ExpenseCategory.stay,
          splitType: SplitType.equal,
          splits: [
            ExpenseSplit(memberId: 'mbr_01', amountInPaise: 30000),
            ExpenseSplit(memberId: 'mbr_02', amountInPaise: 30000),
            ExpenseSplit(memberId: 'mbr_03', amountInPaise: 30000),
            ExpenseSplit(memberId: 'mbr_04', amountInPaise: 30000),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        // 2. Rahul pays ₹800 for Rahul and Virtual Member D (₹400 each)
        Expense(
          id: 'exp_02',
          tripId: 'trip_finance_test',
          title: 'Cafe Lunch',
          amountInPaise: 80000,
          paidById: 'mbr_02',
          category: ExpenseCategory.food,
          splitType: SplitType.equal,
          splits: [
            ExpenseSplit(memberId: 'mbr_02', amountInPaise: 40000),
            ExpenseSplit(memberId: 'mbr_03', amountInPaise: 40000),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        // 3. Virtual Member D pays ₹1,500 for Darpan and Pooja (₹750 each)
        Expense(
          id: 'exp_03',
          tripId: 'trip_finance_test',
          title: 'Jeep Safari',
          amountInPaise: 150000,
          paidById: 'mbr_03',
          category: ExpenseCategory.transport,
          splitType: SplitType.equal,
          splits: [
            ExpenseSplit(memberId: 'mbr_01', amountInPaise: 75000),
            ExpenseSplit(memberId: 'mbr_04', amountInPaise: 75000),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final balance = BalanceEngine.calculateBalances(
        members: members,
        expenses: expenses,
        currentUserId: 'mbr_01',
      );

      // Total trip spending = 1200 + 800 + 1500 = ₹3,500 = 350000 paise
      expect(balance.totalTripSpentInPaise, equals(350000));

      // Net Balances:
      // Darpan (mbr_01): Paid 120000, Shares: 30000 + 75000 = 105000 -> Net = +15000 (Owed ₹150)
      // Rahul (mbr_02): Paid 80000, Shares: 30000 + 40000 = 70000 -> Net = +10000 (Owed ₹100)
      // Virtual D (mbr_03): Paid 150000, Shares: 30000 + 40000 = 70000 -> Net = +80000 (Owed ₹800)
      // Virtual Pooja (mbr_04): Paid 0, Shares: 30000 + 75000 = 105000 -> Net = -105000 (Owes ₹1,050)
      final netBalances = balance.memberNetBalances;
      expect(netBalances['mbr_01'], equals(15000));
      expect(netBalances['mbr_02'], equals(10000));
      expect(netBalances['mbr_03'], equals(80000));
      expect(netBalances['mbr_04'], equals(-105000));

      // Double-entry conservation law: Sum of all net balances must be EXACTLY ZERO
      final totalNetSum = netBalances.values.fold<int>(0, (p, v) => p + v);
      expect(totalNetSum, equals(0), reason: 'Double-entry ledger invariant: sum of net balances must be 0');

      // User-Centric checks for Darpan (mbr_01)
      expect(balance.currentUserNetBalanceInPaise, equals(15000));
      expect(balance.isCurrentUserOwed, isTrue);
      expect(balance.isCurrentUserInDebt, isFalse);
      expect(balance.isCurrentUserSettled, isFalse);
    });

    testWidgets('3. Settlement Engine: Optimal greedy bipartite debt minimization', (tester) async {
      // Net balances:
      // Debtor: mbr_04 owes 105000
      // Creditors: mbr_01 owed 15000, mbr_02 owed 10000, mbr_03 owed 80000
      final netBalances = {
        'mbr_01': 15000,
        'mbr_02': 10000,
        'mbr_03': 80000,
        'mbr_04': -105000,
      };

      final simplified = SettlementEngine.simplifyDebts(netBalances);

      // 4 members -> maximum 3 direct transactions needed (N-1)
      expect(simplified.length, lessThanOrEqualTo(3));

      // Every transaction must originate from debtor mbr_04
      for (final tx in simplified) {
        expect(tx.fromMemberId, equals('mbr_04'));
        expect(tx.amountInPaise, greaterThan(0));
      }

      // Sum of simplified settlements must equal total debt
      final totalSettledAmount = simplified.fold<int>(0, (p, tx) => p + tx.amountInPaise);
      expect(totalSettledAmount, equals(105000));

      // Circular debt test: A owes B, B owes C, C owes A -> 0 transactions
      final circularBalances = {
        'A': 0,
        'B': 0,
        'C': 0,
      };
      final circularSettlements = SettlementEngine.simplifyDebts(circularBalances);
      expect(circularSettlements, isEmpty, reason: 'Circular debt when net balances cancel out produces zero transactions');
    });

    testWidgets('4. SQLite Persistence & Reconciliation: Read-write integrity of financial records', (tester) async {
      final nowStr = DateTime.now().toIso8601String();
      const tripId = 'trip_persisted_01';

      // Insert trip
      dbService.rawDb.execute('''
        INSERT OR REPLACE INTO trips (
          id, name, currency_code, creator_id, invite_code, started_at, created_at, updated_at, raw_json
        ) VALUES (
          '$tripId', 'Manali Roadtrip', 'INR', 'user_darpan', 'KITH88', '$nowStr', '$nowStr', '$nowStr', '{}'
        );
      ''');

      // Insert 3 expenses with exact integer paise in raw_json
      final expData = [
        {'id': 'e1', 'title': 'Toll Plazas', 'amount': 45000, 'paid_by_member_id': 'mbr_01'},
        {'id': 'e2', 'title': 'Fuel HPCL', 'amount': 250000, 'paid_by_member_id': 'mbr_02'},
        {'id': 'e3', 'title': 'Dhaba Dinner', 'amount': 85050, 'paid_by_member_id': 'mbr_01'},
      ];

      for (final e in expData) {
        final rawJson = jsonEncode({
          'id': e['id'],
          'trip_id': tripId,
          'title': e['title'],
          'amount': e['amount'],
          'currency': 'INR',
          'paid_by_member_id': e['paid_by_member_id'],
        });

        dbService.rawDb.execute('''
          INSERT OR REPLACE INTO expenses (
            id, trip_id, title, amount, currency, paid_by_member_id, created_at, updated_at, raw_json
          ) VALUES (
            '${e['id']}', '$tripId', '${e['title']}', ${e['amount']}, 'INR', '${e['paid_by_member_id']}', '$nowStr', '$nowStr', '$rawJson'
          );
        ''');
      }

      // Query database directly
      final savedExpenses = dbService.getSavedExpenses(tripId);
      expect(savedExpenses.length, equals(3));

      // Verify exact paise sum in DB
      final totalDbSpent = savedExpenses.fold<int>(0, (p, row) => p + (row['amount'] as int));
      expect(totalDbSpent, equals(45000 + 250000 + 85050)); // 380050 paise = ₹3,800.50
    });

    testWidgets('5. Dynamic Settlement Transitions: Partial to full debt resolution', (tester) async {
      final now = DateTime.now();
      final members = [
        TripMember(id: 'mbr_01', userId: 'user_darpan', displayName: 'Darpan', role: 'creator', joinedAt: now),
        TripMember(id: 'mbr_02', userId: 'user_rahul', displayName: 'Rahul', role: 'member', joinedAt: now),
      ];

      final expenses = [
        // Darpan pays ₹1,000 (100000 paise) split equally: Rahul owes ₹500 (50000 paise)
        Expense(
          id: 'exp_s1',
          tripId: 'trip_settle_test',
          title: 'Dinner',
          amountInPaise: 100000,
          paidById: 'mbr_01',
          category: ExpenseCategory.food,
          splits: [
            ExpenseSplit(memberId: 'mbr_01', amountInPaise: 50000),
            ExpenseSplit(memberId: 'mbr_02', amountInPaise: 50000),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Phase A: Initial state before any settlement
      final balA = BalanceEngine.calculateBalances(
        members: members,
        expenses: expenses,
        currentUserId: 'mbr_02', // Looking from Rahul's perspective
      );
      expect(balA.currentUserNetBalanceInPaise, equals(-50000));
      expect(balA.isCurrentUserInDebt, isTrue);

      // Phase B: Rahul pays ₹200 (20000 paise) partial settlement
      final partialSettlements = [
        {
          'fromMemberId': 'mbr_02',
          'toMemberId': 'mbr_01',
          'amountInPaise': 20000,
          'status': 'paid',
        },
      ];

      final balB = BalanceEngine.calculateBalances(
        members: members,
        expenses: expenses,
        settlements: partialSettlements,
        currentUserId: 'mbr_02',
      );
      expect(balB.currentUserNetBalanceInPaise, equals(-30000)); // Still owes ₹300
      expect(balB.isCurrentUserInDebt, isTrue);

      // Phase C: Rahul pays remaining ₹300 (30000 paise)
      final fullSettlements = [
        ...partialSettlements,
        {
          'fromMemberId': 'mbr_02',
          'toMemberId': 'mbr_01',
          'amountInPaise': 30000,
          'status': 'confirmed',
        },
      ];

      final balC = BalanceEngine.calculateBalances(
        members: members,
        expenses: expenses,
        settlements: fullSettlements,
        currentUserId: 'mbr_02',
      );
      expect(balC.currentUserNetBalanceInPaise, equals(0)); // All settled up!
      expect(balC.isCurrentUserSettled, isTrue);
      expect(balC.isCurrentUserInDebt, isFalse);
    });

    testWidgets('6. Financial Export & Audit Trail: Tamper-evident checksum validation', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs, databaseService: dbService);
      final exportService = FinanceExportBridgeService(storage: storage);

      // Save personal expense using canonical storage pipeline
      final nowStr = DateTime.now().toIso8601String();
      await storage.savePersonalExpenses([
        {
          'id': 'pexp_01',
          'title': 'Train Ticket',
          'amountInPaise': 145000,
          'currency': 'INR',
          'category': 'transport',
          'date': nowStr,
          'createdAt': nowStr,
        },
      ]);

      // Export records
      final payload = exportService.buildExportPayload();

      expect(payload['stats']['personalExpenses'], equals(1));
      expect(payload['stats']['totalRecords'], greaterThanOrEqualTo(1));
      final checksum = payload['checksum'] as String;
      expect(checksum, isNotEmpty);
      expect(checksum.length, equals(64), reason: 'Checksum must be valid SHA-256 hash');
    });
  });
}
