/// Primary categories for in-app user feedback.
enum FeedbackCategory {
  bugReport('bug_report', 'Bug Report'),
  featureRequest('feature_request', 'Feature Request'),
  generalFeedback('general_feedback', 'General Feedback'),
  complaint('complaint', 'Complaint'),
  uxSuggestion('ux_suggestion', 'UX / UI Suggestion');

  final String value;
  final String label;

  const FeedbackCategory(this.value, this.label);

  static FeedbackCategory fromString(String? cat) {
    if (cat == null) return FeedbackCategory.generalFeedback;
    for (final c in FeedbackCategory.values) {
      if (c.value == cat.toLowerCase() || c.name == cat.toLowerCase()) {
        return c;
      }
    }
    return FeedbackCategory.generalFeedback;
  }
}

/// Operational workflow status for user feedback.
enum FeedbackStatus {
  newStatus('new', 'New'),
  underReview('under_review', 'Under Review'),
  inProgress('in_progress', 'In Progress'),
  waitingForUser('waiting_for_user', 'Waiting for User'),
  resolved('resolved', 'Resolved'),
  rejected('rejected', 'Rejected');

  final String value;
  final String label;

  const FeedbackStatus(this.value, this.label);

  static FeedbackStatus fromString(String? s) {
    if (s == null) return FeedbackStatus.newStatus;
    for (final status in FeedbackStatus.values) {
      if (status.value == s.toLowerCase() || status.name == s.toLowerCase()) {
        return status;
      }
    }
    return FeedbackStatus.newStatus;
  }
}

/// Triage priority for feedback items.
enum FeedbackPriority {
  critical('critical', 'Critical'),
  high('high', 'High'),
  medium('medium', 'Medium'),
  low('low', 'Low');

  final String value;
  final String label;

  const FeedbackPriority(this.value, this.label);

  static FeedbackPriority fromString(String? p) {
    if (p == null) return FeedbackPriority.medium;
    for (final priority in FeedbackPriority.values) {
      if (priority.value == p.toLowerCase() || priority.name == p.toLowerCase()) {
        return priority;
      }
    }
    return FeedbackPriority.medium;
  }
}

/// Represents a user-submitted feedback record.
class UserFeedback {
  final String id;
  final String userId;
  final String? userDisplayName;
  final FeedbackCategory category;
  final String subject;
  final String description;
  final FeedbackPriority priority;
  final FeedbackStatus status;
  final String? screenshotUrl;
  final String? appVersion;
  final String platform;
  final int upvoteCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;
  final String? assignedAdminId;

  const UserFeedback({
    required this.id,
    required this.userId,
    this.userDisplayName,
    required this.category,
    required this.subject,
    required this.description,
    this.priority = FeedbackPriority.medium,
    this.status = FeedbackStatus.newStatus,
    this.screenshotUrl,
    this.appVersion,
    this.platform = 'android',
    this.upvoteCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = false,
    this.assignedAdminId,
  });

  UserFeedback copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    FeedbackCategory? category,
    String? subject,
    String? description,
    FeedbackPriority? priority,
    FeedbackStatus? status,
    String? screenshotUrl,
    String? appVersion,
    String? platform,
    int? upvoteCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? assignedAdminId,
  }) {
    return UserFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      assignedAdminId: assignedAdminId ?? this.assignedAdminId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_display_name': userDisplayName,
    'category': category.value,
    'subject': subject,
    'description': description,
    'priority': priority.value,
    'status': status.value,
    'screenshot_url': screenshotUrl,
    'app_version': appVersion,
    'platform': platform,
    'upvote_count': upvoteCount,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_public': isPublic,
    'assigned_admin_id': assignedAdminId,
  };

  factory UserFeedback.fromJson(Map<String, dynamic> json) {
    return UserFeedback(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      userDisplayName: json['user_display_name'] as String? ?? json['userDisplayName'] as String?,
      category: FeedbackCategory.fromString(json['category'] as String?),
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priority: FeedbackPriority.fromString(json['priority'] as String?),
      status: FeedbackStatus.fromString(json['status'] as String?),
      screenshotUrl: json['screenshot_url'] as String? ?? json['screenshotUrl'] as String?,
      appVersion: json['app_version'] as String? ?? json['appVersion'] as String?,
      platform: json['platform'] as String? ?? 'android',
      upvoteCount: json['upvote_count'] as int? ?? json['upvoteCount'] as int? ?? 0,
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
      isPublic: json['is_public'] as bool? ?? json['isPublic'] as bool? ?? false,
      assignedAdminId: json['assigned_admin_id'] as String? ?? json['assignedAdminId'] as String?,
    );
  }
}
