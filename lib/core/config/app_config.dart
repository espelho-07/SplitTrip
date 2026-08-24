import 'dart:io';

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

    // Auto-detect Android emulator vs Desktop/Web/iOS for local dev
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:4000/api';
      }
    } catch (_) {
      // Platform not supported (e.g. web)
    }
    return 'http://localhost:4000/api';
  }

  static String get wsUrl {
    if (_overrideWsUrl != null) return _overrideWsUrl!;
    if (_envDefineWsUrl.isNotEmpty) return _envDefineWsUrl;

    try {
      if (Platform.isAndroid) {
        return 'ws://10.0.2.2:4000/ws';
      }
    } catch (_) {
      // Platform not supported
    }
    return 'ws://localhost:4000/ws';
  }

  static String buildInviteLink(String inviteCode) {
    return 'https://kith.app/join?code=$inviteCode';
  }
}
