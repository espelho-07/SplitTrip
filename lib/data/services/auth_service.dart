import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/supabase_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/realtime_client.dart';
import '../../core/services/google_auth_service.dart';
import '../../core/services/recovery_key_service.dart';
import '../../core/services/secure_id_service.dart';
import '../../core/services/supabase_cloud_sync.dart';
import '../../core/services/supabase_guest_sync.dart';
import '../../domain/models/guest_user.dart';
import 'local_storage_service.dart';

/// Manages Guest Anonymous identities, cryptographic recovery keys, and account linking.
/// Implements a three-layer persistence strategy:
///   Layer 0: SharedPreferences (fast, normal operation)
///   Layer 1: Android Keystore via flutter_secure_storage (survives reinstall)
///   Layer 2: Supabase user_accounts / guest_sessions (authoritative cloud sync & recovery)
class AuthService {
  final LocalStorageService storage;
  final ApiClient apiClient;
  final RealtimeClient? realtimeClient;
  final SecureIdService _secureId;
  final SupabaseGuestSync _supabaseSync;
  final SupabaseCloudSync _cloudSync;
  final Uuid _uuid = const Uuid();

  AuthService({
    required this.storage,
    required this.apiClient,
    this.realtimeClient,
    SecureIdService? secureIdService,
    SupabaseGuestSync? supabaseGuestSync,
    SupabaseCloudSync? supabaseCloudSync,
  })  : _secureId = secureIdService ?? SecureIdService(),
        _supabaseSync = supabaseGuestSync ?? SupabaseGuestSync(),
        _cloudSync = supabaseCloudSync ?? SupabaseCloudSync() {
    // Re-hydrate session token on startup and sync identity non-blocking
    final user = getCurrentUser();
    if (user != null && user.anonymousToken.isNotEmpty) {
      apiClient.setAuthToken(user.anonymousToken);
      realtimeClient?.setAuthToken(user.anonymousToken);
      syncLocalGuestSession(user);
    }
  }

  /// Syncs local guest user registration, recovery key, and FCM token to server and Supabase.
  Future<void> syncLocalGuestSession([GuestUser? targetUser]) async {
    final user = targetUser ?? getCurrentUser();
    if (user == null) return;
    try {
      if (user.anonymousToken.isNotEmpty) {
        apiClient.setAuthToken(user.anonymousToken);
        realtimeClient?.setAuthToken(user.anonymousToken);
      }

      await apiClient.post('/auth/sync-guest', body: {
        'id': user.id,
        'displayName': user.displayName,
        'recoveryKey': user.recoveryKey,
        'token': user.anonymousToken,
        'avatarUrl': user.avatarUrl,
      });

      final fcmToken = storage.getString('kith_fcm_token');
      if (fcmToken != null && fcmToken.isNotEmpty) {
        final deviceId = storage.getString('kith_device_id') ?? storage.getDeviceId();
        await apiClient.post('/auth/fcm-token', body: {
          'token': fcmToken,
          'deviceId': deviceId,
          'platform': 'android',
          'userId': user.id,
          'accountId': user.effectiveAccountId,
        });

        if (SupabaseConfig.isConfigured) {
          try {
            await _cloudSync.registerFcmToken(
              userId: user.effectiveAccountId,
              deviceId: deviceId,
              token: fcmToken,
              platform: 'android',
            );
          } catch (_) {}
        }
      }
    } catch (_) {
      // Non-blocking background sync to Kith backend
    }

    // Layer 2: Also sync to Supabase with salted cryptographic hashing
    try {
      final deviceId = storage.getDeviceId();
      await _cloudSync.registerOrUpdateAccount(
        accountId: user.effectiveAccountId,
        recoveryKey: user.recoveryKey,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        deviceId: deviceId,
      );
    } catch (_) {}

    // Layer 1: Anchor identity in Android Keystore
    try {
      await _secureId.persistGuestIdentity(user.id, user.recoveryKey);
    } catch (_) {}
  }

  /// Retrieves the existing cached session if present.
  GuestUser? getCurrentUser() {
    final json = storage.getSavedUser();
    if (json == null) return null;
    return GuestUser.fromJson(json);
  }

  /// Detects reinstall scenario and restores guest session from secure/Supabase storage.
  Future<GuestUser?> restoreGuestIfNeeded() async {
    // Fast path: SharedPreferences has a valid user — no reinstall detected
    final cached = getCurrentUser();
    if (cached != null) return cached;

    // Slow path: SharedPreferences is empty — check if Keystore has an anchor
    final secureId = await _secureId.getPersistedGuestId();
    if (secureId == null || secureId.isEmpty) {
      // True fresh install — no identity anywhere
      return null;
    }

    // Reinstall detected: Keystore has guest ID but SharedPreferences is empty.
    // Attempt to restore from Supabase by guest ID.
    final supabaseRow = await _supabaseSync.recoverById(secureId);
    if (supabaseRow != null) {
      final persistedKey = await _secureId.getPersistedRecoveryKey() ?? '';
      final userJson = SupabaseGuestSync.rowToUserJson(supabaseRow, persistedKey);
      final user = GuestUser.fromJson(userJson);
      // Restore to SharedPreferences (and recovery vault)
      await storage.saveUser(user.toJson());
      apiClient.setAuthToken(user.anonymousToken);
      realtimeClient?.setAuthToken(user.anonymousToken);
      // Re-anchor the recovery key in Keystore
      await _secureId.persistGuestIdentity(user.id, user.recoveryKey);

      // Restore full cloud datasets for this account
      unawaited(_restoreAccountDataFromCloud(user.effectiveAccountId));

      return user;
    }

    // Fallback: If Keystore has both ID and Recovery Key, reconstruct local session
    final persistedKey = await _secureId.getPersistedRecoveryKey();
    if (persistedKey != null && persistedKey.isNotEmpty) {
      final vaultUserJson = storage.getUserByRecoveryKey(persistedKey);
      final vaultName = vaultUserJson != null ? (vaultUserJson['displayName'] ?? vaultUserJson['display_name']) as String? : null;

      final user = GuestUser(
        id: secureId,
        displayName: (vaultName != null && vaultName.trim().isNotEmpty && vaultName != 'Traveler') ? vaultName.trim() : (vaultName ?? 'Traveler'),
        recoveryKey: persistedKey,
        anonymousToken: 'kith_sess_${secureId.replaceAll('usr_', '')}',
        createdAt: DateTime.now(),
        isLinkedToAccount: false,
      );
      await storage.saveUser(user.toJson());
      apiClient.setAuthToken(user.anonymousToken);
      realtimeClient?.setAuthToken(user.anonymousToken);
      syncLocalGuestSession(user);
      unawaited(_restoreAccountDataFromCloud(user.effectiveAccountId));
      return user;
    }

    return null;
  }

  /// Restores all cloud data for an account and writes into LocalStorageService.
  Future<void> _restoreAccountDataFromCloud(String accountId) async {
    try {
      final data = await _cloudSync.fetchFullAccountData(accountId);

      // 1. Trips
      final trips = data['trips'] as List<Map<String, dynamic>>? ?? [];
      if (trips.isNotEmpty) {
        final existingTrips = storage.getSavedTrips();
        final tripMap = {for (final t in existingTrips) t['id']: t};
        for (final t in trips) {
          tripMap[t['id']] = t;
        }
        await storage.saveTrips(tripMap.values.toList());
      }

      // 2. Expenses
      final expensesByTrip = data['expenses'] as Map<String, List<Map<String, dynamic>>>? ?? {};
      for (final entry in expensesByTrip.entries) {
        final tripId = entry.key;
        final serverExpenses = entry.value;
        final existingExpenses = storage.getSavedExpenses(tripId);
        final expMap = {for (final e in existingExpenses) e['id']: e};
        for (final e in serverExpenses) {
          expMap[e['id']] = e;
        }
        await storage.saveExpenses(tripId, expMap.values.toList());
      }

      // 3. Settlements
      final settlementsByTrip = data['settlements'] as Map<String, List<Map<String, dynamic>>>? ?? {};
      for (final entry in settlementsByTrip.entries) {
        final tripId = entry.key;
        final serverSettlements = entry.value;
        final existingSettlements = storage.getSavedTripSettlements(tripId);
        final stlMap = {for (final s in existingSettlements) s['id']: s};
        for (final s in serverSettlements) {
          stlMap[s['id']] = s;
        }
        await storage.saveTripSettlements(tripId, stlMap.values.toList());
      }

      // 4. Personal Expenses
      final personalExpenses = data['personal_expenses'] as List<Map<String, dynamic>>? ?? [];
      if (personalExpenses.isNotEmpty) {
        final existingPE = storage.getSavedPersonalExpenses();
        final peMap = {for (final pe in existingPE) pe['id']: pe};
        for (final pe in personalExpenses) {
          peMap[pe['id']] = pe;
        }
        await storage.savePersonalExpenses(peMap.values.toList());
      }

      // 5. Personal Debts
      final personalDebts = data['personal_debts'] as List<Map<String, dynamic>>? ?? [];
      if (personalDebts.isNotEmpty) {
        final existingPD = storage.getSavedPersonalDebts();
        final pdMap = {for (final pd in existingPD) pd['id']: pd};
        for (final pd in personalDebts) {
          pdMap[pd['id']] = pd;
        }
        await storage.savePersonalDebts(pdMap.values.toList());
      }

      debugPrint('[AuthService] Restored ${trips.length} trips and associated data from cloud');
    } catch (e) {
      debugPrint('[AuthService] _restoreAccountDataFromCloud notice: $e');
    }
  }

  /// Creates a new guest session with a cryptographically secure recovery key.
  Future<GuestUser> createGuestUser({
    required String displayName,
    String? avatarUrl,
  }) async {
    final trimmedName = displayName.trim().isEmpty ? 'Traveler' : displayName.trim();
    final deviceId = storage.getDeviceId();

    try {
      final res = await apiClient.post('/auth/guest', body: {
        'displayName': trimmedName,
        'avatarUrl': avatarUrl,
      });

      if (res is Map<String, dynamic>) {
        final data = res.containsKey('data') && res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
        if (data.containsKey('user')) {
          final userData = Map<String, dynamic>.from(data['user'] as Map);
          final token = data['token'] as String? ?? userData['anonymousToken'] as String? ?? '';
          if (token.isNotEmpty && (!userData.containsKey('anonymousToken') || userData['anonymousToken'] == null)) {
            userData['anonymousToken'] = token;
          }

          final user = GuestUser.fromJson(userData);
          apiClient.setAuthToken(token);
          realtimeClient?.setAuthToken(token);
          await storage.saveUser(user.toJson());
          await syncLocalGuestSession(user);
          return user;
        }
      }
    } catch (_) {
      // Offline fallback: generate local session and queue sync
    }

    final id = 'usr_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final recoveryKey = RecoveryKeyService.generateKey();
    final token = 'kith_sess_${_uuid.v4().replaceAll('-', '')}';

    final user = GuestUser(
      id: id,
      accountId: id,
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

    // Register securely on Supabase
    try {
      await _cloudSync.registerOrUpdateAccount(
        accountId: user.effectiveAccountId,
        recoveryKey: recoveryKey,
        displayName: trimmedName,
        avatarUrl: avatarUrl,
        deviceId: deviceId,
      );
      await _supabaseSync.upsertGuestSession(user);
    } catch (_) {}

    // Anchor in Android Keystore
    try {
      await _secureId.persistGuestIdentity(user.id, recoveryKey);
    } catch (_) {}

    return user;
  }

  /// Normalizes a recovery key format regardless of casing, spaces, underscores, or missing KITH- prefix.
  static String normalizeRecoveryKey(String raw) => RecoveryKeyService.normalizeKey(raw);

  /// Recovers a session across devices via recovery key or reviewer email.
  Future<GuestUser?> recoverUser(String recoveryKey) async {
    final rawTrimmed = recoveryKey.trim();
    if (rawTrimmed.toLowerCase().contains('review.nirniq') || rawTrimmed.toUpperCase().contains('PLAY-REVW')) {
      return loginWithReviewerEmail();
    }

    final cleanKey = RecoveryKeyService.normalizeKey(recoveryKey);
    if (cleanKey.isEmpty) return null;

    // Check if locally marked as deleted
    if (storage.isRecoveryKeyDeleted(cleanKey)) {
      debugPrint('[AuthService] Recovery attempt for deleted recovery key rejected: $cleanKey');
      return null;
    }

    final deviceId = storage.getDeviceId();

    // 1. Check active local match
    final existing = getCurrentUser();
    if (existing != null && RecoveryKeyService.normalizeKey(existing.recoveryKey) == cleanKey) {
      return existing;
    }

    // 2. Query Supabase using salted cryptographic verification
    try {
      final supabaseRow = await _cloudSync.recoverAccount(cleanKey, deviceId: deviceId);
      if (supabaseRow != null) {
        final accountId = (supabaseRow['id'] ?? supabaseRow['accountId']) as String;
        final rawDisplayName = supabaseRow['displayName'] as String? ??
            supabaseRow['display_name'] as String? ??
            supabaseRow['name'] as String?;
        final displayName = (rawDisplayName != null && rawDisplayName.trim().isNotEmpty)
            ? rawDisplayName.trim()
            : 'Traveler';
        final token = 'kith_sess_${accountId.replaceAll('usr_', '')}';

        final user = GuestUser(
          id: accountId,
          accountId: accountId,
          displayName: displayName,
          recoveryKey: cleanKey,
          anonymousToken: token,
          createdAt: DateTime.tryParse(supabaseRow['created_at'] as String? ?? '') ?? DateTime.now(),
          isLinkedToAccount: false,
        );

        apiClient.setAuthToken(token);
        realtimeClient?.setAuthToken(token);
        await storage.saveUser(user.toJson());
        await _secureId.persistGuestIdentity(user.id, cleanKey);

        // Fetch and merge all account data from Supabase
        await _restoreAccountDataFromCloud(accountId);

        return user;
      }
    } catch (e) {
      debugPrint('[AuthService] Supabase cloud recovery notice: $e');
    }

    // 3. Query Render backend /auth/recover
    try {
      final backendRes = await apiClient.post('/auth/recover', body: {'recoveryKey': cleanKey});
      if (backendRes is Map<String, dynamic> && backendRes['data'] is Map<String, dynamic>) {
        final data = backendRes['data'] as Map<String, dynamic>;
        final userMap = data['user'] as Map<String, dynamic>?;
        if (userMap != null) {
          final user = GuestUser.fromJson(userMap);
          apiClient.setAuthToken(user.anonymousToken);
          realtimeClient?.setAuthToken(user.anonymousToken);
          await storage.saveUser(user.toJson());
          await _secureId.persistGuestIdentity(user.id, user.recoveryKey);
          syncLocalGuestSession(user);
          return user;
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Backend server recovery notice: $e');
    }

    // 4. Fallback to local device Recovery Vault (if not deleted)
    if (!storage.isRecoveryKeyDeleted(cleanKey)) {
      final vaultUserJson = storage.getUserByRecoveryKey(cleanKey);
      if (vaultUserJson != null) {
        final user = GuestUser.fromJson(vaultUserJson);
        apiClient.setAuthToken(user.anonymousToken);
        realtimeClient?.setAuthToken(user.anonymousToken);
        await storage.saveUser(user.toJson());
        unawaited(_secureId.persistGuestIdentity(user.id, user.recoveryKey));
        syncLocalGuestSession(user);
        return user;
      }
    }

    return null;
  }

  /// Rotates the Recovery Key for the current authenticated user.
  Future<String> rotateRecoveryKey() async {
    final current = getCurrentUser();
    if (current == null) {
      throw Exception('No active user to rotate recovery key.');
    }

    final newKey = RecoveryKeyService.generateKey();
    final updated = current.copyWith(recoveryKey: newKey);

    await storage.saveUser(updated.toJson());
    await _secureId.persistGuestIdentity(updated.id, newKey);

    try {
      await _cloudSync.rotateRecoveryKey(
        accountId: updated.effectiveAccountId,
        newRecoveryKey: newKey,
        displayName: updated.displayName,
      );
    } catch (_) {}

    return newKey;
  }

  /// Direct sign-in for Google Play store review team (review.nirniq@gmail.com)
  Future<GuestUser> loginWithReviewerEmail({String email = 'review.nirniq@gmail.com'}) async {
    final cleanEmail = email.trim().toLowerCase();
    final user = GuestUser(
      id: 'usr_play_reviewer',
      accountId: 'usr_play_reviewer',
      displayName: 'Play Reviewer',
      recoveryKey: 'KITH-PLAY-REVW',
      anonymousToken: 'kith_sess_play_reviewer_token',
      createdAt: DateTime.now(),
      isLinkedToAccount: true,
      email: cleanEmail,
    );
    await storage.saveUser(user.toJson());
    apiClient.setAuthToken(user.anonymousToken);
    realtimeClient?.setAuthToken(user.anonymousToken);
    return user;
  }

  /// Links the current anonymous guest session to a verified email or external auth provider.
  Future<GuestUser> linkToAccount({
    required String email,
    required String provider,
    String? displayName,
  }) async {
    final currentGuest = getCurrentUser();
    final cleanEmail = email.trim().toLowerCase();
    final cleanDisplayName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : (currentGuest?.displayName ?? 'Traveler');

    final updatedUser = (currentGuest ?? GuestUser(
      id: 'usr_${_uuid.v4().replaceAll('-', '').substring(0, 12)}',
      displayName: cleanDisplayName,
      recoveryKey: RecoveryKeyService.generateKey(),
      anonymousToken: 'kith_sess_${cleanEmail.hashCode.abs()}',
      createdAt: DateTime.now(),
      isLinkedToAccount: true,
    )).copyWith(
      isLinkedToAccount: true,
      email: cleanEmail,
      displayName: cleanDisplayName,
    );

    await storage.saveUser(updatedUser.toJson());
    apiClient.setAuthToken(updatedUser.anonymousToken);
    realtimeClient?.setAuthToken(updatedUser.anonymousToken);
    syncLocalGuestSession(updatedUser);
    return updatedUser;
  }

  /// Signs in or canonicalizes account via Nirniq Account credentials.
  Future<GuestUser> signInWithNirniq({
    required String email,
    required String displayName,
    String? photoUrl,
    String? nirniqId,
    String? googleId,
    String? supabaseUserId,
  }) async {
    final currentGuest = getCurrentUser();
    final cleanEmail = email.trim().toLowerCase();
    final cleanDisplayName = displayName.trim().isNotEmpty
        ? displayName.trim()
        : (currentGuest?.displayName ?? 'Traveler');
    final cleanNirniqId = nirniqId ?? supabaseUserId ?? 'nrn_${cleanEmail.hashCode.abs()}';

    try {
      final res = await apiClient.post('/auth/google', body: {
        'email': cleanEmail,
        'displayName': cleanDisplayName,
        'photoUrl': photoUrl,
        'googleId': googleId,
        'supabaseUserId': supabaseUserId,
        'nirniqId': cleanNirniqId,
        'currentGuestId': currentGuest?.id,
      });

      final data = (res is Map<String, dynamic> && res.containsKey('data') && res['data'] is Map<String, dynamic>)
          ? res['data'] as Map<String, dynamic>
          : (res is Map<String, dynamic> ? res : <String, dynamic>{});

      if (data.containsKey('user')) {
        final userData = data['user'] as Map<String, dynamic>;
        final token = data['token'] as String? ?? userData['anonymousToken'] as String? ?? '';
        final user = GuestUser.fromJson(userData);

        await storage.saveUser(user.toJson());
        apiClient.setAuthToken(token);
        realtimeClient?.setAuthToken(token);

        if (currentGuest != null && currentGuest.id != user.id) {
          await _reTagLocalGuestData(currentGuest.id, user.id);
        }

        syncLocalGuestSession(user);
        return user;
      }
    } catch (_) {
      // Offline fallback: continue
    }

    final deterministicId = supabaseUserId ??
        (googleId != null && googleId.isNotEmpty ? 'usr_g_$googleId' : 'usr_nrn_${cleanEmail.hashCode.abs()}');

    final updatedUser = (currentGuest ?? GuestUser(
      id: deterministicId,
      displayName: cleanDisplayName,
      avatarUrl: photoUrl,
      recoveryKey: RecoveryKeyService.generateKey(),
      anonymousToken: 'kith_sess_${cleanEmail.hashCode.abs()}',
      createdAt: DateTime.now(),
      isLinkedToAccount: true,
    )).copyWith(
      id: currentGuest != null ? currentGuest.id : deterministicId,
      isLinkedToAccount: true,
      email: cleanEmail,
      nirniqId: cleanNirniqId,
      googleId: googleId,
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

  Future<void> _reTagLocalGuestData(String oldGuestId, String canonicalUserId) async {
    try {
      final personalExpenses = storage.getSavedPersonalExpenses();
      for (final exp in personalExpenses) {
        if (exp['userId'] == oldGuestId) {
          exp['userId'] = canonicalUserId;
        }
      }
      await storage.savePersonalExpenses(personalExpenses);

      final personalDebts = storage.getSavedPersonalDebts();
      for (final debt in personalDebts) {
        if (debt['userId'] == oldGuestId) {
          debt['userId'] = canonicalUserId;
        }
      }
      await storage.savePersonalDebts(personalDebts);

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
    } catch (_) {}
  }

  /// Signs in or canonicalizes account via Google credentials.
  Future<GuestUser> signInWithGoogle({
    required String email,
    required String displayName,
    String? photoUrl,
    String? googleId,
    String? supabaseUserId,
  }) {
    return signInWithNirniq(
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      googleId: googleId,
      supabaseUserId: supabaseUserId,
    );
  }

  /// Revokes backend session and clears local credentials.

  Future<GuestUser?> restoreNirniqSession() async {
    final session = GoogleAuthService.currentSession;
    if (session == null) return null;

    final supabaseUser = session.user;
    final email = supabaseUser.email;
    if (email == null || email.isEmpty) return null;

    final cached = getCurrentUser();
    if (cached != null && cached.email?.toLowerCase() == email.toLowerCase()) {
      apiClient.setAuthToken(cached.anonymousToken);
      realtimeClient?.setAuthToken(cached.anonymousToken);
      return cached;
    }

    try {
      final displayName = supabaseUser.userMetadata?['full_name'] as String? ??
          supabaseUser.userMetadata?['name'] as String? ??
          email.split('@')[0];
      final photoUrl = supabaseUser.userMetadata?['avatar_url'] as String?;
      final googleId = supabaseUser.userMetadata?['sub'] as String? ?? supabaseUser.id;

      return await signInWithNirniq(
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

  Future<GuestUser?> restoreSupabaseSession() => restoreNirniqSession();

  Future<void> logout() async {
    try {
      await apiClient.post('/auth/fcm-token/delete', body: {});
    } catch (_) {}

    try {
      await GoogleAuthService.signOut();
    } catch (_) {}

    apiClient.setAuthToken(null);
    realtimeClient?.setAuthToken(null);
    realtimeClient?.disconnect();
    await storage.clearAllUserData();
    await _secureId.clearSecureIdentity();
  }

  Future<void> deleteAccount() async {
    final current = getCurrentUser();
    if (current != null) {
      // 1. Mark recovery key permanently deleted on local device & purge vault
      if (current.recoveryKey.isNotEmpty) {
        await storage.markRecoveryKeyDeleted(current.recoveryKey);
        await storage.removeUserFromRecoveryVault(current.recoveryKey);
      }

      // 2. Delete on Render backend server
      try {
        await apiClient.post('/auth/delete-account', body: {'userId': current.id});
      } catch (_) {}
      try {
        await apiClient.delete('/auth/account');
      } catch (_) {}

      // 3. Purge all records from Supabase Cloud
      try {
        await _cloudSync.deleteAccount(
          accountId: current.effectiveAccountId,
          recoveryKey: current.recoveryKey,
        );
      } catch (e) {
        debugPrint('[AuthService] Supabase deleteAccount notice: $e');
      }
    }

    // 4. Wipe local data, Keystore anchor, and disconnect
    await logout();
  }

  Future<GuestUser?> updatePaymentInfo(String upiId, {String? upiQr}) async {
    final current = getCurrentUser();
    if (current == null) return null;
    final updated = current.copyWith(upiId: upiId, upiQr: upiQr);
    await storage.saveUser(updated.toJson());
    await storage.setPrimaryUpiId(upiId);
    try {
      await apiClient.post('/auth/payment', body: {'upiId': upiId, 'upiQr': upiQr});
    } catch (_) {
      try {
        await apiClient.put('/users/${current.id}/payment-info', body: {'upiId': upiId, 'upiQr': upiQr});
      } catch (_) {}
    }
    syncLocalGuestSession(updated);
    return updated;
  }

  Future<GuestUser> updateUserProfile({
    required String displayName,
    String? phoneNumber,
    String? avatarUrl,
    String? email,
    String? upiId,
    String? bio,
  }) async {
    final current = getCurrentUser();
    if (current == null) {
      throw Exception('No active user session');
    }
    final updated = current.copyWith(
      displayName: displayName,
      avatarUrl: avatarUrl ?? current.avatarUrl,
      email: email ?? current.email,
      upiId: upiId ?? current.upiId,
    );
    await storage.saveUser(updated.toJson());
    syncLocalGuestSession(updated);
    return updated;
  }

  Future<String?> getUserUpi(String userId) async {
    final current = getCurrentUser();
    if (current != null && current.id == userId && current.upiId != null) {
      return current.upiId;
    }
    try {
      final res = await apiClient.get('/auth/users/$userId/upi');
      if (res is Map<String, dynamic> && res.containsKey('upiId')) {
        return res['upiId'] as String?;
      }
    } catch (_) {}
    return current?.upiId;
  }
}
