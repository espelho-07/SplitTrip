import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../domain/models/admin/admin_models.dart';
import 'admin_exceptions.dart';

/// Service managing user account inspection and administrative suspension.
class AdminUserService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  /// Retrieves a paginated list of managed users filtered by search query and account status.
  Future<List<ManagedUser>> fetchUsers({
    int limit = 25,
    int offset = 0,
    String? searchQuery,
    bool? isGuestFilter,
    bool? isSuspendedFilter,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('users', 'Supabase client is not configured.');
    }

    try {
      var query = client.from('users').select('''
        id, display_name, email, is_guest, is_suspended, created_at, last_active_at,
        suspended_at, suspension_reason
      ''');

      if (isGuestFilter != null) {
        query = query.eq('is_guest', isGuestFilter);
      }
      if (isSuspendedFilter != null) {
        query = query.eq('is_suspended', isSuspendedFilter);
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final sanitized = searchQuery.trim();
        query = query.or('display_name.ilike.%$sanitized%,email.ilike.%$sanitized%,id.ilike.%$sanitized%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> rows = response as List<dynamic>;
      return rows.map((json) => ManagedUser.fromJson(json as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      debugPrint('[AdminUserService] PostgrestException in fetchUsers: ${e.message} (${e.code})');
      if (e.code == '42P01' || e.code == '42703') {
        throw const AdminBackendUnavailableException('users', 'Required users table columns or migration 000007 are not yet deployed.');
      }
      rethrow;
    }
  }

  /// Suspends an end-user account non-destructively with mandatory justification.
  /// Executes atomically via server-side RPC [kith_admin_suspend_user] ensuring
  /// user record update and immutable audit log insertion occur within the same transaction.
  Future<void> suspendUser({
    required String userId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const AdminValidationException('A valid, non-empty suspension reason is required.');
    }

    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException(
        'kith_admin_suspend_user',
        'Supabase client is not configured.',
      );
    }

    try {
      await client.rpc('kith_admin_suspend_user', params: {
        'p_target_user_id': userId,
        'p_reason': reason.trim(),
      });
    } on PostgrestException catch (e) {
      debugPrint('[AdminUserService] Error suspending user: ${e.message} (${e.code})');
      if (e.code == '42883' || e.code == '42P01' || e.code == '42703') {
        throw const AdminBackendUnavailableException(
          'kith_admin_suspend_user',
          'Atomic user suspension RPC is pending migration 20261101000007.',
        );
      }
      rethrow;
    }
  }

  /// Unsuspends an end-user account, restoring platform access.
  /// Executes atomically via server-side RPC [kith_admin_unsuspend_user] ensuring
  /// user record update and immutable audit log insertion occur within the same transaction.
  Future<void> unsuspendUser({required String userId}) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException(
        'kith_admin_unsuspend_user',
        'Supabase client is not configured.',
      );
    }

    try {
      await client.rpc('kith_admin_unsuspend_user', params: {
        'p_target_user_id': userId,
      });
    } on PostgrestException catch (e) {
      debugPrint('[AdminUserService] Error unsuspending user: ${e.message} (${e.code})');
      if (e.code == '42883' || e.code == '42P01') {
        throw const AdminBackendUnavailableException(
          'kith_admin_unsuspend_user',
          'Atomic user unsuspension RPC is pending migration 20261101000007.',
        );
      }
      rethrow;
    }
  }
}
