import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/config/supabase_config.dart';

void main() {
  group('SupabaseConfig Fail-Closed Security Tests', () {
    tearDown(() {
      SupabaseConfig.resetTestOverrides();
    });

    test('1. Missing URL: fails closed in development/staging without production fallback', () {
      SupabaseConfig.setTestOverrides(
        url: '',
        anonKey: 'valid_test_anon_key_123',
        environment: 'staging',
      );

      expect(SupabaseConfig.isConfigured, isFalse);
      expect(SupabaseConfig.url, isEmpty);
      expect(SupabaseConfig.url, isNot(contains('vcttgydigitisovoibvf')));
    });

    test('2. Missing anon key: fails closed without production fallback', () {
      SupabaseConfig.setTestOverrides(
        url: 'https://staging-project.supabase.co',
        anonKey: '',
        environment: 'staging',
      );

      expect(SupabaseConfig.isConfigured, isFalse);
      expect(SupabaseConfig.anonKey, isEmpty);
      expect(SupabaseConfig.anonKey, isNot(contains('eyJhbGciOiJIUzI1NiInR5cCI6IkpXVCJ9')));
    });

    test('3. Explicit staging configuration: correctly configured and returns staging endpoints', () {
      SupabaseConfig.setTestOverrides(
        url: 'https://qfuptgzksecgyjgohtxi.supabase.co',
        anonKey: 'staging_anon_key_verified_456',
        environment: 'staging',
      );

      expect(SupabaseConfig.isConfigured, isTrue);
      expect(SupabaseConfig.url, equals('https://qfuptgzksecgyjgohtxi.supabase.co'));
      expect(SupabaseConfig.anonKey, equals('staging_anon_key_verified_456'));
      expect(SupabaseConfig.isProduction, isFalse);
    });

    test('4. Explicit production configuration: accessible only when environment is production', () {
      SupabaseConfig.setTestOverrides(
        url: 'https://custom-prod.supabase.co',
        anonKey: 'custom_prod_anon_key_789',
        environment: 'production',
      );

      expect(SupabaseConfig.isConfigured, isTrue);
      expect(SupabaseConfig.isProduction, isTrue);
      expect(SupabaseConfig.url, equals('https://custom-prod.supabase.co'));
      expect(SupabaseConfig.anonKey, equals('custom_prod_anon_key_789'));
    });

    test('5. Accidental production fallback prevention: development never leaks production URL', () {
      SupabaseConfig.setTestOverrides(
        url: '',
        anonKey: '',
        environment: 'development',
      );

      expect(SupabaseConfig.isConfigured, isFalse);
      expect(SupabaseConfig.isProduction, isFalse);
      expect(SupabaseConfig.url, isEmpty);
      expect(SupabaseConfig.anonKey, isEmpty);
      expect(SupabaseConfig.url, isNot(contains('vcttgydigitisovoibvf')));
    });

    test('6. Placeholder detection: rejected as unconfigured', () {
      SupabaseConfig.setTestOverrides(
        url: 'https://REPLACE_WITH_PROJECT_REF.supabase.co',
        anonKey: 'REPLACE_WITH_ANON_KEY',
        environment: 'staging',
      );

      expect(SupabaseConfig.isConfigured, isFalse);
    });
  });
}
