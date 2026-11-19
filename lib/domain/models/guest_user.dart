/// Guest & Authenticated User entity.
/// Supports server-side anonymous recovery, logical account ownership, and account-linking.
class GuestUser {
  final String id;
  final String? accountId;
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
  final String? role;

  /// Returns the canonical logical account ID (defaults to user ID if not explicitly partitioned)
  String get effectiveAccountId => (accountId != null && accountId!.isNotEmpty) ? accountId! : id;

  bool get isNirniqLinked =>
      (nirniqId != null && nirniqId!.isNotEmpty) ||
      (email != null && email!.isNotEmpty) ||
      (googleId != null && googleId!.isNotEmpty);

  /// Backward-compatible alias for existing tests and call sites
  bool get isGoogleLinked => isNirniqLinked;

  bool get isGuest => !isLinkedToAccount && !isNirniqLinked;

  bool get isAdmin =>
      role == 'admin' ||
      (email != null && (email!.endsWith('@kith.app') || email!.endsWith('@nirniq.com')));

  const GuestUser({
    required this.id,
    this.accountId,
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
    this.role,
  });

  GuestUser copyWith({
    String? id,
    String? accountId,
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
    String? role,
  }) {
    return GuestUser(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
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
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId ?? effectiveAccountId,
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
    'role': role,
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
      accountId: json['accountId'] as String? ?? json['account_id'] as String?,
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? 'Traveler',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      recoveryKey: validKey,
      anonymousToken: json['anonymousToken'] as String? ?? json['token'] as String? ?? json['sessionToken'] as String? ?? 'anon_token',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now()),
      isLinkedToAccount: json['isLinkedToAccount'] as bool? ?? false,
      email: json['email'] as String?,
      nirniqId: nirniqId,
      googleId: json['googleId'] as String?,
      upiId: json['upiId'] as String?,
      upiQr: json['upiQr'] as String?,
      role: json['role'] as String?,
    );
  }
}
