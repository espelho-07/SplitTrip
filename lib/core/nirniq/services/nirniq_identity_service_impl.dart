import '../config/nirniq_feature_flags.dart';
import '../models/nirniq_identity.dart';
import '../models/nirniq_migration_state.dart';
import '../repositories/i_nirniq_identity_repository.dart';
import '../repositories/nirniq_identity_repository_impl.dart';
import 'i_nirniq_identity_service.dart';
import 'nirniq_google_auth_service.dart';

/// Concrete implementation of [INirniqIdentityService] coordinating Nirniq
/// central identity operations with local storage and authentication services.
///
/// Invariants:
/// - Strictly respects [NirniqFeatureFlags.enableNirniqIdentity].
/// - Preserves Dual-Session boundary: never touches KITH local session tokens
///   (`kith_sess_*`) or local guest identifiers (`usr_*`).
/// - Never performs destructive re-tagging or data migration.
/// - Allows dependency injection for hermetic unit and integration testing.
class NirniqIdentityServiceImpl implements INirniqIdentityService {
  final INirniqIdentityRepository _repository;
  final INirniqGoogleAuthService _authService;
  final bool Function() _isEnabledGetter;

  NirniqIdentityServiceImpl({
    INirniqIdentityRepository? repository,
    INirniqGoogleAuthService? authService,
    bool Function()? isEnabled,
  })  : _repository = repository ?? NirniqIdentityRepositoryImpl(),
        _authService = authService ?? NirniqGoogleAuthService(),
        _isEnabledGetter = isEnabled ?? (() => NirniqFeatureFlags.enableNirniqIdentity);

  @override
  bool get isEnabled => _isEnabledGetter();

  @override
  Future<NirniqMigrationState> getCurrentMigrationState(String kithLocalUserId) async {
    if (!isEnabled) {
      return NirniqMigrationState.legacyOnly;
    }

    try {
      final active = await _repository.getActiveIdentity();
      if (active != null) {
        return active.migrationState;
      }

      final activeUserId = _authService.currentNirniqUserId;
      if (activeUserId != null) {
        final identity = await _repository.findById(activeUserId);
        if (identity != null) {
          return identity.migrationState;
        }
      }
    } catch (_) {
      // Invariant: any failure degrades gracefully to legacyOnly
      return NirniqMigrationState.legacyOnly;
    }

    return NirniqMigrationState.legacyOnly;
  }

  @override
  Future<NirniqIdentity?> getCurrentNirniqIdentity(String kithLocalUserId) async {
    if (!isEnabled) {
      return null;
    }

    try {
      final active = await _repository.getActiveIdentity();
      if (active != null) {
        return active;
      }

      final activeUserId = _authService.currentNirniqUserId;
      if (activeUserId != null) {
        return await _repository.findById(activeUserId);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  @override
  Future<bool> canLinkToNirniq(String kithLocalUserId) async {
    if (!isEnabled) {
      return false;
    }

    // Gate 2D scope guard: Guest-to-Nirniq linking is deferred to Gate 2E.
    if (!NirniqFeatureFlags.enableGuestToNirniqLinking) {
      return false;
    }

    return kithLocalUserId.startsWith('usr_');
  }

  @override
  Future<NirniqAuthResult?> authenticateWithNirniq() async {
    if (!isEnabled) {
      throw const NirniqAuthException(
        code: NirniqAuthErrorCode.unconfigured,
        message: 'Nirniq identity feature is not enabled by configuration or feature flag.',
      );
    }

    // Step 1: Execute native Google sign-in and Supabase GoTrue token exchange
    final result = await _authService.signInWithGoogle();

    // User cancelled the Google account picker
    if (result == null) {
      return null;
    }

    // Step 2: Retrieve or instantiate canonical NirniqIdentity
    try {
      final existing = await _repository.findById(result.nirniqUserId);
      final canonicalIdentity = existing?.copyWith(
            googleSubject: result.googleSubjectId ?? existing.googleSubject,
            email: result.email,
            displayName: result.displayName,
          ) ??
          NirniqIdentity(
            nirniqId: result.nirniqUserId,
            googleSubject: result.googleSubjectId,
            email: result.email,
            displayName: result.displayName,
            createdAt: DateTime.now().toUtc(),
            migrationState: NirniqMigrationState.mappingCreated,
          );

      // Step 3: Persist active identity in encrypted Keystore storage
      await _repository.save(canonicalIdentity);
    } catch (e) {
      // Invariant: logging and non-fatal persistence fallback
    }

    return result;
  }

  @override
  Future<void> signOutNirniq() async {
    try {
      final active = await _repository.getActiveIdentity();
      if (active != null) {
        await _repository.delete(active.nirniqId);
      }
    } catch (_) {
      // Non-fatal cleanup
    }

    await _authService.signOut();
  }
}
