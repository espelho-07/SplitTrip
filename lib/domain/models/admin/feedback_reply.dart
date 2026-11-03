/// Represents a message in a feedback conversation thread.
class FeedbackReply {
  final String id;
  final String feedbackId;
  final String senderUserId;
  final String senderDisplayName;
  final String message;
  final bool isAdminReply;
  final DateTime createdAt;

  const FeedbackReply({
    required this.id,
    required this.feedbackId,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.message,
    required this.isAdminReply,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'feedback_id': feedbackId,
    'sender_user_id': senderUserId,
    'sender_display_name': senderDisplayName,
    'message': message,
    'is_admin_reply': isAdminReply,
    'created_at': createdAt.toIso8601String(),
  };

  factory FeedbackReply.fromJson(Map<String, dynamic> json) {
    return FeedbackReply(
      id: json['id'] as String? ?? '',
      feedbackId: json['feedback_id'] as String? ?? json['feedbackId'] as String? ?? '',
      senderUserId: json['sender_user_id'] as String? ?? json['senderUserId'] as String? ?? '',
      senderDisplayName: json['sender_display_name'] as String? ?? json['senderDisplayName'] as String? ?? 'User',
      message: json['message'] as String? ?? '',
      isAdminReply: json['is_admin_reply'] as bool? ?? json['isAdminReply'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
    );
  }
}
