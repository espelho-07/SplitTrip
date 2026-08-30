class UnclaimedMemberPreview {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? claimToken;

  const UnclaimedMemberPreview({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.claimToken,
  });

  factory UnclaimedMemberPreview.fromJson(Map<String, dynamic> json) => UnclaimedMemberPreview(
    id: json['id'] as String? ?? '',
    displayName: json['displayName'] as String? ?? 'Member',
    avatarUrl: json['avatarUrl'] as String?,
    claimToken: json['claimToken'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'claimToken': claimToken,
  };
}

class TripPreview {
  final String tripId;
  final String name;
  final String emoji;
  final int coverGradientIndex;
  final String currencyCode;
  final String creatorName;
  final int memberCount;
  final String lifecycleState;
  final String inviteCode;
  final List<UnclaimedMemberPreview> unclaimedMembers;
  final String? targetClaimMemberId;

  const TripPreview({
    required this.tripId,
    required this.name,
    required this.emoji,
    required this.coverGradientIndex,
    required this.currencyCode,
    required this.creatorName,
    required this.memberCount,
    required this.lifecycleState,
    required this.inviteCode,
    this.unclaimedMembers = const [],
    this.targetClaimMemberId,
  });

  factory TripPreview.fromJson(Map<String, dynamic> json) {
    final rawUnclaimed = json['unclaimedMembers'];
    final unclaimed = <UnclaimedMemberPreview>[];
    if (rawUnclaimed is List) {
      for (final item in rawUnclaimed) {
        if (item is Map<String, dynamic>) {
          unclaimed.add(UnclaimedMemberPreview.fromJson(item));
        }
      }
    }

    return TripPreview(
      tripId: json['tripId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '✈️',
      coverGradientIndex: json['coverGradientIndex'] as int? ?? 0,
      currencyCode: json['currencyCode'] as String? ?? 'INR',
      creatorName: json['creatorName'] as String? ?? 'Friend',
      memberCount: json['memberCount'] as int? ?? 1,
      lifecycleState: json['lifecycleState'] as String? ?? 'active',
      inviteCode: json['inviteCode'] as String? ?? '',
      unclaimedMembers: unclaimed,
      targetClaimMemberId: json['targetClaimMemberId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'name': name,
    'emoji': emoji,
    'coverGradientIndex': coverGradientIndex,
    'currencyCode': currencyCode,
    'creatorName': creatorName,
    'memberCount': memberCount,
    'lifecycleState': lifecycleState,
    'inviteCode': inviteCode,
    'unclaimedMembers': unclaimedMembers.map((m) => m.toJson()).toList(),
    'targetClaimMemberId': targetClaimMemberId,
  };
}
