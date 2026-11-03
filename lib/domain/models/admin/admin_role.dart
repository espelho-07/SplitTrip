/// Granular permissions available within the KITH Admin Control Center.
enum AdminPermission {
  viewDashboard,
  manageUsers,
  suspendUsers,
  viewFeedback,
  replyFeedback,
  manageInternalNotes,
  moderateFeatureRequests,
  viewAnalytics,
  manageAnnouncements,
  manageAdminRoles,
  viewAuditLogs,
}

/// Administrative roles within the KITH ecosystem.
enum AdminRole {
  superAdmin('super_admin', 'Super Administrator'),
  admin('admin', 'Administrator'),
  supportAdmin('support_admin', 'Support Administrator'),
  analyst('analyst', 'Product Analyst'),
  moderator('moderator', 'Content Moderator');

  final String value;
  final String label;

  const AdminRole(this.value, this.label);

  static AdminRole fromString(String? role) {
    if (role == null) return AdminRole.moderator;
    final normalized = role.trim().toLowerCase().replaceAll('-', '_');
    for (final r in AdminRole.values) {
      if (r.value == normalized || r.name == normalized) {
        return r;
      }
    }
    return AdminRole.moderator;
  }

  /// Evaluates whether this role possesses the requested granular [permission].
  bool hasPermission(AdminPermission permission) {
    switch (this) {
      case AdminRole.superAdmin:
        return true; // Super Admin possesses all privileges unconditionally

      case AdminRole.admin:
        switch (permission) {
          case AdminPermission.manageAdminRoles:
            return false; // Only Super Admin can manage administrator roles
          default:
            return true;
        }

      case AdminRole.supportAdmin:
        switch (permission) {
          case AdminPermission.viewDashboard:
          case AdminPermission.manageUsers:
          case AdminPermission.viewFeedback:
          case AdminPermission.replyFeedback:
          case AdminPermission.manageInternalNotes:
          case AdminPermission.viewAuditLogs:
            return true;
          case AdminPermission.suspendUsers:
          case AdminPermission.moderateFeatureRequests:
          case AdminPermission.viewAnalytics:
          case AdminPermission.manageAnnouncements:
          case AdminPermission.manageAdminRoles:
            return false;
        }

      case AdminRole.analyst:
        switch (permission) {
          case AdminPermission.viewDashboard:
          case AdminPermission.viewAnalytics:
          case AdminPermission.viewFeedback:
            return true;
          default:
            return false;
        }

      case AdminRole.moderator:
        switch (permission) {
          case AdminPermission.viewDashboard:
          case AdminPermission.viewFeedback:
          case AdminPermission.replyFeedback:
          case AdminPermission.moderateFeatureRequests:
            return true;
          default:
            return false;
        }
    }
  }

  /// Returns true if this role can perform user suspension.
  bool get canSuspendUsers => hasPermission(AdminPermission.suspendUsers);

  /// Returns true if this role can manage announcements.
  bool get canManageAnnouncements => hasPermission(AdminPermission.manageAnnouncements);

  /// Returns true if this role can grant or revoke admin roles.
  bool get canManageAdminRoles => hasPermission(AdminPermission.manageAdminRoles);
}
