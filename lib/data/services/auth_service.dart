import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../core/network/realtime_client.dart';
import '../../core/services/google_auth_service.dart';
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

  /// Signs in or canonicalizes account via Google credentials.
  /// [supabaseUserId] is the Supabase-verified identity — stored for future use.
  Future<GuestUser> signInWithGoogle({
    required String email,
    required String displayName,
    String? photoUrl,
    String? googleId,
    String? supabaseUserId,
  }) async {
    final currentGuest = getCurrentUser();
    final cleanEmail = email.trim().toLowerCase();
    final cleanDisplayName = displayName.trim().isNotEmpty ? displayName.trim() : cleanEmail.split('@')[0];

    try {
      final res = await apiClient.post('/auth/google', body: {
        'email': cleanEmail,
        'displayName': cleanDisplayName,
        'photoUrl': photoUrl,
        'googleId': googleId,
        'supabaseUserId': supabaseUserId,
        'currentGuestUserId': currentGuest?.id,
      });

      if (res is Map<String, dynamic> && res.containsKey('user')) {
        final userData = res['user'] as Map<String, dynamic>;
        final token = res['token'] as String? ?? userData['anonymousToken'] as String? ?? '';

        final user = GuestUser.fromJson(userData);
        apiClient.setAuthToken(token);
        realtimeClient?.setAuthToken(token);
        await storage.saveUser(user.toJson());

        // If previous guest session had a different ID, re-tag all local data
        if (currentGuest != null && currentGuest.id != user.id) {
          await _reTagLocalGuestData(currentGuest.id, user.id);
        }

        return user;
      }
    } catch (e) {
      // Backend offline or 404: seamlessly canonicalize user locally with Google profile
      final deterministicId = supabaseUserId ??
          (googleId != null && googleId.isNotEmpty ? 'usr_g_$googleId' : 'usr_g_${cleanEmail.hashCode.abs()}');

      final updatedUser = (currentGuest ?? GuestUser(
        id: deterministicId,
        displayName: cleanDisplayName,
        avatarUrl: photoUrl,
        recoveryKey: _generateRecoveryKey(),
        anonymousToken: 'kith_sess_${cleanEmail.hashCode.abs()}',
        createdAt: DateTime.now(),
        isLinkedToAccount: true,
      )).copyWith(
        id: currentGuest != null ? currentGuest.id : deterministicId,
        isLinkedToAccount: true,
        email: cleanEmail,
        displayName: cleanDisplayName,
        avatarUrl: photoUrl ?? currentGuest?.avatarUrl,
      );

      await storage.saveUser(updatedUser.toJson());
      apiClient.setAuthToken(updatedUser.anonymousToken);
      realtimeClient?.setAuthToken(updatedUser.anonymousToken);
      if (currentGuest != null && currentGuest.id != updatedUser.id) {
        await _reTagLocalGuestData(currentGuest.id, updatedUser.id);
      }
      syncLocalGuestSession(updatedUser);
      return updatedUser;
    }

    final fallbackId = supabaseUserId ??
        (googleId != null && googleId.isNotEmpty ? 'usr_g_$googleId' : 'usr_g_${cleanEmail.hashCode.abs()}');

    final fallback = (currentGuest ?? GuestUser(
      id: fallbackId,
      displayName: cleanDisplayName,
      avatarUrl: photoUrl,
      recoveryKey: _generateRecoveryKey(),
      anonymousToken: 'kith_sess_${cleanEmail.hashCode.abs()}',
      createdAt: DateTime.now(),
      isLinkedToAccount: true,
    )).copyWith(
      id: currentGuest != null ? currentGuest.id : fallbackId,
      isLinkedToAccount: true,
      email: cleanEmail,
      displayName: cleanDisplayName,
      avatarUrl: photoUrl ?? currentGuest?.avatarUrl,
    );

    await storage.saveUser(fallback.toJson());
    apiClient.setAuthToken(fallback.anonymousToken);
    realtimeClient?.setAuthToken(fallback.anonymousToken);
    if (currentGuest != null && currentGuest.id != fallback.id) {
      await _reTagLocalGuestData(currentGuest.id, fallback.id);
    }
    syncLocalGuestSession(fallback);
    return fallback;
  }

  /// Re-tags local cached guest entities to canonical user ID on Google sign-in
  Future<void> _reTagLocalGuestData(String oldGuestId, String canonicalUserId) async {
    try {
      // 1. Re-tag Personal Expenses
      final personalExpenses = storage.getSavedPersonalExpenses();
      for (final exp in personalExpenses) {
        if (exp['userId'] == oldGuestId) {
          exp['userId'] = canonicalUserId;
        }
      }
      await storage.savePersonalExpenses(personalExpenses);

      // 2. Re-tag Personal Debts
      final personalDebts = storage.getSavedPersonalDebts();
      for (final debt in personalDebts) {
        if (debt['userId'] == oldGuestId) {
          debt['userId'] = canonicalUserId;
        }
      }
      await storage.savePersonalDebts(personalDebts);

      // 3. Re-tag Trips & Members
      final trips = storage.getSavedTrips();
      for (final trip in trips) {
        if (trip['creatorId'] == oldGuestId) {
          trip['creatorId'] = canonicalUserId;
        }
        final members = trip['members'] as List<dynamic>?;
        if (members != null) {
          for (final m in members) {
            if (m is Map<String, dynamic> && m['userId'] == oldGuestId) {
              m['userId'] = canonicalUserId;
            }
          }
        }
      }
      await storage.saveTrips(trips);

      // 4. Re-tag Mutation Queue
      final mutations = storage.getMutationQueue();
      for (final m in mutations) {
        final payload = m['payload'] as Map<String, dynamic>?;
        if (payload != null) {
          if (payload['userId'] == oldGuestId) {
            payload['userId'] = canonicalUserId;
          }
          if (payload['creatorId'] == oldGuestId) {
            payload['creatorId'] = canonicalUserId;
          }
        }
      }
      await storage.saveMutationQueue(mutations);
    } catch (_) {
      // Non-blocking local re-tag
    }
  }

  /// Attempts to restore an authenticated session from a live Supabase session.
  /// Call this on app startup when no local GuestUser session exists.
  /// Returns null if no Supabase session is active.
  Future<GuestUser?> restoreSupabaseSession() async {
    final session = GoogleAuthService.currentSession;
    if (session == null) return null;

    final supabaseUser = session.user;
    final email = supabaseUser.email;
    if (email == null || email.isEmpty) return null;

    // Check if we already have a cached local session for this email
    final cached = getCurrentUser();
    if (cached != null && cached.email?.toLowerCase() == email.toLowerCase()) {
      // Refresh the token
      apiClient.setAuthToken(cached.anonymousToken);
      realtimeClient?.setAuthToken(cached.anonymousToken);
      return cached;
    }

    // Re-authenticate with backend using the Supabase-verified identity
    try {
      final displayName = supabaseUser.userMetadata?['full_name'] as String? ??
          supabaseUser.userMetadata?['name'] as String? ??
          email.split('@')[0];
      final photoUrl = supabaseUser.userMetadata?['avatar_url'] as String?;
      final googleId = supabaseUser.userMetadata?['sub'] as String? ?? supabaseUser.id;

      return await signInWithGoogle(
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        googleId: googleId,
        supabaseUserId: supabaseUser.id,
      );
    } catch (_) {
      return null;
    }
  }

  /// Revokes backend session, disconnects realtime, clears Supabase session,
  /// and clears all local credentials.
  Future<void> logout() async {
    try {
      await apiClient.post('/auth/logout', body: {});
    } catch (_) {
      // Non-blocking network logout
    }
    apiClient.setAuthToken(null);
    realtimeClient?.setAuthToken(null);
    realtimeClient?.disconnect();
    // GoogleAuthService.signOut() handles both Google + Supabase sign-out
    try {
      await GoogleAuthService.signOut();
    } catch (_) {}
    await storage.clearAllUserData();
  }

  static String _generateRecoveryKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    String block1 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    String block2 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'KITH-$block1-$block2';
  }
}
