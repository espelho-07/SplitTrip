import '../models/nirniq_identity.dart';
import '../models/nirniq_migration_state.dart';

/// Abstract service interface for high-level Nirniq identity operations.
///
/// [PHASE 1 — INTERFACE ONLY]
/// No connection to external services, no OAuth, no Supabase Auth.
abstract interface class INirniqIdentityService {
  /// Whether the Nirniq identity feature is enabled.
  /// Always false in Phase 1.
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
}
