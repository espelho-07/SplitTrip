import 'admin_role.dart';

/// Represents an authorized administrative user within the KITH ecosystem.
class AdminUser {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final AdminRole role;
  final DateTime grantedAt;
  final String? grantedBy;
  final DateTime? lastActiveAt;

  const AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.grantedAt,
    this.grantedBy,
    this.lastActiveAt,
  });

  bool hasPermission(AdminPermission permission) => role.hasPermission(permission);

  AdminUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    AdminRole? role,
    DateTime? grantedAt,
    String? grantedBy,
    DateTime? lastActiveAt,
  }) {
    return AdminUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      grantedAt: grantedAt ?? this.grantedAt,
      grantedBy: grantedBy ?? this.grantedBy,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'role': role.value,
    'grantedAt': grantedAt.toIso8601String(),
    'grantedBy': grantedBy,
    'lastActiveAt': lastActiveAt?.toIso8601String(),
  };

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String? ?? json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? 'Admin',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      role: AdminRole.fromString(json['role'] as String?),
      grantedAt: json['grantedAt'] != null
          ? DateTime.tryParse(json['grantedAt'] as String) ?? DateTime.now()
          : (json['granted_at'] != null
              ? DateTime.tryParse(json['granted_at'] as String) ?? DateTime.now()
              : DateTime.now()),
      grantedBy: json['grantedBy'] as String? ?? json['granted_by'] as String?,
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'] as String)
          : (json['last_active_at'] != null ? DateTime.tryParse(json['last_active_at'] as String) : null),
    );
  }
}
