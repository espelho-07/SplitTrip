import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../domain/models/admin/admin_models.dart';
import 'admin_exceptions.dart';

/// Service managing administrative broadcast announcements, audience targeting, and scheduling.
class AnnouncementService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  /// Fetches announcements with optional filtering to currently active items.
  Future<List<AdminAnnouncement>> fetchAnnouncements({bool activeOnly = false}) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('admin_announcements');
    }

    try {
      var query = client.from('admin_announcements').select();

      if (activeOnly) {
        final nowIso = DateTime.now().toIso8601String();
        query = query.lte('starts_at', nowIso).or('expires_at.is.null,expires_at.gt.$nowIso');
      }

      final response = await query.order('created_at', ascending: false);
      final List<dynamic> rows = response as List<dynamic>;
      return rows.map((json) => AdminAnnouncement.fromJson(json as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      debugPrint('[AnnouncementService] Error fetching announcements: ${e.message}');
      if (e.code == '42P01') {
        throw const AdminBackendUnavailableException(
          'admin_announcements',
          'admin_announcements table is pending migration 000007.',
        );
      }
      rethrow;
    }
  }

  /// Creates a new broadcast announcement with target audience validation.
  Future<AdminAnnouncement> createAnnouncement(AdminAnnouncement announcement) async {
    if (announcement.title.trim().isEmpty) {
      throw const AdminValidationException('Announcement title cannot be empty.');
    }
    if (announcement.message.trim().isEmpty) {
      throw const AdminValidationException('Announcement message cannot be empty.');
    }

    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('admin_announcements');
    }

    try {
      final res = await client.from('admin_announcements').insert({
        'title': announcement.title.trim(),
        'message': announcement.message.trim(),
        'priority': announcement.priority.value,
        'target_audience': announcement.targetAudience.value,
        'starts_at': announcement.startsAt.toIso8601String(),
        'expires_at': announcement.expiresAt?.toIso8601String(),
        'created_by': announcement.createdBy,
        'created_by_name': announcement.createdByName,
      }).select().single();

      return AdminAnnouncement.fromJson(res);
    } on PostgrestException catch (e) {
      debugPrint('[AnnouncementService] Error creating announcement: ${e.message}');
      rethrow;
    }
  }

  /// Updates an existing announcement.
  Future<void> updateAnnouncement(AdminAnnouncement announcement) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('admin_announcements');
    }

    try {
      await client.from('admin_announcements').update({
        'title': announcement.title.trim(),
        'message': announcement.message.trim(),
        'priority': announcement.priority.value,
        'target_audience': announcement.targetAudience.value,
        'starts_at': announcement.startsAt.toIso8601String(),
        'expires_at': announcement.expiresAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', announcement.id);
    } on PostgrestException catch (e) {
      debugPrint('[AnnouncementService] Error updating announcement: ${e.message}');
      rethrow;
    }
  }

  /// Immediately expires an announcement by setting `expires_at` to the current timestamp.
  Future<void> expireAnnouncement(String announcementId) async {
    final client = _client;
    if (client == null) {
      throw const AdminBackendUnavailableException('admin_announcements');
    }

    try {
      await client.from('admin_announcements').update({
        'expires_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', announcementId);
    } on PostgrestException catch (e) {
      debugPrint('[AnnouncementService] Error expiring announcement: ${e.message}');
      rethrow;
    }
  }

  /// Fetches broadcast announcements visible to the current end-user based on audience segmentation.
  /// Calls `kith_get_active_announcements` RPC with fallback to filtered table select.
  Future<List<AdminAnnouncement>> fetchActiveAnnouncementsForUser({required bool isGuest}) async {
    final client = _client;
    if (client == null) return [];

    try {
      // 1. Attempt secure RPC
      final rpcRes = await client.rpc('kith_get_active_announcements');
      if (rpcRes is List) {
        return rpcRes.map((json) => AdminAnnouncement.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    // 2. Fallback to client query
    try {
      final nowIso = DateTime.now().toIso8601String();
      final targetAudiences = isGuest ? ['all', 'guest'] : ['all', 'registered'];

      final response = await client
          .from('admin_announcements')
          .select()
          .lte('starts_at', nowIso)
          .or('expires_at.is.null,expires_at.gt.$nowIso')
          .filter('target_audience', 'in', targetAudiences)
          .order('priority', ascending: false)
          .order('starts_at', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      return rows.map((json) => AdminAnnouncement.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[AnnouncementService] Error fetching user announcements: $e');
      return [];
    }
  }
}
