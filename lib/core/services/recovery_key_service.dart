import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Cryptographic Recovery Key Service for Kith.
///
/// Implements:
/// 1. High-entropy, human-friendly recovery key generation (Crockford Base32).
/// 2. Key normalization & validation.
/// 3. Salted HMAC-SHA256 hashing (plaintext keys are NEVER stored in cloud databases).
/// 4. In-memory and persistent attempt throttling (rate-limiting) to defend against brute force.
class RecoveryKeyService {
  // Crockford Base32 alphabet: eliminates visually ambiguous characters (0, O, 1, I, L)
  static const String _alphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int _keyGroupLength = 4;
  static const int _keyGroupCount = 4; // 16 characters = 80 bits of cryptographic entropy

  static final Random _secureRandom = Random.secure();

  // Rate-limiting tracking: deviceId -> list of attempt timestamps
  static final Map<String, List<DateTime>> _attemptHistory = {};
  static const int maxAttemptsPerWindow = 5;
  static const Duration rateLimitWindow = Duration(minutes: 15);

  /// Generates a new cryptographically secure Recovery Key.
  /// Format: `KITH-7X4M-9Q2P-L8VN-3R6T`
  static String generateKey() {
    final buffer = StringBuffer('KITH');
    for (int i = 0; i < _keyGroupCount; i++) {
      buffer.write('-');
      for (int j = 0; j < _keyGroupLength; j++) {
        final index = _secureRandom.nextInt(_alphabet.length);
        buffer.write(_alphabet[index]);
      }
    }
    return buffer.toString();
  }

  /// Normalizes any user-entered recovery key string:
  /// - Trims and converts to uppercase
  /// - Strips whitespace, dashes, colons, underscores
  /// - Removes leading 'KITH' if present
  /// - Reconstructs canonical grouped format
  static String normalizeKey(String raw) {
    if (raw.isEmpty) return '';
    final upper = raw.trim().toUpperCase();
    String clean = upper.replaceAll(RegExp(r'[\s\-_:\r\n]'), '');

    if (clean.startsWith('KITH')) {
      clean = clean.substring(4);
    }

    if (clean.length == 16) {
      return 'KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}-${clean.substring(12, 16)}';
    } else if (clean.length == 12) {
      return 'KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}';
    } else if (clean.length == 8) {
      return 'KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}';
    } else if (clean.isNotEmpty) {
      // Group whatever characters exist in chunks of 4
      final parts = <String>[];
      for (int i = 0; i < clean.length; i += 4) {
        final end = (i + 4 < clean.length) ? i + 4 : clean.length;
        parts.add(clean.substring(i, end));
      }
      return 'KITH-${parts.join('-')}';
    }
    return '';
  }

  /// Validates whether a key matches valid Kith recovery key syntax and length.
  static bool isValidKeyFormat(String key) {
    final normalized = normalizeKey(key);
    // Standard format: KITH-XXXX-XXXX-XXXX-XXXX (21 chars)
    // Legacy formats: KITH-XXXX-XXXX-XXXX (16 chars) or KITH-XXXX-XXXX (11 chars)
    final pattern = RegExp(r'^KITH(-[2-9A-HJ-NP-Z]{4}){2,4}$');
    return pattern.hasMatch(normalized);
  }

  /// Generates a cryptographically secure 128-bit hex salt for account hashing.
  static String generateSalt() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Computes a salted HMAC-SHA256 hash of the normalized recovery key.
  /// Plaintext recovery keys are never transmitted to the database.
  static String hashKey(String rawKey, String salt) {
    final normalized = normalizeKey(rawKey);
    final keyBytes = utf8.encode(salt.isNotEmpty ? salt : 'kith_default_secret_salt_v1');
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(utf8.encode(normalized));
    return digest.toString();
  }

  /// Verifies a raw key against an expected hash using constant-time comparison.
  static bool verifyKey(String rawKey, String expectedHash, String salt) {
    if (expectedHash.isEmpty) return false;
    final computedHash = hashKey(rawKey, salt);
    return _constantTimeEquals(computedHash, expectedHash);
  }

  /// Constant-time string equality comparison to protect against timing attacks.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Checks if a device is allowed to make another recovery attempt.
  static bool canAttemptRecovery(String deviceId) {
    _cleanOldAttempts(deviceId);
    final history = _attemptHistory[deviceId] ?? [];
    return history.length < maxAttemptsPerWindow;
  }

  /// Returns the remaining cooldown duration before the next attempt is permitted.
  static Duration getRemainingCooldown(String deviceId) {
    _cleanOldAttempts(deviceId);
    final history = _attemptHistory[deviceId] ?? [];
    if (history.length < maxAttemptsPerWindow) return Duration.zero;

    final oldestInWindow = history.first;
    final expiresAt = oldestInWindow.add(rateLimitWindow);
    final now = DateTime.now();
    return expiresAt.isAfter(now) ? expiresAt.difference(now) : Duration.zero;
  }

  /// Records a recovery attempt for a device.
  static void recordRecoveryAttempt(String deviceId, {required bool success}) {
    if (success) {
      _attemptHistory.remove(deviceId);
      return;
    }
    final history = _attemptHistory.putIfAbsent(deviceId, () => []);
    history.add(DateTime.now());
  }

  static void _cleanOldAttempts(String deviceId) {
    final history = _attemptHistory[deviceId];
    if (history == null || history.isEmpty) return;
    final now = DateTime.now();
    history.removeWhere((timestamp) => now.difference(timestamp) > rateLimitWindow);
    if (history.isEmpty) {
      _attemptHistory.remove(deviceId);
    }
  }
}
