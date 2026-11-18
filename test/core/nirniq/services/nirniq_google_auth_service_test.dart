import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kith_app/core/nirniq/services/nirniq_google_auth_service.dart';

// --- Lightweight Test Fakes ---

class FakeGoogleSignInAccount extends Fake implements GoogleSignInAccount {
  @override
  final String id;
  @override
  final String email;
  @override
  final String displayName;
  @override
  final String? photoUrl;
  final GoogleSignInAuthentication _auth;

  FakeGoogleSignInAccount({
    this.id = 'google_sub_10928374',
    this.email = 'testuser@example.com',
    this.displayName = 'Test Nirniq User',
    this.photoUrl = 'https://example.com/avatar.png',
    required this._auth,
  });

  @override
  Future<GoogleSignInAuthentication> get authentication async => _auth;
}

class FakeGoogleSignInAuthentication extends Fake implements GoogleSignInAuthentication {
  @override
  final String? idToken;
  @override
  final String? accessToken;

  FakeGoogleSignInAuthentication({
    this.idToken = 'mock_valid_google_id_token',
    this.accessToken = 'mock_valid_google_access_token',
  });
}

class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  GoogleSignInAccount? accountToReturn;
  Completer<GoogleSignInAccount?>? signInCompleter;
  Exception? errorToThrow;
  bool wasSignedOut = false;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (signInCompleter != null) {
      return signInCompleter!.future;
    }
    return accountToReturn;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    wasSignedOut = true;
    return null;
  }
}

class FakeUser extends Fake implements User {
  @override
  final String id;
  @override
  final String? email;
  @override
  final Map<String, dynamic>? userMetadata;

  FakeUser({
    required this.id,
    this.email = 'testuser@example.com',
    this.userMetadata,
  });
}

class FakeSession extends Fake implements Session {
  @override
  final User user;
  @override
  final String accessToken;
  @override
  final String? refreshToken;

  FakeSession({
    required this.user,
    this.accessToken = 'mock_supabase_access_jwt',
    this.refreshToken = 'mock_supabase_refresh_token',
  });
}

class FakeAuthResponse extends Fake implements AuthResponse {
  @override
  final User? user;
  @override
  final Session? session;

  FakeAuthResponse({this.user, this.session});
}

class FakeGoTrueClient extends Fake implements GoTrueClient {
  Session? activeSession;
  AuthResponse? responseToReturn;
  Exception? errorToThrow;
  bool wasSignedOut = false;
  final StreamController<AuthState> _authController = StreamController<AuthState>.broadcast();

  @override
  Session? get currentSession => activeSession;

  @override
  Stream<AuthState> get onAuthStateChange => _authController.stream;

  @override
  Future<AuthResponse> signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
    String? captchaToken,
  }) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return responseToReturn ??
        FakeAuthResponse(
          user: activeSession?.user,
          session: activeSession,
        );
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    wasSignedOut = true;
    activeSession = null;
  }
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final FakeGoTrueClient _auth;

  FakeSupabaseClient({required this._auth});

  @override
  GoTrueClient get auth => _auth;
}

void main() {
  group('NirniqGoogleAuthService Unit Suite', () {
    late FakeGoogleSignIn fakeGoogleSignIn;
    late FakeGoTrueClient fakeGoTrue;
    late FakeSupabaseClient fakeSupabase;
    late NirniqGoogleAuthService authService;

    const String canonicalUuid = '123e4567-e89b-12d3-a456-426614174000';

    setUp(() {
      fakeGoogleSignIn = FakeGoogleSignIn();
      fakeGoTrue = FakeGoTrueClient();
      fakeSupabase = FakeSupabaseClient(auth: fakeGoTrue);

      authService = NirniqGoogleAuthService(
        googleSignIn: fakeGoogleSignIn,
        supabaseClient: fakeSupabase,
      );
    });

    test('1. Successful Google Sign-In exchanges token with Supabase and returns NirniqAuthResult', () async {
      final fakeAuth = FakeGoogleSignInAuthentication();
      final fakeAccount = FakeGoogleSignInAccount(auth: fakeAuth);
      fakeGoogleSignIn.accountToReturn = fakeAccount;

      final testUser = FakeUser(id: canonicalUuid, email: 'testuser@example.com');
      final testSession = FakeSession(user: testUser);
      fakeGoTrue.activeSession = testSession;
      fakeGoTrue.responseToReturn = FakeAuthResponse(user: testUser, session: testSession);

      final result = await authService.signInWithGoogle();

      expect(result, isNotNull);
      expect(result!.nirniqUserId, canonicalUuid);
      expect(result.email, 'testuser@example.com');
      expect(result.displayName, 'Test Nirniq User');
      expect(result.googleSubjectId, 'google_sub_10928374');
      expect(result.session.accessToken, 'mock_supabase_access_jwt');
      expect(fakeGoogleSignIn.wasSignedOut, isTrue, reason: 'Must sign out previous account first');
    });

    test('2. User dismissal or cancellation returns null without error', () async {
      fakeGoogleSignIn.accountToReturn = null; // User cancelled

      final result = await authService.signInWithGoogle();

      expect(result, isNull);
    });

    test('3. Missing ID token throws NirniqAuthException with missingIdToken code', () async {
      final fakeAuth = FakeGoogleSignInAuthentication(idToken: null);
      fakeGoogleSignIn.accountToReturn = FakeGoogleSignInAccount(auth: fakeAuth);

      expect(
        () => authService.signInWithGoogle(),
        throwsA(isA<NirniqAuthException>().having(
          (e) => e.code,
          'code',
          NirniqAuthErrorCode.missingIdToken,
        )),
      );
    });

    test('4. PlatformException sign_in_canceled or sign_in_cancelled returns null (user cancellation)', () async {
      fakeGoogleSignIn.errorToThrow = PlatformException(
        code: 'sign_in_canceled',
        message: 'The user canceled the sign-in flow',
      );

      final result = await authService.signInWithGoogle();
      expect(result, isNull);

      fakeGoogleSignIn.errorToThrow = PlatformException(
        code: 'sign_in_cancelled',
        message: 'The user canceled the sign-in flow',
      );

      final result2 = await authService.signInWithGoogle();
      expect(result2, isNull);
    });

    test('4b. Generic PlatformException throws NirniqAuthException with googleSignInFailed', () async {
      fakeGoogleSignIn.errorToThrow = PlatformException(
        code: 'developer_error',
        message: 'Developer configuration error',
      );

      expect(
        () => authService.signInWithGoogle(),
        throwsA(isA<NirniqAuthException>().having(
          (e) => e.code,
          'code',
          NirniqAuthErrorCode.googleSignInFailed,
        )),
      );
    });

    test('5. PlatformException network_error is mapped to networkError error code', () async {
      fakeGoogleSignIn.errorToThrow = PlatformException(
        code: 'network_error',
        message: 'Network connection failed',
      );

      expect(
        () => authService.signInWithGoogle(),
        throwsA(isA<NirniqAuthException>().having(
          (e) => e.code,
          'code',
          NirniqAuthErrorCode.networkError,
        )),
      );
    });

    test('6. Supabase AuthException is mapped to supabaseAuthError code', () async {
      final fakeAuth = FakeGoogleSignInAuthentication();
      fakeGoogleSignIn.accountToReturn = FakeGoogleSignInAccount(auth: fakeAuth);
      fakeGoTrue.errorToThrow = const AuthException('Invalid ID token signature');

      expect(
        () => authService.signInWithGoogle(),
        throwsA(isA<NirniqAuthException>().having(
          (e) => e.code,
          'code',
          NirniqAuthErrorCode.supabaseAuthError,
        )),
      );
    });

    test('7. Unexpected Supabase error is mapped to supabaseExchangeFailed code', () async {
      final fakeAuth = FakeGoogleSignInAuthentication();
      fakeGoogleSignIn.accountToReturn = FakeGoogleSignInAccount(auth: fakeAuth);
      fakeGoTrue.errorToThrow = Exception('Connection reset by peer');

      expect(
        () => authService.signInWithGoogle(),
        throwsA(isA<NirniqAuthException>().having(
          (e) => e.code,
          'code',
          NirniqAuthErrorCode.supabaseExchangeFailed,
        )),
      );
    });

    test('8. signOut clears both Google Play Services and Central Supabase sessions', () async {
      final testUser = FakeUser(id: canonicalUuid);
      fakeGoTrue.activeSession = FakeSession(user: testUser);

      expect(authService.isAuthenticated, isTrue);

      await authService.signOut();

      expect(fakeGoogleSignIn.wasSignedOut, isTrue);
      expect(fakeGoTrue.wasSignedOut, isTrue);
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentNirniqUserId, isNull);
    });

    test('9. Active getters correctly reflect authentication state', () {
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentSession, isNull);
      expect(authService.currentNirniqUserId, isNull);

      final testUser = FakeUser(id: canonicalUuid);
      fakeGoTrue.activeSession = FakeSession(user: testUser);

      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentSession, isNotNull);
      expect(authService.currentNirniqUserId, canonicalUuid);
    });

    test('10. Concurrent call while authentication in progress throws alreadyInProgress', () async {
      final completer = Completer<GoogleSignInAccount?>();
      fakeGoogleSignIn.signInCompleter = completer;

      final future1 = authService.signInWithGoogle();
      expect(
        () => authService.signInWithGoogle(),
        throwsA(isA<NirniqAuthException>().having(
          (e) => e.code,
          'code',
          NirniqAuthErrorCode.alreadyInProgress,
        )),
      );

      completer.complete(null);
      await future1;
    });
  });
}
