import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/config/app_config.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/data/services/ipo_data_provider.dart';
import 'package:kith_app/domain/models/ipo/ipo.dart';
import 'package:kith_app/presentation/viewmodels/ipo_viewmodel.dart';
import 'package:kith_app/data/repositories/ipo_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IPO Guru Centralized Cache Architecture Tests', () {
    test('Zero Client Credentials: AppConfig contains no external API keys or URLs', () {
      expect(AppConfig.ipoApiKey, isEmpty, reason: 'Client must never contain IPO Guru or external API key');
      expect(AppConfig.ipoApiBaseUrl, isEmpty, reason: 'Client must never target external IPO scrapers directly');
    });

    test('Ipo.fromJson parses PostgreSQL cache schema and joined ipo_gmp_cache', () {
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      final pgRow = {
        'id': 'ipo_acme_tech',
        'name': 'Acme Technologies Limited',
        'company_name': 'Acme Technologies Limited',
        'symbol': 'ACMETECH',
        'market_type': 'mainboard',
        'status': 'open',
        'open_date': '2026-11-01T00:00:00Z',
        'close_date': '2026-11-03T00:00:00Z',
        'allotment_date': '2026-11-04T00:00:00Z',
        'listing_date': '2026-11-07T00:00:00Z',
        'min_price': 250,
        'max_price': 265,
        'lot_size': 56,
        'issue_size_crores': 850.5,
        'slug': 'acme-tech',
        'source_updated_at': nowUtcIso,
        'fetched_at': nowUtcIso,
        'is_stale': false,
        'last_updated': nowUtcIso,
        'ipo_gmp_cache': [
          {
            'id': 'gmp_acme-tech',
            'ipo_id': 'ipo_acme_tech',
            'slug': 'acme-tech',
            'ipo_name': 'Acme Technologies Limited',
            'price_band_min': 250,
            'price_band_max': 265,
            'gmp_raw': 45,
            'gmp_last_valid_at': nowUtcIso,
            'estimated_listing_price': 310,
            'estimated_gain_percentage': 16.98,
            'is_stale': false,
          }
        ],
      };

      final ipo = Ipo.fromJson(pgRow);
      expect(ipo.id, equals('ipo_acme_tech'));
      expect(ipo.name, equals('Acme Technologies Limited'));
      expect(ipo.slug, equals('acme-tech'));
      expect(ipo.gmp, equals(45), reason: 'Should extract gmp_raw from joined ipo_gmp_cache');
      expect(ipo.gmpLastValidAt, isNotNull);
      expect(ipo.isGmpExpired, isFalse);
      expect(ipo.currentGmp, equals(45));
      expect(ipo.estimatedListingPrice, equals(310));
      expect(ipo.isStale, isFalse);
    });

    test('Ipo.fromJson distinguishes null GMP from 0 (par/flat) GMP', () {
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      // 1. Unquoted / null GMP
      final nullGmpRow = {
        'id': 'ipo_null_gmp',
        'name': 'Unquoted SME Ltd',
        'min_price': 100,
        'max_price': 100,
        'lot_size': 1000,
        'ipo_gmp_cache': [
          {
            'slug': 'unquoted-sme',
            'gmp_raw': null,
          }
        ],
      };
      final nullIpo = Ipo.fromJson(nullGmpRow);
      expect(nullIpo.gmp, isNull, reason: 'Unquoted GMP must remain null');
      expect(nullIpo.isGmpExpired, isFalse, reason: 'Unquoted is not expired');
      expect(nullIpo.currentGmp, isNull);
      expect(nullIpo.estimatedListingPrice, isNull);

      // 2. Quoted at flat / 0 GMP with fresh timestamp
      final zeroGmpRow = {
        'id': 'ipo_zero_gmp',
        'name': 'Flat Mainboard Ltd',
        'min_price': 500,
        'max_price': 525,
        'lot_size': 28,
        'gmp_last_valid_at': nowUtcIso,
        'ipo_gmp_cache': [
          {
            'slug': 'flat-mainboard',
            'gmp_raw': 0,
            'gmp_last_valid_at': nowUtcIso,
          }
        ],
      };
      final zeroIpo = Ipo.fromJson(zeroGmpRow);
      expect(zeroIpo.gmp, equals(0), reason: 'Zero GMP must be strictly 0');
      expect(zeroIpo.isGmpExpired, isFalse, reason: 'Fresh 0 GMP is valid');
      expect(zeroIpo.currentGmp, equals(0), reason: 'Zero GMP preserved');
      expect(zeroIpo.estimatedListingPrice, equals(525));
    });

    test('Read-Time Expiry: GMP older than 24 hours expires and is hidden from current quotes', () {
      final now = DateTime.now().toUtc();
      final staleTime = now.subtract(const Duration(hours: 26)).toIso8601String();
      final freshTime = now.subtract(const Duration(hours: 2)).toIso8601String();

      // 1. Expired (>24 hours) GMP record
      final expiredRow = {
        'id': 'ipo_stale_gmp',
        'name': 'Stale GMP Technologies Ltd',
        'min_price': 100,
        'max_price': 110,
        'lot_size': 100,
        'status': 'open',
        'gmp': 25,
        'gmp_last_valid_at': staleTime,
        'source_updated_at': staleTime,
      };
      final expiredIpo = Ipo.fromJson(expiredRow);
      expect(expiredIpo.gmp, equals(25), reason: 'Raw historical GMP should be preserved');
      expect(expiredIpo.gmpLastValidAt, isNotNull);
      expect(expiredIpo.isGmpExpired, isTrue, reason: 'GMP older than 24 hours must be marked expired');
      expect(expiredIpo.currentGmp, isNull, reason: 'currentGmp must return null when expired');
      expect(expiredIpo.estimatedListingPrice, isNull, reason: 'Estimated listing price must be null when expired');
      expect(expiredIpo.estimatedGainPercentage, isNull);

      // 2. Fresh (<24 hours) GMP record
      final freshRow = {
        'id': 'ipo_fresh_gmp',
        'name': 'Fresh GMP Technologies Ltd',
        'min_price': 100,
        'max_price': 110,
        'lot_size': 100,
        'status': 'open',
        'gmp': 25,
        'gmp_last_valid_at': freshTime,
        'source_updated_at': freshTime,
      };
      final freshIpo = Ipo.fromJson(freshRow);
      expect(freshIpo.gmp, equals(25));
      expect(freshIpo.isGmpExpired, isFalse, reason: 'GMP within 24 hours must not be expired');
      expect(freshIpo.currentGmp, equals(25), reason: 'currentGmp returns valid quote');
      expect(freshIpo.estimatedListingPrice, equals(135), reason: 'Cutoff 110 + GMP 25 = 135');
      expect(freshIpo.estimatedGainPercentage, closeTo(22.72, 0.05));

      // 3. Listed IPO immediately expires active GMP
      final listedRow = {
        'id': 'ipo_listed_co',
        'name': 'Listed Co Ltd',
        'min_price': 100,
        'max_price': 110,
        'lot_size': 100,
        'status': 'listed',
        'gmp': 30,
        'gmp_last_valid_at': freshTime,
      };
      final listedIpo = Ipo.fromJson(listedRow);
      expect(listedIpo.isGmpExpired, isTrue, reason: 'Listed status immediately invalidates active GMP');
      expect(listedIpo.currentGmp, isNull);
      expect(listedIpo.estimatedListingPrice, isNull);

      // 4. Missing GMP is distinguishable from expired GMP
      final unquotedRow = {
        'id': 'ipo_unquoted_co',
        'name': 'Unquoted Co Ltd',
        'min_price': 100,
        'max_price': 110,
        'lot_size': 100,
        'status': 'open',
        'gmp': null,
      };
      final unquotedIpo = Ipo.fromJson(unquotedRow);
      expect(unquotedIpo.gmp, isNull);
      expect(unquotedIpo.isGmpExpired, isFalse, reason: 'Unquoted issue is not expired; it was never quoted');
      expect(unquotedIpo.currentGmp, isNull);

      // 5. Explicit Legacy-Record Policy: Missing gmp_last_valid_at cannot establish freshness
      // Even if source_updated_at is fresh, it represents general record changes, not GMP updates.
      final legacyRow = {
        'id': 'ipo_legacy_co',
        'name': 'Legacy Co Ltd',
        'min_price': 100,
        'max_price': 110,
        'lot_size': 100,
        'status': 'open',
        'gmp': 40,
        'gmp_last_valid_at': null,
        'source_updated_at': freshTime, // Fresh record update MUST NOT certify fresh GMP!
      };
      final legacyIpo = Ipo.fromJson(legacyRow);
      expect(legacyIpo.gmp, equals(40), reason: 'Raw GMP is preserved for historical audit');
      expect(legacyIpo.isGmpExpired, isTrue, reason: 'source_updated_at cannot certify GMP freshness; unverified quotes expire');
      expect(legacyIpo.currentGmp, isNull);
      expect(legacyIpo.estimatedListingPrice, isNull);

      // 6. Future Timestamp Protection: Anomaly beyond 5-minute skew tolerance is untrusted
      final farFutureTime = now.add(const Duration(hours: 3)).toIso8601String();
      final farFutureRow = {
        'id': 'ipo_future_co',
        'name': 'Future Anomaly Ltd',
        'min_price': 100,
        'max_price': 110,
        'status': 'open',
        'gmp': 50,
        'gmp_last_valid_at': farFutureTime,
      };
      final farFutureIpo = Ipo.fromJson(farFutureRow);
      expect(farFutureIpo.isGmpExpired, isTrue, reason: 'Timestamps hours in the future must be rejected as untrusted');
      expect(farFutureIpo.currentGmp, isNull);

      // 7. Minor Device Clock Skew Tolerance: Timestamps within 5 minutes in future are accepted
      final minorFutureTime = now.add(const Duration(minutes: 2)).toIso8601String();
      final minorFutureRow = {
        'id': 'ipo_skew_co',
        'name': 'Minor Skew Ltd',
        'min_price': 100,
        'max_price': 110,
        'status': 'open',
        'gmp': 50,
        'gmp_last_valid_at': minorFutureTime,
      };
      final minorFutureIpo = Ipo.fromJson(minorFutureRow);
      expect(minorFutureIpo.isGmpExpired, isFalse, reason: 'Small clock drift <= 5 minutes is safely accommodated');
      expect(minorFutureIpo.currentGmp, equals(50));

      // 8. Corrupt / Epoch 0 Timestamp Protection
      final corruptRow = {
        'id': 'ipo_corrupt_co',
        'name': 'Corrupt Date Ltd',
        'min_price': 100,
        'max_price': 110,
        'status': 'open',
        'gmp': 50,
        'gmp_last_valid_at': '1970-01-01T00:00:00Z',
      };
      final corruptIpo = Ipo.fromJson(corruptRow);
      expect(corruptIpo.isGmpExpired, isTrue, reason: 'Epoch 0 or ancient timestamps are corrupt and rejected');
      expect(corruptIpo.currentGmp, isNull);

      // 9. Expired Flat GMP: A 0 GMP quote older than 24 hours expires
      final expiredFlatRow = {
        'id': 'ipo_expired_flat',
        'name': 'Expired Flat Ltd',
        'min_price': 100,
        'max_price': 100,
        'status': 'open',
        'gmp': 0,
        'gmp_last_valid_at': staleTime,
      };
      final expiredFlatIpo = Ipo.fromJson(expiredFlatRow);
      expect(expiredFlatIpo.gmp, equals(0));
      expect(expiredFlatIpo.isGmpExpired, isTrue, reason: 'Stale flat quotes also expire after 24h');
      expect(expiredFlatIpo.currentGmp, isNull);
    });

    test('SupabaseIpoDataProvider handles unconfigured Supabase gracefully without crash', () async {
      final provider = SupabaseIpoDataProvider(client: null);
      final ipos = await provider.fetchIpos();
      expect(ipos, isEmpty, reason: 'Must return empty list safely when database is unconfigured');
    });

    test('IpoViewModel exposes IPO Guru attribution and disclaimer URL', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final syncService = SyncService(storage);
      final apiClient = ApiClient();
      final personalRepo = PersonalRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
      final dataProvider = SupabaseIpoDataProvider(client: null);
      final ipoRepo = IpoRepository(
        storage: storage,
        dataProvider: dataProvider,
        personalRepo: personalRepo,
      );

      final viewModel = IpoViewModel(ipoRepo: ipoRepo);
      expect(viewModel.sourceAttribution, equals('Data: IPO Guru'));
      expect(viewModel.attributionUrl, equals('https://ipoguru.in'));
      expect(viewModel.gmpDisclaimer, contains('Grey Market Premium (GMP) is indicative'));
    });
  });
}
