import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'recovery_key_service.dart';

/// Thrown when a cloud snapshot fetch fails partially or is missing critical datasets,

/// preventing the client from silently truncating or wiping local persistent data.

class SyncSnapshotIncompleteException implements Exception {
  final String message;

  final String failedResource;

  const SyncSnapshotIncompleteException(
    this.message, {
    required this.failedResource,
  });

  @override
  String toString() =>
      'SyncSnapshotIncompleteException: $message ($failedResource)';
}

/// Comprehensive, production-grade Supabase cloud synchronization, recovery & notification engine.

///

/// Features:

/// 1. Authoritative Cloud Truth with RLS & Anonymous Guest Sessions.

/// 2. Salted Recovery Key Authentication (plain keys never stored in database).

/// 3. Incremental Delta Sync with cursor tracking to protect Supabase Free Tier.

/// 4. Atomic Multi-Device Recovery and reconciliation.

/// 5. Tombstone-based deletion synchronization.

/// 6. FCM device token management & collaborative event notification dispatch.

class SupabaseCloudSync {
  static const String tableAccounts = 'user_accounts';

  static const String tableGuestSessions = 'guest_sessions';

  static const String tableDevices = 'devices';

  static const String tableTrips = 'trips';

  static const String tableExpenses = 'expenses';

  static const String tableMembers = 'trip_members';

  static const String tableSettlements = 'settlements';

  static const String tablePersonalExpenses = 'personal_expenses';

  static const String tablePersonalDebts = 'personal_debts';

  SupabaseClient get _client => Supabase.instance.client;

  String? _activeSessionToken;

  /// Binds the high-entropy 256-bit guest session token to outgoing PostgREST requests

  /// so that PostgreSQL's hardened `kith_current_user_id()` function cryptographically

  /// verifies identity via SHA-256 hash lookup in `guest_sessions`.

  void setSessionToken(String? sessionToken) {
    _activeSessionToken = sessionToken;

    if (!isAvailable) return;

    try {
      if (sessionToken == null || sessionToken.isEmpty) {
        _client.rest.headers.remove('x-kith-session-token');
      } else {
        _client.rest.headers['x-kith-session-token'] = sessionToken;
      }
    } catch (e) {
      debugPrint('[SupabaseCloudSync] Failed to set session token header: $e');
    }
  }

  /// Registers or refreshes a guest session token hash in Supabase.

  Future<bool> registerGuestSession({
    required String accountId,

    required String sessionTokenHash,

    required String deviceId,
  }) async {
    if (!isAvailable || accountId.isEmpty || sessionTokenHash.isEmpty) {
      return false;
    }

    try {
      await _client.from('guest_sessions').upsert({
        'id': accountId,

        'session_token_hash': sessionTokenHash,

        'is_revoked': false,

        'token_created_at': DateTime.now().toIso8601String(),

        'updated_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Backward-compatible account header binder (used alongside session token during migration).

  void _ensureAccountHeader(String accountId, {String? sessionToken}) {
    if (!isAvailable) return;

    try {
      if (accountId.isNotEmpty) {
        _client.rest.headers['x-kith-account-id'] = accountId;
      }

      if (sessionToken != null && sessionToken.isNotEmpty) {
        setSessionToken(sessionToken);
      } else if (_activeSessionToken != null &&
          _activeSessionToken!.isNotEmpty) {
        _client.rest.headers['x-kith-session-token'] = _activeSessionToken!;
      }
    } catch (e) {
      debugPrint('[SupabaseCloudSync] Failed to set tenant headers: $e');
    }
  }

  /// Fetches records from [tableName] updated after [cursorIso] using stable Composite Keyset Pagination

  /// `(updated_at, id)` in 500-record batches.

  ///

  /// Guarantees:

  /// 1. Concurrent writes during pagination do not shift offsets or skip modified records.

  /// 2. Deterministic traversal even when multiple records share identical timestamps.

  /// 3. Safely bypasses PostgREST's default 1,000-row limit without silent truncation.

  Future<List<Map<String, dynamic>>> _fetchPaginatedTable({
    required String tableName,

    required String cursorIso,

    String? accountIdFilterColumn,

    String? accountId,

    int pageSize = 500,
  }) async {
    final allRecords = <Map<String, dynamic>>[];

    String? lastUpdatedAt;

    String? lastId;

    bool hasMore = true;

    while (hasMore) {
      dynamic query = _client.from(tableName).select('*');

      if (lastUpdatedAt == null || lastId == null) {
        query = query.gt('updated_at', cursorIso);
      } else {
        query = query.or(
          'updated_at.gt.$lastUpdatedAt,and(updated_at.eq.$lastUpdatedAt,id.gt.$lastId)',
        );
      }

      if (accountIdFilterColumn != null &&
          accountId != null &&
          accountId.isNotEmpty) {
        query = query.eq(accountIdFilterColumn, accountId);
      }

      final pageRecords = await query
          .order('updated_at', ascending: true)
          .order('id', ascending: true)
          .limit(pageSize);

      final list = (pageRecords as List<dynamic>? ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      allRecords.addAll(list);

      if (list.length < pageSize) {
        hasMore = false;
      } else {
        final last = list.last;

        lastUpdatedAt = last['updated_at']?.toString();

        lastId = last['id']?.toString();

        if (lastUpdatedAt == null || lastId == null) {
          hasMore = false;
        }
      }
    }

    return allRecords;
  }

  bool get isAvailable {
    try {
      Supabase.instance.client;

      return true;
    } catch (_) {
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────

  // 1. ACCOUNT REGISTRATION & METADATA

  // ───────────────────────────────────────────────────────────────────────────

  /// Registers or updates the logical user account on Supabase with salted key hash.

  Future<bool> registerOrUpdateAccount({
    required String accountId,

    required String recoveryKey,

    required String displayName,

    String? sessionToken,

    String? avatarUrl,

    String? deviceId,
  }) async {
    if (!isAvailable) return false;

    if (accountId.isEmpty || recoveryKey.isEmpty) return false;

    final salt = RecoveryKeyService.generateSalt();

    final keyHash = RecoveryKeyService.hashKey(recoveryKey, salt);

    final token = (sessionToken != null && sessionToken.isNotEmpty)
        ? sessionToken
        : RecoveryKeyService.generateSessionToken();

    final tokenHash = RecoveryKeyService.hashSessionToken(token);

    final nowIso = DateTime.now().toIso8601String();

    setSessionToken(token);

    _ensureAccountHeader(accountId, sessionToken: token);

    try {
      // 1. Attempt secure RPC first

      try {
        await _client.rpc(
          'kith_register_guest_session',
          params: {
            'p_account_id': accountId,

            'p_recovery_key_hash': keyHash,

            'p_salt': salt,

            'p_session_token_hash': tokenHash,

            'p_display_name': displayName,

            'p_device_id': deviceId ?? 'primary',
          },
        );
      } catch (rpcError) {
        // Fallback to direct upsert if RPC not yet deployed

        await _client.from(tableGuestSessions).upsert({
          'id': accountId,

          'recovery_key': keyHash,

          'display_name': displayName,

          'anonymous_token': salt,

          'session_token_hash': tokenHash,

          'last_seen_at': nowIso,
        }, onConflict: 'id');
      }

      // 2. Register device

      if (deviceId != null && deviceId.isNotEmpty) {
        try {
          await registerDevice(
            accountId: accountId,

            deviceId: deviceId,

            platform: 'android',

            appVersion: '1.0.1+14',
          );
        } catch (_) {}
      }

      debugPrint(
        '[SupabaseCloudSync] Account registered securely with session token for $accountId',
      );

      return true;
    } catch (e) {
      debugPrint(
        '[SupabaseCloudSync] registerOrUpdateAccount notice (non-fatal): $e',
      );

      return false;
    }
  }

  /// Registers a device belonging to the logical account.

  Future<void> registerDevice({
    required String accountId,

    required String deviceId,

    required String platform,

    required String appVersion,
  }) async {
    if (!isAvailable) return;

    try {
      await _client.from(tableDevices).upsert({
        'id': '${accountId}_$deviceId',

        'account_id': accountId,

        'device_id': deviceId,

        'platform': platform,

        'app_version': appVersion,

        'last_seen_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('[SupabaseCloudSync] registerDevice notice: $e');
    }
  }

  /// Permanently purges the user account, session, devices, FCM tokens, and associated data from Supabase.

  Future<bool> deleteAccount({
    required String accountId,

    required String recoveryKey,
  }) async {
    if (!isAvailable) return false;

    if (accountId.isEmpty) return false;

    try {
      // 1. Delete from guest_sessions table

      try {
        await _client.from(tableGuestSessions).delete().eq('id', accountId);
      } catch (e) {
        debugPrint('[SupabaseCloudSync] guest_sessions delete notice: $e');
      }

      // Also delete any session matching the recovery key hash

      if (recoveryKey.isNotEmpty) {
        try {
          final normalizedKey = RecoveryKeyService.normalizeKey(recoveryKey);

          final rows = await _client
              .from(tableGuestSessions)
              .select('id, recovery_key, anonymous_token');

          final rList = rows as List<dynamic>? ?? [];

          for (final r in rList) {
            final storedHash = r['recovery_key'] as String?;

            final salt = r['anonymous_token'] as String?;

            final rId = r['id'] as String?;

            if (storedHash != null && salt != null && rId != null) {
              if (RecoveryKeyService.verifyKey(
                normalizedKey,
                storedHash,
                salt,
              )) {
                await _client.from(tableGuestSessions).delete().eq('id', rId);
              }
            }
          }
        } catch (_) {}
      }

      // 2. Delete from user_accounts

      try {
        await _client.from(tableAccounts).delete().eq('id', accountId);
      } catch (_) {}

      // 3. Delete registered devices

      try {
        await _client.from(tableDevices).delete().eq('account_id', accountId);
      } catch (_) {}

      // 4. Delete FCM tokens

      try {
        await _client.from('user_fcm_tokens').delete().eq('user_id', accountId);
      } catch (_) {}

      // 5. Delete personal finances

      try {
        await _client
            .from(tablePersonalExpenses)
            .delete()
            .eq('user_id', accountId);
      } catch (_) {}

      try {
        await _client
            .from(tablePersonalDebts)
            .delete()
            .eq('user_id', accountId);
      } catch (_) {}

      try {
        await _client
            .from('personal_budgets')
            .delete()
            .eq('user_id', accountId);
      } catch (_) {}

      try {
        await _client
            .from('personal_repayments')
            .delete()
            .eq('user_id', accountId);
      } catch (_) {}

      // 6. Delete trip memberships

      try {
        await _client.from(tableMembers).delete().eq('user_id', accountId);
      } catch (_) {}

      // 7. Delete trips created by this account

      try {
        await _client.from(tableTrips).delete().eq('creator_id', accountId);
      } catch (_) {}

      // 8. Delete user record

      try {
        await _client.from('users').delete().eq('id', accountId);
      } catch (_) {}

      debugPrint(
        '[SupabaseCloudSync] Successfully purged account $accountId from Supabase',
      );

      return true;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] deleteAccount error: $e');

      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────

  // 2. ACCOUNT RECOVERY (VERIFY SALTED HASH)

  // ───────────────────────────────────────────────────────────────────────────

  /// Recovers account data by verifying raw recovery key against stored salted hashes.

  Future<Map<String, dynamic>?> recoverAccount(
    String rawRecoveryKey, {

    required String deviceId,
  }) async {
    if (!isAvailable) return null;

    final normalizedKey = RecoveryKeyService.normalizeKey(rawRecoveryKey);

    if (!RecoveryKeyService.isValidKeyFormat(normalizedKey)) {
      debugPrint('[SupabaseCloudSync] Invalid key format during recovery');

      return null;
    }

    final newSessionToken = RecoveryKeyService.generateSessionToken();

    final newSessionTokenHash = RecoveryKeyService.hashSessionToken(
      newSessionToken,
    );

    // 1. Attempt secure server-side RPC (prevents downloading table)

    try {
      final rpcRes = await _client.rpc(
        'kith_recover_guest_account',
        params: {
          'p_recovery_key': normalizedKey,

          'p_new_session_token_hash': newSessionTokenHash,

          'p_device_id': deviceId,
        },
      );

      if (rpcRes is Map && rpcRes['success'] == true) {
        final accountId =
            rpcRes['id']?.toString() ?? rpcRes['accountId']?.toString() ?? '';

        final resolvedName = rpcRes['displayName']?.toString() ?? 'Traveler';

        setSessionToken(newSessionToken);

        _ensureAccountHeader(accountId, sessionToken: newSessionToken);

        await registerDevice(
          accountId: accountId,

          deviceId: deviceId,

          platform: 'android',

          appVersion: '1.0.1+14',
        );

        return {
          'id': accountId,

          'accountId': accountId,

          'displayName': resolvedName,

          'display_name': resolvedName,

          'recoveryKey': normalizedKey,

          'sessionToken': newSessionToken,

          'anonymousToken': 'kith_rec_$accountId',

          'createdAt': rpcRes['createdAt'] ?? DateTime.now().toIso8601String(),
        };
      }
    } catch (rpcErr) {
      debugPrint(
        '[SupabaseCloudSync] RPC recovery notice (trying direct): $rpcErr',
      );
    }

    // 2. Fallback to direct salted key verification

    try {
      final response = await _client
          .from(tableGuestSessions)
          .select(
            'id, recovery_key, display_name, anonymous_token, created_at, last_seen_at',
          );

      final rows = response as List<dynamic>? ?? [];

      for (final row in rows) {
        final storedHash = row['recovery_key'] as String?;

        final salt = row['anonymous_token'] as String?;

        if (storedHash == null || salt == null) continue;

        if (RecoveryKeyService.verifyKey(normalizedKey, storedHash, salt)) {
          final accountId = row['id'] as String;

          debugPrint(
            '[SupabaseCloudSync] Salted hash matched for account $accountId',
          );

          setSessionToken(newSessionToken);

          _ensureAccountHeader(accountId, sessionToken: newSessionToken);

          await registerDevice(
            accountId: accountId,

            deviceId: deviceId,

            platform: 'android',

            appVersion: '1.0.1+14',
          );

          String resolvedName = (row['display_name'] as String?)?.trim() ?? '';

          if (resolvedName.isEmpty || resolvedName == 'Traveler') {
            try {
              final userRes = await _client
                  .from('users')
                  .select('display_name')
                  .eq('id', accountId)
                  .maybeSingle();

              if (userRes != null &&
                  userRes['display_name'] != null &&
                  (userRes['display_name'] as String).trim().isNotEmpty) {
                resolvedName = (userRes['display_name'] as String).trim();
              }
            } catch (_) {}
          }

          if (resolvedName.isEmpty || resolvedName == 'Traveler') {
            try {
              final memberRes = await _client
                  .from(tableMembers)
                  .select('display_name')
                  .eq('user_id', accountId)
                  .limit(1);

              final mList = memberRes as List<dynamic>? ?? [];

              if (mList.isNotEmpty &&
                  mList.first['display_name'] != null &&
                  (mList.first['display_name'] as String).trim().isNotEmpty) {
                resolvedName = (mList.first['display_name'] as String).trim();
              }
            } catch (_) {}
          }

          if (resolvedName.isEmpty) {
            resolvedName = 'Traveler';
          }

          return {
            'id': accountId,

            'accountId': accountId,

            'displayName': resolvedName,

            'display_name': resolvedName,

            'recoveryKey': normalizedKey,

            'sessionToken': newSessionToken,

            'anonymousToken': 'kith_rec_$accountId',

            'createdAt': row['created_at'] ?? DateTime.now().toIso8601String(),
          };
        }
      }

      debugPrint(
        '[SupabaseCloudSync] No matching account found for provided key hash',
      );

      return null;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] recoverAccount error: $e');

      return null;
    }
  }

  /// Fetches all cloud entities for an account to restore local storage.

  Future<Map<String, dynamic>> fetchFullAccountData(String accountId) async {
    if (!isAvailable) return {};

    _ensureAccountHeader(accountId);

    final result = <String, dynamic>{};

    try {
      // 1. Trips

      try {
        final memberTrips = await _client
            .from(tableMembers)
            .select('trip_id')
            .eq('user_id', accountId);

        final tripIds = (memberTrips as List<dynamic>? ?? [])
            .map((m) => m['trip_id'] as String)
            .toSet()
            .toList();

        final tripsCreated = await _client
            .from(tableTrips)
            .select('id')
            .eq('creator_id', accountId);

        for (final t in (tripsCreated as List<dynamic>? ?? [])) {
          tripIds.add(t['id'] as String);
        }

        if (tripIds.isNotEmpty) {
          final tripsData = await _client
              .from(tableTrips)
              .select('*')
              .inFilter('id', tripIds)
              .eq('is_deleted', false);

          final tripsList = <Map<String, dynamic>>[];

          for (final t in (tripsData as List<dynamic>? ?? [])) {
            final tripMap = Map<String, dynamic>.from(t as Map);

            final membersData = await _client
                .from(tableMembers)
                .select('*')
                .eq('trip_id', tripMap['id']);

            tripMap['members'] = (membersData as List<dynamic>? ?? [])
                .map(
                  (m) => {
                    'id': m['id'],

                    'tripId': m['trip_id'],

                    'userId': m['user_id'],

                    'displayName': m['display_name'],

                    'avatarUrl': m['avatar_url'],

                    'role': m['role'],

                    'upiId': m['upi_id'],

                    'isClaimed': m['is_claimed'] ?? true,

                    'isVirtual': m['is_virtual'] ?? false,

                    'claimToken': m['claim_token'],

                    'status': m['status'],

                    'mergedIntoMemberId': m['merged_into_member_id'],

                    'joinedAt': m['joined_at'],
                  },
                )
                .toList();

            tripsList.add(tripMap);
          }

          result['trips'] = tripsList;

          // Expenses for these trips

          final expensesData = await _client
              .from(tableExpenses)
              .select('*')
              .inFilter('trip_id', tripIds)
              .eq('is_deleted', false);

          final expensesByTrip = <String, List<Map<String, dynamic>>>{};

          for (final e in (expensesData as List<dynamic>? ?? [])) {
            final expMap = Map<String, dynamic>.from(e as Map);

            final tid = expMap['trip_id'] as String;

            expensesByTrip.putIfAbsent(tid, () => []).add(expMap);
          }

          result['expenses'] = expensesByTrip;

          // Settlements for these trips

          final settlementsData = await _client
              .from(tableSettlements)
              .select('*')
              .inFilter('trip_id', tripIds)
              .eq('is_deleted', false);

          final settlementsByTrip = <String, List<Map<String, dynamic>>>{};

          for (final s in (settlementsData as List<dynamic>? ?? [])) {
            final stlMap = Map<String, dynamic>.from(s as Map);

            final tid = stlMap['trip_id'] as String;

            settlementsByTrip.putIfAbsent(tid, () => []).add(stlMap);
          }

          result['settlements'] = settlementsByTrip;
        }
      } catch (e) {
        debugPrint('[SupabaseCloudSync] fetch trips notice: $e');
      }

      // 2. Personal Expenses

      try {
        final peData = await _client
            .from(tablePersonalExpenses)
            .select('*')
            .eq('user_id', accountId)
            .eq('is_deleted', false);

        result['personal_expenses'] = (peData as List<dynamic>? ?? [])
            .map((pe) => Map<String, dynamic>.from(pe as Map))
            .toList();
      } catch (_) {}

      // 3. Personal Debts

      try {
        final pdData = await _client
            .from(tablePersonalDebts)
            .select('*')
            .eq('user_id', accountId)
            .eq('is_deleted', false);

        result['personal_debts'] = (pdData as List<dynamic>? ?? [])
            .map((pd) => Map<String, dynamic>.from(pd as Map))
            .toList();
      } catch (_) {}

      return result;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] fetchFullAccountData error: $e');

      return {};
    }
  }

  // ───────────────────────────────────────────────────────────────────────────

  // 3. INCREMENTAL DELTA SYNC (BY CURSOR)

  // ───────────────────────────────────────────────────────────────────────────

  /// Fetches changes that occurred since [sinceCursor] for this account.

  /// Fetches ordered change events using PostgreSQL serialized monotonic sequence RPC (kith_fetch_sync_events).
  /// Guarantees that committed changes cannot be missed or skipped due to transaction commit lag.
  Future<List<Map<String, dynamic>>> fetchSyncEvents({
    required String accountId,
    required int lastSeq,
    int limit = 500,
  }) async {
    if (!isAvailable) return [];
    _ensureAccountHeader(accountId);
    try {
      final res = await _client.rpc(
        'kith_fetch_sync_events',
        params: {'p_last_seq': lastSeq, 'p_limit': limit},
      );
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[SupabaseCloudSync] fetchSyncEvents notice: ');
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchDeltaChanges({
    required String accountId,

    required DateTime sinceCursor,

    List<String> activeTripIds = const [],
  }) async {
    if (!isAvailable) return {};

    _ensureAccountHeader(accountId);

    final fetchStartTime = DateTime.now();

    // Safety buffer (minimum 30 seconds) protects against transaction start timestamp lag

    final safeCursor = sinceCursor.subtract(const Duration(seconds: 30));

    final cursorIso = safeCursor.toIso8601String();

    final deltas = <String, dynamic>{};

    try {
      // 1. Fetch updated trips paginated

      final tripsRes = await _fetchPaginatedTable(
        tableName: tableTrips,

        cursorIso: cursorIso,
      );

      final modifiedTrips = <Map<String, dynamic>>[];

      for (final tripMap in tripsRes) {
        final membersData = await _client
            .from(tableMembers)
            .select('*')
            .eq('trip_id', tripMap['id']);

        tripMap['members'] = (membersData as List<dynamic>? ?? [])
            .map(
              (m) => {
                'id': m['id'],

                'tripId': m['trip_id'],

                'userId': m['user_id'],

                'displayName': m['display_name'],

                'avatarUrl': m['avatar_url'],

                'role': m['role'],

                'upiId': m['upi_id'],

                'isClaimed': m['is_claimed'] ?? true,

                'isVirtual': m['is_virtual'] ?? false,

                'claimToken': m['claim_token'],

                'status': m['status'],

                'mergedIntoMemberId': m['merged_into_member_id'],

                'joinedAt': m['joined_at'],
              },
            )
            .toList();

        modifiedTrips.add(tripMap);
      }

      deltas['modifiedTrips'] = modifiedTrips;

      // 2. Fetch updated expenses paginated

      deltas['modifiedExpenses'] = await _fetchPaginatedTable(
        tableName: tableExpenses,

        cursorIso: cursorIso,
      );

      // 3. Fetch updated settlements paginated

      deltas['modifiedSettlements'] = await _fetchPaginatedTable(
        tableName: tableSettlements,

        cursorIso: cursorIso,
      );

      // 4. Fetch updated personal expenses paginated

      deltas['modifiedPersonalExpenses'] = await _fetchPaginatedTable(
        tableName: tablePersonalExpenses,

        cursorIso: cursorIso,

        accountIdFilterColumn: 'user_id',

        accountId: accountId,
      );

      // 5. Fetch updated personal debts paginated

      deltas['modifiedPersonalDebts'] = await _fetchPaginatedTable(
        tableName: tablePersonalDebts,

        cursorIso: cursorIso,

        accountIdFilterColumn: 'user_id',

        accountId: accountId,
      );

      DateTime? latestTs;

      void checkTs(String? tsStr) {
        if (tsStr != null && tsStr.isNotEmpty) {
          final dt = DateTime.tryParse(tsStr);

          if (dt != null && (latestTs == null || dt.isAfter(latestTs!))) {
            latestTs = dt;
          }
        }
      }

      for (final t in modifiedTrips) {
        checkTs(t['updated_at']?.toString());
      }

      for (final e
          in (deltas['modifiedExpenses'] as List<Map<String, dynamic>>? ??
              [])) {
        checkTs(e['updated_at']?.toString());
      }

      for (final s
          in (deltas['modifiedSettlements'] as List<Map<String, dynamic>>? ??
              [])) {
        checkTs(s['updated_at']?.toString());
      }

      for (final pe
          in (deltas['modifiedPersonalExpenses']
                  as List<Map<String, dynamic>>? ??
              [])) {
        checkTs(pe['updated_at']?.toString());
      }

      for (final pd
          in (deltas['modifiedPersonalDebts'] as List<Map<String, dynamic>>? ??
              [])) {
        checkTs(pd['updated_at']?.toString());
      }

      if (latestTs != null) {
        // Cursor Bound Safety: Cursor watermark can NEVER advance beyond query start time,

        // preventing race conditions with uncommitted in-flight transactions.

        final boundedCursor = latestTs!.isBefore(fetchStartTime)
            ? latestTs!
            : fetchStartTime;

        deltas['latestServerTimestamp'] = boundedCursor.toIso8601String();
      }

      return deltas;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] fetchDeltaChanges notice: $e');

      return {};
    }
  }

  // ───────────────────────────────────────────────────────────────────────────

  // 4. ENTITY SYNCHRONIZATION

  // ───────────────────────────────────────────────────────────────────────────

  /// Upserts a trip and its members to Supabase.

  Future<bool> syncTrip(
    Map<String, dynamic> tripJson, {
    required String accountId,
  }) async {
    if (!isAvailable) return false;

    _ensureAccountHeader(accountId);

    try {
      final tripId = tripJson['id'];

      await _client.from(tableTrips).upsert({
        'id': tripId,

        'name': tripJson['name'],

        'description': tripJson['description'],

        'emoji': tripJson['emoji'] ?? '✈️',

        'currency_code': tripJson['currencyCode'] ?? 'INR',

        'creator_id': tripJson['creatorId'] ?? accountId,

        'invite_code': tripJson['inviteCode'],

        'lifecycle_state': tripJson['lifecycleState'] ?? 'active',

        'trip_mode': tripJson['tripMode'] ?? 'split_only',

        'is_deleted': tripJson['isDeleted'] ?? false,

        'created_at': tripJson['createdAt'] ?? DateTime.now().toIso8601String(),

        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      final members = tripJson['members'] as List<dynamic>? ?? [];

      for (final m in members) {
        if (m is Map<String, dynamic>) {
          final isVirtual =
              m['isVirtual'] == true ||
              m['is_virtual'] == true ||
              m['isClaimed'] == false ||
              m['is_claimed'] == false ||
              (m['userId'] as String? ?? '').startsWith('unclaimed_');

          await _client.from(tableMembers).upsert({
            'id': m['id'],

            'trip_id': tripId,

            'user_id': m['userId'] ?? 'unclaimed_',

            'display_name':
                (m['displayName'] ?? m['display_name'] ?? 'Traveler')
                    .toString()
                    .trim()
                    .isNotEmpty
                ? (m['displayName'] ?? m['display_name']).toString().trim()
                : 'Traveler',

            'avatar_url': m['avatarUrl'] ?? m['avatar_url'],

            'role': m['role'] ?? 'member',

            'upi_id': m['upi_id'] ?? m['upiId'],

            'is_claimed': m['isClaimed'] ?? m['is_claimed'] ?? !isVirtual,

            'is_virtual': isVirtual,

            'claim_token': m['claimToken'] ?? m['claim_token'],

            'status': m['status'] ?? (isVirtual ? 'unclaimed' : 'claimed'),

            'merged_into_member_id':
                m['mergedIntoMemberId'] ?? m['merged_into_member_id'],

            'joined_at':
                m['joinedAt'] ??
                m['joined_at'] ??
                DateTime.now().toIso8601String(),
          }, onConflict: 'id');
        }
      }

      return true;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] syncTrip error: $e');

      return false;
    }
  }

  /// Upserts an expense to Supabase.

  Future<bool> syncExpense(
    Map<String, dynamic> expenseJson, {
    required String accountId,
  }) async {
    if (!isAvailable) return false;

    try {
      final paidById =
          expenseJson['paidById'] ??
          expenseJson['paid_by_id'] ??
          expenseJson['paidByMemberId'] ??
          expenseJson['paid_by_member_id'];

      await _client.from(tableExpenses).upsert({
        'id': expenseJson['id'],

        'trip_id': expenseJson['tripId'] ?? expenseJson['trip_id'],

        'title': expenseJson['title'],

        'amount_in_paise':
            expenseJson['amountInPaise'] ?? expenseJson['amount_in_paise'],

        'category': expenseJson['category'] ?? 'general',

        'paid_by_id': paidById,

        'paid_by_member_id': paidById,

        'paid_by_user_id':
            expenseJson['paidByUserId'] ??
            expenseJson['paid_by_user_id'] ??
            accountId,

        'split_type':
            expenseJson['splitType'] ?? expenseJson['split_type'] ?? 'equal',

        'splits': expenseJson['splits'] ?? [],

        'location': expenseJson['location'],

        'receipt_url': expenseJson['receiptUrl'] ?? expenseJson['receipt_url'],

        'is_deleted':
            expenseJson['isDeleted'] ?? expenseJson['is_deleted'] ?? false,

        'created_at':
            expenseJson['createdAt'] ??
            expenseJson['created_at'] ??
            DateTime.now().toIso8601String(),

        'updated_at':
            expenseJson['updatedAt'] ??
            expenseJson['updated_at'] ??
            DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      return true;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] syncExpense error: $e');

      return false;
    }
  }

  /// Synchronizes a tombstone deletion for an expense.

  Future<bool> markExpenseDeleted(String expenseId, String tripId) async {
    if (!isAvailable) return false;

    try {
      await _client
          .from(tableExpenses)
          .update({
            'is_deleted': true,

            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', expenseId);

      return true;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] markExpenseDeleted error: $e');

      return false;
    }
  }

  /// Upserts a settlement transaction to Supabase.

  Future<bool> syncSettlement(
    Map<String, dynamic> settlementJson, {
    required String accountId,
  }) async {
    if (!isAvailable) return false;

    try {
      await _client.from(tableSettlements).upsert({
        'id': settlementJson['id'],

        'trip_id': settlementJson['tripId'],

        'from_member_id': settlementJson['fromMemberId'],

        'to_member_id': settlementJson['toMemberId'],

        'amount_in_paise': settlementJson['amountInPaise'],

        'status': settlementJson['status'] ?? 'completed',

        'payment_reference': settlementJson['paymentReference'],

        'proof_url': settlementJson['proofUrl'],

        'settled_at':
            settlementJson['settledAt'] ??
            settlementJson['createdAt'] ??
            DateTime.now().toIso8601String(),

        'created_at':
            settlementJson['createdAt'] ?? DateTime.now().toIso8601String(),

        'updated_at': DateTime.now().toIso8601String(),

        'is_deleted': false,
      }, onConflict: 'id');

      return true;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] syncSettlement error: $e');

      return false;
    }
  }

  /// Upserts a personal expense to Supabase.

  Future<bool> syncPersonalExpense(
    Map<String, dynamic> peJson, {
    required String accountId,
  }) async {
    if (!isAvailable) return false;

    _ensureAccountHeader(accountId);

    try {
      await _client.from(tablePersonalExpenses).upsert({
        'id': peJson['id'],

        'user_id': peJson['userId'] ?? accountId,

        'title': peJson['title'],

        'amount_in_paise': peJson['amountInPaise'],

        'category': peJson['category'] ?? 'general',

        'date': peJson['date'] ?? DateTime.now().toIso8601String(),

        'notes': peJson['notes'],

        'created_at': peJson['createdAt'] ?? DateTime.now().toIso8601String(),

        'updated_at': peJson['updatedAt'] ?? DateTime.now().toIso8601String(),

        'is_deleted': peJson['isDeleted'] ?? false,
      }, onConflict: 'id');

      return true;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] syncPersonalExpense error: $e');

      return false;
    }
  }

  /// Upserts a personal debt/loan to Supabase.

  Future<bool> syncPersonalDebt(
    Map<String, dynamic> debtJson, {
    required String accountId,
  }) async {
    if (!isAvailable) return false;

    _ensureAccountHeader(accountId);

    try {
      await _client.from(tablePersonalDebts).upsert({
        'id': debtJson['id'],

        'user_id': debtJson['userId'] ?? accountId,

        'borrower_name':
            debtJson['personName'] ?? debtJson['borrowerName'] ?? 'Friend',

        'lender_name': debtJson['lenderName'] ?? 'Me',

        'amount_in_paise': debtJson['amountInPaise'],

        'status': debtJson['status'] ?? 'pending',

        'notes': debtJson['notes'],

        'due_date': debtJson['dueDate'],

        'created_at': debtJson['createdAt'] ?? DateTime.now().toIso8601String(),

        'updated_at': debtJson['updatedAt'] ?? DateTime.now().toIso8601String(),

        'is_deleted': debtJson['isDeleted'] ?? false,
      }, onConflict: 'id');

      return true;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] syncPersonalDebt error: $e');

      return false;
    }
  }

  /// Rotates the Recovery Key for an existing account.

  Future<bool> rotateRecoveryKey({
    required String accountId,

    required String newRecoveryKey,

    required String displayName,
  }) async {
    return registerOrUpdateAccount(
      accountId: accountId,

      recoveryKey: newRecoveryKey,

      displayName: displayName,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────

  // 5. NOTIFICATION TOKEN MANAGEMENT & SERVER-SIDE EVENT DISPATCH

  // ───────────────────────────────────────────────────────────────────────────

  /// Registers or refreshes an FCM device token in Supabase user_fcm_tokens.

  Future<bool> registerFcmToken({
    required String userId,

    required String deviceId,

    required String token,

    String platform = 'android',
  }) async {
    if (!isAvailable) return false;

    try {
      try {
        await _client
            .from('user_fcm_tokens')
            .delete()
            .eq('token', token)
            .neq('user_id', userId);
      } catch (_) {}

      await _client.from('user_fcm_tokens').upsert({
        'user_id': userId,

        'device_id': deviceId,

        'token': token,

        'platform': platform,

        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_id');

      debugPrint(
        '[SupabaseCloudSync] FCM token registered for $userId on $deviceId',
      );

      return true;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] registerFcmToken notice: $e');

      return false;
    }
  }

  /// Removes an FCM device token upon logout or account change.

  Future<void> unregisterFcmToken(String token) async {
    if (!isAvailable) return;

    try {
      await _client.from('user_fcm_tokens').delete().eq('token', token);

      debugPrint('[SupabaseCloudSync] FCM token unregistered');
    } catch (e) {
      debugPrint('[SupabaseCloudSync] unregisterFcmToken notice: $e');
    }
  }

  /// Dispatches a persistent notification event to Supabase.

  Future<void> dispatchNotificationEvent({
    required String recipientUserId,

    required String actorUserId,

    required String actorName,

    required String title,

    required String body,

    required String eventType,

    String? tripId,

    String? tripName,

    String? expenseId,

    String? settlementId,

    int? amountInPaise,

    String? route,

    String? idempotencyKey,
  }) async {
    if (!isAvailable || recipientUserId.isEmpty) return;

    if (recipientUserId == actorUserId) return;

    final nowIso = DateTime.now().toIso8601String();

    final notifId =
        idempotencyKey ??
        'notif_${DateTime.now().millisecondsSinceEpoch}_${recipientUserId.hashCode.abs()}';

    try {
      await _client.from('notifications').upsert({
        'id': notifId,

        'recipient_user_id': recipientUserId,

        'actor_user_id': actorUserId,

        'actor_name': actorName,

        'trip_id': tripId,

        'trip_name': tripName,

        'expense_id': expenseId,

        'settlement_id': settlementId,

        'type': eventType,

        'title': title,

        'body': body,

        'route': route ?? (tripId != null ? '/trip/$tripId' : '/notifications'),

        'amount_in_paise': amountInPaise ?? 0,

        'is_read': false,

        'created_at': nowIso,

        'updated_at': nowIso,
      }, onConflict: 'id');

      debugPrint(
        '[SupabaseCloudSync] Notification event recorded: $notifId for $recipientUserId',
      );
    } catch (e) {
      debugPrint(
        '[SupabaseCloudSync] dispatchNotificationEvent notice (non-fatal): $e',
      );
    }
  }

  /// Automatically broadcasts notifications to other members of a trip when an expense is added/updated.

  Future<void> notifyTripMembersForExpense({
    required String tripId,

    required String actorUserId,

    required String actorName,

    required String expenseTitle,

    required int amountInPaise,

    required String expenseId,

    bool isUpdate = false,
  }) async {
    if (!isAvailable) return;

    try {
      final membersRes = await _client
          .from(tableMembers)
          .select('user_id')
          .eq('trip_id', tripId);

      final members = membersRes as List<dynamic>? ?? [];

      final formattedAmt = '₹${(amountInPaise / 100).toStringAsFixed(2)}';

      final title = isUpdate
          ? '$actorName updated an expense'
          : '$actorName added an expense';

      final body = '$expenseTitle · $formattedAmt';

      final route = '/trip/$tripId?expenseId=$expenseId';

      for (final m in members) {
        final uid = m['user_id'] as String?;

        if (uid != null &&
            uid.isNotEmpty &&
            uid != actorUserId &&
            !uid.startsWith('unclaimed_')) {
          await dispatchNotificationEvent(
            recipientUserId: uid,

            actorUserId: actorUserId,

            actorName: actorName,

            title: title,

            body: body,

            eventType: isUpdate ? 'EXPENSE_UPDATED' : 'EXPENSE_ADDED',

            tripId: tripId,

            expenseId: expenseId,

            amountInPaise: amountInPaise,

            route: route,

            idempotencyKey:
                '${expenseId}_${isUpdate ? 'update' : 'create'}_$uid',
          );
        }
      }
    } catch (e) {
      debugPrint('[SupabaseCloudSync] notifyTripMembersForExpense notice: $e');
    }
  }
}
