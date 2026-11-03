/// Target audience segmentation for administrative announcements.
enum AnnouncementAudience {
  all('all', 'Everyone'),
  registered('registered', 'Registered Users Only'),
  guest('guest', 'Guest Users Only');

  final String value;
  final String label;

  const AnnouncementAudience(this.value, this.label);

  static AnnouncementAudience fromString(String? a) {
    if (a == null) return AnnouncementAudience.all;
    for (final aud in AnnouncementAudience.values) {
      if (aud.value == a.toLowerCase() || aud.name == a.toLowerCase()) {
        return aud;
      }
    }
    return AnnouncementAudience.all;
  }
}

/// Urgency tier for administrative announcements.
enum AnnouncementPriority {
  normal('normal', 'Normal'),
  high('high', 'High Priority'),
  urgent('urgent', 'Urgent Alert');

  final String value;
  final String label;

  const AnnouncementPriority(this.value, this.label);

  static AnnouncementPriority fromString(String? p) {
    if (p == null) return AnnouncementPriority.normal;
    for (final pri in AnnouncementPriority.values) {
      if (pri.value == p.toLowerCase() || pri.name == p.toLowerCase()) {
        return pri;
      }
    }
    return AnnouncementPriority.normal;
  }
}

/// Administrative announcement broadcasted to targeted user cohorts.
class AdminAnnouncement {
  final String id;
  final String title;
  final String message;
  final AnnouncementPriority priority;
  final AnnouncementAudience targetAudience;
  final DateTime startsAt;
  final DateTime? expiresAt;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    this.priority = AnnouncementPriority.normal,
    this.targetAudience = AnnouncementAudience.all,
    required this.startsAt,
    this.expiresAt,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Evaluates whether this announcement is currently active and eligible for display.
  bool get isActive {
    final now = DateTime.now();
    if (now.isBefore(startsAt)) return false;
    if (expiresAt != null && now.isAfter(expiresAt!)) return false;
    return true;
  }

  AdminAnnouncement copyWith({
    String? id,
    String? title,
    String? message,
    AnnouncementPriority? priority,
    AnnouncementAudience? targetAudience,
    DateTime? startsAt,
    DateTime? expiresAt,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminAnnouncement(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      priority: priority ?? this.priority,
      targetAudience: targetAudience ?? this.targetAudience,
      startsAt: startsAt ?? this.startsAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'priority': priority.value,
    'target_audience': targetAudience.value,
    'starts_at': startsAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'created_by': createdBy,
    'created_by_name': createdByName,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory AdminAnnouncement.fromJson(Map<String, dynamic> json) {
    return AdminAnnouncement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      priority: AnnouncementPriority.fromString(json['priority'] as String?),
      targetAudience: AnnouncementAudience.fromString(
        json['target_audience'] as String? ?? json['targetAudience'] as String?,
      ),
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'] as String) ?? DateTime.now()
          : (json['startsAt'] != null
              ? DateTime.tryParse(json['startsAt'] as String) ?? DateTime.now()
              : DateTime.now()),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : (json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'] as String) : null),
      createdBy: json['created_by'] as String? ?? json['createdBy'] as String? ?? '',
      createdByName: json['created_by_name'] as String? ?? json['createdByName'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : (json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
              : DateTime.now()),
    );
  }
}
