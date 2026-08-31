/// Application configuration and environment separation.
/// Supports runtime overrides and compile-time `--dart-define` injection for Staging / Production.
class AppConfig {
  AppConfig._();

  static const String appName = 'Kith';
  static const String appVersion = '1.0.0';

  /// Feature flag: Temporarily disable Google Auth in user-facing flows
  static const bool enableGoogleAuth = false;

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
  static String? _customServerUrl;

  static void setOverrideUrls({String? baseUrl, String? wsUrl}) {
    _overrideBaseUrl = baseUrl;
    _overrideWsUrl = wsUrl;
  }

  static void setCustomServerUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      _customServerUrl = null;
      return;
    }
    var clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    _customServerUrl = clean;
  }

  static String? get customServerUrl => _customServerUrl;

  static String get baseUrl {
    if (_overrideBaseUrl != null) return _overrideBaseUrl!;
    if (_customServerUrl != null && _customServerUrl!.isNotEmpty) {
      final clean = _customServerUrl!;
      return clean.endsWith('/api') ? clean : '$clean/api';
    }
    if (_envDefineApiUrl.isNotEmpty) return _envDefineApiUrl;

    // By default, connect to the live cloud backend so real physical devices on Wi-Fi/Cellular work out of the box
    return 'https://splittrip-4es6.onrender.com/api';
  }

  static String get wsUrl {
    if (_overrideWsUrl != null) return _overrideWsUrl!;
    if (_customServerUrl != null && _customServerUrl!.isNotEmpty) {
      var clean = _customServerUrl!;
      if (clean.endsWith('/api')) {
        clean = clean.substring(0, clean.length - 4);
      }
      if (clean.startsWith('https://')) {
        clean = 'wss://${clean.substring(8)}';
      } else if (clean.startsWith('http://')) {
        clean = 'ws://${clean.substring(7)}';
      }
      return '$clean/ws';
    }
    if (_envDefineWsUrl.isNotEmpty) return _envDefineWsUrl;

    return 'wss://splittrip-4es6.onrender.com/ws';
  }

  static String buildInviteLink(String inviteCode) {
    return 'https://kith.app/join?code=$inviteCode';
  }
}
