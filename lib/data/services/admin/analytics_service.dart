import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../domain/models/admin/admin_models.dart';
import 'admin_exceptions.dart';

/// Service managing aggregated product analytics and privacy-conscious client event logging.
class AnalyticsService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  /// Strict event name allowlist. Unlisted events are rejected before transmission.
  static const Set<String> allowedEvents = {
    'app_session_start',
    'account_created',
    'guest_session_created',
    'trip_created',
    'expense_added',
    'invitation_generated',
    'feedback_submitted',
    'feature_voted',
  };

  /// Disallowed metadata keys to strictly prevent sensitive PII leakage.
  static const Set<String> prohibitedMetadataKeys = {
    'password',
    'recovery_key',
    'token',
    'session_token',
    'secret',
    'phone',
    'upi_id',
    'pin',
    'auth',
  };

  /// Fetches platform analytics summary via server-side aggregated RPC.
  /// Explicitly fails closed: if the server-side aggregation RPC is unavailable,
  /// throws [AdminBackendUnavailableException] without performing any client-side full-table scans.
  Future<AnalyticsSummary> fetchAnalyticsSummary() async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException(
        'kith_get_analytics_summary',
        'Supabase client is not configured.',
      );
    }

    try {
      final rpcRes = await client.rpc('kith_get_analytics_summary');
      if (rpcRes is Map<String, dynamic>) {
        return AnalyticsSummary.fromJson(rpcRes);
      }
      throw const AdminBackendUnavailableException(
        'kith_get_analytics_summary',
        'Analytics RPC returned an unexpected payload format.',
      );
    } on PostgrestException catch (e) {
      debugPrint('[AnalyticsService] PostgrestException calling kith_get_analytics_summary: ${e.message} (${e.code})');
      throw AdminBackendUnavailableException(
        'kith_get_analytics_summary',
        'Server-side analytics aggregation RPC is unavailable (error code: ${e.code ?? "unknown"}). Migration 000007 is required.',
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Unexpected error in fetchAnalyticsSummary: $e');
      throw AdminBackendUnavailableException(
        'kith_get_analytics_summary',
        'Failed to retrieve server-side analytics: $e',
      );
    }
  }

  /// Logs a permitted product analytics event with strict allowlist and privacy validation.
  Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? metadata,
    String? customUserId,
  }) async {
    // 1. Strict Event Allowlist Enforcement
    if (!allowedEvents.contains(eventName)) {
      debugPrint('[AnalyticsService] Rejected unapproved event: "$eventName"');
      return;
    }

    final client = _client;
    if (client == null) return;

    // 2. Sensitive Key Sanitization
    final cleanMeta = <String, dynamic>{};
    if (metadata != null) {
      for (final entry in metadata.entries) {
        final keyLower = entry.key.toLowerCase().trim();
        if (prohibitedMetadataKeys.contains(keyLower)) {
          debugPrint('[AnalyticsService] Dropped prohibited metadata key: "${entry.key}"');
          continue;
        }
        // Reject nested objects or arrays to enforce flat structure
        if (entry.value is Map || entry.value is List) {
          continue;
        }
        cleanMeta[entry.key] = entry.value;
      }
    }

    try {
      final payload = <String, dynamic>{
        'event_name': eventName,
        'metadata': cleanMeta,
        'client_timestamp': DateTime.now().toIso8601String(),
      };
      if (customUserId != null) {
        payload['user_id'] = customUserId;
      }
      await client.from('analytics_events').insert(payload);
    } catch (_) {
      // Non-blocking telemetry
    }
  }
}
