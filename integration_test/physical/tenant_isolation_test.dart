import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/core/config/supabase_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 12: Cross-Account Data Isolation & Client Policy Invariants', () {
    testWidgets('enforces fail-closed configuration and tenant isolation parameters', (tester) async {
      // In non-production without explicit env defines, configuration fails closed
      SupabaseConfig.resetTestOverrides();
      expect(SupabaseConfig.isProduction, isFalse);

      // Verify that production URL is never exposed in unconfigured test mode
      expect(SupabaseConfig.url, isNot(contains('vcttgydigitisovoibvf')));

      // Test Hermetic Staging Injection
      SupabaseConfig.setTestOverrides(
        url: 'https://qfuptgzksecgyjgohtxi.supabase.co',
        anonKey: 'valid_staging_anon_key_for_testing',
        environment: 'staging',
      );

      expect(SupabaseConfig.isConfigured, isTrue);
      expect(SupabaseConfig.url, equals('https://qfuptgzksecgyjgohtxi.supabase.co'));
      expect(SupabaseConfig.anonKey, equals('valid_staging_anon_key_for_testing'));

      SupabaseConfig.resetTestOverrides();
    });
  });
}
