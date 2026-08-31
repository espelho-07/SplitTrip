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

class MockLedgerHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Person-Based Lending/Borrowing Ledger & Chat Timeline Tests', () {
    late LocalStorageService storage;
    late PersonalRepository personalRepo;
    late ExpenseRepository expenseRepo;
    late TripRepository tripRepo;
    late PersonLedgerViewModel ledgerVm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      final sync = SyncService(storage);
      final client = ApiClient(httpClient: MockLedgerHttpClient());

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

    test('1. Calculates dynamic running balance for multiple lends and borrows with Rahul', () async {
      const currentUserId = 'usr_alice';
      const personName = 'Rahul';

      // 1. You lent ₹30,000
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personName,
        debtType: PersonalDebtType.lent,
        amountInPaise: 3000000,
        description: 'Flight tickets advance',
      );

      // 2. You borrowed ₹742
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personName,
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 74200,
        description: 'Dinner contribution',
      );

      // 3. You lent ₹720
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personName,
        debtType: PersonalDebtType.lent,
        amountInPaise: 72000,
        description: 'Coffee & Snacks',
      );

      // 4. You borrowed ₹2,000
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personName,
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 200000,
        description: 'Fuel split',
      );

      await ledgerVm.loadLedger(
        personName: personName,
        currentUserId: currentUserId,
      );

      // Verification of running balance:
      // Lent sum: ₹30,000 + ₹720 = ₹30,720 (3072000 paise)
      // Borrowed sum: ₹742 + ₹2,000 = ₹2,742 (274200 paise)
      // Net: ₹30,720 - ₹2,742 = ₹27,978 (2797800 paise)
      expect(ledgerVm.totalLentPaise, 3072000);
      expect(ledgerVm.totalBorrowedPaise, 274200);
      expect(ledgerVm.netBalancePaise, 2797800);
      expect(ledgerVm.runningBalanceStatusText, 'Rahul owes you');

      // Check timeline items
      expect(ledgerVm.items.length, 4);
      expect(ledgerVm.items.where((i) => i.isCreditToUser).length, 2); // 2 lends
      expect(ledgerVm.items.where((i) => !i.isCreditToUser).length, 2); // 2 borrows
    });

    test('2. Dynamic wording switches to "You owe [Person]" when net balance is negative', () async {
      const currentUserId = 'usr_alice';
      const personName = 'Hardev';

      // You borrowed ₹5,000
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personName,
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 500000,
        description: 'Hotel advance',
      );

      await ledgerVm.loadLedger(
        personName: personName,
        currentUserId: currentUserId,
      );

      expect(ledgerVm.netBalancePaise, -500000);
      expect(ledgerVm.runningBalanceStatusText, 'You owe Hardev');
    });

    test('3. Dynamic wording displays "Settled / Even" when net balance is zero', () async {
      const currentUserId = 'usr_alice';
      const personName = 'Maya';

      // Lent ₹1,000 and borrowed ₹1,000
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personName,
        debtType: PersonalDebtType.lent,
        amountInPaise: 100000,
      );
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: personName,
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 100000,
      );

      await ledgerVm.loadLedger(
        personName: personName,
        currentUserId: currentUserId,
      );

      expect(ledgerVm.netBalancePaise, 0);
      expect(ledgerVm.runningBalanceStatusText, 'Settled / Even');
    });

    test('4. Adding transactions directly from ledger updates single persistent store immediately', () async {
      const currentUserId = 'usr_alice';
      const personName = 'Rahul';

      await ledgerVm.loadLedger(
        personName: personName,
        currentUserId: currentUserId,
      );
      expect(ledgerVm.items.isEmpty, true);

      // Add lend directly from ViewModel
      await ledgerVm.addLendTransaction(
        amountInPaise: 150000,
        note: 'Concert ticket',
      );

      expect(ledgerVm.items.length, 1);
      expect(ledgerVm.netBalancePaise, 150000);
      expect(ledgerVm.items.first.title, 'Concert ticket');

      // Verify single source of truth in personal repository
      final cachedDebts = personalRepo.getCachedPersonalDebts();
      expect(cachedDebts.debts.length, 1);
      expect(cachedDebts.debts.first.personName, 'Rahul');
      expect(cachedDebts.debts.first.remainingAmountInPaise, 150000);
    });
  });
}
