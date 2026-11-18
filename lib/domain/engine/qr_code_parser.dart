import 'dart:convert';

/// Payload data extracted from an authenticated trip invitation QR code.
class QrJoinPayload {
  final String inviteCode;
  final String? p2pTripSecret;
  final String? claimMemberId;
  final String? claimToken;

  const QrJoinPayload({
    required this.inviteCode,
    this.p2pTripSecret,
    this.claimMemberId,
    this.claimToken,
  });
}

/// Parser and validator for QR code payloads and deep links.
class QrCodeParser {
  QrCodeParser._();

  static const List<String> _allowedHosts = [
    'kith.app',
    'www.kith.app',
    'splittrip.app',
    'splittrip-4es6.onrender.com',
    'onrender.com',
    'localhost',
    '10.0.2.2',
  ];

  static const List<String> _allowedSchemes = [
    'kith',
    'splittrip',
  ];

  /// Extracts high-entropy P2P trip secret from QR payload or deep link query parameters.
  static String? extractTripSecret(String rawPayload) {
    if (rawPayload.trim().isEmpty) return null;
    try {
      final trimmed = rawPayload.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final s = decoded['secret'] ?? decoded['p2p_secret'] ?? decoded['p2pSecret'] ?? decoded['key'];
          if (s != null && s.toString().isNotEmpty) return s.toString().trim();
        }
      }
      final uri = Uri.parse(trimmed);
      for (final param in ['secret', 'p2p_secret', 'p2pSecret', 'key', 's']) {
        if (uri.queryParameters.containsKey(param)) {
          final val = uri.queryParameters[param]?.trim();
          if (val != null && val.isNotEmpty && val.length >= 16) {
            return val;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Extracts member ID from a personal claim link or QR payload.
  static String? extractClaimMemberId(String rawPayload) {
    if (rawPayload.trim().isEmpty) return null;
    try {
      final trimmed = rawPayload.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final mId = decoded['claimMemberId'] ?? decoded['memberId'];
          if (mId != null && mId.toString().isNotEmpty) return mId.toString().trim();
        }
      }
      final uri = Uri.parse(trimmed);
      for (final param in ['memberId', 'claimMemberId', 'mId']) {
        if (uri.queryParameters.containsKey(param)) {
          final val = uri.queryParameters[param]?.trim();
          if (val != null && val.isNotEmpty) return val;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Extracts secure claim token from a personal claim link or QR payload.
  static String? extractClaimToken(String rawPayload) {
    if (rawPayload.trim().isEmpty) return null;
    try {
      final trimmed = rawPayload.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final tok = decoded['claimToken'] ?? decoded['token'];
          if (tok != null && tok.toString().isNotEmpty) return tok.toString().trim();
        }
      }
      final uri = Uri.parse(trimmed);
      for (final param in ['token', 'claimToken', 'tok']) {
        if (uri.queryParameters.containsKey(param)) {
          final val = uri.queryParameters[param]?.trim();
          if (val != null && val.isNotEmpty) return val;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Parses human-readable invite code, P2P trip secret, and claim credentials from QR code.
  static QrJoinPayload? parsePayload(String rawPayload) {
    if (rawPayload.trim().isEmpty) return null;
    final trimmed = rawPayload.trim();

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final code = decoded['code']?.toString() ?? decoded['inviteCode']?.toString();
          if (code != null && _isValidCode(code)) {
            final cleanCode = code.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
            final secret = decoded['secret']?.toString() ?? decoded['p2p_secret']?.toString();
            final memberId = decoded['claimMemberId']?.toString() ?? decoded['memberId']?.toString();
            final token = decoded['claimToken']?.toString() ?? decoded['token']?.toString();
            return QrJoinPayload(
              inviteCode: cleanCode,
              p2pTripSecret: secret,
              claimMemberId: memberId,
              claimToken: token,
            );
          }
        }
      } catch (_) {}
    }

    final code = extractInviteCode(rawPayload);
    if (code == null) return null;

    final secret = extractTripSecret(rawPayload);
    final claimMemberId = extractClaimMemberId(rawPayload);
    final claimToken = extractClaimToken(rawPayload);

    return QrJoinPayload(
      inviteCode: code,
      p2pTripSecret: secret,
      claimMemberId: claimMemberId,
      claimToken: claimToken,
    );
  }

  /// Extracts clean invite code from a QR payload or deep link URL.
  /// Returns null if the payload is invalid, unrecognized, or from an unauthorized domain.
  static String? extractInviteCode(String rawPayload) {
    if (rawPayload.trim().isEmpty) return null;
    final trimmed = rawPayload.trim();

    // 0. Check JSON QR payload
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final code = decoded['code']?.toString() ?? decoded['inviteCode']?.toString();
          if (code != null && _isValidCode(code)) {
            return code.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
          }
        }
      } catch (_) {}
    }

    // 1. Try URI parsing for deep links (https://kith.app/join?code=... or kith://join?code=...)
    try {
      final uri = Uri.parse(trimmed);
      if (uri.hasScheme) {
        final scheme = uri.scheme.toLowerCase();
        final host = uri.host.toLowerCase();

        if (scheme == 'http' || scheme == 'https') {
          final isAllowedHost = _allowedHosts.any((h) =>
              host == h ||
              host.endsWith('.$h') ||
              host.endsWith('onrender.com') ||
              host.contains('192.168.') ||
              host.contains('10.0.'));
          if (!isAllowedHost) {
            return null; // Reject untrusted web host
          }
        } else if (!_allowedSchemes.contains(scheme)) {
          return null; // Reject untrusted scheme
        }

        // Check query parameters: code, inviteCode, tripId, id
        for (final param in ['code', 'inviteCode', 'tripId', 'id']) {
          if (uri.queryParameters.containsKey(param)) {
            final val = uri.queryParameters[param];
            if (val != null && _isValidCode(val)) {
              return val.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
            }
          }
        }

        // Check path segments e.g. https://kith.app/join/ABC123 or /trip/ABC123
        if (uri.pathSegments.isNotEmpty) {
          final lastSegment = uri.pathSegments.last;
          if (_isValidCode(lastSegment)) {
            return lastSegment.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
          }
        }

        return null;
      }
    } catch (_) {
      // Not a standard URI, fallback to direct code check
    }

    // 2. Direct alphanumeric join code format check (4 to 12 alphanumeric characters or trip_...)
    if (_isValidCode(trimmed)) {
      return trimmed.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    }

    return null;
  }

  static bool _isValidCode(String code) {
    final clean = code.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (clean.isEmpty) return false;

    // Alphanumeric invite code (4 to 12 characters)
    final codeRegex = RegExp(r'^[A-Z0-9]{4,12}$');
    if (codeRegex.hasMatch(clean)) return true;

    // Direct trip ID format (trip_xxxxxxxxxxxx)
    final tripIdRegex = RegExp(r'^TRIP_[A-Z0-9_]{4,36}$');
    if (tripIdRegex.hasMatch(clean)) return true;

    return false;
  }
}
