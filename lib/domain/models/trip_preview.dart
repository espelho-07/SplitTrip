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
  });

  factory TripPreview.fromJson(Map<String, dynamic> json) {
    return TripPreview(
      tripId: json['tripId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '✈️',
      coverGradientIndex: json['coverGradientIndex'] as int? ?? 0,
      currencyCode: json['currencyCode'] as String? ?? 'INR',
      creatorName: json['creatorName'] as String? ?? 'Friend',
      memberCount: json['memberCount'] as int? ?? 1,
      lifecycleState: json['lifecycleState'] as String? ?? 'active',
      inviteCode: json['inviteCode'] as String? ?? '',
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
  };
}
