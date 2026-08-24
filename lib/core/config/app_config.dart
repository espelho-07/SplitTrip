import 'dart:io';

class AppConfig {
  static const String appName = 'Kith';
  static const String appVersion = '1.0.0';

  /// Deep link scheme for invitation sharing
  static const String deepLinkScheme = 'kith';
  static const String deepLinkHost = 'trip';

  // Configurable base URL
  static String? _overrideBaseUrl;
  static String? _overrideWsUrl;

  static void setOverrideUrls({String? baseUrl, String? wsUrl}) {
    _overrideBaseUrl = baseUrl;
    _overrideWsUrl = wsUrl;
  }

  static String get baseUrl {
    if (_overrideBaseUrl != null) return _overrideBaseUrl!;

    // Auto-detect Android emulator vs Desktop/Web/iOS
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
    return 'kith://trip/join?code=$inviteCode';
  }
}
