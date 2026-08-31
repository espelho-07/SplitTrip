import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/ipo_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/ipo_data_provider.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/ipo/ipo.dart';
import 'package:kith_app/domain/models/ipo/ipo_application.dart';
import 'package:kith_app/domain/models/personal_debt.dart';
import 'package:kith_app/presentation/viewmodels/ipo_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/person_ledger_viewmodel.dart';

class MockIpoHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final responsePayload = jsonEncode({'status': 'ok', 'data': {}});
    return http.StreamedResponse(
      Stream.value(utf8.encode(responsePayload)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late PersonalRepository personalRepo;
  late ExpenseRepository expenseRepo;
  late TripRepository tripRepo;
  late IpoDataProvider dataProvider;
  late IpoRepository ipoRepo;
  late IpoViewModel ipoViewModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
    apiClient = ApiClient(httpClient: MockIpoHttpClient());
    personalRepo = PersonalRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    expenseRepo = ExpenseRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    tripRepo = TripRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    dataProvider = LiveIpoDataProvider();
    ipoRepo = IpoRepository(
      storage: storage,
      dataProvider: dataProvider,
      personalRepo: personalRepo,
    );
    ipoViewModel = IpoViewModel(ipoRepo: ipoRepo);
  });

  group('IPO Application Mathematical Calculations', () {
    test('calculateApplicationAmountPaise calculates exact lots * lotSize * bidPrice', () {
      // 3 lots * 30 shares * Rs 475 = Rs 42,750 = 4,275,000 paise
      final amountPaise = IpoApplication.calculateApplicationAmountPaise(
        lots: 3,
        lotSize: 30,
        bidPriceRupees: 475,
      );
      expect(amountPaise, equals(4275000));
    });

    test('calculateAllotmentAmounts correctly computes full allotment', () {
      final res = IpoApplication.calculateAllotmentAmounts(
        applicationAmountPaise: 4275000,
        allottedLots: 3,
        lotSize: 30,
        issuePriceRupees: 475,
      );
      expect(res['investedPaise'], equals(4275000));
      expect(res['releasedPaise'], equals(0));
    });

    test('calculateAllotmentAmounts correctly computes partial allotment', () {
      // 3 lots applied (Rs 42,750), 1 lot allotted (Rs 14,250), 2 lots released (Rs 28,500)
      final res = IpoApplication.calculateAllotmentAmounts(
        applicationAmountPaise: 4275000,
        allottedLots: 1,
        lotSize: 30,
        issuePriceRupees: 475,
      );
      expect(res['investedPaise'], equals(1425000));
      expect(res['releasedPaise'], equals(2850000));
    });

    test('calculateAllotmentAmounts correctly computes zero allotment / not allotted', () {
      final res = IpoApplication.calculateAllotmentAmounts(
        applicationAmountPaise: 4275000,
        allottedLots: 0,
        lotSize: 30,
        issuePriceRupees: 475,
      );
      expect(res['investedPaise'], equals(0));
      expect(res['releasedPaise'], equals(4275000));
    });
  });

  group('IPO Funding Allocation & Person Ledger Integration', () {
    test('Validates multi-funder allocation and creates linked peer debts', () async {
      // Total amount: Rs 42,900 (4,290,000 paise)
      // Me: Rs 20,000 (2,000,000 paise)
      // Rohit: Rs 15,000 (1,500,000 paise)
      // Priya: Rs 7,900 (790,000 paise)
      const totalAmountPaise = 4290000;

      final fundings = [
        const IpoFunding(
          id: 'fund_1',
          applicationId: 'app_123',
          funderType: IpoFunderType.self,
          amountInPaise: 2000000,
        ),
        const IpoFunding(
          id: 'fund_2',
          applicationId: 'app_123',
          funderType: IpoFunderType.person,
          personName: 'Rohit',
          amountInPaise: 1500000,
        ),
        const IpoFunding(
          id: 'fund_3',
          applicationId: 'app_123',
          funderType: IpoFunderType.person,
          personName: 'Priya',
          amountInPaise: 790000,
        ),
      ];

      final application = IpoApplication(
        id: 'app_123',
        ipoId: 'ipo_bajaj_housing',
        ipoName: 'Bajaj Housing Finance IPO',
        userId: 'usr_main',
        applicationDate: DateTime(2026, 8, 30),
        lotsApplied: 3,
        lotSize: 200,
        bidPriceInRupees: 70,
        applicationAmountInPaise: totalAmountPaise,
        fundings: fundings,
        status: IpoApplicationStatus.applied,
        createdAt: DateTime(2026, 8, 30),
        updatedAt: DateTime(2026, 8, 30),
      );

      expect(application.isFundingAllocationExact, isTrue);
      expect(application.fundingDifferencePaise, equals(0));

      // Record application via repository
      await ipoRepo.recordApplication(application);

      // Verify that PersonalDebt records were created for Rohit and Priya
      final debts = personalRepo.getCachedPersonalDebts().debts;
      expect(debts.length, equals(2));

      final rohitDebt = debts.firstWhere((d) => d.personName == 'Rohit');
      expect(rohitDebt.initialAmountInPaise, equals(1500000));
      expect(rohitDebt.debtType, equals(PersonalDebtType.borrowed));
      expect(rohitDebt.description, contains('Bajaj Housing Finance IPO'));

      final priyaDebt = debts.firstWhere((d) => d.personName == 'Priya');
      expect(priyaDebt.initialAmountInPaise, equals(790000));
      expect(priyaDebt.debtType, equals(PersonalDebtType.borrowed));

      // Verify that PersonLedgerViewModel displays the IPO funding transaction
      final rohitLedger = PersonLedgerViewModel(
        personalRepo: personalRepo,
        expenseRepo: expenseRepo,
        tripRepo: tripRepo,
        storage: storage,
      );
      await rohitLedger.loadLedger(personName: 'Rohit', currentUserId: 'usr_main');

      expect(rohitLedger.items.length, equals(1));
      final item = rohitLedger.items.first;
      expect(item.amountInPaise, equals(1500000));
      expect(item.isIpoFunding, isTrue);
      expect(item.ipoName, contains('Bajaj Housing Finance IPO'));
    });

    test('Updates Allotment outcome and calculates invested vs released amount', () async {
      final application = IpoApplication(
        id: 'app_456',
        ipoId: 'ipo_krn_heat',
        ipoName: 'KRN Heat Exchanger IPO',
        userId: 'usr_main',
        applicationDate: DateTime.now(),
        lotsApplied: 2,
        lotSize: 65,
        bidPriceInRupees: 220,
        applicationAmountInPaise: 2860000, // 2 * 65 * 220 * 100
        fundings: [
          const IpoFunding(
            id: 'f1',
            applicationId: 'app_456',
            funderType: IpoFunderType.self,
            amountInPaise: 2860000,
          ),
        ],
        status: IpoApplicationStatus.applied,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ipoRepo.recordApplication(application);

      // Update to Partial Allotment (1 lot)
      final updated = await ipoRepo.updateAllotment(
        applicationId: 'app_456',
        status: IpoApplicationStatus.partiallyAllotted,
        allottedLots: 1,
      );

      expect(updated, isNotNull);
      expect(updated!.status, equals(IpoApplicationStatus.partiallyAllotted));
      expect(updated.allottedLots, equals(1));
      expect(updated.allottedShares, equals(65));
      expect(updated.actualInvestedAmountInPaise, equals(1430000));
      expect(updated.releasedAmountInPaise, equals(1430000));
    });

    test('Persists IPOs and applications across cold restarts', () async {
      await ipoViewModel.loadData();
      expect(ipoViewModel.ipos.isNotEmpty, isTrue);

      final openIpo = ipoViewModel.ipos.firstWhere((i) => i.status == IpoStatus.open);

      final app = IpoApplication(
        id: 'app_restart_test',
        ipoId: openIpo.id,
        ipoName: openIpo.name,
        userId: 'usr_main',
        applicationDate: DateTime.now(),
        lotsApplied: 1,
        lotSize: openIpo.lotSize,
        bidPriceInRupees: openIpo.maxPrice,
        applicationAmountInPaise: openIpo.lotSize * openIpo.maxPrice * 100,
        fundings: [
          IpoFunding(
            id: 'f_self',
            applicationId: 'app_restart_test',
            funderType: IpoFunderType.self,
            amountInPaise: openIpo.lotSize * openIpo.maxPrice * 100,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ipoViewModel.recordApplication(app);

      // Simulate Cold Restart: create new repository and viewmodel from same storage
      final restartedRepo = IpoRepository(
        storage: storage,
        dataProvider: dataProvider,
        personalRepo: personalRepo,
      );
      final restartedVm = IpoViewModel(ipoRepo: restartedRepo);

      expect(restartedVm.applications.length, equals(1));
      expect(restartedVm.applications.first.ipoId, equals(openIpo.id));
      expect(restartedVm.totalAppliedPaise, equals(openIpo.lotSize * openIpo.maxPrice * 100));
    });
  });
}
