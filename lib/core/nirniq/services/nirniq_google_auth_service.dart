import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/nirniq_auth_config.dart';

/// Result of successful native Google authentication exchanged with Central Supabase IdP.
class NirniqAuthResult {
  /// Canonical RFC 4122 UUID v4 assigned by Supabase GoTrue (auth.users.id).
  final String nirniqUserId;

  /// Verified email address from Google OpenID Connect claim.
  final String email;

  /// Display name resolved from Google account profile.
  final String displayName;

  /// Profile photo URL from Google, if available.
  final String? avatarUrl;

  /// Underlying Google subject ID (sub claim).
  final String? googleSubjectId;

  /// Active Central Supabase Session containing access JWT and refresh token.
  final Session session;

  const NirniqAuthResult({
    required this.nirniqUserId,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.googleSubjectId,
    required this.session,
  });

  @override
  String toString() =>
      'NirniqAuthResult(nirniqUserId: $nirniqUserId, email: $email, displayName: $displayName)';
}

/// Normalized error codes for Nirniq authentication failures.
enum NirniqAuthErrorCode {
  cancelled,
  networkError,
  missingIdToken,
  googleSignInFailed,
  supabaseExchangeFailed,
  supabaseAuthError,
  unconfigured,
  alreadyInProgress,
}

/// Actionable exception for Nirniq authentication failures.
class NirniqAuthException implements Exception {
  final NirniqAuthErrorCode code;
  final String message;
  final Object? underlyingError;

  const NirniqAuthException({
    required this.code,
    required this.message,
    this.underlyingError,
  });

  @override
  String toString() => 'NirniqAuthException($code): $message';
}

/// Contract for native Google authentication exchanged with Central Supabase.
abstract interface class INirniqGoogleAuthService {
  /// Reactive stream of Supabase auth state changes.
  Stream<AuthState> get onAuthStateChange;

  /// Currently active Central Supabase session, or null if unauthenticated.
  Session? get currentSession;

  /// Canonical Nirniq UUID of the active user, or null if unauthenticated.
  String? get currentNirniqUserId;

  /// Whether an active Central Supabase session is present.
  bool get isAuthenticated;

  /// Triggers native Google account picker and exchanges tokens with Central Supabase IdP.
  ///
  /// Returns [NirniqAuthResult] on success.
  /// Returns `null` if the user dismissed or cancelled the account picker.
  /// Throws [NirniqAuthException] on failure.
  Future<NirniqAuthResult?> signInWithGoogle();

  /// Signs out from both Google Play Services and Central Supabase.
  Future<void> signOut();
}

/// Concrete implementation of [INirniqGoogleAuthService] using Google Play Services
/// and Central Supabase GoTrue IdP.
class NirniqGoogleAuthService implements INirniqGoogleAuthService {
  final GoogleSignIn _googleSignIn;
  final SupabaseClient _supabaseClient;

  bool _isAuthenticating = false;

  NirniqGoogleAuthService({
    GoogleSignIn? googleSignIn,
    SupabaseClient? supabaseClient,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: NirniqAuthConfig.googleWebClientId,
              scopes: const ['email', 'profile'],
            ),
        _supabaseClient = supabaseClient ??
            (Supabase.instance.isInitialized
                ? Supabase.instance.client
                : SupabaseClient(
                    NirniqAuthConfig.centralSupabaseUrl,
                    NirniqAuthConfig.centralSupabaseAnonKey,
                  ));

  @override
  Stream<AuthState> get onAuthStateChange => _supabaseClient.auth.onAuthStateChange;

  @override
  Session? get currentSession {
    try {
      return _supabaseClient.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  @override
  String? get currentNirniqUserId => currentSession?.user.id;

  @override
  bool get isAuthenticated => currentSession != null;

  @override
  Future<NirniqAuthResult?> signInWithGoogle() async {
    if (_isAuthenticating) {
      throw const NirniqAuthException(
        code: NirniqAuthErrorCode.alreadyInProgress,
        message: 'An authentication request is already in progress.',
      );
    }

    _isAuthenticating = true;

    try {
      // 1. Force account picker clean launch
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // 2. Launch native Google Play Services account picker
      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.signIn();
      } on PlatformException catch (e) {
        debugPrint('[NirniqGoogleAuthService] PlatformException: ${e.code} — ${e.message}');
        if (e.code == 'sign_in_cancelled' ||
            e.code == 'sign_in_canceled' ||
            e.code == 'access_denied') {
          return null;
        }
        if (e.code == 'network_error') {
          throw const NirniqAuthException(
            code: NirniqAuthErrorCode.networkError,
            message: 'No internet connection. Please verify your network and try again.',
          );
        }
        throw NirniqAuthException(
          code: NirniqAuthErrorCode.googleSignInFailed,
          message: e.message ?? e.code,
          underlyingError: e,
        );
      } catch (e) {
        if (e is NirniqAuthException) rethrow;
        throw NirniqAuthException(
          code: NirniqAuthErrorCode.googleSignInFailed,
          message: 'Failed to initiate Google Sign-In: $e',
          underlyingError: e,
        );
      }

      if (account == null) {
        return null; // Clean cancellation: user dismissed sheet
      }

      // 3. Extract OpenID Connect ID token and Access token
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      final String? accessToken = auth.accessToken;

      if (idToken == null || idToken.isEmpty) {
        throw const NirniqAuthException(
          code: NirniqAuthErrorCode.missingIdToken,
          message:
              'Google Play Services returned an empty ID token. Please verify Google Play Services configuration.',
        );
      }

      // 4. Exchange tokens with Central Supabase IdP
      try {
        final AuthResponse response = await _supabaseClient.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        final User? user = response.user;
        final Session? session = response.session;

        if (user == null || session == null) {
          throw const NirniqAuthException(
            code: NirniqAuthErrorCode.supabaseExchangeFailed,
            message: 'Central Supabase IdP failed to issue an authenticated session.',
          );
        }

        final email = user.email ?? account.email;
        final displayName = (user.userMetadata?['full_name'] as String?) ??
            account.displayName ??
            email.split('@')[0];
        final avatarUrl = (user.userMetadata?['avatar_url'] as String?) ?? account.photoUrl;

        return NirniqAuthResult(
          nirniqUserId: user.id,
          email: email,
          displayName: displayName,
          avatarUrl: avatarUrl,
          googleSubjectId: account.id,
          session: session,
        );
      } on AuthException catch (e) {
        debugPrint('[NirniqGoogleAuthService] Supabase AuthException: ${e.statusCode} — ${e.message}');
        throw NirniqAuthException(
          code: NirniqAuthErrorCode.supabaseAuthError,
          message: e.message,
          underlyingError: e,
        );
      } catch (e) {
        if (e is NirniqAuthException) rethrow;
        throw NirniqAuthException(
          code: NirniqAuthErrorCode.supabaseExchangeFailed,
          message: 'Token exchange with Central IdP failed: $e',
          underlyingError: e,
        );
      }
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        _supabaseClient.auth.signOut(),
      ]);
    } catch (e) {
      debugPrint('[NirniqGoogleAuthService] Sign-Out notice: $e');
    }
  }
}
