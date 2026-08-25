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
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isJourneyEnabled => tripMode == 'split_and_journey';

  const Trip({
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
    required this.createdAt,
    required this.updatedAt,
  });

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
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
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
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : DateTime.now(),
  );
}
