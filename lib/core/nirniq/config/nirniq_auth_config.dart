import 'package:flutter/foundation.dart';

/// Centralized configuration for Nirniq Central Identity Provider.
///
/// Encapsulates the dedicated Central Supabase endpoints, public client keys,
/// and Google OAuth Web Client ID for native token exchange.
///
/// Invariants:
/// - Never contains client secrets, service-role keys, or database passwords.
/// - Only exposes public, client-safe keys approved for client bundling.
/// - Supports hermetic test overrides for deterministic unit testing.
class NirniqAuthConfig {
  const NirniqAuthConfig._();

  static const String _envCentralSupabaseUrl =
      String.fromEnvironment('NIRNIQ_SUPABASE_URL', defaultValue: 'https://nbtbqsmlkcdpkysvpsum.supabase.co');

  static const String _envCentralSupabaseAnonKey = String.fromEnvironment(
    'NIRNIQ_SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_4CLRd4lf6aelQ3-XrOvZ1w_hFXfrBCY',
  );

  static const String _envGoogleWebClientId = String.fromEnvironment(
    'NIRNIQ_GOOGLE_WEB_CLIENT_ID',
    defaultValue: '975934560976-kspgmp7uh5f47e1004hk8qkqtbkjb7fm.apps.googleusercontent.com',
  );

  // Test overrides for hermetic unit testing
  static String? _testOverrideUrl;
  static String? _testOverrideAnonKey;
  static String? _testOverrideWebClientId;
  static bool _hasTestOverrides = false;

  /// Sets in-memory test overrides for hermetic testing.
  @visibleForTesting
  static void setTestOverrides({
    String? url,
    String? anonKey,
    String? webClientId,
  }) {
    _testOverrideUrl = url;
    _testOverrideAnonKey = anonKey;
    _testOverrideWebClientId = webClientId;
    _hasTestOverrides = true;
  }

  /// Resets in-memory test overrides.
  @visibleForTesting
  static void resetTestOverrides() {
    _testOverrideUrl = null;
    _testOverrideAnonKey = null;
    _testOverrideWebClientId = null;
    _hasTestOverrides = false;
  }

  /// Authoritative Central Supabase URL for Nirniq Identity.
  static String get centralSupabaseUrl =>
      _hasTestOverrides && _testOverrideUrl != null ? _testOverrideUrl! : _envCentralSupabaseUrl;

  /// Authoritative Central Supabase Publishable/Anon Key.
  static String get centralSupabaseAnonKey =>
      _hasTestOverrides && _testOverrideAnonKey != null ? _testOverrideAnonKey! : _envCentralSupabaseAnonKey;

  /// Google Web Client ID used as [serverClientId] in GoogleSignIn.
  ///
  /// This must be the Web Client ID (not Android Client ID) so that Google Play
  /// Services generates an ID Token with the audience matching Supabase GoTrue.
  static String get googleWebClientId =>
      _hasTestOverrides && _testOverrideWebClientId != null
          ? _testOverrideWebClientId!
          : _envGoogleWebClientId;

  /// Validates that the configuration is populated with non-placeholder values.
  static bool get isConfigured =>
      centralSupabaseUrl.isNotEmpty &&
      centralSupabaseAnonKey.isNotEmpty &&
      googleWebClientId.isNotEmpty &&
      !centralSupabaseUrl.contains('REPLACE_WITH');
}
