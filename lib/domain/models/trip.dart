import '../enums/trip_lifecycle.dart';
import 'trip_member.dart';

/// Core Trip aggregate root.
class Trip {
  final String id;
  final String name;
  final String? description;
  final String emoji;
  final int coverGradientIndex;
  final String currencyCode;
  final String creatorId;
  final List<TripMember> members;
  final TripLifecycle lifecycleState;
  final String inviteCode;
  final String tripMode; // 'split_only' or 'split_and_journey'
  final int revision;
  final String? completionMode;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? completedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isJourneyEnabled => tripMode == 'split_and_journey';

  Trip({
    required this.id,
    required this.name,
    this.description,
    this.emoji = '✈️',
    this.coverGradientIndex = 0,
    this.currencyCode = 'INR',
    required this.creatorId,
    required this.members,
    this.lifecycleState = TripLifecycle.active,
    required this.inviteCode,
    this.tripMode = 'split_only',
    this.revision = 1,
    this.completionMode,
    DateTime? startedAt,
    this.completedAt,
    this.completedBy,
    required this.createdAt,
    required this.updatedAt,
  }) : startedAt = startedAt ?? createdAt;

  Trip copyWith({
    String? id,
    String? name,
    String? description,
    String? emoji,
    int? coverGradientIndex,
    String? currencyCode,
    String? creatorId,
    List<TripMember>? members,
    TripLifecycle? lifecycleState,
    String? inviteCode,
    String? tripMode,
    int? revision,
    String? completionMode,
    DateTime? startedAt,
    DateTime? completedAt,
    String? completedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      coverGradientIndex: coverGradientIndex ?? this.coverGradientIndex,
      currencyCode: currencyCode ?? this.currencyCode,
      creatorId: creatorId ?? this.creatorId,
      members: members ?? this.members,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      inviteCode: inviteCode ?? this.inviteCode,
      tripMode: tripMode ?? this.tripMode,
      revision: revision ?? this.revision,
      completionMode: completionMode ?? this.completionMode,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'emoji': emoji,
    'coverGradientIndex': coverGradientIndex,
    'currencyCode': currencyCode,
    'creatorId': creatorId,
    'members': members.map((m) => m.toJson()).toList(),
    'lifecycleState': lifecycleState.name,
    'inviteCode': inviteCode,
    'tripMode': tripMode,
    'revision': revision,
    'completionMode': completionMode,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'completedBy': completedBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Trip.fromJson(Map<String, dynamic> json) {
    final parsedCreatedAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : (json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now());
    final parsedStartedAt = json['startedAt'] != null
        ? DateTime.tryParse(json['startedAt'] as String) ?? parsedCreatedAt
        : (json['started_at'] != null
            ? DateTime.tryParse(json['started_at'] as String) ?? parsedCreatedAt
            : parsedCreatedAt);

    final rawLifecycle = json['lifecycleState'] as String? ??
        json['lifecycle_state'] as String? ??
        json['status'] as String? ??
        'active';

    final rawCompletedAt = json['completedAt'] != null
        ? DateTime.tryParse(json['completedAt'] as String)
        : (json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'] as String)
            : null);

    final rawCompletedBy = json['completedBy'] as String? ?? json['completed_by'] as String?;

    return Trip(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Trip',
      description: json['description'] as String?,
      emoji: json['emoji'] as String? ?? '✈️',
      coverGradientIndex: json['coverGradientIndex'] as int? ?? json['cover_gradient_index'] as int? ?? 0,
      currencyCode: json['currencyCode'] as String? ?? json['currency_code'] as String? ?? 'INR',
      creatorId: (json['creatorId'] as String?) ?? (json['creator_id'] as String?) ?? '',
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => TripMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lifecycleState: TripLifecycle.fromString(rawLifecycle),
      inviteCode: json['inviteCode'] as String? ?? json['invite_code'] as String? ?? 'KITH00',
      tripMode: json['tripMode'] as String? ?? json['trip_mode'] as String? ?? 'split_only',
      revision: json['revision'] as int? ?? 1,
      completionMode: json['completionMode'] as String? ?? json['completion_mode'] as String?,
      startedAt: parsedStartedAt,
      completedAt: rawCompletedAt,
      completedBy: rawCompletedBy,
      createdAt: parsedCreatedAt,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? parsedCreatedAt
          : (json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'] as String) ?? parsedCreatedAt
              : parsedCreatedAt),
    );
  }
}
