/// Supabase project configuration.
///
/// SUPABASE_URL and SUPABASE_ANON_KEY are SAFE to commit — the anon key is
/// designed to be public. Row-Level Security (RLS) policies control data access.
///
/// Override at build time:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  SupabaseConfig._();

  static const String _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Your Supabase project URL.
  /// Find it at: Supabase Dashboard > Project Settings > API > Project URL
  static const String _defaultUrl = 'https://REPLACE_WITH_YOUR_SUPABASE_URL.supabase.co';

  /// Your Supabase anon (public) key.
  /// Find it at: Supabase Dashboard > Project Settings > API > anon (public)
  static const String _defaultAnonKey = 'REPLACE_WITH_YOUR_SUPABASE_ANON_KEY';

  static String get url => _envSupabaseUrl.isNotEmpty ? _envSupabaseUrl : _defaultUrl;
  static String get anonKey => _envAnonKey.isNotEmpty ? _envAnonKey : _defaultAnonKey;

  /// Whether Supabase has been properly configured with real values.
  /// Returns false when placeholder strings are still in place.
  static bool get isConfigured =>
      !url.contains('REPLACE_WITH') && !anonKey.contains('REPLACE_WITH');
}