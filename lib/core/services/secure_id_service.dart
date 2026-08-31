import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Android Keystore-backed guest ID persistence service.
///
/// Android Keystore entries **survive app reinstalls** on the same device,
/// making this the most reliable anchor for guest identity recovery.
///
/// On true factory reset or device change, SecureStorage is also wiped —
/// in that case Layer 2 (Supabase recovery by recovery key) takes over.
class SecureIdService {
  static const String _guestIdKey = 'kith_secure_guest_id';
  static const String _recoveryKeySecure = 'kith_secure_recovery_key';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
    ),
  );

  /// Reads the persisted guest user ID from Android Keystore.
  /// Returns null if this is a true first-time install or after factory reset.
  Future<String?> getPersistedGuestId() async {
    try {
      return await _storage.read(key: _guestIdKey);
    } catch (e) {
      debugPrint('[SecureIdService] Read guest ID error: $e');
      return null;
    }
  }

  /// Reads the persisted recovery key from Android Keystore.
  Future<String?> getPersistedRecoveryKey() async {
    try {
      return await _storage.read(key: _recoveryKeySecure);
    } catch (e) {
      debugPrint('[SecureIdService] Read recovery key error: $e');
      return null;
    }
  }

  /// Persists guest ID and recovery key to Android Keystore.
  /// Call this whenever a guest account is created or recovered.
  Future<void> persistGuestIdentity(String guestId, String recoveryKey) async {
    try {
      await Future.wait([
        _storage.write(key: _guestIdKey, value: guestId),
        _storage.write(key: _recoveryKeySecure, value: recoveryKey),
      ]);
      debugPrint('[SecureIdService] Guest identity anchored to Keystore: $guestId');
    } catch (e) {
      debugPrint('[SecureIdService] Write error (non-fatal): $e');
    }
  }

  /// Clears secure storage on explicit user logout or account deletion.
  Future<void> clearSecureIdentity() async {
    try {
      await Future.wait([
        _storage.delete(key: _guestIdKey),
        _storage.delete(key: _recoveryKeySecure),
      ]);
    } catch (e) {
      debugPrint('[SecureIdService] Clear error (non-fatal): $e');
    }
  }

  /// Returns true if a secure guest identity is anchored in Keystore.
  Future<bool> hasPersistedIdentity() async {
    final id = await getPersistedGuestId();
    return id != null && id.isNotEmpty;
  }
}
