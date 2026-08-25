import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthResult {
  final String email;
  final String displayName;
  final String googleId;
  final String? avatarUrl;

  const GoogleAuthResult({
    required this.email,
    required this.displayName,
    required this.googleId,
    this.avatarUrl,
  });
}

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Triggers native Android / iOS Google Sign-In account picker.
  /// Returns [GoogleAuthResult] if successful, or null if user cancelled.
  static Future<GoogleAuthResult?> signIn() async {
    try {
      // Try signing out of any cached session to ensure account picker opens
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User explicitly cancelled or backed out
        return null;
      }

      final email = account.email.trim();
      final displayName = (account.displayName != null && account.displayName!.trim().isNotEmpty)
          ? account.displayName!.trim()
          : (email.contains('@') ? email.split('@')[0] : 'Kith User');
      final googleId = account.id.isNotEmpty
          ? account.id
          : 'g_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

      return GoogleAuthResult(
        email: email,
        displayName: displayName,
        googleId: googleId,
        avatarUrl: account.photoUrl,
      );
    } catch (e, stack) {
      debugPrint('Native Google Sign-In error: $e\n$stack');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google Sign-Out error: $e');
    }
  }
}
