import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Result of a successful Google Sign-In + Supabase identity verification.
class GoogleAuthResult {
  final String email;
  final String displayName;
  final String googleId;
  final String? avatarUrl;

  /// The Supabase user id — available when Supabase was initialized.
  final String? supabaseUserId;

  const GoogleAuthResult({
    required this.email,
    required this.displayName,
    required this.googleId,
    this.avatarUrl,
    this.supabaseUserId,
  });
}

/// Reason that Google Sign-In was not completed.
enum GoogleSignInFailure { cancelled, networkError, signInFailed, supabaseError }

/// Wraps the complete Google Sign-In → Supabase identity verification flow.
///
/// Flow:
///   1. Native Android account picker via [GoogleSignIn.signIn()]
///   2. Retrieve [GoogleSignInAuthentication] (idToken + accessToken)
///   3. Call [supabase.auth.signInWithIdToken()] to verify identity
///      server-side against the configured Google provider
///   4. Return [GoogleAuthResult] (unchanged interface — callers unaffected)
///
/// If Supabase is not yet configured (placeholder URL), step 3 is skipped
/// and the raw Google account info is returned directly.
class GoogleAuthService {
  /// Web OAuth Client ID — registered in Google Cloud Console and configured
  /// in Supabase Auth → Providers → Google.
  ///
  /// Required as [serverClientId] so the native Google Sign-In plugin
  /// requests an idToken scoped for this server client, which Supabase
  /// can then verify via [signInWithIdToken()].
  ///
  /// This is the Web client ID (not the Android client) — that is correct.
  /// The Android client ID is embedded in google-services.json for the
  /// native SDK; the Web client ID here identifies the token audience.
  static const String _webClientId =
      '752190461758-m6ikshjbood33faqfacgfnvkdjrp7vj2.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _webClientId,
  );

  /// Triggers the native Google account picker, verifies identity via Supabase,
  /// and returns a [GoogleAuthResult] on success.
  ///
  /// Returns `null` if the user cancelled.
  /// Throws [GoogleSignInException] with a [GoogleSignInFailure] reason on error.
  static Future<GoogleAuthResult?> signIn() async {
    GoogleSignInAccount? account;

    try {
      // Force account picker to appear even if a session was previously cached
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      try {
        account = await _googleSignIn.signIn();
      } on PlatformException catch (pErr) {
        final msg = pErr.message ?? '';
        if (pErr.code == 'sign_in_failed' || msg.contains('10') || msg.contains('DEVELOPER_ERROR') || msg.contains('12500')) {
          debugPrint('[GoogleAuthService] ServerClientId sign-in error ($pErr). Trying native GoogleSignIn fallback...');
          final nativeSignIn = GoogleSignIn(scopes: ['email', 'profile']);
          try {
            await nativeSignIn.signOut();
          } catch (_) {}
          account = await nativeSignIn.signIn();
        } else {
          rethrow;
        }
      }
      if (account == null) return null; // User cancelled
    } on PlatformException catch (e) {
      debugPrint('[GoogleAuthService] PlatformException: ${e.code} — ${e.message}');
      if (e.code == 'sign_in_cancelled' || e.code == 'access_denied') {
        return null; // User explicitly cancelled
      }
      if (e.code == 'network_error') {
        throw const GoogleSignInException(
          failure: GoogleSignInFailure.networkError,
          message: 'No internet connection. Please check your network and try again.',
        );
      }
      final msg = e.message ?? '';
      if (msg.contains('10') || msg.contains('12500') || msg.contains('404') || msg.contains('DEVELOPER_ERROR') || e.code == 'sign_in_failed') {
        throw GoogleSignInException(
          failure: GoogleSignInFailure.signInFailed,
          message: 'Google Sign-In setup: Please re-download google-services.json from Firebase Console after adding SHA-1. (${e.code}: ${e.message ?? ""})',
        );
      }
      throw GoogleSignInException(
        failure: GoogleSignInFailure.signInFailed,
        message: 'Google Sign-In error: ${e.message ?? e.code}',
      );
    } catch (e) {
      debugPrint('[GoogleAuthService] Unexpected signIn error: $e');
      throw GoogleSignInException(
        failure: GoogleSignInFailure.signInFailed,
        message: e.toString(),
      );
    }

    // --- Extract account info ---
    final email = account.email.trim();
    final displayName = _resolveDisplayName(account.displayName, email);
    final googleId = account.id.isNotEmpty
        ? account.id
        : 'g_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    final avatarUrl = account.photoUrl;

    // --- Supabase identity verification ---
    String? supabaseUserId;
    if (SupabaseConfig.isConfigured) {
      try {
        final auth = await account.authentication;
        final idToken = auth.idToken;
        final accessToken = auth.accessToken;

        if (idToken == null || idToken.isEmpty) {
          throw const GoogleSignInException(
            failure: GoogleSignInFailure.supabaseError,
            message:
                'Google did not return an idToken. Make sure the Android OAuth client is configured in Google Cloud Console for package com.nirniq.kith.',
          );
        }

        final response = await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        supabaseUserId = response.user?.id;
        debugPrint('[GoogleAuthService] Supabase signInWithIdToken OK — user: $supabaseUserId');
      } on AuthException catch (e) {
        debugPrint('[GoogleAuthService] Supabase AuthException: ${e.message}');
        throw GoogleSignInException(
          failure: GoogleSignInFailure.supabaseError,
          message: 'Supabase could not verify your Google account: ${e.message}',
        );
      } catch (e) {
        if (e is GoogleSignInException) rethrow;
        debugPrint('[GoogleAuthService] Supabase error: $e');
        throw GoogleSignInException(
          failure: GoogleSignInFailure.supabaseError,
          message: 'Authentication verification failed: $e',
        );
      }
    } else {
      debugPrint('[GoogleAuthService] Supabase not configured — skipping signInWithIdToken.');
    }

    return GoogleAuthResult(
      email: email,
      displayName: displayName,
      googleId: googleId,
      avatarUrl: avatarUrl,
      supabaseUserId: supabaseUserId,
    );
  }

  /// Signs the user out of both Google and Supabase.
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    if (SupabaseConfig.isConfigured) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        debugPrint('[GoogleAuthService] Supabase Sign-Out error: $e');
      }
    }
  }

  /// Returns the active Supabase session if one exists.
  static Session? get currentSession {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentSession;
  }

  static String _resolveDisplayName(String? name, String email) {
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return email.contains('@') ? email.split('@')[0] : 'Kith User';
  }
}

/// Thrown when Google Sign-In fails with a specific, actionable reason.
class GoogleSignInException implements Exception {
  final GoogleSignInFailure failure;
  final String message;

  const GoogleSignInException({required this.failure, required this.message});

  @override
  String toString() => 'GoogleSignInException(${failure.name}): $message';
}