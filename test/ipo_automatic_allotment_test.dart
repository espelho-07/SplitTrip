import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/data/repositories/ipo_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/services/ipo_data_provider.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/domain/models/ipo/ipo.dart';
import 'package:kith_app/domain/models/ipo/ipo_application.dart';

class MockAllotmentProvider implements IpoDataProvider {
  final Map<String, IpoApplicationStatus> _resultMap;
  int checkCount = 0;
  bool simulateTimeout = false;

  MockAllotmentProvider({Map<String, IpoApplicationStatus>? results})
      : _resultMap = results ?? {};

  @override
  Future<List<Ipo>> fetchIpos() async => const [];

  @override
  Future<bool> registerApplicationMonitoring(IpoApplication app) async => true;

  @override
  Future<IpoApplication?> checkApplicationAllotment(String applicationId) async {
    checkCount++;
    if (simulateTimeout) {
      throw Exception('Provider timeout');
    }
    final outcome = _resultMap[applicationId];
    if (outcome == null) return null;
    return IpoApplication(
      id: applicationId,
      ipoId: 'ipo_esds',
      ipoName: 'ESDS Software Solution IPO',
      userId: 'user_test',
      lotsApplied: 1,
      lotSize: 19,
      bidPriceInRupees: 170,
      applicationAmountInPaise: 19 * 170 * 100,
      applicationDate: DateTime.now(),
      fundings: const [],
      status: outcome,
      monitoringStatus: IpoMonitoringStatus.resultFound,
      allottedLots: outcome == IpoApplicationStatus.allotted ? 1 : 0,
      allottedShares: outcome == IpoApplicationStatus.allotted ? 19 : 0,
      lastCheckMessage: outcome == IpoApplicationStatus.allotted
          ? 'Allotted 1 lot via FinAPI'
          : 'Not allotted — full refund',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<IpoApplication>> syncUserAllotments(String userId) async => const [];
}

IpoApplication _makeEsdsApp({required String id, required String accountName}) {
  final now = DateTime.now();
  return IpoApplication(
    id: id,
    ipoId: 'ipo_esds',
    ipoName: 'ESDS Software Solution IPO',
    userId: 'user_test',
    accountDisplayName: accountName,
    applicationDate: now,
    lotsApplied: 1,
    lotSize: 19,
    bidPriceInRupees: 170,
    applicationAmountInPaise: 19 * 170 * 100,
    fundings: const [],
    status: IpoApplicationStatus.applied,
    monitoringStatus: IpoMonitoringStatus.monitoring,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late PersonalRepository personalRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    final syncService = SyncService(storage);
    final apiClient = ApiClient();
    personalRepo = PersonalRepository(storage: storage, syncService: syncService, apiClient: apiClient);
  });

  group('ESDS IPO: 3-Account Independent Allotment (Scenario 36)', () {
    test('Brother allotted, Friend not allotted, Friend friend not allotted', () async {
      final brotherApp = _makeEsdsApp(id: 'app_brother', accountName: 'Brother');
      final friendApp = _makeEsdsApp(id: 'app_friend', accountName: 'Friend');
      final friendFriendApp = _makeEsdsApp(id: 'app_ff', accountName: "Friend's Friend");

      final provider = MockAllotmentProvider(results: {
        'app_brother': IpoApplicationStatus.allotted,
        'app_friend': IpoApplicationStatus.notAllotted,
        'app_ff': IpoApplicationStatus.notAllotted,
      });
      final repo = IpoRepository(storage: storage, dataProvider: provider, personalRepo: personalRepo);
      await repo.recordApplication(brotherApp);
      await repo.recordApplication(friendApp);
      await repo.recordApplication(friendFriendApp);

      final brother = await repo.checkAllotmentNow('app_brother');
      final friend = await repo.checkAllotmentNow('app_friend');
      final ff = await repo.checkAllotmentNow('app_ff');

      expect(brother?.status, IpoApplicationStatus.allotted);
      expect(friend?.status, IpoApplicationStatus.notAllotted);
      expect(ff?.status, IpoApplicationStatus.notAllotted);
    });
  });

  group('Financial Ledger Automation', () {
    test('Not Allotted releases 100 percent funds', () async {
      final app = _makeEsdsApp(id: 'app_na', accountName: 'Brother');
      final provider = MockAllotmentProvider(results: {'app_na': IpoApplicationStatus.notAllotted});
      final repo = IpoRepository(storage: storage, dataProvider: provider, personalRepo: personalRepo);
      await repo.recordApplication(app);
      final result = await repo.checkAllotmentNow('app_na');
      expect(result?.releasedAmountInPaise, 323000);
      expect(result?.actualInvestedAmountInPaise, 0);
    });

    test('Allotted invests 100 percent, zero released', () async {
      final app = _makeEsdsApp(id: 'app_a', accountName: 'Brother');
      final provider = MockAllotmentProvider(results: {'app_a': IpoApplicationStatus.allotted});
      final repo = IpoRepository(storage: storage, dataProvider: provider, personalRepo: personalRepo);
      await repo.recordApplication(app);
      final result = await repo.checkAllotmentNow('app_a');
      expect(result?.actualInvestedAmountInPaise, 323000);
      expect(result?.releasedAmountInPaise, 0);
    });

    test('Partially allotted splits invested and released correctly', () async {
      final app = IpoApplication(
        id: 'app_partial',
        ipoId: 'ipo_esds',
        ipoName: 'ESDS',
        userId: 'user_test',
        applicationDate: DateTime.now(),
        lotsApplied: 3,
        lotSize: 19,
        bidPriceInRupees: 170,
        applicationAmountInPaise: 3 * 19 * 170 * 100,
        fundings: const [],
        status: IpoApplicationStatus.applied,
        monitoringStatus: IpoMonitoringStatus.monitoring,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final provider = MockAllotmentProvider();
      final repo = IpoRepository(storage: storage, dataProvider: provider, personalRepo: personalRepo);
      await repo.recordApplication(app);
      await repo.updateAllotment(
        applicationId: 'app_partial',
        status: IpoApplicationStatus.partiallyAllotted,
        allottedLots: 1,
        issuePriceInRupees: 170,
      );
      final updated = repo.getCachedApplications().firstWhere((a) => a.id == 'app_partial');
      expect(updated.actualInvestedAmountInPaise, 323000);
      expect(updated.releasedAmountInPaise, 646000);
    });
  });

  group('Provider Reliability', () {
    test('Timeout never sets status to Not Allotted', () async {
      final app = _makeEsdsApp(id: 'app_timeout', accountName: 'Brother');
      final provider = MockAllotmentProvider()..simulateTimeout = true;
      final repo = IpoRepository(storage: storage, dataProvider: provider, personalRepo: personalRepo);
      await repo.recordApplication(app);
      final result = await repo.checkAllotmentNow('app_timeout');
      expect(result?.status, isNot(IpoApplicationStatus.notAllotted));
      expect(result?.status, isNot(IpoApplicationStatus.allotted));
    });
  });

  group('Idempotency', () {
    test('Double updateAllotment does not double-credit released funds', () async {
      final app = _makeEsdsApp(id: 'app_idem', accountName: 'Brother');
      final provider = MockAllotmentProvider();
      final repo = IpoRepository(storage: storage, dataProvider: provider, personalRepo: personalRepo);
      await repo.recordApplication(app);
      await repo.updateAllotment(applicationId: 'app_idem', status: IpoApplicationStatus.notAllotted, allottedLots: 0);
      final first = repo.getCachedApplications().firstWhere((a) => a.id == 'app_idem');
      await repo.updateAllotment(applicationId: 'app_idem', status: IpoApplicationStatus.notAllotted, allottedLots: 0);
      final second = repo.getCachedApplications().firstWhere((a) => a.id == 'app_idem');
      expect(second.releasedAmountInPaise, first.releasedAmountInPaise);
    });
  });

  group('IpoApplication Model Serialization', () {
    test('monitoringStatus survives JSON round-trip', () {
      final app = _makeEsdsApp(id: 'app_s', accountName: 'Test')
          .copyWith(monitoringStatus: IpoMonitoringStatus.resultFound, checkCount: 5);
      final restored = IpoApplication.fromJson(app.toJson());
      expect(restored.monitoringStatus, IpoMonitoringStatus.resultFound);
      expect(restored.checkCount, 5);
    });

    test('IpoAuditEntry JSON round-trip', () {
      final entry = IpoAuditEntry(
        id: 'audit_1',
        timestamp: DateTime(2026, 9, 1),
        title: 'Allotment Confirmed',
        description: 'Allotted via FinAPI',
      );
      final restored = IpoAuditEntry.fromJson(entry.toJson());
      expect(restored.id, 'audit_1');
      expect(restored.title, 'Allotment Confirmed');
    });

    test('maskedApplicationNumber works correctly', () {
      final app = _makeEsdsApp(id: 'x', accountName: 'Test').copyWith(applicationNumber: 'AB1234567890');
      expect(app.maskedApplicationNumber, '\u2022\u2022\u2022\u20227890');
    });

    test('IpoMonitoringStatus fromString handles all values', () {
      expect(IpoMonitoringStatus.fromString('monitoring'), IpoMonitoringStatus.monitoring);
      expect(IpoMonitoringStatus.fromString('resultfound'), IpoMonitoringStatus.resultFound);
      expect(IpoMonitoringStatus.fromString('result_found'), IpoMonitoringStatus.resultFound);
      expect(IpoMonitoringStatus.fromString('retrying'), IpoMonitoringStatus.retrying);
      expect(IpoMonitoringStatus.fromString('failed'), IpoMonitoringStatus.failed);
      expect(IpoMonitoringStatus.fromString(null), IpoMonitoringStatus.monitoring);
    });

    test('Audit trail grows after allotment update', () async {
      final app = _makeEsdsApp(id: 'app_audit', accountName: 'Brother');
      final provider = MockAllotmentProvider(results: {'app_audit': IpoApplicationStatus.allotted});
      final repo = IpoRepository(storage: storage, dataProvider: provider, personalRepo: personalRepo);
      final saved = await repo.recordApplication(app);
      expect(saved.auditTrail, isNotEmpty);
      final result = await repo.checkAllotmentNow('app_audit');
      expect(result?.auditTrail.length, greaterThan(1));
    });
  });
}
