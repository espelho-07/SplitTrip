import '../models/nirniq_legacy_mapping.dart';
import '../models/nirniq_migration_state.dart';

/// Abstract repository interface for the legacy-to-Nirniq mapping layer.
///
/// [PHASE 1 — INTERFACE ONLY]
/// Implements the Approach A (Preserve & Overlay) design.
/// Does NOT modify usr_*, kith_sess_*, or Recovery Keys.
abstract interface class INirniqMappingRepository {
  /// Find the mapping for the given KITH local user ID (usr_*).
  /// Returns null if no mapping exists yet (user is in legacyOnly state).
  Future<NirniqLegacyMapping?> findByKithLocalUserId(String kithLocalUserId);

  /// Find the mapping for the given KITH effective account ID.
  Future<NirniqLegacyMapping?> findByKithEffectiveAccountId(
      String kithEffectiveAccountId);

  /// Find the mapping for the given Nirniq ID.
  Future<NirniqLegacyMapping?> findByNirniqId(String nirniqId);

  /// Store a new mapping row.
  /// Throws [MappingCollisionException] if a conflicting mapping exists.
  Future<NirniqLegacyMapping> createMapping(NirniqLegacyMapping mapping);

  /// Update the migration state of an existing mapping.
  Future<NirniqLegacyMapping> updateMigrationState(
    String nirniqId,
    NirniqMigrationState newState,
  );
}

/// Thrown when a mapping creation would violate uniqueness constraints.
class MappingCollisionException implements Exception {
  final String message;
  final String? existingNirniqId;
  const MappingCollisionException(this.message, {this.existingNirniqId});

  @override
  String toString() => 'MappingCollisionException: $message';
}
