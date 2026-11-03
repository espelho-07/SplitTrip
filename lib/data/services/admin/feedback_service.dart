import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../domain/models/admin/admin_models.dart';
import 'admin_exceptions.dart';

/// Service managing feedback triage, internal administrative notes, and thread replies.
class FeedbackService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  /// Fetches feedback records with optional filtering by category, status, and priority.
  Future<List<UserFeedback>> fetchFeedbackList({
    FeedbackCategory? category,
    FeedbackStatus? status,
    FeedbackPriority? priority,
    int limit = 25,
    int offset = 0,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('user_feedback');
    }

    try {
      var query = client.from('user_feedback').select();

      if (category != null) {
        query = query.eq('category', category.value);
      }
      if (status != null) {
        query = query.eq('status', status.value);
      }
      if (priority != null) {
        query = query.eq('priority', priority.value);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> rows = response as List<dynamic>;
      return rows.map((json) => UserFeedback.fromJson(json as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      debugPrint('[FeedbackService] fetchFeedbackList error: ${e.message} (${e.code})');
      if (e.code == '42P01') {
        throw const AdminBackendUnavailableException('user_feedback', 'user_feedback table is pending migration 000007.');
      }
      rethrow;
    }
  }

  /// Updates status and priority of a feedback item.
  Future<void> updateFeedbackStatus({
    required String feedbackId,
    required FeedbackStatus newStatus,
    FeedbackPriority? priority,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('user_feedback');
    }

    try {
      final updates = <String, dynamic>{
        'status': newStatus.value,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (priority != null) {
        updates['priority'] = priority.value;
      }

      await client.from('user_feedback').update(updates).eq('id', feedbackId);
    } on PostgrestException catch (e) {
      debugPrint('[FeedbackService] updateFeedbackStatus error: ${e.message}');
      rethrow;
    }
  }

  /// Fetches internal administrative notes for a feedback item.
  Future<List<FeedbackInternalNote>> fetchInternalNotes(String feedbackId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('feedback_admin_notes')
          .select()
          .eq('feedback_id', feedbackId)
          .order('created_at', ascending: true);

      final List<dynamic> rows = response as List<dynamic>;
      return rows.map((json) => FeedbackInternalNote.fromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Adds a private administrative internal note to a feedback item.
  Future<FeedbackInternalNote> addInternalNote({
    required String feedbackId,
    required String note,
    required String adminUserId,
    required String adminDisplayName,
  }) async {
    if (note.trim().isEmpty) {
      throw const AdminValidationException('Note content cannot be empty.');
    }

    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('feedback_admin_notes');
    }

    final res = await client.from('feedback_admin_notes').insert({
      'feedback_id': feedbackId,
      'admin_user_id': adminUserId,
      'admin_display_name': adminDisplayName,
      'note': note.trim(),
    }).select().single();

    return FeedbackInternalNote.fromJson(res);
  }

  /// Fetches threaded conversation replies for a feedback item.
  Future<List<FeedbackReply>> fetchReplies(String feedbackId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('feedback_replies')
          .select()
          .eq('feedback_id', feedbackId)
          .order('created_at', ascending: true);

      final List<dynamic> rows = response as List<dynamic>;
      return rows.map((json) => FeedbackReply.fromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Posts an official administrative response in the feedback thread.
  Future<FeedbackReply> postAdminReply({
    required String feedbackId,
    required String message,
    required String adminUserId,
    required String adminDisplayName,
  }) async {
    if (message.trim().isEmpty) {
      throw const AdminValidationException('Reply message cannot be empty.');
    }

    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('feedback_replies');
    }

    final res = await client.from('feedback_replies').insert({
      'feedback_id': feedbackId,
      'sender_user_id': adminUserId,
      'sender_display_name': adminDisplayName,
      'message': message.trim(),
      'is_admin_reply': true,
    }).select().single();

    return FeedbackReply.fromJson(res);
  }

  /// Submits an in-app user feedback report from an end-user (registered or guest).
  Future<UserFeedback> submitFeedback({
    required FeedbackCategory category,
    required String message,
    String? title,
    FeedbackPriority priority = FeedbackPriority.medium,
    Map<String, dynamic>? metadata,
  }) async {
    if (message.trim().isEmpty) {
      throw const AdminValidationException('Feedback message cannot be empty.');
    }

    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('user_feedback');
    }

    try {
      final payload = <String, dynamic>{
        'category': category.value,
        'title': title?.trim(),
        'message': message.trim(),
        'priority': priority.value,
        'status': FeedbackStatus.newStatus.value,
      };
      if (metadata != null) {
        payload['metadata'] = metadata;
      }

      final res = await client.from('user_feedback').insert(payload).select().single();

      return UserFeedback.fromJson(res);
    } on PostgrestException catch (e) {
      debugPrint('[FeedbackService] Error submitting feedback: ${e.message}');
      if (e.code == '42P01') {
        throw const AdminBackendUnavailableException('user_feedback', 'user_feedback table pending migration 000007.');
      }
      rethrow;
    }
  }
}
