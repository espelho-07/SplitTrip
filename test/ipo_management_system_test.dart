import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/data/services/ipo/ipo_api_adapter.dart';
import 'package:kith_app/data/services/ipo/ipo_data_mapper.dart';
import 'package:kith_app/data/services/ipo/ipo_dtos.dart';
import 'package:kith_app/data/services/ipo/ipo_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/models/ipo/ipo.dart';
import 'package:kith_app/domain/models/ipo/ipo_application.dart';

class MockIpoApiAdapter implements IpoApiAdapter {
  final bool configured;
  final List<IpoDto> mockDtos;

  MockIpoApiAdapter({
    this.configured = true,
    this.mockDtos = const [],
  });

  @override
  bool get isConfigured => configured;

  @override
  String get sourceAttribution => 'Verified Exchange Feed';

  @override
  Future<List<IpoDto>> fetchIpos() async {
    if (!configured) {
      throw const IpoApiNotConfiguredException('Mock API is unconfigured.');
    }
    return mockDtos;
  }

  @override
  Future<IpoDto?> fetchIpoDetails(String idOrSymbol) async {
    return mockDtos.where((d) => d.id == idOrSymbol || d.symbol == idOrSymbol).firstOrNull;
  }

  @override
  Future<List<IpoGmpHistoryDto>> fetchGmpHistory(String idOrSymbol) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
  });

  group('IPO Data Layer & DTO Mapping', () {
    test('IpoDto correctly serializes and deserializes JSON', () {
      final json = {
        'id': 'ipo_test_1',
        'name': 'Test Tech Solutions',
        'company_name': 'Test Tech Solutions Ltd',
        'symbol': 'TESTTECH',
        'category': 'mainboard',
        'issue_type': 'book_built',
        'min_price': 100,
        'max_price': 105,
        'lot_size': 140,
        'issue_size_crores': 1200.50,
        'open_date': '2026-11-05T00:00:00.000Z',
        'close_date': '2026-11-08T00:00:00.000Z',
        'allotment_date': '2026-11-10T00:00:00.000Z',
        'refund_date': '2026-11-11T00:00:00.000Z',
        'listing_date': '2026-11-13T00:00:00.000Z',
        'gmp': 45,
        'status': 'upcoming',
      };

      final dto = IpoDto.fromJson(json);
      expect(dto.id, 'ipo_test_1');
      expect(dto.companyName, 'Test Tech Solutions Ltd');
      expect(dto.minPrice, 100);
      expect(dto.maxPrice, 105);
      expect(dto.lotSize, 140);
      expect(dto.gmp, 45);

      final outJson = dto.toJson();
      expect(outJson['symbol'], 'TESTTECH');
      expect(outJson['max_price'], 105);
    });

    test('IpoDataMapper maps DTO to domain model with exact attributes', () {
      final dto = IpoDto(
        id: 'ipo_2',
        name: 'Apex Innovations',
        companyName: 'Apex Innovations',
        symbol: 'APEX',
        minPrice: 200,
        maxPrice: 215,
        lotSize: 70,
        issueSizeCrores: 500.0,
        openDate: '2026-11-01',
        closeDate: '2026-11-04',
        allotmentDate: '2026-11-06',
        refundDate: '2026-11-07',
        listingDate: '2026-11-09',
        gmp: 65,
        gmpLastValidAt: DateTime.now().toUtc().toIso8601String(),
      );

      final domain = IpoDataMapper.mapDtoToDomain(dto);
      expect(domain.id, 'ipo_2');
      expect(domain.companyName, 'Apex Innovations');
      expect(domain.minPrice, 200);
      expect(domain.maxPrice, 215);
      expect(domain.lotSize, 70);
      expect(domain.minInvestmentRupees, 215 * 70);
      expect(domain.gmp, 65);
      expect(domain.estimatedListingPrice, 215 + 65); // 280
      expect(domain.estimatedGainPercentage, closeTo(30.23, 0.05));

      // Legacy DTO with no timestamp cannot establish freshness
      final legacyDto = const IpoDto(
        id: 'ipo_legacy',
        name: 'Legacy Unverified Co',
        maxPrice: 100,
        gmp: 30,
      );
      final legacyDomain = IpoDataMapper.mapDtoToDomain(legacyDto);
      expect(legacyDomain.gmp, equals(30), reason: 'Raw GMP is preserved');
      expect(legacyDomain.isGmpExpired, isTrue, reason: 'Legacy records without gmpLastValidAt cannot establish freshness');
      expect(legacyDomain.currentGmp, isNull);
      expect(legacyDomain.estimatedListingPrice, isNull);
    });

    test('IpoGuruApiAdapter throws IpoApiNotConfiguredException when unconfigured', () async {
      final adapter = IpoGuruApiAdapter();
      expect(adapter.isConfigured, isFalse);
      expect(() async => await adapter.fetchIpos(), throwsA(isA<IpoApiNotConfiguredException>()));
    });

    test('IpoService returns mapped domain items and updates storage cache', () async {
      final mockAdapter = MockIpoApiAdapter(
        mockDtos: [
          const IpoDto(
            id: 'mock_1',
            name: 'Mock Tech Ltd',
            minPrice: 100,
            maxPrice: 110,
            lotSize: 50,
          ),
        ],
      );

      final service = IpoService(
        apiAdapter: mockAdapter,
        storage: storage,
      );

      final ipos = await service.fetchIpoCatalog();
      expect(ipos.isNotEmpty, isTrue);
      expect(ipos.first.id, 'mock_1');
      expect(service.sourceAttribution, 'Verified Exchange Feed');

      // Check offline persistence in storage
      final savedInStorage = storage.getSavedIpos();
      expect(savedInStorage.isNotEmpty, isTrue);
      expect(savedInStorage.first['id'], 'mock_1');
    });

    test('IpoService falls back to cached data when adapter throws unconfigured error', () async {
      // Pre-seed storage cache
      await storage.saveIpos([
        {
          'id': 'cached_ipo_1',
          'name': 'Cached Corp',
          'companyName': 'Cached Corp',
          'symbol': 'CACHED',
          'marketType': 'mainboard',
          'status': 'open',
          'openDate': DateTime.now().toIso8601String(),
          'closeDate': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          'minPrice': 50,
          'maxPrice': 55,
          'lotSize': 100,
          'lastUpdated': DateTime.now().toIso8601String(),
        }
      ]);
      await storage.setIposLastUpdated(DateTime.now());

      final unconfiguredAdapter = MockIpoApiAdapter(configured: false);
      final service = IpoService(
        apiAdapter: unconfiguredAdapter,
        storage: storage,
      );

      final ipos = await service.fetchIpoCatalog();
      expect(ipos.length, 1);
      expect(ipos.first.id, 'cached_ipo_1');
    });
  });

  group('Price Band & Lot Calculations', () {
    final testIpo = Ipo(
      id: 'ipo_band_test',
      name: 'Band Test Corp',
      companyName: 'Band Test Corp',
      symbol: 'BAND',
      minPrice: 150,
      maxPrice: 160,
      lotSize: 90,
      issueSizeCrores: 400.0,
      openDate: DateTime(2026, 11, 1),
      closeDate: DateTime(2026, 11, 4),
      allotmentDate: DateTime(2026, 11, 6),
      listingDate: DateTime(2026, 11, 9),
      marketType: IpoMarketType.mainboard,
      status: IpoStatus.open,
      lastUpdated: DateTime.now(),
    );

    test('Cut-off price is upper price band', () {
      expect(testIpo.maxPrice, 160);
      final cutoffLotCostRupees = testIpo.lotSize * testIpo.maxPrice;
      expect(cutoffLotCostRupees, 14400);
    });

    test('Custom price validation correctly enforces price band limits', () {
      bool isPriceValid(int price, Ipo ipo) {
        return price >= ipo.minPrice && price <= ipo.maxPrice;
      }

      expect(isPriceValid(149, testIpo), isFalse); // Below lower band
      expect(isPriceValid(150, testIpo), isTrue);  // At lower band
      expect(isPriceValid(155, testIpo), isTrue);  // Inside band
      expect(isPriceValid(160, testIpo), isTrue);  // At upper band
      expect(isPriceValid(161, testIpo), isFalse); // Above upper band
    });
  });

  group('Multi-Account Planning & Financial Calculations', () {
    test('Calculates multi-account mandate and application amounts accurately in paise', () {
      const lotSize = 100;
      const bidPrice = 250; // ₹250
      const account1Lots = 1;
      const account2Lots = 2;
      const account3Lots = 3;

      final acc1Paise = IpoApplication.calculateApplicationAmountPaise(
        lots: account1Lots,
        lotSize: lotSize,
        bidPriceRupees: bidPrice,
      );
      final acc2Paise = IpoApplication.calculateApplicationAmountPaise(
        lots: account2Lots,
        lotSize: lotSize,
        bidPriceRupees: bidPrice,
      );
      final acc3Paise = IpoApplication.calculateApplicationAmountPaise(
        lots: account3Lots,
        lotSize: lotSize,
        bidPriceRupees: bidPrice,
      );

      // Account 1: 1 * 100 * 250 = ₹25,000 = 2,500,000 paise
      expect(acc1Paise, 2500000);
      // Account 2: 2 * 100 * 250 = ₹50,000 = 5,000,000 paise
      expect(acc2Paise, 5000000);
      // Account 3: 3 * 100 * 250 = ₹75,000 = 7,500,000 paise
      expect(acc3Paise, 7500000);

      final totalMandatePaise = acc1Paise + acc2Paise + acc3Paise;
      // Total: ₹150,000 = 15,000,000 paise
      expect(totalMandatePaise, 15000000);
    });

    test('Zero double-counting invariant in application lifecycle states', () {
      const mandatePaise = 1500000; // ₹15,000 (1 lot @ ₹150, 100 shares)

      // State 1: Planned (Pre-mandate approval)
      final plannedApp = IpoApplication(
        id: 'app_1',
        ipoId: 'ipo_test',
        ipoName: 'Test Corp',
        userId: 'u1',
        applicationAccountId: 'acc_1',
        accountDisplayName: 'Self Demat',
        accountMaskedPan: 'XXXXX1234F',
        applicationDate: DateTime.now(),
        lotsApplied: 1,
        lotSize: 100,
        bidPriceInRupees: 150,
        applicationAmountInPaise: mandatePaise,
        fundings: const [],
        status: IpoApplicationStatus.planned,
        mandateAmountInPaise: mandatePaise,
        upiMandateStatus: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(plannedApp.currentBlockedAmountInPaise, 0);
      expect(plannedApp.actualAllottedAmountInPaise, 0);
      expect(plannedApp.outstandingRefundInPaise, 0);

      // State 2: Mandate Approved (Funds blocked in bank via ASBA/UPI)
      final approvedApp = plannedApp.copyWith(
        status: IpoApplicationStatus.mandateApproved,
        upiMandateStatus: 'approved',
      );

      expect(approvedApp.currentBlockedAmountInPaise, mandatePaise);
      expect(approvedApp.actualAllottedAmountInPaise, 0);
      expect(approvedApp.outstandingRefundInPaise, 0);

      // State 3: Fully Allotted (Funds debited, shares credited, unblocked)
      final allottedApp = approvedApp.copyWith(
        status: IpoApplicationStatus.allotted,
        allottedLots: 1,
        actualInvestedAmountInPaise: mandatePaise,
      );

      expect(allottedApp.currentBlockedAmountInPaise, 0); // No longer blocked
      expect(allottedApp.actualAllottedAmountInPaise, mandatePaise); // Invested
      expect(allottedApp.outstandingRefundInPaise, 0);

      // Invariant: Blocked + Invested == Mandate
      expect(allottedApp.currentBlockedAmountInPaise + allottedApp.actualAllottedAmountInPaise, mandatePaise);

      // State 4: Not Allotted (Mandate revoked, full refund due)
      final notAllottedApp = approvedApp.copyWith(
        status: IpoApplicationStatus.notAllotted,
        allottedLots: 0,
      );

      expect(notAllottedApp.currentBlockedAmountInPaise, 0);
      expect(notAllottedApp.actualAllottedAmountInPaise, 0);
      expect(notAllottedApp.outstandingRefundInPaise, mandatePaise);

      // Invariant: Debited (0) + Outstanding Refund (15,000) == Mandate (15,000)
      expect(notAllottedApp.actualAllottedAmountInPaise + notAllottedApp.outstandingRefundInPaise, mandatePaise);

      // State 5: Refund Credited
      final refundCreditedApp = notAllottedApp.copyWith(
        status: IpoApplicationStatus.refundCredited,
        refundCreditedAmountInPaise: mandatePaise,
      );

      expect(refundCreditedApp.currentBlockedAmountInPaise, 0);
      expect(refundCreditedApp.outstandingRefundInPaise, 0);
      expect(refundCreditedApp.refundCreditedAmountInPaise, mandatePaise);
    });

    test('Partial Allotment correctly splits invested funds and pending refund', () {
      // Applied for 4 lots @ ₹100, lot size 50 = ₹20,000 (2,000,000 paise)
      const appliedLots = 4;
      const lotSize = 50;
      const bidPrice = 100;
      const mandatePaise = appliedLots * lotSize * bidPrice * 100; // 2,000,000 paise

      // Allotted 1 lot = 1 * 50 * 100 * 100 = 500,000 paise (₹5,000)
      const allottedLots = 1;
      const allottedPaise = allottedLots * lotSize * bidPrice * 100; // 500,000 paise

      final partialApp = IpoApplication(
        id: 'partial_1',
        ipoId: 'ipo_part',
        ipoName: 'Partial Corp',
        userId: 'u1',
        applicationAccountId: 'acc_1',
        accountDisplayName: 'Main Demat',
        accountMaskedPan: 'XXXXX9999Z',
        applicationDate: DateTime.now(),
        lotsApplied: appliedLots,
        allottedLots: allottedLots,
        lotSize: lotSize,
        bidPriceInRupees: bidPrice,
        applicationAmountInPaise: mandatePaise,
        mandateAmountInPaise: mandatePaise,
        fundings: const [],
        status: IpoApplicationStatus.partiallyAllotted,
        actualInvestedAmountInPaise: allottedPaise,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(partialApp.actualAllottedAmountInPaise, 500000); // ₹5,000 invested
      expect(partialApp.expectedRefundInPaise, 1500000);      // ₹15,000 refund expected
      expect(partialApp.outstandingRefundInPaise, 1500000);   // ₹15,000 pending before credit

      // Invariant: Debited + Expected Refund == Total Mandate Amount
      expect(
        partialApp.actualAllottedAmountInPaise + partialApp.expectedRefundInPaise,
        partialApp.mandateAmountInPaise,
      );

      // Now partially refund 10,000 credited
      final partialCredited = partialApp.copyWith(
        refundCreditedAmountInPaise: 1000000,
      );
      expect(partialCredited.outstandingRefundInPaise, 500000); // 500,000 still pending
    });
  });
}
