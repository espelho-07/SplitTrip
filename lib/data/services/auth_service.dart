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
    // Re-hydrate session token on startup and sync identity non-blocking
    final user = getCurrentUser();
    if (user != null && user.anonymousToken.isNotEmpty) {
      apiClient.setAuthToken(user.anonymousToken);
      realtimeClient?.setAuthToken(user.anonymousToken);
      syncLocalGuestSession(user);
    }
  }

  /// Syncs local guest user registration and recovery key to server
  Future<void> syncLocalGuestSession([GuestUser? targetUser]) async {
    final user = targetUser ?? getCurrentUser();
    if (user == null) return;
    try {
      await apiClient.post('/auth/sync-guest', body: {
        'id': user.id,
        'displayName': user.displayName,
        'recoveryKey': user.recoveryKey,
        'token': user.anonymousToken,
        'avatarUrl': user.avatarUrl,
      });
    } catch (_) {
      // Non-blocking background sync
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
    syncLocalGuestSession(user);
    return user;
  }

  /// Normalizes a recovery key format regardless of casing, spaces, underscores, or missing KITH- prefix.
  static String normalizeRecoveryKey(String raw) {
    final trimmed = raw.trim().toUpperCase();
    String clean = trimmed.replaceAll(RegExp(r'[\s\-_:]'), '');
    if (clean.startsWith('KITH')) {
      clean = clean.substring(4);
    }
    if (clean.length == 8) {
      return 'KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}';
    }
    return trimmed.isEmpty ? '' : (clean.length > 8 ? 'KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}' : clean);
  }

  /// Recovers a session across devices via recovery key.
  Future<GuestUser?> recoverUser(String recoveryKey) async {
    final cleanKey = normalizeRecoveryKey(recoveryKey);
    if (cleanKey.isEmpty) return null;

    // Check local match first for instant recovery
    final existing = getCurrentUser();
    if (existing != null && normalizeRecoveryKey(existing.recoveryKey) == cleanKey) {
      return existing;
    }

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

    if (existing != null && normalizeRecoveryKey(existing.recoveryKey) == cleanKey) {
      return existing;
    }

    return null;
  }

  /// Links an existing guest identity to a permanent account (e.g. Google Sign-In or Email)
  Future<GuestUser> linkToAccount({
    required String email,
    required String provider,
    String? displayName,
  }) async {
    final current = getCurrentUser();
    if (current == null) {
      throw StateError('No active guest session to link');
    }

    try {
      final res = await apiClient.post('/auth/link', body: {
        'email': email,
        'provider': provider,
        ...? (displayName != null ? {'displayName': displayName} : null),
      });

      if (res is Map<String, dynamic> && res.containsKey('user')) {
        final userData = res['user'] as Map<String, dynamic>;
        final user = GuestUser.fromJson(userData);
        await storage.saveUser(user.toJson());
        return user;
      }
    } catch (_) {
      // Offline fallback: update local storage
    }

    final updated = current.copyWith(
      isLinkedToAccount: true,
      email: email,
      displayName: displayName ?? current.displayName,
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
