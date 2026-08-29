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
  });

  bool get isCreator => role.toLowerCase() == 'creator';

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
  };

  factory TripMember.fromJson(Map<String, dynamic> json) => TripMember(
    id: json['id'] as String,
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    role: json['role'] as String? ?? 'member',
    joinedAt: json['joinedAt'] != null
        ? DateTime.tryParse(json['joinedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    lastSeenAt: json['lastSeenAt'] != null
        ? DateTime.tryParse(json['lastSeenAt'] as String)
        : null,
    lastSyncedRevision: json['lastSyncedRevision'] as int? ?? 1,
    pendingMutationsCount: json['pendingMutationsCount'] as int? ?? 0,
    upiId: json['upiId'] as String?,
  );
}
