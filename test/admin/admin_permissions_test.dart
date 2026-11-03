import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/models/admin/admin_role.dart';

void main() {
  group('Admin Permission Matrix Tests', () {
    test('Super Admin has all 11 administrative permissions', () {
      const role = AdminRole.superAdmin;
      for (final permission in AdminPermission.values) {
        expect(
          role.hasPermission(permission),
          isTrue,
          reason: 'Super Admin must possess permission: ${permission.name}',
        );
      }
      expect(role.canSuspendUsers, isTrue);
      expect(role.canManageAnnouncements, isTrue);
      expect(role.canManageAdminRoles, isTrue);
    });

    test('Admin possesses operational permissions but cannot manage admin roles', () {
      const role = AdminRole.admin;
      expect(role.hasPermission(AdminPermission.viewDashboard), isTrue);
      expect(role.hasPermission(AdminPermission.manageUsers), isTrue);
      expect(role.hasPermission(AdminPermission.suspendUsers), isTrue);
      expect(role.hasPermission(AdminPermission.viewFeedback), isTrue);
      expect(role.hasPermission(AdminPermission.replyFeedback), isTrue);
      expect(role.hasPermission(AdminPermission.manageInternalNotes), isTrue);
      expect(role.hasPermission(AdminPermission.moderateFeatureRequests), isTrue);
      expect(role.hasPermission(AdminPermission.viewAnalytics), isTrue);
      expect(role.hasPermission(AdminPermission.manageAnnouncements), isTrue);
      expect(role.hasPermission(AdminPermission.viewAuditLogs), isTrue);

      // Only Super Admin can manage admin roles
      expect(role.hasPermission(AdminPermission.manageAdminRoles), isFalse);
      expect(role.canManageAdminRoles, isFalse);
    });

    test('Support Admin can triage feedback and manage users, but cannot suspend users or broadcast', () {
      const role = AdminRole.supportAdmin;
      expect(role.hasPermission(AdminPermission.viewDashboard), isTrue);
      expect(role.hasPermission(AdminPermission.manageUsers), isTrue);
      expect(role.hasPermission(AdminPermission.viewFeedback), isTrue);
      expect(role.hasPermission(AdminPermission.replyFeedback), isTrue);
      expect(role.hasPermission(AdminPermission.manageInternalNotes), isTrue);
      expect(role.hasPermission(AdminPermission.viewAuditLogs), isTrue);

      // Forbidden
      expect(role.hasPermission(AdminPermission.suspendUsers), isFalse);
      expect(role.canSuspendUsers, isFalse);
      expect(role.hasPermission(AdminPermission.moderateFeatureRequests), isFalse);
      expect(role.hasPermission(AdminPermission.viewAnalytics), isFalse);
      expect(role.hasPermission(AdminPermission.manageAnnouncements), isFalse);
      expect(role.canManageAnnouncements, isFalse);
      expect(role.hasPermission(AdminPermission.manageAdminRoles), isFalse);
      expect(role.canManageAdminRoles, isFalse);
    });

    test('Analyst has read-only analytics, dashboard, and feedback inspection privileges', () {
      const role = AdminRole.analyst;
      expect(role.hasPermission(AdminPermission.viewDashboard), isTrue);
      expect(role.hasPermission(AdminPermission.viewAnalytics), isTrue);
      expect(role.hasPermission(AdminPermission.viewFeedback), isTrue);

      // Mutative or sensitive permissions denied
      expect(role.hasPermission(AdminPermission.manageUsers), isFalse);
      expect(role.hasPermission(AdminPermission.suspendUsers), isFalse);
      expect(role.hasPermission(AdminPermission.replyFeedback), isFalse);
      expect(role.hasPermission(AdminPermission.manageInternalNotes), isFalse);
      expect(role.hasPermission(AdminPermission.moderateFeatureRequests), isFalse);
      expect(role.hasPermission(AdminPermission.manageAnnouncements), isFalse);
      expect(role.hasPermission(AdminPermission.manageAdminRoles), isFalse);
      expect(role.hasPermission(AdminPermission.viewAuditLogs), isFalse);
    });

    test('Moderator can triage feedback and moderate feature requests, but cannot suspend or broadcast', () {
      const role = AdminRole.moderator;
      expect(role.hasPermission(AdminPermission.viewDashboard), isTrue);
      expect(role.hasPermission(AdminPermission.viewFeedback), isTrue);
      expect(role.hasPermission(AdminPermission.replyFeedback), isTrue);
      expect(role.hasPermission(AdminPermission.moderateFeatureRequests), isTrue);

      // Forbidden
      expect(role.hasPermission(AdminPermission.manageUsers), isFalse);
      expect(role.hasPermission(AdminPermission.suspendUsers), isFalse);
      expect(role.hasPermission(AdminPermission.manageInternalNotes), isFalse);
      expect(role.hasPermission(AdminPermission.viewAnalytics), isFalse);
      expect(role.hasPermission(AdminPermission.manageAnnouncements), isFalse);
      expect(role.hasPermission(AdminPermission.manageAdminRoles), isFalse);
      expect(role.hasPermission(AdminPermission.viewAuditLogs), isFalse);
    });

    test('fromString parses known role strings safely and rejects unknown values with least-privilege fallback', () {
      expect(AdminRole.fromString('super_admin'), equals(AdminRole.superAdmin));
      expect(AdminRole.fromString('admin'), equals(AdminRole.admin));
      expect(AdminRole.fromString('support_admin'), equals(AdminRole.supportAdmin));
      expect(AdminRole.fromString('analyst'), equals(AdminRole.analyst));
      expect(AdminRole.fromString('moderator'), equals(AdminRole.moderator));

      // Unknown or malicious fallback to moderator (least privilege)
      expect(AdminRole.fromString('root'), equals(AdminRole.moderator));
      expect(AdminRole.fromString(''), equals(AdminRole.moderator));
      expect(AdminRole.fromString('super_admin; DROP TABLE admin_roles;--'), equals(AdminRole.moderator));
    });
  });
}
