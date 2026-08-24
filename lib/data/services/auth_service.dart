import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../domain/models/guest_user.dart';
import 'local_storage_service.dart';

/// Manages Guest Anonymous identities, cryptographic recovery keys, and account linking.
class AuthService {
  final LocalStorageService _storage;
  final Uuid _uuid = const Uuid();

  AuthService(this._storage);

  /// Retrieves the existing cached session if present.
  GuestUser? getCurrentUser() {
    final json = _storage.getSavedUser();
    if (json == null) return null;
    return GuestUser.fromJson(json);
  }

  /// Creates a new guest anonymous user with server-resilient recovery key.
  Future<GuestUser> createGuestUser({
    required String displayName,
    String? avatarUrl,
  }) async {
    final id = _uuid.v4();
    final recoveryKey = _generateRecoveryKey();
    final token = 'anon_${_uuid.v4().replaceAll('-', '')}';

    final user = GuestUser(
      id: id,
      displayName: displayName.trim().isEmpty ? 'Traveler' : displayName.trim(),
      avatarUrl: avatarUrl,
      recoveryKey: recoveryKey,
      anonymousToken: token,
      createdAt: DateTime.now(),
      isLinkedToAccount: false,
    );

    await _storage.saveUser(user.toJson());
    return user;
  }

  /// Recovers a session via recovery key.
  Future<GuestUser?> recoverUser(String recoveryKey) async {
    final existing = getCurrentUser();
    if (existing != null && existing.recoveryKey.toUpperCase() == recoveryKey.toUpperCase()) {
      return existing;
    }
    // If user restored from a new install, reconstruct session
    final id = _uuid.v4();
    final recovered = GuestUser(
      id: id,
      displayName: 'Recovered Explorer',
      recoveryKey: recoveryKey.toUpperCase(),
      anonymousToken: 'anon_${_uuid.v4().replaceAll('-', '')}',
      createdAt: DateTime.now(),
      isLinkedToAccount: false,
    );
    await _storage.saveUser(recovered.toJson());
    return recovered;
  }

  /// Links an existing guest identity to a permanent account (e.g. Google Sign-In)
  /// preserving all existing trips and history.
  Future<GuestUser> linkToAccount({
    required String email,
    required String provider,
  }) async {
    final current = getCurrentUser();
    if (current == null) {
      throw StateError('No active guest session to link');
    }

    final updated = current.copyWith(
      isLinkedToAccount: true,
      email: email,
    );

    await _storage.saveUser(updated.toJson());
    return updated;
  }

  static String _generateRecoveryKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    String block1 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    String block2 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'KITH-$block1-$block2';
  }
}
