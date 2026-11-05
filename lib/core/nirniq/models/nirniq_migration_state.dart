/// Represents the migration state of a KITH user account
/// as it transitions toward Nirniq canonical identity.
///
/// States are additive — a user advances forward but never loses
/// data or access when moving between states.
enum NirniqMigrationState {
  /// User has KITH local identity only (usr_* + kith_sess_*).
  /// No Nirniq identity exists yet.
  legacyOnly,

  /// A nirniq_legacy_mappings row exists. nirniq_id is assigned.
  /// No Supabase Auth linkage yet. kith_sess_* still active.
  mappingCreated,

  /// Nirniq account has Google identity linked.
  /// kith_sess_* still used for KITH cloud auth.
  googleLinked,

  /// All auth through Nirniq. kith_sess_* deprecated for this user.
  /// auth.uid() is the trust anchor.
  fullyMigrated;

  /// Parses a [NirniqMigrationState] from a string name (e.g. 'mappingCreated').
  ///
  /// Returns [fallback] (defaults to [mappingCreated]) if [value] is null
  /// or does not match any valid enum state.
  static NirniqMigrationState fromString(
    String? value, {
    NirniqMigrationState fallback = NirniqMigrationState.mappingCreated,
  }) {
    if (value == null) return fallback;
    for (final state in NirniqMigrationState.values) {
      if (state.name == value) return state;
    }
    return fallback;
  }

  /// Parses a [NirniqMigrationState] from a string name, or returns null if not found.
  static NirniqMigrationState? tryParse(String? value) {
    if (value == null) return null;
    for (final state in NirniqMigrationState.values) {
      if (state.name == value) return state;
    }
    return null;
  }
}

/// Extension methods for [NirniqMigrationState].
extension NirniqMigrationStateX on NirniqMigrationState {
  /// Whether the user only has a legacy KITH local identity.
  bool get isLegacy => this == NirniqMigrationState.legacyOnly;

  /// Whether a canonical Nirniq ID has been assigned.
  bool get hasNirniqId => this != NirniqMigrationState.legacyOnly;

  /// Whether the identity is fully transitioned to Nirniq authentication.
  bool get isFullyMigrated => this == NirniqMigrationState.fullyMigrated;

  /// Whether this state can legally transition to [target].
  ///
  /// State progression is strictly monotonic (additive):
  /// legacyOnly -> mappingCreated -> googleLinked -> fullyMigrated.
  /// Backward transitions (e.g. fullyMigrated -> legacyOnly) are forbidden.
  /// Self-transitions (target == this) are permitted as idempotent operations.
  bool canTransitionTo(NirniqMigrationState target) {
    return target.index >= index;
  }

  /// Human-readable display name for the migration state.
  String get displayName {
    switch (this) {
      case NirniqMigrationState.legacyOnly:
        return 'Legacy Only';
      case NirniqMigrationState.mappingCreated:
        return 'Mapping Created';
      case NirniqMigrationState.googleLinked:
        return 'Google Linked';
      case NirniqMigrationState.fullyMigrated:
        return 'Fully Migrated';
    }
  }
}
