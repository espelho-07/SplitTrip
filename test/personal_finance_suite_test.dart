import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/voice_parser.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/personal_debt.dart';
import 'package:kith_app/presentation/viewmodels/personal_expense_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late PersonalRepository personalRepo;

  const testUserId = 'usr_personal_qa_001';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    apiClient = ApiClient();
    syncService = SyncService(storage);
    personalRepo = PersonalRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
  });

  group('Personal Finance & Ultra-Simple Money Tracking Tests', () {
    test('1. Personal Expense CRUD & integer paise financial precision', () async {
      final vm = PersonalExpenseViewModel(personalRepo: personalRepo);
      await vm.loadData(testUserId);

      expect(vm.expenses, isEmpty);
      expect(vm.totalSpentInPaise, 0);

      // Create
      final exp = await vm.addExpense(
        userId: testUserId,
        title: 'Team Lunch',
        amountInPaise: 65000, // ₹650.00
        category: ExpenseCategory.food,
      );

      expect(exp, isNotNull);
      expect(vm.expenses.length, 1);
      expect(vm.totalSpentInPaise, 65000);
      expect(vm.categoryTotalsInPaise[ExpenseCategory.food], 65000);

      // Edit / Update
      final updated = exp!.copyWith(
        title: 'Grand Team Lunch',
        amountInPaise: 80000, // ₹800.00
      );
      final updateSuccess = await vm.updateExpense(updated);
      expect(updateSuccess, true);
      expect(vm.expenses.first.title, 'Grand Team Lunch');
      expect(vm.totalSpentInPaise, 80000);

      // Delete
      final deleteSuccess = await vm.deleteExpense(exp.id);
      expect(deleteSuccess, true);
      expect(vm.expenses, isEmpty);
      expect(vm.totalSpentInPaise, 0);
    });

    test('2. Time & Date Filters (Today, This Week, This Month)', () async {
      final vm = PersonalExpenseViewModel(personalRepo: personalRepo);
      final now = DateTime.now();

      // Expense today
      await vm.addExpense(
        userId: testUserId,
        title: 'Morning Coffee',
        amountInPaise: 15000,
        category: ExpenseCategory.drinks,
        date: now,
      );

      // Expense last week
      await vm.addExpense(
        userId: testUserId,
        title: 'Old Train Ticket',
        amountInPaise: 40000,
        category: ExpenseCategory.transport,
        date: now.subtract(const Duration(days: 10)),
      );

      // Today filter
      vm.setTimeFilter(PersonalTimeFilter.today);
      expect(vm.filteredExpenses.length, 1);
      expect(vm.filteredExpenses.first.title, 'Morning Coffee');
      expect(vm.totalSpentInPaise, 15000);

      // This month filter
      vm.setTimeFilter(PersonalTimeFilter.thisMonth);
      expect(vm.filteredExpenses.length, 2);
      expect(vm.totalSpentInPaise, 55000);
    });

    test('3. Peer-to-Peer Lending with partial repayment tracking', () async {
      final vm = PersonalExpenseViewModel(personalRepo: personalRepo);
      await vm.loadData(testUserId);

      // I lent ₹1,000 to Rahul
      final debt = await vm.addDebt(
        userId: testUserId,
        personName: 'Rahul',
        debtType: PersonalDebtType.lent,
        amountInPaise: 100000,
        description: 'Dinner contribution',
      );

      expect(debt, isNotNull);
      expect(vm.debtsSummary.totalLentPaise, 100000);
      expect(vm.debtsSummary.netBalancePaise, 100000);

      // Rahul repays ₹400
      final repSuccess = await vm.recordRepayment(
        userId: testUserId,
        debtId: debt!.id,
        amountInPaise: 40000,
        note: 'GPay',
      );

      expect(repSuccess, true);
      expect(vm.debtsSummary.totalLentPaise, 60000); // ₹600 remaining
      expect(vm.debtsSummary.debts.first.isSettled, false);

      // Rahul repays remaining ₹600
      await vm.recordRepayment(
        userId: testUserId,
        debtId: debt.id,
        amountInPaise: 60000,
      );

      expect(vm.debtsSummary.totalLentPaise, 0);
      expect(vm.debtsSummary.debts.first.isSettled, true);
    });

    test('4. Peer-to-Peer Borrowing balance tracking', () async {
      final vm = PersonalExpenseViewModel(personalRepo: personalRepo);
      await vm.loadData(testUserId);

      // I borrowed ₹500 from Priya
      final debt = await vm.addDebt(
        userId: testUserId,
        personName: 'Priya',
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 50000,
        description: 'Cab fare share',
      );

      expect(debt, isNotNull);
      expect(vm.debtsSummary.totalBorrowedPaise, 50000);
      expect(vm.debtsSummary.netBalancePaise, -50000);

      // Repay Priya full ₹500
      await vm.recordRepayment(
        userId: testUserId,
        debtId: debt!.id,
        amountInPaise: 50000,
      );

      expect(vm.debtsSummary.totalBorrowedPaise, 0);
      expect(vm.debtsSummary.netBalancePaise, 0);
    });

    test('5. Voice Intent Parser for Personal Expenses & Lending', () {
      // Normal expense in English
      final draft1 = VoiceIntentParser.parsePersonalDraft('Spent 500 on lunch');
      expect(draft1.amountInPaise, 50000);
      expect(draft1.title, 'Lunch');
      expect(draft1.category, ExpenseCategory.food);
      expect(draft1.type, PersonalVoiceIntentType.expense);

      // Normal expense in Hinglish
      final draft2 = VoiceIntentParser.parsePersonalDraft('Spent 300 today on auto');
      expect(draft2.amountInPaise, 30000);
      expect(draft2.title, 'Auto Ride');
      expect(draft2.category, ExpenseCategory.transport);

      // Lending in Hindi
      final draft3 = VoiceIntentParser.parsePersonalDraft('Rahul ko 500 udhar diye');
      expect(draft3.amountInPaise, 50000);
      expect(draft3.type, PersonalVoiceIntentType.lend);
      expect(draft3.personName, 'Rahul');

      // Borrowing in Hinglish
      final draft4 = VoiceIntentParser.parsePersonalDraft('Priya se 300 udhar liye');
      expect(draft4.amountInPaise, 30000);
      expect(draft4.type, PersonalVoiceIntentType.borrow);
      expect(draft4.personName, 'Priya');

      // Missing amount prompts safely without guessing
      final draft5 = VoiceIntentParser.parsePersonalDraft('Maine pizza mangwaya');
      expect(draft5.amountInPaise, 0);
      expect(draft5.unresolvedFields.contains('missing_amount'), true);
      expect(draft5.isReady, false);
    });

    test('6. Monthly Budget tracking & progress percentage', () async {
      final vm = PersonalExpenseViewModel(personalRepo: personalRepo);
      await vm.loadData(testUserId);

      // Set budget of ₹10,000
      await vm.setMonthlyBudget(1000000);
      expect(vm.budget.hasBudget, true);
      expect(vm.budget.monthlyLimitInPaise, 1000000);

      // Add expense of ₹3,500
      await vm.addExpense(
        userId: testUserId,
        title: 'Groceries',
        amountInPaise: 350000,
        category: ExpenseCategory.groceries,
      );

      expect(vm.budget.spentInPaise, 350000);
      expect(vm.budget.remainingInPaise, 650000);
      expect(vm.budget.percentageUsed, 35);
    });

    test('7. Offline-first local cache & mutation queue isolation', () async {
      // Create personal expense locally while storage has cached items
      final exp = await personalRepo.createPersonalExpense(
        userId: testUserId,
        title: 'Offline Snacks',
        amountInPaise: 8000,
        category: ExpenseCategory.food,
      );

      final cached = personalRepo.getCachedPersonalExpenses();
      expect(cached.any((e) => e.id == exp.id), true);

      // Verify mutation queue enqueued if network is unreachable
      final queue = syncService.getPendingMutations();
      expect(queue.any((m) => m.type == MutationType.createPersonalExpense), true);
    });

    test('8. Smart Next Action triggers and budget threshold calculations', () async {
      final vm = PersonalExpenseViewModel(personalRepo: personalRepo);
      await vm.loadData(testUserId);

      // Set budget of ₹5,000
      await vm.setMonthlyBudget(500000);
      expect(vm.budget.percentageUsed, 0);

      // Spend ₹4,500 (>85% spent -> 90%)
      await vm.addExpense(
        userId: testUserId,
        title: 'Flight Ticket Share',
        amountInPaise: 450000,
        category: ExpenseCategory.transport,
      );

      expect(vm.budget.percentageUsed, 90);
      expect(vm.budget.remainingInPaise, 50000);

      // Add lent debt
      final debt = await vm.addDebt(
        userId: testUserId,
        personName: 'Sameer',
        debtType: PersonalDebtType.lent,
        amountInPaise: 120000,
      );

      expect(debt, isNotNull);
      final uncollected = vm.debtsSummary.debts
          .where((d) => d.debtType == PersonalDebtType.lent && !d.isSettled)
          .firstOrNull;

      expect(uncollected?.personName, 'Sameer');
      expect(uncollected?.remainingAmountInPaise, 120000);
    });
  });
}
