/// Private administrative internal note attached to a feedback record.
/// STRICT INVARIANT: Must never be returned or exposed to ordinary end-users.
class FeedbackInternalNote {
  final String id;
  final String feedbackId;
  final String adminUserId;
  final String adminDisplayName;
  final String note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FeedbackInternalNote({
    required this.id,
    required this.feedbackId,
    required this.adminUserId,
    required this.adminDisplayName,
    required this.note,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'feedback_id': feedbackId,
    'admin_user_id': adminUserId,
    'admin_display_name': adminDisplayName,
    'note': note,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory FeedbackInternalNote.fromJson(Map<String, dynamic> json) {
    return FeedbackInternalNote(
      id: json['id'] as String? ?? '',
      feedbackId: json['feedback_id'] as String? ?? json['feedbackId'] as String? ?? '',
      adminUserId: json['admin_user_id'] as String? ?? json['adminUserId'] as String? ?? '',
      adminDisplayName: json['admin_display_name'] as String? ?? json['adminDisplayName'] as String? ?? 'Admin',
      note: json['note'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : (json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null),
    );
  }
}
