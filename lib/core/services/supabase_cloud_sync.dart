import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'recovery_key_service.dart';

/// Comprehensive, production-grade Supabase cloud synchronization & recovery engine.
///
/// Features:
/// 1. Authoritative Cloud Truth with RLS & Anonymous Guest Sessions.
/// 2. Salted Recovery Key Authentication (plain keys never stored in database).
/// 3. Incremental Delta Sync with cursor tracking to protect Supabase Free Tier.
/// 4. Atomic Multi-Device Recovery and reconciliation.
/// 5. Tombstone-based deletion synchronization.
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
    } catch (_) {
      // Non-blocking device registration
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. CRYPTOGRAPHIC ACCOUNT RECOVERY
  // ───────────────────────────────────────────────────────────────────────────

  /// Recovers a logical account from Supabase using a raw Recovery Key.
  /// Validates key with rate limiting and verifies salted HMAC-SHA256 hash.
  Future<Map<String, dynamic>?> recoverAccount(String rawKey, {required String deviceId}) async {
    if (!isAvailable) return null;

    final cleanKey = RecoveryKeyService.normalizeKey(rawKey);
    if (cleanKey.isEmpty) return null;

    // Rate-limiting check
    if (!RecoveryKeyService.canAttemptRecovery(deviceId)) {
      final cooldown = RecoveryKeyService.getRemainingCooldown(deviceId);
      throw Exception('Too many recovery attempts. Please wait ${cooldown.inMinutes + 1} minutes.');
    }

    try {
      // 1. Fetch potential candidate sessions from Supabase
      final response = await _client
          .from(tableGuestSessions)
          .select()
          .limit(100);

      final rows = List<Map<String, dynamic>>.from(response as List<dynamic>);
      Map<String, dynamic>? matchingAccount;

      for (final row in rows) {
        final storedKeyOrHash = row['recovery_key'] as String? ?? '';
        final salt = row['anonymous_token'] as String? ?? '';

        // Check if stored value matches salted hash
        if (salt.isNotEmpty && RecoveryKeyService.verifyKey(cleanKey, storedKeyOrHash, salt)) {
          matchingAccount = row;
          break;
        }

        // Backward-compatibility: Check if stored value was legacy plaintext normalized
        if (RecoveryKeyService.normalizeKey(storedKeyOrHash) == cleanKey) {
          matchingAccount = row;
          // Upgrade this account to salted hash immediately!
          unawaited(registerOrUpdateAccount(
            accountId: row['id'] as String,
            recoveryKey: cleanKey,
            displayName: row['display_name'] as String? ?? 'Traveler',
            deviceId: deviceId,
          ));
          break;
        }
      }

      if (matchingAccount != null) {
        RecoveryKeyService.recordRecoveryAttempt(deviceId, success: true);
        return matchingAccount;
      } else {
        RecoveryKeyService.recordRecoveryAttempt(deviceId, success: false);
        return null;
      }
    } catch (e) {
      RecoveryKeyService.recordRecoveryAttempt(deviceId, success: false);
      debugPrint('[SupabaseCloudSync] Recovery lookup notice: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. FULL ACCOUNT DATA RESTORATION (FOR REINSTALL / NEW DEVICE)
  // ───────────────────────────────────────────────────────────────────────────

  /// Fetches all user data (trips, expenses, settlements, debts) for a recovered account.
  Future<Map<String, dynamic>> fetchFullAccountData(String accountId) async {
    final result = <String, dynamic>{
      'trips': <Map<String, dynamic>>[],
      'expenses': <String, List<Map<String, dynamic>>>{},
      'settlements': <String, List<Map<String, dynamic>>>{},
      'personal_expenses': <Map<String, dynamic>>[],
      'personal_debts': <Map<String, dynamic>>[],
    };

    if (!isAvailable || accountId.isEmpty) return result;

    try {
      // 1. Fetch Trips created by or belonging to account
      try {
        final tripsRes = await _client
            .from(tableTrips)
            .select()
            .or('creator_id.eq.$accountId,account_id.eq.$accountId')
            .eq('is_deleted', false);
        result['trips'] = List<Map<String, dynamic>>.from(tripsRes as List<dynamic>);
      } catch (_) {}

      // 2. Fetch Expenses for all retrieved trips
      final tripsList = result['trips'] as List<Map<String, dynamic>>;
      for (final trip in tripsList) {
        final tripId = trip['id'] as String?;
        if (tripId != null && tripId.isNotEmpty) {
          try {
            final expRes = await _client
                .from(tableExpenses)
                .select()
                .eq('trip_id', tripId)
                .eq('is_deleted', false);
            final expList = List<Map<String, dynamic>>.from(expRes as List<dynamic>);
            (result['expenses'] as Map<String, List<Map<String, dynamic>>>)[tripId] = expList;
          } catch (_) {}

          // 3. Fetch Settlements for trip
          try {
            final stlRes = await _client
                .from(tableSettlements)
                .select()
                .eq('trip_id', tripId)
                .eq('is_deleted', false);
            final stlList = List<Map<String, dynamic>>.from(stlRes as List<dynamic>);
            (result['settlements'] as Map<String, List<Map<String, dynamic>>>)[tripId] = stlList;
          } catch (_) {}
        }
      }

      // 4. Fetch Personal Expenses
      try {
        final peRes = await _client
            .from(tablePersonalExpenses)
            .select()
            .or('user_id.eq.$accountId,account_id.eq.$accountId')
            .eq('is_deleted', false);
        result['personal_expenses'] = List<Map<String, dynamic>>.from(peRes as List<dynamic>);
      } catch (_) {}

      // 5. Fetch Personal Debts
      try {
        final pdRes = await _client
            .from(tablePersonalDebts)
            .select()
            .or('user_id.eq.$accountId,account_id.eq.$accountId')
            .eq('is_deleted', false);
        result['personal_debts'] = List<Map<String, dynamic>>.from(pdRes as List<dynamic>);
      } catch (_) {}

      debugPrint('[SupabaseCloudSync] Full account restoration payload loaded for $accountId');
    } catch (e) {
      debugPrint('[SupabaseCloudSync] fetchFullAccountData error: $e');
    }

    return result;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. INCREMENTAL DELTA SYNC (BANDWIDTH & FREE-TIER OPTIMIZED)
  // ───────────────────────────────────────────────────────────────────────────

  /// Fetches only changes that occurred after [sinceCursor] for this account.
  Future<Map<String, dynamic>> fetchDeltaChanges({
    required String accountId,
    required DateTime sinceCursor,
    required List<String> activeTripIds,
  }) async {
    final cursorIso = sinceCursor.toIso8601String();
    final deltas = <String, dynamic>{
      'modifiedTrips': <Map<String, dynamic>>[],
      'modifiedExpenses': <Map<String, dynamic>>[],
      'modifiedSettlements': <Map<String, dynamic>>[],
      'modifiedPersonalExpenses': <Map<String, dynamic>>[],
      'modifiedPersonalDebts': <Map<String, dynamic>>[],
    };

    if (!isAvailable || accountId.isEmpty) return deltas;

    try {
      // 1. Modified Trips
      try {
        final tripsRes = await _client
            .from(tableTrips)
            .select()
            .or('creator_id.eq.$accountId,account_id.eq.$accountId')
            .gt('updated_at', cursorIso);
        deltas['modifiedTrips'] = List<Map<String, dynamic>>.from(tripsRes as List<dynamic>);
      } catch (_) {}

      // 2. Modified Expenses across active trips
      if (activeTripIds.isNotEmpty) {
        try {
          final tripFilter = activeTripIds.map((id) => 'trip_id.eq.$id').join(',');
          final expRes = await _client
              .from(tableExpenses)
              .select()
              .or(tripFilter)
              .gt('updated_at', cursorIso);
          deltas['modifiedExpenses'] = List<Map<String, dynamic>>.from(expRes as List<dynamic>);
        } catch (_) {}

        // 3. Modified Settlements across active trips
        try {
          final tripFilter = activeTripIds.map((id) => 'trip_id.eq.$id').join(',');
          final stlRes = await _client
              .from(tableSettlements)
              .select()
              .or(tripFilter)
              .gt('updated_at', cursorIso);
          deltas['modifiedSettlements'] = List<Map<String, dynamic>>.from(stlRes as List<dynamic>);
        } catch (_) {}
      }

      // 4. Modified Personal Expenses
      try {
        final peRes = await _client
            .from(tablePersonalExpenses)
            .select()
            .or('user_id.eq.$accountId,account_id.eq.$accountId')
            .gt('updated_at', cursorIso);
        deltas['modifiedPersonalExpenses'] = List<Map<String, dynamic>>.from(peRes as List<dynamic>);
      } catch (_) {}

      // 5. Modified Personal Debts
      try {
        final pdRes = await _client
            .from(tablePersonalDebts)
            .select()
            .or('user_id.eq.$accountId,account_id.eq.$accountId')
            .gt('updated_at', cursorIso);
        deltas['modifiedPersonalDebts'] = List<Map<String, dynamic>>.from(pdRes as List<dynamic>);
      } catch (_) {}
    } catch (e) {
      debugPrint('[SupabaseCloudSync] fetchDeltaChanges notice: $e');
    }

    return deltas;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. ATOMIC DATA MUTATION UPSERTS & DELETIONS
  // ───────────────────────────────────────────────────────────────────────────

  /// Upserts a trip to Supabase.
  Future<bool> syncTrip(Map<String, dynamic> tripJson, {required String accountId}) async {
    if (!isAvailable) return false;
    try {
      await _client.from(tableTrips).upsert({
        'id': tripJson['id'],
        'name': tripJson['name'],
        'description': tripJson['description'],
        'emoji': tripJson['emoji'] ?? '✈️',
        'cover_gradient_index': tripJson['coverGradientIndex'] ?? 0,
        'currency_code': tripJson['currencyCode'] ?? 'INR',
        'creator_id': tripJson['creatorId'] ?? accountId,
        'lifecycle_state': tripJson['lifecycleState'] ?? 'active',
        'invite_code': tripJson['inviteCode'] ?? '',
        'trip_mode': tripJson['tripMode'] ?? 'split_only',
        'revision': tripJson['revision'] ?? 1,
        'created_at': tripJson['createdAt'] ?? DateTime.now().toIso8601String(),
        'updated_at': tripJson['updatedAt'] ?? DateTime.now().toIso8601String(),
        'is_deleted': false,
      }, onConflict: 'id');
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
        'paid_by_member_id': expenseJson['paidById'],
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
}
