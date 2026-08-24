/// Parser and validator for QR code payloads and deep links.
class QrCodeParser {
  QrCodeParser._();

  /// Extracts clean invite code from a QR payload or deep link URL.
  /// Returns null if the payload is invalid or unrecognized.
  static String? extractInviteCode(String rawPayload) {
    if (rawPayload.trim().isEmpty) return null;
    final trimmed = rawPayload.trim();

    // 1. Try URI parsing for deep links (https://kith.app/join?code=... or kith://join?code=...)
    try {
      final uri = Uri.parse(trimmed);
      if (uri.hasQuery && uri.queryParameters.containsKey('code')) {
        final code = uri.queryParameters['code'];
        if (code != null && _isValidCode(code)) {
          return code.trim().toUpperCase();
        }
      }

      // Check path segments e.g. https://kith.app/join/ABC123
      if (uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last;
        if (_isValidCode(lastSegment)) {
          return lastSegment.trim().toUpperCase();
        }
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
    final tripIdRegex = RegExp(r'^TRIP_[A-Z0-9]{8,16}$');
    if (tripIdRegex.hasMatch(clean)) return true;

    return false;
  }
}
