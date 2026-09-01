import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'recovery_key_service.dart';

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
    String? avatarUrl,
    String? deviceId,
  }) async {
    if (!isAvailable) return false;
    if (accountId.isEmpty || recoveryKey.isEmpty) return false;

    final salt = RecoveryKeyService.generateSalt();
    final keyHash = RecoveryKeyService.hashKey(recoveryKey, salt);
    final nowIso = DateTime.now().toIso8601String();

    try {
      // 1. Upsert into guest_sessions (existing table) with hashed metadata
      await _client.from(tableGuestSessions).upsert({
        'id': accountId,
        'recovery_key': keyHash, // Storing cryptographic hash
        'display_name': displayName,
        'anonymous_token': salt, // Storing per-account cryptographic salt
        'last_seen_at': nowIso,
      }, onConflict: 'id');

      // 2. Also register device if deviceId provided
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

      debugPrint('[SupabaseCloudSync] Account registered securely for $accountId');
      return true;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] registerOrUpdateAccount notice (non-fatal): $e');
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

    try {
      final response = await _client
          .from(tableGuestSessions)
          .select('id, recovery_key, display_name, anonymous_token, created_at, last_seen_at');

      final rows = response as List<dynamic>? ?? [];

      for (final row in rows) {
        final storedHash = row['recovery_key'] as String?;
        final salt = row['anonymous_token'] as String?;

        if (storedHash == null || salt == null) continue;

        if (RecoveryKeyService.verifyKey(normalizedKey, storedHash, salt)) {
          debugPrint('[SupabaseCloudSync] Salted hash matched for account ${row['id']}');

          await registerDevice(
            accountId: row['id'],
            deviceId: deviceId,
            platform: 'android',
            appVersion: '1.0.1+14',
          );

          return {
            'id': row['id'],
            'accountId': row['id'],
            'displayName': row['display_name'] ?? 'Traveler',
            'recoveryKey': normalizedKey,
            'anonymousToken': 'kith_rec_${row['id']}',
            'createdAt': row['created_at'] ?? DateTime.now().toIso8601String(),
          };
        }
      }

      debugPrint('[SupabaseCloudSync] No matching account found for provided key hash');
      return null;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] recoverAccount error: $e');
      return null;
    }
  }

  /// Fetches all cloud entities for an account to restore local storage.
  Future<Map<String, dynamic>> fetchFullAccountData(String accountId) async {
    if (!isAvailable) return {};

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

            tripMap['members'] = (membersData as List<dynamic>? ?? []).map((m) => {
              'id': m['id'],
              'tripId': m['trip_id'],
              'userId': m['user_id'],
              'displayName': m['display_name'],
              'avatarUrl': m['avatar_url'],
              'role': m['role'],
              'upiId': m['upi_id'],
              'joinedAt': m['joined_at'],
            }).toList();

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
  Future<Map<String, dynamic>> fetchDeltaChanges({
    required String accountId,
    required DateTime sinceCursor,
    List<String> activeTripIds = const [],
  }) async {
    if (!isAvailable) return {};

    final cursorIso = sinceCursor.toIso8601String();
    final deltas = <String, dynamic>{};

    try {
      // 1. Fetch updated trips
      final tripsRes = await _client
          .from(tableTrips)
          .select('*')
          .gt('updated_at', cursorIso);

      final modifiedTrips = <Map<String, dynamic>>[];
      for (final t in (tripsRes as List<dynamic>? ?? [])) {
        final tripMap = Map<String, dynamic>.from(t as Map);
        final membersData = await _client
            .from(tableMembers)
            .select('*')
            .eq('trip_id', tripMap['id']);

        tripMap['members'] = (membersData as List<dynamic>? ?? []).map((m) => {
          'id': m['id'],
          'tripId': m['trip_id'],
          'userId': m['user_id'],
          'displayName': m['display_name'],
          'avatarUrl': m['avatar_url'],
          'role': m['role'],
          'upiId': m['upi_id'],
          'joinedAt': m['joined_at'],
        }).toList();

        modifiedTrips.add(tripMap);
      }
      deltas['modifiedTrips'] = modifiedTrips;

      // 2. Fetch updated expenses
      final expensesRes = await _client
          .from(tableExpenses)
          .select('*')
          .gt('updated_at', cursorIso);

      deltas['modifiedExpenses'] = (expensesRes as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // 3. Fetch updated settlements
      final settlementsRes = await _client
          .from(tableSettlements)
          .select('*')
          .gt('updated_at', cursorIso);

      deltas['modifiedSettlements'] = (settlementsRes as List<dynamic>? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

      // 4. Fetch updated personal expenses
      final peRes = await _client
          .from(tablePersonalExpenses)
          .select('*')
          .eq('user_id', accountId)
          .gt('updated_at', cursorIso);

      deltas['modifiedPersonalExpenses'] = (peRes as List<dynamic>? ?? [])
          .map((pe) => Map<String, dynamic>.from(pe as Map))
          .toList();

      // 5. Fetch updated personal debts
      final pdRes = await _client
          .from(tablePersonalDebts)
          .select('*')
          .eq('user_id', accountId)
          .gt('updated_at', cursorIso);

      deltas['modifiedPersonalDebts'] = (pdRes as List<dynamic>? ?? [])
          .map((pd) => Map<String, dynamic>.from(pd as Map))
          .toList();

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
  Future<bool> syncTrip(Map<String, dynamic> tripJson, {required String accountId}) async {
    if (!isAvailable) return false;
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
          await _client.from(tableMembers).upsert({
            'id': m['id'],
            'trip_id': tripId,
            'user_id': m['userId'],
            'display_name': m['displayName'] ?? 'Traveler',
            'avatar_url': m['avatarUrl'],
            'role': m['role'] ?? 'member',
            'upi_id': m['upi_id'] ?? m['upiId'],
            'joined_at': m['joinedAt'] ?? DateTime.now().toIso8601String(),
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
  Future<bool> syncExpense(Map<String, dynamic> expenseJson, {required String accountId}) async {
    if (!isAvailable) return false;
    try {
      await _client.from(tableExpenses).upsert({
        'id': expenseJson['id'],
        'trip_id': expenseJson['tripId'],
        'title': expenseJson['title'],
        'amount_in_paise': expenseJson['amountInPaise'],
        'category': expenseJson['category'] ?? 'general',
        'paid_by_member_id': expenseJson['paidByMemberId'],
        'paid_by_user_id': expenseJson['paidByUserId'] ?? accountId,
        'split_type': expenseJson['splitType'] ?? 'equal',
        'splits': expenseJson['splits'] ?? [],
        'location': expenseJson['location'],
        'receipt_url': expenseJson['receiptUrl'],
        'is_deleted': expenseJson['isDeleted'] ?? false,
        'created_at': expenseJson['createdAt'] ?? DateTime.now().toIso8601String(),
        'updated_at': expenseJson['updatedAt'] ?? DateTime.now().toIso8601String(),
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
      await _client.from(tableExpenses).update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', expenseId);
      return true;
    } catch (e) {
      debugPrint('[SupabaseCloudSync] markExpenseDeleted error: $e');
      return false;
    }
  }

  /// Upserts a settlement transaction to Supabase.
  Future<bool> syncSettlement(Map<String, dynamic> settlementJson, {required String accountId}) async {
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
        'settled_at': settlementJson['settledAt'] ?? settlementJson['createdAt'] ?? DateTime.now().toIso8601String(),
        'created_at': settlementJson['createdAt'] ?? DateTime.now().toIso8601String(),
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
  Future<bool> syncPersonalExpense(Map<String, dynamic> peJson, {required String accountId}) async {
    if (!isAvailable) return false;
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
  Future<bool> syncPersonalDebt(Map<String, dynamic> debtJson, {required String accountId}) async {
    if (!isAvailable) return false;
    try {
      await _client.from(tablePersonalDebts).upsert({
        'id': debtJson['id'],
        'user_id': debtJson['userId'] ?? accountId,
        'borrower_name': debtJson['personName'] ?? debtJson['borrowerName'] ?? 'Friend',
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

      debugPrint('[SupabaseCloudSync] FCM token registered for $userId on $deviceId');
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
    final notifId = idempotencyKey ?? 'notif_${DateTime.now().millisecondsSinceEpoch}_${recipientUserId.hashCode.abs()}';

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

      debugPrint('[SupabaseCloudSync] Notification event recorded: $notifId for $recipientUserId');
    } catch (e) {
      debugPrint('[SupabaseCloudSync] dispatchNotificationEvent notice (non-fatal): $e');
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
      final title = isUpdate ? '$actorName updated an expense' : '$actorName added an expense';
      final body = '$expenseTitle · $formattedAmt';
      final route = '/trip/$tripId?expenseId=$expenseId';

      for (final m in members) {
        final uid = m['user_id'] as String?;
        if (uid != null && uid.isNotEmpty && uid != actorUserId && !uid.startsWith('unclaimed_')) {
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
            idempotencyKey: '${expenseId}_${isUpdate ? 'update' : 'create'}_$uid',
          );
        }
      }
    } catch (e) {
      debugPrint('[SupabaseCloudSync] notifyTripMembersForExpense notice: $e');
    }
  }
}
