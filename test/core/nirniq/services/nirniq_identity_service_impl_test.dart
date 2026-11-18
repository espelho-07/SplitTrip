import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kith_app/core/nirniq/models/nirniq_identity.dart';
import 'package:kith_app/core/nirniq/models/nirniq_migration_state.dart';
import 'package:kith_app/core/nirniq/repositories/i_nirniq_identity_repository.dart';
import 'package:kith_app/core/nirniq/services/nirniq_google_auth_service.dart';
import 'package:kith_app/core/nirniq/services/nirniq_identity_service_impl.dart';

// --- Lightweight In-Memory Test Fakes ---

class FakeNirniqIdentityRepository implements INirniqIdentityRepository {
  final Map<String, NirniqIdentity> _identities = {};
  NirniqIdentity? activeIdentity;
  bool throwOnSave = false;

  @override
  Future<NirniqIdentity?> findById(String nirniqId) async {
    return _identities[nirniqId] ?? (activeIdentity?.nirniqId == nirniqId ? activeIdentity : null);
  }

  @override
  Future<NirniqIdentity?> findByGoogleSubject(String googleSubject) async {
    return _identities.values.firstWhere(
      (id) => id.googleSubject == googleSubject,
      orElse: () => activeIdentity?.googleSubject == googleSubject ? activeIdentity! : throw 'not_found',
    );
  }

  @override
  Future<bool> existsForGoogleSubject(String googleSubject) async {
    return _identities.values.any((id) => id.googleSubject == googleSubject) ||
        activeIdentity?.googleSubject == googleSubject;
  }

  @override
  Future<void> save(NirniqIdentity identity) async {
    if (throwOnSave) throw Exception('Storage write failure');
    _identities[identity.nirniqId] = identity;
    activeIdentity = identity;
  }

  @override
  Future<NirniqIdentity?> getActiveIdentity() async {
    return activeIdentity;
  }

  @override
  Future<void> delete(String nirniqId) async {
    _identities.remove(nirniqId);
    if (activeIdentity?.nirniqId == nirniqId) {
      activeIdentity = null;
    }
  }
}

class FakeNirniqGoogleAuthService extends Fake implements INirniqGoogleAuthService {
  NirniqAuthResult? resultToReturn;
  Exception? errorToThrow;
  String? mockCurrentNirniqUserId;
  bool wasSignedOut = false;

  @override
  String? get currentNirniqUserId => mockCurrentNirniqUserId;

  @override
  bool get isAuthenticated => mockCurrentNirniqUserId != null;

  @override
  Future<NirniqAuthResult?> signInWithGoogle() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return resultToReturn;
  }

  @override
  Future<void> signOut() async {
    wasSignedOut = true;
    mockCurrentNirniqUserId = null;
  }
}

class FakeSession extends Fake implements Session {
  @override
  final String accessToken;
  FakeSession({this.accessToken = 'jwt_test'});
}

void main() {
  group('NirniqIdentityServiceImpl Unit Suite', () {
    late FakeNirniqIdentityRepository fakeRepo;
    late FakeNirniqGoogleAuthService fakeAuth;
    const String canonicalUuid = 'e4b2d3c1-1234-4567-89ab-cdef01234567';

    setUp(() {
      fakeRepo = FakeNirniqIdentityRepository();
      fakeAuth = FakeNirniqGoogleAuthService();
    });

    test('1. isEnabled defaults to false (strictly honoring NirniqFeatureFlags in Gate 2D)', () {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
      );

      expect(service.isEnabled, isFalse);
    });

    test('2. isEnabled reflects injected getter override for testing', () {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
        isEnabled: () => true,
      );

      expect(service.isEnabled, isTrue);
    });

    test('3. getCurrentMigrationState returns legacyOnly when feature is disabled', () async {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
        isEnabled: () => false,
      );

      final state = await service.getCurrentMigrationState('usr_123456789abc');
      expect(state, NirniqMigrationState.legacyOnly);
    });

    test('4. getCurrentMigrationState returns stored identity state when enabled', () async {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
        isEnabled: () => true,
      );

      fakeRepo.activeIdentity = NirniqIdentity(
        nirniqId: canonicalUuid,
        createdAt: DateTime.utc(2026, 11, 5),
        migrationState: NirniqMigrationState.mappingCreated,
      );

      final state = await service.getCurrentMigrationState('usr_123456789abc');
      expect(state, NirniqMigrationState.mappingCreated);
    });

    test('5. getCurrentNirniqIdentity returns null when disabled', () async {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
        isEnabled: () => false,
      );

      fakeRepo.activeIdentity = NirniqIdentity(
        nirniqId: canonicalUuid,
        createdAt: DateTime.utc(2026, 11, 5),
      );

      final identity = await service.getCurrentNirniqIdentity('usr_123456789abc');
      expect(identity, isNull);
    });

    test('6. getCurrentNirniqIdentity returns active identity when enabled', () async {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
        isEnabled: () => true,
      );

      final existing = NirniqIdentity(
        nirniqId: canonicalUuid,
        email: 'nirniq.user@gmail.com',
        displayName: 'Nirniq User',
        createdAt: DateTime.utc(2026, 11, 5),
      );
      fakeRepo.activeIdentity = existing;

      final identity = await service.getCurrentNirniqIdentity('usr_123456789abc');
      expect(identity, isNotNull);
      expect(identity!.nirniqId, canonicalUuid);
      expect(identity.email, 'nirniq.user@gmail.com');
    });

    test('7. canLinkToNirniq is false in Gate 2D (linking deferred to Gate 2E)', () async {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
        isEnabled: () => true,
      );

      // Gate 2D scope constraint: enableGuestToNirniqLinking is false
      final canLink = await service.canLinkToNirniq('usr_123456789abc');
      expect(canLink, isFalse);
    });

    test('8. authenticateWithNirniq throws NirniqAuthException when disabled', () async {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
        isEnabled: () => false,
      );

      expect(
        () => service.authenticateWithNirniq(),
        throwsA(isA<NirniqAuthException>().having(
          (e) => e.code,
          'code',
          NirniqAuthErrorCode.unconfigured,
        )),
      );
    });

    test('9. authenticateWithNirniq returns null when user cancels sign-in', () async {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
        isEnabled: () => true,
      );

      fakeAuth.resultToReturn = null; // User cancelled account picker

      final result = await service.authenticateWithNirniq();
      expect(result, isNull);
      expect(fakeRepo.activeIdentity, isNull);
    });

    test('10. authenticateWithNirniq persists NirniqIdentity on success', () async {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
        isEnabled: () => true,
      );

      fakeAuth.resultToReturn = NirniqAuthResult(
        nirniqUserId: canonicalUuid,
        email: 'authenticated@gmail.com',
        displayName: 'Auth User',
        googleSubjectId: 'sub_123456',
        session: FakeSession(),
      );

      final result = await service.authenticateWithNirniq();
      expect(result, isNotNull);
      expect(result!.nirniqUserId, canonicalUuid);

      // Assert repository was updated
      expect(fakeRepo.activeIdentity, isNotNull);
      expect(fakeRepo.activeIdentity!.nirniqId, canonicalUuid);
      expect(fakeRepo.activeIdentity!.email, 'authenticated@gmail.com');
      expect(fakeRepo.activeIdentity!.googleSubject, 'sub_123456');
    });

    test('11. signOutNirniq cleans up active identity and calls auth sign out', () async {
      final service = NirniqIdentityServiceImpl(
        repository: fakeRepo,
        authService: fakeAuth,
        isEnabled: () => true,
      );

      fakeRepo.activeIdentity = NirniqIdentity(
        nirniqId: canonicalUuid,
        createdAt: DateTime.utc(2026, 11, 5),
      );

      await service.signOutNirniq();

      expect(fakeRepo.activeIdentity, isNull);
      expect(fakeAuth.wasSignedOut, isTrue);
    });
  });
}
