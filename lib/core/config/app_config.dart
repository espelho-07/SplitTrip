/// Application configuration and environment separation.
/// Supports runtime overrides and compile-time `--dart-define` injection for Staging / Production.
class AppConfig {
  AppConfig._();

  static const String appName = 'Kith';
  static const String appVersion = '1.0.0';

  /// Deep link scheme for invitation sharing
  static const String deepLinkScheme = 'kith';
  static const String deepLinkHost = 'trip';

  // Compile-time environment definitions via --dart-define
  static const String _envDefineApiUrl = String.fromEnvironment('API_URL');
  static const String _envDefineWsUrl = String.fromEnvironment('WS_URL');
  static const String environment = String.fromEnvironment('APP_ENV', defaultValue: 'development');

  // Configurable runtime overrides (used in integration tests)
  static String? _overrideBaseUrl;
  static String? _overrideWsUrl;

  static void setOverrideUrls({String? baseUrl, String? wsUrl}) {
    _overrideBaseUrl = baseUrl;
    _overrideWsUrl = wsUrl;
  }

  static String get baseUrl {
    if (_overrideBaseUrl != null) return _overrideBaseUrl!;
    if (_envDefineApiUrl.isNotEmpty) return _envDefineApiUrl;

    // By default, connect to the live cloud backend so real physical devices on Wi-Fi/Cellular work out of the box
    return 'https://kith-staging-backend.onrender.com/api';
  }

  static String get wsUrl {
    if (_overrideWsUrl != null) return _overrideWsUrl!;
    if (_envDefineWsUrl.isNotEmpty) return _envDefineWsUrl;

    return 'wss://kith-staging-backend.onrender.com/ws';
  }

  static String buildInviteLink(String inviteCode) {
    return 'https://kith.app/join?code=$inviteCode';
  }
}
