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
  final String? p2pTripSecret;
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
    this.p2pTripSecret,
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
    String? p2pTripSecret,
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
      p2pTripSecret: p2pTripSecret ?? this.p2pTripSecret,
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

  /// Safely merges this local trip aggregate with a remote or cached snapshot.
  /// Guarantees:
  /// 1. Virtual members and locally joined members are NEVER dropped.
  /// 2. Member lists are merged union-wise by member ID and user ID.
  /// 3. Existing member display names are preserved and never overwritten by generic fallbacks.
  /// 4. Higher revision number and newest updatedAt are preserved.
  Trip mergeWith(Trip other) {
    if (other.id != id) return this;

    final mergedMembersMap = <String, TripMember>{};
    // 1. Seed with this trip's members
    for (final m in members) {
      mergedMembersMap[m.id] = m;
    }

    // 2. Union merge other trip's members
    for (final otherMember in other.members) {
      if (mergedMembersMap.containsKey(otherMember.id)) {
        final existing = mergedMembersMap[otherMember.id]!;
        final chosenDisplayName =
            (otherMember.displayName.isNotEmpty &&
                otherMember.displayName != 'Member')
            ? otherMember.displayName
            : existing.displayName;

        final bool isNowClaimed = otherMember.isClaimed || existing.isClaimed;
        final String chosenUserId;
        if (!existing.userId.startsWith('unclaimed_') && existing.userId.isNotEmpty) {
          chosenUserId = existing.userId;
        } else if (!otherMember.userId.startsWith('unclaimed_') && otherMember.userId.isNotEmpty) {
          chosenUserId = otherMember.userId;
        } else {
          chosenUserId = existing.userId.isNotEmpty ? existing.userId : otherMember.userId;
        }

        mergedMembersMap[otherMember.id] = existing.copyWith(
          displayName: chosenDisplayName,
          userId: chosenUserId,
          avatarUrl: otherMember.avatarUrl ?? existing.avatarUrl,
          role: otherMember.role != 'member' && otherMember.role != 'virtual' ? otherMember.role : existing.role,
          upiId: otherMember.upiId ?? existing.upiId,
          isClaimed: isNowClaimed,
          status: isNowClaimed ? 'claimed' : (otherMember.status ?? existing.status),
          claimToken: otherMember.claimToken ?? existing.claimToken,
          mergedIntoMemberId:
              otherMember.mergedIntoMemberId ?? existing.mergedIntoMemberId,
          isVirtualMember: !isNowClaimed,
        );
      } else {
        // Check by authenticated userId if not unclaimed
        final byUserId = mergedMembersMap.values
            .where(
              (m) =>
                  m.userId.isNotEmpty &&
                  !m.userId.startsWith('unclaimed_') &&
                  m.userId == otherMember.userId,
            )
            .firstOrNull;

        if (byUserId != null) {
          mergedMembersMap[byUserId.id] = byUserId.copyWith(
            displayName:
                (otherMember.displayName.isNotEmpty &&
                    otherMember.displayName != 'Member')
                ? otherMember.displayName
                : byUserId.displayName,
            avatarUrl: otherMember.avatarUrl ?? byUserId.avatarUrl,
            upiId: otherMember.upiId ?? byUserId.upiId,
          );
        } else {
          // Genuinely new member from other device/server
          mergedMembersMap[otherMember.id] = otherMember;
        }
      }
    }

    final isOtherNewer =
        other.revision > revision || other.updatedAt.isAfter(updatedAt);

    final String? mergedSecret;
    if (other.revision > revision &&
        other.p2pTripSecret != null &&
        other.p2pTripSecret!.isNotEmpty) {
      mergedSecret = other.p2pTripSecret;
    } else if (p2pTripSecret != null && p2pTripSecret!.isNotEmpty) {
      mergedSecret = p2pTripSecret;
    } else {
      mergedSecret = other.p2pTripSecret;
    }

    return Trip(
      id: id,
      name: isOtherNewer && other.name.isNotEmpty ? other.name : name,
      description: isOtherNewer
          ? (other.description ?? description)
          : (description ?? other.description),
      emoji: isOtherNewer ? other.emoji : emoji,
      coverGradientIndex: isOtherNewer
          ? other.coverGradientIndex
          : coverGradientIndex,
      currencyCode: other.currencyCode.isNotEmpty
          ? other.currencyCode
          : currencyCode,
      creatorId: creatorId.isNotEmpty ? creatorId : other.creatorId,
      members: mergedMembersMap.values.toList(),
      lifecycleState: isOtherNewer ? other.lifecycleState : lifecycleState,
      inviteCode: inviteCode.isNotEmpty ? inviteCode : other.inviteCode,
      p2pTripSecret: mergedSecret,
      tripMode: isOtherNewer ? other.tripMode : tripMode,
      revision: other.revision > revision ? other.revision : revision,
      completionMode: other.completionMode ?? completionMode,
      startedAt: startedAt.isBefore(other.startedAt)
          ? startedAt
          : other.startedAt,
      completedAt: other.completedAt ?? completedAt,
      completedBy: other.completedBy ?? completedBy,
      createdAt: createdAt.isBefore(other.createdAt)
          ? createdAt
          : other.createdAt,
      updatedAt: isOtherNewer ? other.updatedAt : updatedAt,
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
    'p2pTripSecret': p2pTripSecret,
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
              ? DateTime.tryParse(json['created_at'] as String) ??
                    DateTime.now()
              : DateTime.now());
    final parsedStartedAt = json['startedAt'] != null
        ? DateTime.tryParse(json['startedAt'] as String) ?? parsedCreatedAt
        : (json['started_at'] != null
              ? DateTime.tryParse(json['started_at'] as String) ??
                    parsedCreatedAt
              : parsedCreatedAt);

    final rawLifecycle =
        json['lifecycleState'] as String? ??
        json['lifecycle_state'] as String? ??
        json['status'] as String? ??
        'active';

    final rawCompletedAt = json['completedAt'] != null
        ? DateTime.tryParse(json['completedAt'] as String)
        : (json['completed_at'] != null
              ? DateTime.tryParse(json['completed_at'] as String)
              : null);

    final rawCompletedBy =
        json['completedBy'] as String? ?? json['completed_by'] as String?;

    return Trip(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Trip',
      description: json['description'] as String?,
      emoji: json['emoji'] as String? ?? '✈️',
      coverGradientIndex:
          json['coverGradientIndex'] as int? ??
          json['cover_gradient_index'] as int? ??
          0,
      currencyCode:
          json['currencyCode'] as String? ??
          json['currency_code'] as String? ??
          'INR',
      creatorId:
          (json['creatorId'] as String?) ??
          (json['creator_id'] as String?) ??
          '',
      members:
          (json['members'] as List<dynamic>?)
              ?.map((e) => TripMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lifecycleState: TripLifecycle.fromString(rawLifecycle),
      inviteCode:
          json['inviteCode'] as String? ??
          json['invite_code'] as String? ??
          'KITH00',
      p2pTripSecret:
          json['p2pTripSecret'] as String? ??
          json['p2p_trip_secret'] as String?,
      tripMode:
          json['tripMode'] as String? ??
          json['trip_mode'] as String? ??
          'split_only',
      revision: json['revision'] as int? ?? 1,
      completionMode:
          json['completionMode'] as String? ??
          json['completion_mode'] as String?,
      startedAt: parsedStartedAt,
      completedAt: rawCompletedAt,
      completedBy: rawCompletedBy,
      createdAt: parsedCreatedAt,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? parsedCreatedAt
          : (json['updated_at'] != null
                ? DateTime.tryParse(json['updated_at'] as String) ??
                      parsedCreatedAt
                : parsedCreatedAt),
    );
  }
}
