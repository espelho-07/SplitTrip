import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/guest_user.dart';

/// Supabase-backed guest session synchronization service.
///
/// Uses the existing Supabase project (already configured) to persist
/// minimal guest account metadata for cross-reinstall recovery.
///
/// Table: guest_sessions
/// - id (TEXT PK): guest user ID
/// - recovery_key (TEXT UNIQUE): the Kith recovery key
/// - display_name (TEXT): user display name
/// - anonymous_token (TEXT): session token
/// - created_at (TIMESTAMPTZ): creation time
/// - last_seen_at (TIMESTAMPTZ): last sync time
///
/// RLS: open policy — data is anonymous & keyed by recovery key.
class SupabaseGuestSync {
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

  /// Upserts guest metadata to Supabase.
  /// Non-blocking: failures are silently swallowed to preserve offline-first behavior.
  Future<void> upsertGuestSession(GuestUser user) async {
    if (!_isAvailable) return;
    if (user.recoveryKey.isEmpty) return;

    try {
      await _client.from(_table).upsert({
        'id': user.id,
        'recovery_key': user.recoveryKey,
        'display_name': user.displayName,
        'anonymous_token': user.anonymousToken,
        'last_seen_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      debugPrint('[SupabaseGuestSync] Session upserted for ${user.id}');
    } catch (e) {
      debugPrint('[SupabaseGuestSync] Upsert notice (non-fatal): $e');
    }
  }

  /// Recovers guest session metadata from Supabase by recovery key.
  Future<Map<String, dynamic>?> recoverByRecoveryKey(String recoveryKey) async {
    if (!_isAvailable) return null;
    if (recoveryKey.isEmpty) return null;

    try {
      final result = await _client
          .from(_table)
          .select()
          .eq('recovery_key', recoveryKey)
          .maybeSingle();
      return result;
    } catch (e) {
      debugPrint('[SupabaseGuestSync] RecoverByKey notice (non-fatal): $e');
      return null;
    }
  }

  /// Recovers guest session metadata from Supabase by guest user ID.
  /// Used when SecureStorage has the ID but SharedPreferences was cleared.
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
  static Map<String, dynamic> rowToUserJson(Map<String, dynamic> row) {
    return {
      'id': row['id'] as String,
      'displayName': row['display_name'] as String? ?? 'Traveler',
      'recoveryKey': row['recovery_key'] as String? ?? '',
      'anonymousToken': row['anonymous_token'] as String? ?? '',
      'createdAt': row['created_at'] as String? ?? DateTime.now().toIso8601String(),
      'isLinkedToAccount': false,
    };
  }
}
