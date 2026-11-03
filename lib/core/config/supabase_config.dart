import 'package:flutter/foundation.dart';

/// Supabase project configuration with fail-closed security.
///
/// Prevents accidental fallback to the production database when developing,
/// testing, or staging.
class SupabaseConfig {
  SupabaseConfig._();

  static const String _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _envAppEnv = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const String _envProdSupabaseUrl = String.fromEnvironment('PROD_SUPABASE_URL');
  static const String _envProdAnonKey = String.fromEnvironment('PROD_SUPABASE_ANON_KEY');

  // Hardcoded production defaults are ONLY accessible when explicitly targeting production
  static const String _legacyProductionUrl = 'https://vcttgydigitisovoibvf.supabase.co';
  static const String _legacyProductionAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZjdHRneWRpZ2l0aXNvdm9pYnZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc1NTc4MjMsImV4cCI6MjEwMzEzMzgyM30.CbWNo_LZToLoB-F2vp_dodTvW0kf0hwlWvqle0QYULI';

  // Test overrides for hermetic unit testing
  static String? _testOverrideUrl;
  static String? _testOverrideAnonKey;
  static String? _testOverrideEnv;
  static bool _hasTestOverride = false;

  @visibleForTesting
  static void setTestOverrides({
    String? url,
    String? anonKey,
    String? environment,
  }) {
    _testOverrideUrl = url;
    _testOverrideAnonKey = anonKey;
    _testOverrideEnv = environment;
    _hasTestOverride = true;
  }

  @visibleForTesting
  static void resetTestOverrides() {
    _testOverrideUrl = null;
    _testOverrideAnonKey = null;
    _testOverrideEnv = null;
    _hasTestOverride = false;
  }

  static String get environment =>
      _hasTestOverride && _testOverrideEnv != null ? _testOverrideEnv! : _envAppEnv;

  static bool get isProduction => environment == 'production';

  /// Whether Supabase has been explicitly and properly configured for the current environment.
  /// Fails closed: returns false if required configuration is missing or incomplete,
  /// preventing silent fallbacks to production.
  static bool get isConfigured {
    if (_hasTestOverride) {
      final u = _testOverrideUrl ?? '';
      final a = _testOverrideAnonKey ?? '';
      return u.isNotEmpty &&
          a.isNotEmpty &&
          !u.contains('REPLACE_WITH') &&
          !a.contains('REPLACE_WITH');
    }

    // 1. If explicit SUPABASE_URL and SUPABASE_ANON_KEY are provided, use them
    if (_envSupabaseUrl.isNotEmpty && _envAnonKey.isNotEmpty) {
      return !_envSupabaseUrl.contains('REPLACE_WITH') && !_envAnonKey.contains('REPLACE_WITH');
    }

    // 2. In non-production environments (development, staging, test), NEVER fall back to production
    if (!isProduction) {
      return false;
    }

    // 3. In production, require either explicit PROD_SUPABASE_* or legacy production default
    if (_envProdSupabaseUrl.isNotEmpty && _envProdAnonKey.isNotEmpty) {
      return true;
    }

    return true;
  }

  /// Current Supabase URL.
  /// Fails closed: returns empty string if unconfigured in development/staging,
  /// preventing accidental connection to production.
  static String get url {
    if (_hasTestOverride) {
      return _testOverrideUrl ?? '';
    }

    if (_envSupabaseUrl.isNotEmpty) {
      return _envSupabaseUrl;
    }

    if (!isProduction) {
      return '';
    }

    if (_envProdSupabaseUrl.isNotEmpty) {
      return _envProdSupabaseUrl;
    }

    return _legacyProductionUrl;
  }

  /// Current Supabase Anon Key.
  /// Fails closed: returns empty string if unconfigured in development/staging,
  /// preventing accidental connection to production.
  static String get anonKey {
    if (_hasTestOverride) {
      return _testOverrideAnonKey ?? '';
    }

    if (_envAnonKey.isNotEmpty) {
      return _envAnonKey;
    }

    if (!isProduction) {
      return '';
    }

    if (_envProdAnonKey.isNotEmpty) {
      return _envProdAnonKey;
    }

    return _legacyProductionAnonKey;
  }
}
