import 'package:flutter/foundation.dart';
import 'google_auth_service.dart';

/// Ecosystem identity provided by Nirniq Account.
class NirniqIdentity {
  /// Unique Nirniq User Identifier (e.g. `nrn_...` or canonical user ID)
  final String nirniqId;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String provider; // 'google', 'email', 'apple', etc.
  final List<String> connectedApps;
  final String? supabaseUserId;
  final String? externalProviderId; // e.g. raw googleId

  const NirniqIdentity({
    required this.nirniqId,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.provider = 'google',
    this.connectedApps = const ['kith'],
    this.supabaseUserId,
    this.externalProviderId,
  });

  Map<String, dynamic> toJson() => {
        'nirniqId': nirniqId,
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'provider': provider,
        'connectedApps': connectedApps,
        'supabaseUserId': supabaseUserId,
        'externalProviderId': externalProviderId,
      };

  factory NirniqIdentity.fromJson(Map<String, dynamic> json) {
    return NirniqIdentity(
      nirniqId: json['nirniqId'] as String? ?? json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Nirniq User',
      avatarUrl: json['avatarUrl'] as String?,
      provider: json['provider'] as String? ?? 'google',
      connectedApps: (json['connectedApps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['kith'],
      supabaseUserId: json['supabaseUserId'] as String?,
      externalProviderId: json['externalProviderId'] as String? ?? json['googleId'] as String?,
    );
  }

  /// Backward-compatible alias
  String? get googleId => externalProviderId;
}

/// Result of a Nirniq Account authentication attempt.
class NirniqAuthResult {
  final NirniqIdentity identity;
  final bool isNewAccount;

  const NirniqAuthResult({
    required this.identity,
    this.isNewAccount = false,
  });

  bool get isSuccess => true;
}

/// Central identity and authentication abstraction for the Nirniq Ecosystem.
///
/// Encapsulates authentication providers (such as Google OAuth, Supabase JWT verification)
/// behind a unified Nirniq Account interface. Kith and future Nirniq products interact
/// solely with [NirniqAccountService] to authenticate ecosystem users.
class NirniqAccountService {
  /// Executes the Nirniq Account authentication sequence.
  ///
  /// Currently uses native Google OAuth + Supabase identity verification under the hood,
  /// seamlessly transforming the result into a verified [NirniqIdentity].
  ///
  /// Returns `null` if the user cancelled.
  /// Throws [NirniqAuthException] on failure.
  static Future<NirniqAuthResult?> authenticate() => signIn();

  static Future<NirniqAuthResult?> signIn() async {
    try {
      final googleResult = await GoogleAuthService.signIn();
      if (googleResult == null) {
        return null; // User cancelled
      }

      // Generate or map deterministic Nirniq Identity ID
      final nirniqId = googleResult.supabaseUserId ??
          'nrn_${googleResult.googleId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

      final identity = NirniqIdentity(
        nirniqId: nirniqId,
        email: googleResult.email,
        displayName: googleResult.displayName,
        avatarUrl: googleResult.avatarUrl,
        provider: 'google',
        connectedApps: const ['kith'],
        supabaseUserId: googleResult.supabaseUserId,
        externalProviderId: googleResult.googleId,
      );

      return NirniqAuthResult(identity: identity);
    } on GoogleSignInException catch (e) {
      debugPrint('[NirniqAccountService] Provider error: ${e.message}');
      throw NirniqAuthException(
        message: e.message,
        code: e.failure.name,
      );
    } catch (e) {
      debugPrint('[NirniqAccountService] Unexpected auth error: $e');
      throw NirniqAuthException(
        message: 'Could not connect to Nirniq Account. Please try again.',
        code: 'UNKNOWN_AUTH_ERROR',
      );
    }
  }

  /// Signs the user out of the active Nirniq Account session.
  static Future<void> signOut() async {
    try {
      await GoogleAuthService.signOut();
    } catch (e) {
      debugPrint('[NirniqAccountService] Sign-out error: $e');
    }
  }

  /// Returns true if an underlying identity session is currently active.
  static bool get hasActiveSession {
    return GoogleAuthService.currentSession != null;
  }
}

/// Thrown when Nirniq Account authentication fails.
class NirniqAuthException implements Exception {
  final String message;
  final String code;

  const NirniqAuthException({required this.message, required this.code});

  @override
  String toString() => 'NirniqAuthException($code): $message';
}
