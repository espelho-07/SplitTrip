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
