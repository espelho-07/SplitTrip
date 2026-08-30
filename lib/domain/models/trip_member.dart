/// Member within a Trip.
class TripMember {
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String role; // 'creator' or 'member'
  final DateTime joinedAt;
  final DateTime? lastSeenAt;
  final int lastSyncedRevision;
  final int pendingMutationsCount;
  final String? upiId;
  final bool isClaimed;
  final String? claimToken;
  final String? status;
  final String? mergedIntoMemberId;

  const TripMember({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = 'member',
    required this.joinedAt,
    this.lastSeenAt,
    this.lastSyncedRevision = 1,
    this.pendingMutationsCount = 0,
    this.upiId,
    this.isClaimed = true,
    this.claimToken,
    this.status,
    this.mergedIntoMemberId,
  });

  bool get isCreator => role.toLowerCase() == 'creator';
  bool get isUnclaimed => !isClaimed || status == 'unclaimed';
  bool get isMerged => status == 'merged' || mergedIntoMemberId != null;
  String get currentStatus => status ?? (isClaimed ? 'claimed' : 'unclaimed');

  TripMember copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? role,
    DateTime? joinedAt,
    DateTime? lastSeenAt,
    int? lastSyncedRevision,
    int? pendingMutationsCount,
    String? upiId,
    bool? isClaimed,
    String? claimToken,
    String? status,
    String? mergedIntoMemberId,
  }) {
    return TripMember(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastSyncedRevision: lastSyncedRevision ?? this.lastSyncedRevision,
      pendingMutationsCount: pendingMutationsCount ?? this.pendingMutationsCount,
      upiId: upiId ?? this.upiId,
      isClaimed: isClaimed ?? this.isClaimed,
      claimToken: claimToken ?? this.claimToken,
      status: status ?? this.status,
      mergedIntoMemberId: mergedIntoMemberId ?? this.mergedIntoMemberId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'role': role,
    'joinedAt': joinedAt.toIso8601String(),
    'lastSeenAt': lastSeenAt?.toIso8601String(),
    'lastSyncedRevision': lastSyncedRevision,
    'pendingMutationsCount': pendingMutationsCount,
    'upiId': upiId,
    'isClaimed': isClaimed,
    'claimToken': claimToken,
    'status': currentStatus,
    'mergedIntoMemberId': mergedIntoMemberId,
  };

  factory TripMember.fromJson(Map<String, dynamic> json) {
    final rawUserId = json['userId'] as String? ?? json['user_id'] as String? ?? '';
    final rawStatus = json['status'] as String?;
    final isUnclaimed = json['isClaimed'] == false ||
        json['is_claimed'] == false ||
        rawStatus == 'unclaimed' ||
        rawUserId.startsWith('unclaimed_');

    return TripMember(
      id: (json['id'] as String?) ?? '',
      userId: rawUserId,
      displayName: (json['displayName'] as String?) ?? (json['display_name'] as String?) ?? 'Member',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String) ?? DateTime.now()
          : (json['joined_at'] != null
              ? DateTime.tryParse(json['joined_at'] as String) ?? DateTime.now()
              : DateTime.now()),
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.tryParse(json['lastSeenAt'] as String)
          : (json['last_seen_at'] != null
              ? DateTime.tryParse(json['last_seen_at'] as String)
              : null),
      lastSyncedRevision: json['lastSyncedRevision'] as int? ?? json['last_synced_revision'] as int? ?? 1,
      pendingMutationsCount: json['pendingMutationsCount'] as int? ?? json['pending_mutations_count'] as int? ?? 0,
      upiId: json['upiId'] as String? ?? json['upi_id'] as String?,
      isClaimed: json['isClaimed'] as bool? ?? json['is_claimed'] as bool? ?? !isUnclaimed,
      claimToken: json['claimToken'] as String? ?? json['claim_token'] as String?,
      status: rawStatus ?? (isUnclaimed ? 'unclaimed' : 'claimed'),
      mergedIntoMemberId: json['mergedIntoMemberId'] as String? ?? json['merged_into_member_id'] as String?,
    );
  }
}

