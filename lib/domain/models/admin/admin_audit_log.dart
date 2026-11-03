/// Administrative action recorded in the immutable audit ledger.
enum AuditAction {
  userSuspended('user_suspended', 'User Suspended'),
  userUnsuspended('user_unsuspended', 'User Unsuspended'),
  feedbackStatusUpdated('feedback_status_updated', 'Feedback Status Updated'),
  feedbackReplyPosted('feedback_reply_posted', 'Feedback Reply Posted'),
  featureModerated('feature_moderated', 'Feature Moderated'),
  announcementCreated('announcement_created', 'Announcement Created'),
  announcementUpdated('announcement_updated', 'Announcement Updated'),
  announcementExpired('announcement_expired', 'Announcement Expired'),
  roleAssigned('role_assigned', 'Role Assigned'),
  roleRevoked('role_revoked', 'Role Revoked'),
  initialOwnerProvisioned('initial_owner_provisioned', 'Initial Super Admin Provisioned');

  final String value;
  final String label;

  const AuditAction(this.value, this.label);

  static AuditAction fromString(String? a) {
    if (a == null) return AuditAction.feedbackStatusUpdated;
    for (final act in AuditAction.values) {
      if (act.value == a.toLowerCase() || act.name == a.toLowerCase()) {
        return act;
      }
    }
    return AuditAction.feedbackStatusUpdated;
  }
}

/// Represents an immutable audit entry for an administrative action.
class AdminAuditLog {
  final String id;
  final String adminUserId;
  final String? adminEmail;
  final AuditAction action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic>? previousState;
  final Map<String, dynamic>? newState;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  const AdminAuditLog({
    required this.id,
    required this.adminUserId,
    this.adminEmail,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.previousState,
    this.newState,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'admin_user_id': adminUserId,
    'admin_email': adminEmail,
    'action': action.value,
    'target_type': targetType,
    'target_id': targetId,
    'previous_state': previousState,
    'new_state': newState,
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'created_at': createdAt.toIso8601String(),
  };

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      id: json['id'] as String? ?? '',
      adminUserId: json['admin_user_id'] as String? ?? json['adminUserId'] as String? ?? '',
      adminEmail: json['admin_email'] as String? ?? json['adminEmail'] as String?,
      action: AuditAction.fromString(json['action'] as String?),
      targetType: json['target_type'] as String? ?? json['targetType'] as String? ?? '',
      targetId: json['target_id'] as String? ?? json['targetId'] as String? ?? '',
      previousState: json['previous_state'] as Map<String, dynamic>? ?? json['previousState'] as Map<String, dynamic>?,
      newState: json['new_state'] as Map<String, dynamic>? ?? json['newState'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String? ?? json['ipAddress'] as String?,
      userAgent: json['user_agent'] as String? ?? json['userAgent'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
    );
  }
}
