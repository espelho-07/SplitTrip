import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/domain/models/ipo/ipo.dart';
import 'package:kith_app/data/services/ipo_data_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST: IPO Screen Cache & GMP Expiry Handling', () {
    testWidgets('Scenario O: IPO screen cache parses PostgreSQL join format safely without network', (tester) async {
      final mockJoinedRow = {
        'id': 'test_cache_ipo_01',
        'name': 'Staging Cache IPO Ltd',
        'company_name': 'Staging Cache IPO Limited',
        'symbol': 'STGCACHE',
        'market_type': 'mainboard',
        'status': 'open',
        'open_date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'close_date': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'allotment_date': DateTime.now().add(const Duration(days: 4)).toIso8601String(),
        'listing_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'min_price': 250,
        'max_price': 275,
        'lot_size': 50,
        'issue_size_crores': 500.0,
        'gmp': 45,
        'gmp_last_valid_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'slug': 'staging-cache-ipo',
        'ipo_gmp_cache': [
          {
            'id': 'gmp_staging-cache-ipo',
            'ipo_id': 'test_cache_ipo_01',
            'slug': 'staging-cache-ipo',
            'ipo_name': 'Staging Cache IPO Ltd',
            'price_band_min': 250,
            'price_band_max': 275,
            'gmp_raw': 45,
            'gmp_last_valid_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
            'estimated_listing_price': 320.0,
            'estimated_gain_percentage': 16.36,
          }
        ]
      };

      final ipo = Ipo.fromJson(mockJoinedRow);
      expect(ipo.id, equals('test_cache_ipo_01'));
      expect(ipo.name, equals('Staging Cache IPO Ltd'));
      expect(ipo.currentGmp, equals(45));
      expect(ipo.isGmpExpired, isFalse);
      expect(ipo.estimatedListingPrice, equals(320));
      expect(ipo.estimatedGainPercentage, isNotNull);
      expect(ipo.estimatedGainPercentage!, closeTo(16.36, 0.1));

      // Unconfigured Supabase client fails closed cleanly without crash
      final provider = SupabaseIpoDataProvider();
      final list = await provider.fetchIpos();
      expect(list, isA<List<Ipo>>());
    });

    testWidgets('Scenario P: GMP expired (>24h), listed status, and valid zero GMP handling', (tester) async {
      // 1. Valid Zero GMP (Par / Flat listing quote)
      final zeroGmpRow = {
        'id': 'zero_gmp_ipo',
        'name': 'Zero Premium Ltd',
        'company_name': 'Zero Premium Limited',
        'symbol': 'ZEROPREM',
        'status': 'open',
        'open_date': DateTime.now().toIso8601String(),
        'close_date': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'min_price': 100,
        'max_price': 100,
        'lot_size': 100,
        'gmp': 0, // Explicit zero
        'gmp_last_valid_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      };
      final zeroIpo = Ipo.fromJson(zeroGmpRow);
      expect(zeroIpo.gmp, equals(0));
      expect(zeroIpo.currentGmp, equals(0));
      expect(zeroIpo.isGmpExpired, isFalse);
      expect(zeroIpo.estimatedListingPrice, equals(100)); // 100 + 0

      // 2. Expired GMP (>24 hours old quote)
      final expiredGmpRow = {
        'id': 'expired_gmp_ipo',
        'name': 'Expired Premium Ltd',
        'company_name': 'Expired Premium Limited',
        'symbol': 'EXPIRED',
        'status': 'open',
        'open_date': DateTime.now().toIso8601String(),
        'close_date': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'min_price': 100,
        'max_price': 100,
        'lot_size': 100,
        'gmp': 25,
        'gmp_last_valid_at': DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
      };
      final expiredIpo = Ipo.fromJson(expiredGmpRow);
      expect(expiredIpo.isGmpExpired, isTrue);
      expect(expiredIpo.currentGmp, isNull, reason: 'Expired GMP must evaluate to null');
      expect(expiredIpo.estimatedListingPrice, isNull);
      expect(expiredIpo.estimatedGainPercentage, isNull);

      // 3. Listed status immediately clears GMP quotes
      final listedRow = {
        'id': 'listed_ipo',
        'name': 'Already Listed Ltd',
        'company_name': 'Already Listed Limited',
        'symbol': 'ALRLIST',
        'status': 'listed',
        'open_date': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        'close_date': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        'listing_date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'min_price': 100,
        'max_price': 100,
        'lot_size': 100,
        'gmp': 30, // Incoming GMP on listed issue must be ignored
      };
      final listedIpo = Ipo.fromJson(listedRow);
      expect(listedIpo.isGmpExpired, isTrue);
      expect(listedIpo.currentGmp, isNull);
      expect(listedIpo.estimatedListingPrice, isNull);
    });
  });
}
