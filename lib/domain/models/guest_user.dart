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
  final String? nirniqId;
  final String? googleId;
  final String? upiId;
  final String? upiQr;

  bool get isNirniqLinked =>
      (nirniqId != null && nirniqId!.isNotEmpty) ||
      (email != null && email!.isNotEmpty) ||
      (googleId != null && googleId!.isNotEmpty);

  /// Backward-compatible alias for existing tests and call sites
  bool get isGoogleLinked => isNirniqLinked;

  bool get isGuest => !isLinkedToAccount && !isNirniqLinked;

  const GuestUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.recoveryKey,
    required this.anonymousToken,
    required this.createdAt,
    this.isLinkedToAccount = false,
    this.email,
    this.nirniqId,
    this.googleId,
    this.upiId,
    this.upiQr,
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
    String? nirniqId,
    String? googleId,
    String? upiId,
    String? upiQr,
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
      nirniqId: nirniqId ?? this.nirniqId,
      googleId: googleId ?? this.googleId,
      upiId: upiId ?? this.upiId,
      upiQr: upiQr ?? this.upiQr,
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
    'nirniqId': nirniqId,
    'googleId': googleId,
    'upiId': upiId,
    'upiQr': upiQr,
  };

  static String generateFallbackRecoveryKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    final p1 = List.generate(4, (i) => chars[(rand + i * 7) % chars.length]).join();
    final p2 = List.generate(4, (i) => chars[(rand ~/ 13 + i * 11) % chars.length]).join();
    return 'KITH-$p1-$p2';
  }

  factory GuestUser.fromJson(Map<String, dynamic> json) {
    final rawKey = json['recoveryKey'] as String?;
    final validKey = (rawKey != null && rawKey.isNotEmpty && rawKey != 'KITH-RECOVERY-KEY')
        ? rawKey
        : generateFallbackRecoveryKey();

    final nirniqId = json['nirniqId'] as String? ??
        (json['googleId'] != null && (json['googleId'] as String).isNotEmpty
            ? 'nrn_${json['googleId']}'
            : null);

    return GuestUser(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      recoveryKey: validKey,
      anonymousToken: json['anonymousToken'] as String? ?? json['token'] as String? ?? json['sessionToken'] as String? ?? 'anon_token',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isLinkedToAccount: json['isLinkedToAccount'] as bool? ?? false,
      email: json['email'] as String?,
      nirniqId: nirniqId,
      googleId: json['googleId'] as String?,
      upiId: json['upiId'] as String?,
      upiQr: json['upiQr'] as String?,
    );
  }
}
