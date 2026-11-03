import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../domain/models/admin/admin_models.dart';
import 'admin_exceptions.dart';

/// Service managing public feature request browsing, community voting, and admin moderation.
class FeatureRequestService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  /// Fetches approved public feature requests through the secure public view.
  Future<List<FeatureRequest>> fetchFeatureRequests({
    int limit = 25,
    int offset = 0,
    String sortBy = 'upvotes', // 'upvotes' or 'recent'
  }) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('public_feature_requests');
    }

    try {
      dynamic query = client.from('public_feature_requests').select();

      if (sortBy == 'upvotes') {
        query = query.order('upvote_count', ascending: false).order('created_at', ascending: false);
      } else {
        query = query.order('created_at', ascending: false);
      }

      final response = await query.range(offset, offset + limit - 1);
      final List<dynamic> rows = response as List<dynamic>;
      return rows.map((json) => FeatureRequest.fromJson(json as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      debugPrint('[FeatureRequestService] Error fetching public features: ${e.message}');
      if (e.code == '42P01') {
        throw const AdminBackendUnavailableException(
          'public_feature_requests',
          'public_feature_requests view is pending migration 000007.',
        );
      }
      rethrow;
    }
  }

  /// Toggles an upvote atomically using the server-side concurrency-safe RPC.
  Future<bool> toggleVote(String featureId) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('kith_toggle_feedback_vote');
    }

    try {
      final res = await client.rpc(
        'kith_toggle_feedback_vote',
        params: {'p_feedback_id': featureId},
      );

      if (res is Map && res['has_voted'] != null) {
        return res['has_voted'] as bool;
      }
      return true;
    } on PostgrestException catch (e) {
      debugPrint('[FeatureRequestService] Error in toggleVote RPC: ${e.message}');
      rethrow;
    }
  }

  /// Moderates a user feedback submission into a public feature request.
  Future<void> moderateFeature({
    required String feedbackId,
    required bool isApproved,
    String? publicTitle,
    String? publicDescription,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('user_feedback');
    }

    try {
      await client.from('user_feedback').update({
        'is_public': isApproved,
        'moderation_status': isApproved ? 'approved' : 'rejected',
        if (publicTitle != null) 'public_title': publicTitle.trim(),
        if (publicDescription != null) 'public_description': publicDescription.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', feedbackId);
    } on PostgrestException catch (e) {
      debugPrint('[FeatureRequestService] Error moderating feature: ${e.message}');
      rethrow;
    }
  }
}
