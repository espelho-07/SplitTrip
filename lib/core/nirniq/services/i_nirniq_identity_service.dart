import '../models/nirniq_identity.dart';
import '../models/nirniq_migration_state.dart';
import 'nirniq_google_auth_service.dart';

/// Abstract service interface for high-level Nirniq identity operations.
abstract interface class INirniqIdentityService {
  /// Whether the Nirniq identity feature is enabled.
  bool get isEnabled;

  /// The current migration state for the active KITH user.
  /// Returns [NirniqMigrationState.legacyOnly] when disabled.
  Future<NirniqMigrationState> getCurrentMigrationState(String kithLocalUserId);

  /// Retrieve the current user's Nirniq identity if one exists.
  /// Returns null if the user has no Nirniq identity yet.
  Future<NirniqIdentity?> getCurrentNirniqIdentity(String kithLocalUserId);

  /// Whether a Nirniq identity can be created for this KITH user.
  /// Returns false when [isEnabled] is false.
  Future<bool> canLinkToNirniq(String kithLocalUserId);

  /// Triggers native Nirniq authentication (via Google Sign-In and Central Supabase IdP).
  ///
  /// Returns [NirniqAuthResult] on success, or null if the user cancelled the flow.
  Future<NirniqAuthResult?> authenticateWithNirniq();

  /// Signs out from the active Nirniq session.
  Future<void> signOutNirniq();
}
