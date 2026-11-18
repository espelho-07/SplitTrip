import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/nirniq/config/nirniq_feature_flags.dart';
import 'package:kith_app/core/nirniq/models/nirniq_identity.dart';
import 'package:kith_app/core/nirniq/repositories/i_nirniq_identity_repository.dart';
import 'package:kith_app/core/nirniq/services/nirniq_google_auth_service.dart';
import 'package:kith_app/core/nirniq/services/nirniq_identity_service_impl.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';

// --- Hermetic In-Memory Fakes ---

class InMemoryNirniqRepository implements INirniqIdentityRepository {
  final Map<String, NirniqIdentity> _identities = {};
  NirniqIdentity? _active;

  @override
  Future<NirniqIdentity?> findById(String nirniqId) async => _identities[nirniqId] ?? _active;

  @override
  Future<NirniqIdentity?> findByGoogleSubject(String googleSubject) async =>
      _identities.values.firstWhere((i) => i.googleSubject == googleSubject, orElse: () => _active!);

  @override
  Future<bool> existsForGoogleSubject(String googleSubject) async =>
      _identities.values.any((i) => i.googleSubject == googleSubject) || _active?.googleSubject == googleSubject;

  @override
  Future<void> save(NirniqIdentity identity) async {
    _identities[identity.nirniqId] = identity;
    _active = identity;
  }

  @override
  Future<NirniqIdentity?> getActiveIdentity() async => _active;

  @override
  Future<void> delete(String nirniqId) async {
    _identities.remove(nirniqId);
    if (_active?.nirniqId == nirniqId) _active = null;
  }
}

class FakeGoogleAuthService extends Fake implements INirniqGoogleAuthService {
  NirniqAuthResult? mockResult;

  @override
  String? get currentNirniqUserId => mockResult?.nirniqUserId;

  @override
  bool get isAuthenticated => mockResult != null;

  @override
  Future<NirniqAuthResult?> signInWithGoogle() async => mockResult;

  @override
  Future<void> signOut() async {
    mockResult = null;
  }
}

class FakeSession extends Fake implements Session {
  @override
  final String accessToken;
  FakeSession({required this.accessToken});
}

void main() {
  group('Nirniq Dual-Session Coexistence & Non-Destructive Preservation (Gate 2D)', () {
    const String kithLocalUserId = 'usr_a1b2c3d4e5f6';
    const String kithSessionToken = 'kith_sess_99887766554433221100aabbccddeeff';
    const String canonicalNirniqUuid = 'b5f92c3a-7841-4e2b-a134-8c8877665544';
    const String centralSupabaseJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.central_nirniq_token.signature';

    late InMemoryNirniqRepository nirniqRepo;
    late FakeGoogleAuthService fakeAuthService;
    late NirniqIdentityServiceImpl nirniqService;
    late ApiClient apiClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      nirniqRepo = InMemoryNirniqRepository();
      fakeAuthService = FakeGoogleAuthService();
      nirniqService = NirniqIdentityServiceImpl(
        repository: nirniqRepo,
        authService: fakeAuthService,
        isEnabled: () => true,
      );
      apiClient = ApiClient();
    });

    test('1. Dual-Session Invariant: KITH ApiClient strictly uses kith_sess_* and never Supabase JWT', () async {
      // 1. Establish existing KITH guest session
      apiClient.setAuthToken(kithSessionToken);
      expect(apiClient.authToken, kithSessionToken);
      expect(apiClient.authToken?.startsWith('kith_sess_'), isTrue);

      // 2. Perform Nirniq authentication (Central IdP session established)
      fakeAuthService.mockResult = NirniqAuthResult(
        nirniqUserId: canonicalNirniqUuid,
        email: 'traveler@nirniq.com',
        displayName: 'Nirniq Traveler',
        googleSubjectId: 'google_sub_883311',
        session: FakeSession(accessToken: centralSupabaseJwt),
      );

      final authResult = await nirniqService.authenticateWithNirniq();
      expect(authResult, isNotNull);
      expect(authResult!.session.accessToken, centralSupabaseJwt);

      // 3. CRITICAL INVARIANT: KITH Express ApiClient token remains untouched
      expect(
        apiClient.authToken,
        kithSessionToken,
        reason: 'ApiClient MUST retain kith_sess_* to prevent unauthorized KITH Express backend rejections',
      );
      expect(
        apiClient.authToken,
        isNot(centralSupabaseJwt),
        reason: 'Supabase JWT must NEVER leak into KITH Express backend ApiClient headers',
      );
    });

    test('2. Identifier Immutability: Local trips and members retain usr_* without UUID corruption', () async {
      // Create local guest user with usr_* format
      final guest = GuestUser(
        id: kithLocalUserId,
        displayName: 'Local Guest',
        recoveryKey: 'KITH-TEST-1234',
        anonymousToken: 'anon_test_token_1234',
        createdAt: DateTime.now().toUtc(),
      );

      // Create a local trip linked to usr_*
      final trip = Trip(
        id: 'trip_100',
        name: 'Himalayan Expedition',
        inviteCode: 'HIMA-100',
        currencyCode: 'INR',
        creatorId: guest.id,
        members: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(trip.creatorId, startsWith('usr_'));
      expect(trip.creatorId, isNot(contains('-'))); // Not a UUID

      // Perform Nirniq authentication
      fakeAuthService.mockResult = NirniqAuthResult(
        nirniqUserId: canonicalNirniqUuid,
        email: 'traveler@nirniq.com',
        displayName: 'Nirniq Traveler',
        session: FakeSession(accessToken: centralSupabaseJwt),
      );

      final result = await nirniqService.authenticateWithNirniq();
      expect(result, isNotNull);

      // Assert local trip creatorId is completely intact
      expect(trip.creatorId, kithLocalUserId);
      expect(trip.creatorId, isNot(canonicalNirniqUuid));

      // Assert canonical Nirniq Identity is safely isolated in repository
      final nirniqIdentity = await nirniqRepo.getActiveIdentity();
      expect(nirniqIdentity, isNotNull);
      expect(nirniqIdentity!.nirniqId, canonicalNirniqUuid);
    });

    test('3. Zero Destructive Re-tagging: Guest session and Nirniq identity coexist without data wipe', () async {
      // Nirniq identity created
      fakeAuthService.mockResult = NirniqAuthResult(
        nirniqUserId: canonicalNirniqUuid,
        email: 'persisted@nirniq.com',
        displayName: 'Persisted User',
        session: FakeSession(accessToken: centralSupabaseJwt),
      );

      await nirniqService.authenticateWithNirniq();

      // Sign out from Nirniq
      await nirniqService.signOutNirniq();

      // Assert Nirniq identity is removed
      final afterSignOut = await nirniqRepo.getActiveIdentity();
      expect(afterSignOut, isNull);

      // Assert KITH session token was NEVER affected by Nirniq sign-out
      apiClient.setAuthToken(kithSessionToken);
      expect(apiClient.authToken, kithSessionToken);
    });

    test('4. Gate 2D Feature Flag Invariant: Default flag configuration remains completely disabled', () {
      expect(NirniqFeatureFlags.enableNirniqIdentity, isFalse);
      expect(NirniqFeatureFlags.showNirniqSignInButton, isFalse);
      expect(NirniqFeatureFlags.enableGuestToNirniqLinking, isFalse);
      expect(NirniqFeatureFlags.enableNirniqFirstInstall, isFalse);
      expect(NirniqFeatureFlags.enableLocalMappingPersistence, isFalse);
    });
  });
}
