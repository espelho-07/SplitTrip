/// High-level aggregated platform analytics summary for the administrative dashboard.
class AnalyticsSummary {
  final int dau;
  final int wau;
  final int mau;
  final int totalUsers;
  final int registeredUsers;
  final int guestUsers;
  final int newUsersToday;
  final int suspendedUsers;
  final double retentionRate; // e.g. 0.42 = 42%
  final double guestToRegisteredConversionRate; // e.g. 0.18 = 18%
  final DateTime calculatedAt;
  final Map<String, int> platformDistribution;
  final Map<String, int> versionDistribution;

  const AnalyticsSummary({
    this.dau = 0,
    this.wau = 0,
    this.mau = 0,
    this.totalUsers = 0,
    this.registeredUsers = 0,
    this.guestUsers = 0,
    this.newUsersToday = 0,
    this.suspendedUsers = 0,
    this.retentionRate = 0.0,
    this.guestToRegisteredConversionRate = 0.0,
    required this.calculatedAt,
    this.platformDistribution = const {'android': 0, 'ios': 0},
    this.versionDistribution = const {},
  });

  Map<String, dynamic> toJson() => {
    'dau': dau,
    'wau': wau,
    'mau': mau,
    'total_users': totalUsers,
    'registered_users': registeredUsers,
    'guest_users': guestUsers,
    'new_users_today': newUsersToday,
    'suspended_users': suspendedUsers,
    'retention_rate': retentionRate,
    'conversion_rate': guestToRegisteredConversionRate,
    'calculated_at': calculatedAt.toIso8601String(),
    'platform_distribution': platformDistribution,
    'version_distribution': versionDistribution,
  };

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      dau: json['dau'] as int? ?? 0,
      wau: json['wau'] as int? ?? 0,
      mau: json['mau'] as int? ?? 0,
      totalUsers: json['total_users'] as int? ?? json['totalUsers'] as int? ?? 0,
      registeredUsers: json['registered_users'] as int? ?? json['registeredUsers'] as int? ?? 0,
      guestUsers: json['guest_users'] as int? ?? json['guestUsers'] as int? ?? 0,
      newUsersToday: json['new_users_today'] as int? ?? json['newUsersToday'] as int? ?? 0,
      suspendedUsers: json['suspended_users'] as int? ?? json['suspendedUsers'] as int? ?? 0,
      retentionRate: (json['retention_rate'] as num?)?.toDouble() ?? 0.0,
      guestToRegisteredConversionRate:
          (json['conversion_rate'] as num?)?.toDouble() ??
          (json['guestToRegisteredConversionRate'] as num?)?.toDouble() ??
          0.0,
      calculatedAt: json['calculated_at'] != null
          ? DateTime.tryParse(json['calculated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      platformDistribution:
          (json['platform_distribution'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          const {'android': 0, 'ios': 0},
      versionDistribution:
          (json['version_distribution'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          const {},
    );
  }
}

/// Permitted privacy-conscious product activity event.
class UserActivityEvent {
  final String id;
  final String userId;
  final String eventName;
  final Map<String, dynamic> metadata;
  final DateTime clientTimestamp;
  final DateTime createdAt;

  const UserActivityEvent({
    required this.id,
    required this.userId,
    required this.eventName,
    this.metadata = const {},
    required this.clientTimestamp,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'event_name': eventName,
    'metadata': metadata,
    'client_timestamp': clientTimestamp.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  factory UserActivityEvent.fromJson(Map<String, dynamic> json) {
    return UserActivityEvent(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      eventName: json['event_name'] as String? ?? json['eventName'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      clientTimestamp: json['client_timestamp'] != null
          ? DateTime.tryParse(json['client_timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
