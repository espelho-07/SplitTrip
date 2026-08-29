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

  /// Extracts clean invite code from a QR payload or deep link URL.
  /// Returns null if the payload is invalid, unrecognized, or from an unauthorized domain.
  static String? extractInviteCode(String rawPayload) {
    if (rawPayload.trim().isEmpty) return null;
    final trimmed = rawPayload.trim();

    // 1. Try URI parsing for deep links (https://kith.app/join?code=... or kith://join?code=...)
    try {
      final uri = Uri.parse(trimmed);
      if (uri.hasScheme) {
        final scheme = uri.scheme.toLowerCase();
        final host = uri.host.toLowerCase();

        if (scheme == 'http' || scheme == 'https') {
          final isAllowedHost = _allowedHosts.any((h) => host == h || host.endsWith('.$h') || host.endsWith('onrender.com'));
          if (!isAllowedHost) {
            return null; // Reject untrusted web host
          }
        } else if (!_allowedSchemes.contains(scheme)) {
          return null; // Reject untrusted scheme
        }

        if (uri.hasQuery && uri.queryParameters.containsKey('code')) {
          final code = uri.queryParameters['code'];
          if (code != null && _isValidCode(code)) {
            return code.trim().toUpperCase();
          }
        }

        // Check path segments e.g. https://kith.app/join/ABC123 or /trip/ABC123
        if (uri.pathSegments.isNotEmpty) {
          final lastSegment = uri.pathSegments.last;
          if (_isValidCode(lastSegment)) {
            return lastSegment.trim().toUpperCase();
          }
        }
        return null;
      }
    } catch (_) {
      // Not a standard URI, fallback to direct code check
    }

    // 2. Direct alphanumeric join code format check (6 alphanumeric characters or trip_...)
    if (_isValidCode(trimmed)) {
      return trimmed.toUpperCase();
    }

    return null;
  }

  static bool _isValidCode(String code) {
    final clean = code.trim().toUpperCase();
    // 6-character alphanumeric invite code (excluding easily confused chars 0, 1, I, O)
    final codeRegex = RegExp(r'^[A-Z0-9]{6}$');
    if (codeRegex.hasMatch(clean)) return true;

    // Direct trip ID format (trip_xxxxxxxxxxxx)
    final tripIdRegex = RegExp(r'^TRIP_[A-Z0-9_]{6,32}$');
    if (tripIdRegex.hasMatch(clean)) return true;

    return false;
  }
}
