import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/ipo_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/services/ipo_data_provider.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/ipo/ipo_account.dart';
import 'package:kith_app/domain/models/ipo/ipo_application.dart';
import 'package:kith_app/presentation/viewmodels/ipo_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late IpoRepository ipoRepo;
  late PersonalRepository personalRepo;
  late IpoViewModel ipoVm;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    final apiClient = ApiClient();
    final syncService = SyncService(storage);
    personalRepo = PersonalRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    ipoRepo = IpoRepository(storage: storage, dataProvider: LiveIpoDataProvider(), personalRepo: personalRepo);
    ipoVm = IpoViewModel(ipoRepo: ipoRepo);
  });

  group('IPO Multi-Account System & Smart Payment Allocation Tests', () {
    test('1. PAN Security Masking: only last 4 digits are visible', () {
      final acc = IpoAccount.create(
        displayName: 'Brother',
        rawPan: 'ABCDE1234F',
      );

      expect(acc.maskedPan, 'XXXXX1234F');
      expect(acc.displayName, 'Brother');
    });

    test('2. Reusable Accounts Creation and Persistence', () async {
      await ipoVm.createAccount(
        displayName: 'Brother (Zerodha)',
        rawPan: 'ABCDE5678G',
      );

      await ipoVm.createAccount(
        displayName: 'Friend (Groww)',
        rawPan: 'XYZAB9999K',
      );

      expect(ipoVm.accounts.length, 3); // Me (Default) + Brother + Friend
      expect(ipoVm.accounts.any((a) => a.displayName == 'Brother (Zerodha)'), isTrue);
      expect(ipoVm.accounts.any((a) => a.displayName == 'Friend (Groww)'), isTrue);
    });

    test('3. Multi-Account Application Recording for Single IPO', () async {
      final brotherAcc = await ipoVm.createAccount(
        displayName: 'Brother',
        rawPan: 'ABCDE5678G',
      );

      final meApp = IpoApplication(
        id: 'app_me',
        ipoId: 'ipo_tcs',
        ipoName: 'TCS Infotech Ltd',
        userId: 'usr_test',
        applicationAccountId: 'me',
        accountDisplayName: 'Me',
        applicationDate: DateTime.now(),
        lotsApplied: 1,
        lotSize: 30,
        bidPriceInRupees: 500,
        applicationAmountInPaise: 1500000,
        paidAmountInPaise: 1500000,
        fundings: const [],
        status: IpoApplicationStatus.applied,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final brotherApp = IpoApplication(
        id: 'app_bro',
        ipoId: 'ipo_tcs',
        ipoName: 'TCS Infotech Ltd',
        userId: 'usr_test',
        applicationAccountId: brotherAcc.id,
        accountDisplayName: brotherAcc.displayName,
        accountMaskedPan: brotherAcc.maskedPan,
        applicationDate: DateTime.now(),
        lotsApplied: 2,
        lotSize: 30,
        bidPriceInRupees: 500,
        applicationAmountInPaise: 3000000,
        paidAmountInPaise: 3000000,
        fundings: const [],
        status: IpoApplicationStatus.applied,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ipoVm.recordMultipleApplications([meApp, brotherApp]);

      final allApps = ipoVm.getAllApplicationsForIpo('ipo_tcs');
      expect(allApps.length, 2);

      final broMetrics = ipoVm.getAccountMetrics(brotherAcc.id);
      expect(broMetrics['totalAppliedPaise'], 3000000);
      expect(broMetrics['applicationCount'], 1);
    });

    test('4. Smart Payment Calculation with Eligible Reusable Credit', () async {
      final brotherAcc = await ipoVm.createAccount(
        displayName: 'Brother',
        rawPan: 'ABCDE5678G',
      );

      // 1. First IPO was applied and not allotted (Refunded ₹14,857 / 1,485,700 paise)
      final app1 = IpoApplication(
        id: 'app_1',
        ipoId: 'ipo_old',
        ipoName: 'Old Solar IPO',
        userId: 'usr_test',
        applicationAccountId: brotherAcc.id,
        accountDisplayName: brotherAcc.displayName,
        applicationDate: DateTime.now().subtract(const Duration(days: 10)),
        lotsApplied: 1,
        lotSize: 30,
        bidPriceInRupees: 495,
        applicationAmountInPaise: 1485700,
        paidAmountInPaise: 1485700,
        releasedAmountInPaise: 1485700,
        fundings: const [],
        status: IpoApplicationStatus.notAllotted,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ipoRepo.recordApplication(app1);

      // Verify available credit is ₹14,857
      final availableCredit = ipoVm.getAccountAvailableCreditPaise(brotherAcc.id);
      expect(availableCredit, 1485700);

      // 2. New IPO B requires ₹15,000 (1,500,000 paise)
      final requiredPaise = 1500000;
      final additionalNeededPaise = (requiredPaise - availableCredit).clamp(0, requiredPaise);

      // Needed = 1,500,000 - 1,485,700 = 14,300 paise (₹143)
      expect(additionalNeededPaise, 14300);
    });
  });
}
