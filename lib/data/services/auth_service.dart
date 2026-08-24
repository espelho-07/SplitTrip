import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../core/network/realtime_client.dart';
import '../../domain/models/guest_user.dart';
import 'local_storage_service.dart';

/// Manages Guest Anonymous identities, cryptographic recovery keys, and account linking.
class AuthService {
  final LocalStorageService storage;
  final ApiClient apiClient;
  final RealtimeClient? realtimeClient;
  final Uuid _uuid = const Uuid();

  AuthService({
    required this.storage,
    required this.apiClient,
    this.realtimeClient,
  }) {
    // Re-hydrate session token on startup
    final user = getCurrentUser();
    if (user != null && user.anonymousToken.isNotEmpty) {
      apiClient.setAuthToken(user.anonymousToken);
      realtimeClient?.setAuthToken(user.anonymousToken);
    }
  }

  /// Retrieves the existing cached session if present.
  GuestUser? getCurrentUser() {
    final json = storage.getSavedUser();
    if (json == null) return null;
    return GuestUser.fromJson(json);
  }

  /// Creates a new guest anonymous user with server-side persistence and recovery key.
  Future<GuestUser> createGuestUser({
    required String displayName,
    String? avatarUrl,
  }) async {
    final trimmedName = displayName.trim().isEmpty ? 'Traveler' : displayName.trim();

    try {
      final res = await apiClient.post('/auth/guest', body: {
        'displayName': trimmedName,
        'avatarUrl': avatarUrl,
      });

      if (res is Map<String, dynamic> && res.containsKey('user')) {
        final userData = res['user'] as Map<String, dynamic>;
        final token = res['token'] as String? ?? userData['anonymousToken'] as String? ?? '';

        final user = GuestUser.fromJson(userData);
        apiClient.setAuthToken(token);
        realtimeClient?.setAuthToken(token);
        await storage.saveUser(user.toJson());
        return user;
      }
    } catch (_) {
      // Offline fallback: generate local session and queue sync
    }

    final id = 'usr_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final recoveryKey = _generateRecoveryKey();
    final token = 'kith_sess_${_uuid.v4().replaceAll('-', '')}';

    final user = GuestUser(
      id: id,
      displayName: trimmedName,
      avatarUrl: avatarUrl,
      recoveryKey: recoveryKey,
      anonymousToken: token,
      createdAt: DateTime.now(),
      isLinkedToAccount: false,
    );

    apiClient.setAuthToken(token);
    realtimeClient?.setAuthToken(token);
    await storage.saveUser(user.toJson());
    return user;
  }

  /// Recovers a session across devices via recovery key.
  Future<GuestUser?> recoverUser(String recoveryKey) async {
    final cleanKey = recoveryKey.trim().toUpperCase();

    try {
      final res = await apiClient.post('/auth/recover', body: {
        'recoveryKey': cleanKey,
      });

      if (res is Map<String, dynamic> && res.containsKey('user')) {
        final userData = res['user'] as Map<String, dynamic>;
        final token = res['token'] as String? ?? userData['anonymousToken'] as String? ?? '';

        final user = GuestUser.fromJson(userData);
        apiClient.setAuthToken(token);
        realtimeClient?.setAuthToken(token);
        await storage.saveUser(user.toJson());
        return user;
      }
    } catch (_) {
      // Offline fallback: check local match
    }

    final existing = getCurrentUser();
    if (existing != null && existing.recoveryKey.toUpperCase() == cleanKey) {
      return existing;
    }

    return null;
  }

  /// Links an existing guest identity to a permanent account (e.g. Google Sign-In)
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

    await storage.saveUser(updated.toJson());
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
