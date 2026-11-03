/// Publicly visible, moderated feature request.
class FeatureRequest {
  final String id;
  final String title;
  final String description;
  final String status;
  final int upvoteCount;
  final bool hasVoted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeatureRequest({
    required this.id,
    required this.title,
    required this.description,
    this.status = 'open',
    this.upvoteCount = 0,
    this.hasVoted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  FeatureRequest copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    int? upvoteCount,
    bool? hasVoted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeatureRequest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      hasVoted: hasVoted ?? this.hasVoted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'status': status,
    'upvote_count': upvoteCount,
    'has_voted': hasVoted,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory FeatureRequest.fromJson(Map<String, dynamic> json) {
    // Strictly read approved public fields. Zero fallback to private feedback fields.
    final publicTitle = (json['public_title'] as String?)?.trim() ?? (json['title'] as String?)?.trim() ?? '';
    final publicDesc = (json['public_description'] as String?)?.trim() ?? (json['description'] as String?)?.trim() ?? '';

    return FeatureRequest(
      id: json['id'] as String? ?? '',
      title: publicTitle,
      description: publicDesc,
      status: json['status'] as String? ?? 'open',
      upvoteCount: json['upvote_count'] as int? ?? json['upvoteCount'] as int? ?? 0,
      hasVoted: json['has_voted'] as bool? ?? json['hasVoted'] as bool? ?? false,
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

/// Represents a single vote cast for a feature request.
class FeatureVote {
  final String feedbackId;
  final String userId;
  final DateTime createdAt;

  const FeatureVote({
    required this.feedbackId,
    required this.userId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'feedback_id': feedbackId,
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
  };

  factory FeatureVote.fromJson(Map<String, dynamic> json) {
    return FeatureVote(
      feedbackId: json['feedback_id'] as String? ?? json['feedbackId'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
