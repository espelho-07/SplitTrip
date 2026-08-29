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
        : DateTime.now();
    final parsedStartedAt = json['startedAt'] != null
        ? DateTime.tryParse(json['startedAt'] as String) ?? parsedCreatedAt
        : (json['started_at'] != null
            ? DateTime.tryParse(json['started_at'] as String) ?? parsedCreatedAt
            : parsedCreatedAt);

    return Trip(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      emoji: json['emoji'] as String? ?? '✈️',
      coverGradientIndex: json['coverGradientIndex'] as int? ?? 0,
      currencyCode: json['currencyCode'] as String? ?? 'INR',
      creatorId: json['creatorId'] as String,
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => TripMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lifecycleState: TripLifecycle.fromString(json['lifecycleState'] as String? ?? 'active'),
      inviteCode: json['inviteCode'] as String? ?? 'KITH00',
      tripMode: json['tripMode'] as String? ?? json['trip_mode'] as String? ?? 'split_only',
      revision: json['revision'] as int? ?? 1,
      completionMode: json['completionMode'] as String?,
      startedAt: parsedStartedAt,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      completedBy: json['completedBy'] as String?,
      createdAt: parsedCreatedAt,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? parsedCreatedAt
          : parsedCreatedAt,
    );
  }
}
