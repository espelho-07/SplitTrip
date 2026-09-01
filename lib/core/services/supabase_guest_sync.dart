import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/guest_user.dart';
import 'supabase_cloud_sync.dart';

/// Supabase-backed guest session synchronization service.
/// Provides backward-compatible bridge to [SupabaseCloudSync].
class SupabaseGuestSync {
  final SupabaseCloudSync _cloudSync = SupabaseCloudSync();

  static const String _table = 'guest_sessions';
  SupabaseClient get _client => Supabase.instance.client;

  bool get _isAvailable {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Upserts guest metadata securely to Supabase.
  Future<void> upsertGuestSession(GuestUser user) async {
    if (!_isAvailable) return;
    if (user.recoveryKey.isEmpty) return;

    await _cloudSync.registerOrUpdateAccount(
      accountId: user.effectiveAccountId,
      recoveryKey: user.recoveryKey,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      
    );
  }

  /// Recovers guest session metadata from Supabase by recovery key.
  Future<Map<String, dynamic>?> recoverByRecoveryKey(String recoveryKey) async {
    if (!_isAvailable) return null;
    return _cloudSync.recoverAccount(recoveryKey, deviceId: 'primary_device');
  }

  /// Recovers guest session metadata from Supabase by guest user ID.
  Future<Map<String, dynamic>?> recoverById(String guestId) async {
    if (!_isAvailable) return null;
    if (guestId.isEmpty) return null;

    try {
      final result = await _client
          .from(_table)
          .select()
          .eq('id', guestId)
          .maybeSingle();
      return result;
    } catch (e) {
      debugPrint('[SupabaseGuestSync] RecoverById notice (non-fatal): $e');
      return null;
    }
  }

  /// Converts a Supabase guest_sessions row back to GuestUser fields.
  static Map<String, dynamic> rowToUserJson(Map<String, dynamic> row, [String? rawRecoveryKey]) {
    return {
      'id': row['id'] as String,
      'accountId': row['account_id'] as String? ?? row['id'] as String,
      'displayName': row['display_name'] as String? ?? 'Traveler',
      'recoveryKey': rawRecoveryKey ?? row['recovery_key'] as String? ?? '',
      'anonymousToken': row['anonymous_token'] as String? ?? '',
      'createdAt': row['created_at'] as String? ?? DateTime.now().toIso8601String(),
      'isLinkedToAccount': false,
    };
  }
}
