/// Member within a Trip.
class TripMember {
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String role; // 'creator' or 'member'
  final DateTime joinedAt;
  final String? upiId;

  const TripMember({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = 'member',
    required this.joinedAt,
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
    String? upiId,
  }) {
    return TripMember(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
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
    'upiId': upiId,
  };

  factory TripMember.fromJson(Map<String, dynamic> json) => TripMember(
    id: json['id'] as String,
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    role: json['role'] as String? ?? 'member',
    joinedAt: json['joinedAt'] != null
        ? DateTime.parse(json['joinedAt'] as String)
        : DateTime.now(),
    upiId: json['upiId'] as String?,
  );
}
