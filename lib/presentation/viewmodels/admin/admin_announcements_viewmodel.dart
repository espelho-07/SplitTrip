import 'package:flutter/material.dart';
import '../../../data/services/admin/admin_audit_service.dart';
import '../../../data/services/admin/admin_exceptions.dart';
import '../../../data/services/admin/announcement_service.dart';
import '../../../domain/models/admin/admin_models.dart';

/// ViewModel managing administrative broadcast announcements and audience targeting.
class AdminAnnouncementsViewModel extends ChangeNotifier {
  final AnnouncementService announcementService;
  final AdminAuditService auditService;

  AdminAnnouncementsViewModel({
    required this.announcementService,
    required this.auditService,
  });

  List<AdminAnnouncement> _announcements = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AdminAnnouncement> get announcements => _announcements;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetches all broadcast announcements.
  Future<void> fetchAnnouncements() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _announcements = await announcementService.fetchAnnouncements();
    } on AdminBackendUnavailableException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load announcements: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new announcement.
  Future<bool> createAnnouncement({
    required String title,
    required String message,
    required AnnouncementPriority priority,
    required AnnouncementAudience targetAudience,
    required DateTime startsAt,
    DateTime? expiresAt,
    required AdminUser currentAdmin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newAnnouncement = AdminAnnouncement(
        id: '',
        title: title,
        message: message,
        priority: priority,
        targetAudience: targetAudience,
        startsAt: startsAt,
        expiresAt: expiresAt,
        createdBy: currentAdmin.id,
        createdByName: currentAdmin.displayName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await announcementService.createAnnouncement(newAnnouncement);
      _announcements.insert(0, created);

      await auditService.recordAction(
        action: AuditAction.announcementCreated,
        targetType: 'announcement',
        targetId: created.id,
        newState: {'title': created.title, 'audience': created.targetAudience.value},
      );

      return true;
    } on AdminException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to publish announcement: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// Immediately expires an announcement.
  Future<bool> expireAnnouncement({
    required AdminAnnouncement announcement,
    required AdminUser currentAdmin,
  }) async {
    try {
      await announcementService.expireAnnouncement(announcement.id);

      await auditService.recordAction(
        action: AuditAction.announcementExpired,
        targetType: 'announcement',
        targetId: announcement.id,
      );

      final idx = _announcements.indexWhere((a) => a.id == announcement.id);
      if (idx != -1) {
        _announcements[idx] = announcement.copyWith(
          expiresAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to expire announcement: $e';
      notifyListeners();
      return false;
    }
  }
}
