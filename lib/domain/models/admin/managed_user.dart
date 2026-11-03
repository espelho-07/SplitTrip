/// Lifecycle status of an end-user account.
enum UserAccountStatus {
  active('active', 'Active'),
  suspended('suspended', 'Suspended'),
  deleted('deleted', 'Deleted');

  final String value;
  final String label;

  const UserAccountStatus(this.value, this.label);

  static UserAccountStatus fromString(String? status, {bool isSuspended = false}) {
    if (isSuspended) return UserAccountStatus.suspended;
    if (status == null) return UserAccountStatus.active;
    for (final s in UserAccountStatus.values) {
      if (s.value == status.toLowerCase() || s.name == status.toLowerCase()) {
        return s;
      }
    }
    return UserAccountStatus.active;
  }
}

/// Represents an end-user account viewed from the Admin Control Center.
class ManagedUser {
  final String id;
  final String displayName;
  final String? email;
  final bool isGuest;
  final UserAccountStatus status;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final int tripCount;
  final int expenseCount;
  final DateTime? suspendedAt;
  final String? suspensionReason;
  final String? appVersion;

  const ManagedUser({
    required this.id,
    required this.displayName,
    this.email,
    required this.isGuest,
    required this.status,
    required this.createdAt,
    this.lastActiveAt,
    this.tripCount = 0,
    this.expenseCount = 0,
    this.suspendedAt,
    this.suspensionReason,
    this.appVersion,
  });

  bool get isSuspended => status == UserAccountStatus.suspended;

  ManagedUser copyWith({
    String? id,
    String? displayName,
    String? email,
    bool? isGuest,
    UserAccountStatus? status,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    int? tripCount,
    int? expenseCount,
    DateTime? suspendedAt,
    String? suspensionReason,
    String? appVersion,
  }) {
    return ManagedUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      isGuest: isGuest ?? this.isGuest,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      tripCount: tripCount ?? this.tripCount,
      expenseCount: expenseCount ?? this.expenseCount,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspensionReason: suspensionReason ?? this.suspensionReason,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'email': email,
    'isGuest': isGuest,
    'status': status.value,
    'createdAt': createdAt.toIso8601String(),
    'lastActiveAt': lastActiveAt?.toIso8601String(),
    'tripCount': tripCount,
    'expenseCount': expenseCount,
    'suspendedAt': suspendedAt?.toIso8601String(),
    'suspensionReason': suspensionReason,
    'appVersion': appVersion,
  };

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    final isSuspendedBool = json['is_suspended'] as bool? ?? json['isSuspended'] as bool? ?? false;
    final statusStr = json['status'] as String?;

    return ManagedUser(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? 'Traveler',
      email: json['email'] as String?,
      isGuest: json['isGuest'] as bool? ?? json['is_guest'] as bool? ?? true,
      status: UserAccountStatus.fromString(statusStr, isSuspended: isSuspendedBool),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
              : DateTime.now()),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'] as String)
          : (json['last_active_at'] != null ? DateTime.tryParse(json['last_active_at'] as String) : null),
      tripCount: json['tripCount'] as int? ?? json['trip_count'] as int? ?? 0,
      expenseCount: json['expenseCount'] as int? ?? json['expense_count'] as int? ?? 0,
      suspendedAt: json['suspendedAt'] != null
          ? DateTime.tryParse(json['suspendedAt'] as String)
          : (json['suspended_at'] != null ? DateTime.tryParse(json['suspended_at'] as String) : null),
      suspensionReason: json['suspensionReason'] as String? ?? json['suspension_reason'] as String?,
      appVersion: json['appVersion'] as String? ?? json['app_version'] as String?,
    );
  }
}
