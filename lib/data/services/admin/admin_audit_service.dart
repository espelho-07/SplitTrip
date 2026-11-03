import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../domain/models/admin/admin_models.dart';
import 'admin_exceptions.dart';

/// Service for inspecting and querying the immutable administrative audit ledger.
class AdminAuditService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  /// Retrieves a paginated list of audit logs with optional filtering.
  Future<List<AdminAuditLog>> fetchAuditLogs({
    String? actionFilter,
    String? targetTypeFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('admin_audit_logs');
    }

    try {
      var query = client.from('admin_audit_logs').select();

      if (actionFilter != null && actionFilter.isNotEmpty) {
        query = query.eq('action', actionFilter);
      }
      if (targetTypeFilter != null && targetTypeFilter.isNotEmpty) {
        query = query.eq('target_type', targetTypeFilter);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> rows = response as List<dynamic>;
      return rows.map((json) => AdminAuditLog.fromJson(json as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      debugPrint('[AdminAuditService] Error fetching audit logs: ${e.message}');
      if (e.code == '42P01') {
        throw const AdminBackendUnavailableException(
          'admin_audit_logs',
          'admin_audit_logs table is pending migration 000007.',
        );
      }
      rethrow;
    }
  }

  /// Records an administrative audit entry via trusted server-side RPC.
  /// Direct table INSERT is strictly revoked for all client roles.
  /// The server-side function validates actor identity strictly via auth.uid(),
  /// stamps the server clock_timestamp(), and ensures non-repudiation.
  /// The client never transmits actor UID, actor email, or timestamp.
  Future<void> recordAction({
    required AuditAction action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? previousState,
    Map<String, dynamic>? newState,
  }) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.rpc('kith_record_audit_log', params: {
        'p_action': action.value,
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_previous_state': previousState,
        'p_new_state': newState,
      });
    } on PostgrestException catch (e) {
      debugPrint('[AdminAuditService] Error calling kith_record_audit_log RPC: ${e.message} (${e.code})');
    } catch (e) {
      debugPrint('[AdminAuditService] Warning: Failed to record audit log: $e');
    }
  }
}
