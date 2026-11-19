library;

/// Application configuration and environment separation.

/// Supports runtime overrides and compile-time `--dart-define` injection for Staging / Production.

class AppConfig {

  AppConfig._();



  static const String appName = 'Kith';

  static const String appVersion = '2.0.25';



  /// Feature flag: Temporarily disable Google Auth in user-facing flows

  static const bool enableGoogleAuth = false;

  /// Whether the Nirniq identity platform is enabled.
  /// 
  /// [PHASE 1] Always false. No Nirniq code path is active.
  /// Do not change this value until Gates 1, 2, and 3 are approved.
  /// See: NirniqFeatureFlags for granular control.
  static const bool enableNirniqIdentity = false;



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



  // Deprecated: External IPO API URLs and keys are eliminated from Flutter.
  // All market data is centrally ingested server-side into PostgreSQL (KITH-STAGING).
  @Deprecated('External IPO API is replaced by centralized PostgreSQL caching')
  static String get ipoApiBaseUrl => '';
  @Deprecated('External IPO API is replaced by centralized PostgreSQL caching')
  static String get ipoApiKey => '';
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



  static String buildInviteLink(String inviteCode, {String? p2pTripSecret}) {

    if (p2pTripSecret != null && p2pTripSecret.isNotEmpty) {

      return 'https://kith.app/join?code=$inviteCode&secret=$p2pTripSecret';

    }

    return 'https://kith.app/join?code=$inviteCode';

  }

  /// Builds a secure personalized claim link for an unclaimed virtual member.
  /// Delivered out-of-band by the trip creator to the intended participant.
  static String buildClaimLink(
    String inviteCode, {
    required String memberId,
    required String claimToken,
    String? p2pTripSecret,
  }) {
    final cleanCode = inviteCode.trim().toUpperCase();
    final cleanMemberId = memberId.trim();
    final cleanToken = claimToken.trim();
    var link = 'https://kith.app/join?code=$cleanCode&memberId=$cleanMemberId&token=$cleanToken';
    if (p2pTripSecret != null && p2pTripSecret.isNotEmpty) {
      link += '&secret=$p2pTripSecret';
    }
    return link;
  }

}

