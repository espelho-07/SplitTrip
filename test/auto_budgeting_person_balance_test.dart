import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/personal_debt.dart';
import 'package:kith_app/presentation/viewmodels/person_ledger_viewmodel.dart';

class MockAutoBudgetHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auto Budgeting / Personal Chat Balance System Comprehensive Tests', () {
    late SharedPreferences prefs;
    late LocalStorageService storage;
    late PersonalRepository personalRepo;
    late ExpenseRepository expenseRepo;
    late TripRepository tripRepo;
    late PersonLedgerViewModel ledgerVm;

    const currentUserId = 'usr_alice';
    const personX = 'Rohit';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      final sync = SyncService(storage);
      final client = ApiClient(httpClient: MockAutoBudgetHttpClient());

      personalRepo = PersonalRepository(storage: storage, syncService: sync, apiClient: client);
      expenseRepo = ExpenseRepository(storage: storage, syncService: sync, apiClient: client);
      tripRepo = TripRepository(storage: storage, syncService: sync, apiClient: client);

      ledgerVm = PersonLedgerViewModel(
        personalRepo: personalRepo,
        expenseRepo: expenseRepo,
        tripRepo: tripRepo,
        storage: storage,
      );
    });

    test('1. STRICT DEFAULT STATE: Auto Budgeting defaults to OFF for every new person relationship', () async {
      await ledgerVm.loadLedger(personName: personX, currentUserId: currentUserId);

      // Verify toggle is OFF by default
      expect(ledgerVm.isAutoBudgetingEnabled, isFalse);
      expect(storage.isAutoBudgetingEnabled(personX), isFalse);

      // Check for another new person
      const personY = 'Priya';
      expect(storage.isAutoBudgetingEnabled(personY), isFalse);
    });

    test('2. TOGGLE PERSISTENCE: Toggling Auto Budgeting ON persists across cold reload', () async {
      await ledgerVm.loadLedger(personName: personX, currentUserId: currentUserId);
      expect(ledgerVm.isAutoBudgetingEnabled, isFalse);

      // Toggle ON
      await ledgerVm.toggleAutoBudgeting(true);
      expect(ledgerVm.isAutoBudgetingEnabled, isTrue);
      expect(storage.isAutoBudgetingEnabled(personX), isTrue);

      // Simulate cold app restart: instantiate new LocalStorageService and ViewModel
      final newStorage = LocalStorageService(prefs);
      final newLedgerVm = PersonLedgerViewModel(
        personalRepo: personalRepo,
        expenseRepo: expenseRepo,
        tripRepo: tripRepo,
        storage: newStorage,
      );

      await newLedgerVm.loadLedger(personName: personX, currentUserId: currentUserId);
      expect(newLedgerVm.isAutoBudgetingEnabled, isTrue);

      // Other person remains OFF
      expect(newStorage.isAutoBudgetingEnabled('SomeoneElse'), isFalse);
    });

    test('3. REQUIREMENT EXAMPLE 1: Rohit gives ₹15,000; User gives ₹5,000 -> You owe Rohit ₹10,000', () async {
      // Rohit gives user ₹15,000 (User borrowed from Rohit / Received from Rohit)
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personX,
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 1500000,
        description: 'Rent share received',
      );

      // User gives Rohit ₹5,000 (User lent to Rohit / Paid to Rohit)
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personX,
        debtType: PersonalDebtType.lent,
        amountInPaise: 500000,
        description: 'Groceries paid',
      );

      await ledgerVm.loadLedger(personName: personX, currentUserId: currentUserId);
      await ledgerVm.toggleAutoBudgeting(true);

      expect(ledgerVm.totalPaidPaise, 500000); // User gave ₹5,000
      expect(ledgerVm.totalReceivedPaise, 1500000); // Rohit gave ₹15,000
      expect(ledgerVm.netBalancePaise, -1000000); // -₹10,000
      expect(ledgerVm.runningBalanceStatusText, 'You owe $personX');
    });

    test('4. REQUIREMENT EXAMPLE 2: User gives Rohit ₹15,000; Rohit gives ₹5,000 -> Rohit owes you ₹10,000', () async {
      // User gives Rohit ₹15,000
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personX,
        debtType: PersonalDebtType.lent,
        amountInPaise: 1500000,
        description: 'Concert tickets paid',
      );

      // Rohit gives user ₹5,000
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personX,
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 500000,
        description: 'Snacks received',
      );

      await ledgerVm.loadLedger(personName: personX, currentUserId: currentUserId);

      expect(ledgerVm.totalPaidPaise, 1500000); // ₹15,000
      expect(ledgerVm.totalReceivedPaise, 500000); // ₹5,000
      expect(ledgerVm.netBalancePaise, 1000000); // +₹10,000
      expect(ledgerVm.runningBalanceStatusText, '$personX owes you');
    });

    test('5. REQUIREMENT EXAMPLE 3: Even exchange (₹5,000 each) -> Settled / Even', () async {
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personX,
        debtType: PersonalDebtType.lent,
        amountInPaise: 500000,
      );

      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personX,
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 500000,
      );

      await ledgerVm.loadLedger(personName: personX, currentUserId: currentUserId);

      expect(ledgerVm.netBalancePaise, 0);
      expect(ledgerVm.runningBalanceStatusText, 'Settled / Even');
    });

    test('6. REQUIREMENT EXAMPLE 4: Rohit gives ₹17,500; User gives ₹6,000 -> You owe Rohit ₹11,500', () async {
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personX,
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 1750000,
      );

      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personX,
        debtType: PersonalDebtType.lent,
        amountInPaise: 600000,
      );

      await ledgerVm.loadLedger(personName: personX, currentUserId: currentUserId);

      expect(ledgerVm.netBalancePaise, -1150000);
      expect(ledgerVm.runningBalanceStatusText, 'You owe $personX');
    });

    test('7. PARTIAL SETTLEMENT: Step-by-step settlement updates net balance dynamically', () async {
      // Start: You owe Rohit ₹10,000
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personX,
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 1000000,
      );

      await ledgerVm.loadLedger(personName: personX, currentUserId: currentUserId);
      expect(ledgerVm.netBalancePaise, -1000000);
      expect(ledgerVm.runningBalanceStatusText, 'You owe $personX');

      // Step 1: Partial settlement of ₹4,000 (User pays Rohit ₹4,000)
      await ledgerVm.settleBalance(amountInPaise: 400000, note: 'Partial settlement via UPI');
      expect(ledgerVm.netBalancePaise, -600000); // Remaining: -₹6,000
      expect(ledgerVm.runningBalanceStatusText, 'You owe $personX');

      // Step 2: Final settlement of remaining ₹6,000
      await ledgerVm.settleBalance(amountInPaise: 600000, note: 'Final settlement');
      expect(ledgerVm.netBalancePaise, 0); // 0
      expect(ledgerVm.runningBalanceStatusText, 'Settled / Even');
    });

    test('8. DYNAMIC EDIT & DELETE: Editing or deleting transaction updates ledger balance immediately', () async {
      // Add a debt
      final debt = await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personX,
        debtType: PersonalDebtType.lent,
        amountInPaise: 1000000, // ₹10,000
        description: 'Original amount',
      );

      await ledgerVm.loadLedger(personName: personX, currentUserId: currentUserId);
      expect(ledgerVm.netBalancePaise, 1000000);

      // Edit transaction to ₹7,500
      await ledgerVm.updateDebtTransaction(
        debt.id,
        newAmountInPaise: 750000,
        newNote: 'Updated amount',
      );
      expect(ledgerVm.netBalancePaise, 750000);

      // Delete transaction
      final itemToDelete = ledgerVm.items.firstWhere((it) => it.referenceId == debt.id);
      await ledgerVm.deleteTransaction(itemToDelete);
      expect(ledgerVm.netBalancePaise, 0);
      expect(ledgerVm.items.isEmpty, isTrue);
    });
  });
}
