/// Helper for validating, formatting, and identifying UPI Virtual Payment Addresses (VPAs).
class UpiValidator {
  UpiValidator._();

  /// Standard NPCI UPI VPA regex pattern:
  /// Username: 2 to 256 alphanumeric characters, dots, hyphens, or underscores.
  /// Domain: @ followed by 2 to 64 letters/alphanumeric characters.
  static final RegExp _vpaRegex = RegExp(
    r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z0-9]{2,64}$',
  );

  /// Validates whether the given string is a syntactically correct UPI ID.
  static bool isValidUpiId(String? vpa) {
    if (vpa == null) return false;
    final trimmed = vpa.trim();
    if (trimmed.isEmpty || trimmed.length > 256) return false;
    return _vpaRegex.hasMatch(trimmed);
  }

  /// Cleans and formats a raw UPI ID string.
  static String normalizeUpiId(String vpa) {
    return vpa.trim().toLowerCase();
  }

  /// Identifies the likely UPI PSP (Payment Service Provider) app from the handle.
  static String detectProviderName(String vpa) {
    final lower = vpa.trim().toLowerCase();
    if (lower.contains('@okhdfcbank') ||
        lower.contains('@okaxis') ||
        lower.contains('@oksbi') ||
        lower.contains('@okicici')) {
      return 'Google Pay';
    } else if (lower.contains('@ybl') || lower.contains('@ibl') || lower.contains('@axl')) {
      return 'PhonePe';
    } else if (lower.contains('@paytm')) {
      return 'Paytm';
    } else if (lower.contains('@upi')) {
      return 'BHIM / NPCI';
    } else if (lower.contains('@apl') || lower.contains('@rapl')) {
      return 'Amazon Pay';
    } else if (lower.contains('@slice')) {
      return 'Slice';
    } else if (lower.contains('@jupiteraxis')) {
      return 'Jupiter';
    } else if (lower.contains('@fam')) {
      return 'FamPay';
    } else if (lower.contains('@postpe')) {
      return 'PostPe';
    }
    return 'UPI';
  }
}
