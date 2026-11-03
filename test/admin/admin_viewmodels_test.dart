import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/admin/admin_audit_service.dart';
import 'package:kith_app/data/services/admin/admin_service.dart';
import 'package:kith_app/data/services/admin/admin_user_service.dart';
import 'package:kith_app/data/services/admin/analytics_service.dart';
import 'package:kith_app/data/services/admin/announcement_service.dart';
import 'package:kith_app/data/services/admin/feedback_service.dart';
import 'package:kith_app/domain/models/admin/admin_models.dart';
import 'package:kith_app/presentation/viewmodels/admin/admin_announcements_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/admin/admin_audit_logs_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/admin/admin_dashboard_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/admin/admin_feedback_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/admin/admin_users_viewmodel.dart';

void main() {
  group('AdminDashboardViewModel Tests', () {
    test('Default section is overview and section switching updates state', () {
      final vm = AdminDashboardViewModel(
        adminService: AdminService(),
        analyticsService: AnalyticsService(),
      );

      expect(vm.currentSection, equals(AdminSection.overview));
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);

      vm.setSection(AdminSection.users);
      expect(vm.currentSection, equals(AdminSection.users));

      vm.setSection(AdminSection.feedback);
      expect(vm.currentSection, equals(AdminSection.feedback));

      vm.setSection(AdminSection.analytics);
      expect(vm.currentSection, equals(AdminSection.analytics));

      vm.setSection(AdminSection.announcements);
      expect(vm.currentSection, equals(AdminSection.announcements));

      vm.setSection(AdminSection.auditLogs);
      expect(vm.currentSection, equals(AdminSection.auditLogs));
    });

    test('Initializes gracefully and fails closed when backend is unconfigured/offline', () async {
      final vm = AdminDashboardViewModel(
        adminService: AdminService(),
        analyticsService: AnalyticsService(),
      );

      await vm.initialize();

      // In unit test without Supabase credentials/session, it fails closed safely
      expect(vm.isLoading, isFalse);
      expect(vm.isAuthenticated, isFalse);
      expect(vm.currentAdmin, isNull);
    });
  });

  group('AdminUsersViewModel Tests', () {
    test('Filtering and search query updates trigger state changes', () {
      final vm = AdminUsersViewModel(
        userService: AdminUserService(),
        auditService: AdminAuditService(),
      );

      expect(vm.activeFilter, equals(UserFilterType.all));
      expect(vm.searchQuery, isEmpty);
      expect(vm.users, isEmpty);

      vm.setFilter(UserFilterType.suspended);
      expect(vm.activeFilter, equals(UserFilterType.suspended));

      vm.setFilter(UserFilterType.guest);
      expect(vm.activeFilter, equals(UserFilterType.guest));

      vm.setFilter(UserFilterType.registered);
      expect(vm.activeFilter, equals(UserFilterType.registered));

      vm.setSearchQuery('test@kith.app');
      expect(vm.searchQuery, equals('test@kith.app'));
    });
  });

  group('AdminFeedbackViewModel Tests', () {
    test('Category and status filtering update state', () {
      final vm = AdminFeedbackViewModel(
        feedbackService: FeedbackService(),
        auditService: AdminAuditService(),
      );

      expect(vm.selectedFeedback, isNull);
      expect(vm.selectedCategory, isNull);
      expect(vm.selectedStatus, isNull);

      vm.setCategoryFilter(FeedbackCategory.bugReport);
      expect(vm.selectedCategory, equals(FeedbackCategory.bugReport));

      vm.setStatusFilter(FeedbackStatus.inProgress);
      expect(vm.selectedStatus, equals(FeedbackStatus.inProgress));

      vm.clearSelection();
      expect(vm.selectedFeedback, isNull);
      expect(vm.internalNotes, isEmpty);
      expect(vm.replies, isEmpty);
    });
  });

  group('AdminAnnouncementsViewModel Tests', () {
    test('Announcements list and loading state management', () {
      final vm = AdminAnnouncementsViewModel(
        announcementService: AnnouncementService(),
        auditService: AdminAuditService(),
      );

      expect(vm.announcements, isEmpty);
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
    });
  });

  group('AdminAuditLogsViewModel Tests', () {
    test('Filter setter and pagination reset behavior', () {
      final vm = AdminAuditLogsViewModel(
        auditService: AdminAuditService(),
      );

      expect(vm.logs, isEmpty);
      expect(vm.actionFilter, isNull);
      expect(vm.targetFilter, isNull);

      vm.setFilter(action: 'user_suspended', target: 'user');
      expect(vm.actionFilter, equals('user_suspended'));
      expect(vm.targetFilter, equals('user'));
    });
  });
}
