/// Guest & Authenticated User entity.
/// Supports server-side anonymous recovery and account-linking.
class GuestUser {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String recoveryKey;
  final String anonymousToken;
  final DateTime createdAt;
  final bool isLinkedToAccount;
  final String? email;

  const GuestUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.recoveryKey,
    required this.anonymousToken,
    required this.createdAt,
    this.isLinkedToAccount = false,
    this.email,
  });

  GuestUser copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? recoveryKey,
    String? anonymousToken,
    DateTime? createdAt,
    bool? isLinkedToAccount,
    String? email,
  }) {
    return GuestUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      recoveryKey: recoveryKey ?? this.recoveryKey,
      anonymousToken: anonymousToken ?? this.anonymousToken,
      createdAt: createdAt ?? this.createdAt,
      isLinkedToAccount: isLinkedToAccount ?? this.isLinkedToAccount,
      email: email ?? this.email,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'recoveryKey': recoveryKey,
    'anonymousToken': anonymousToken,
    'createdAt': createdAt.toIso8601String(),
    'isLinkedToAccount': isLinkedToAccount,
    'email': email,
  };

  factory GuestUser.fromJson(Map<String, dynamic> json) => GuestUser(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    recoveryKey: json['recoveryKey'] as String? ?? 'KITH-RECOVERY-KEY',
    anonymousToken: json['anonymousToken'] as String? ?? 'anon_token',
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
    isLinkedToAccount: json['isLinkedToAccount'] as bool? ?? false,
    email: json['email'] as String?,
  );
}
