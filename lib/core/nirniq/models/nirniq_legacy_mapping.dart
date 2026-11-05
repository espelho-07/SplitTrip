import 'package:flutter/foundation.dart';
import 'nirniq_migration_state.dart';

/// A local mapping between KITH's existing identity system
/// and the new Nirniq canonical identity.
///
/// This is an APPROACH A (Preserve & Overlay) artifact.
/// It NEVER rewrites existing primary keys.
/// It NEVER modifies usr_* or kith_sess_* values.
/// It NEVER touches the Recovery Key.
///
/// [PHASE 1 — SCAFFOLD ONLY] Not persisted yet.
@immutable
class NirniqLegacyMapping {
  /// Canonical Nirniq identity UUID.
  final String nirniqId;

  /// The legacy KITH local user ID (`usr_*`).
  final String kithLocalUserId;

  /// The legacy KITH effective account ID.
  final String kithEffectiveAccountId;

  /// Linked Supabase Auth user UID (nullable, populated post-linkage).
  final String? supabaseAuthUid;

  /// Current migration state of this mapping.
  final NirniqMigrationState migrationState;

  /// Timestamp when this mapping was created.
  final DateTime createdAt;

  /// Timestamp when Google/Nirniq identity was linked (nullable).
  final DateTime? linkedAt;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  NirniqLegacyMapping({
    required this.nirniqId,
    required this.kithLocalUserId,
    required this.kithEffectiveAccountId,
    this.supabaseAuthUid,
    this.migrationState = NirniqMigrationState.mappingCreated,
    required this.createdAt,
    this.linkedAt,
  })  : assert(
          kithLocalUserId.startsWith('usr_'),
          'kithLocalUserId must start with usr_',
        ),
        assert(
          _uuidRegex.hasMatch(nirniqId),
          'nirniqId must be a valid UUID format',
        );

  /// Creates a copy with the given fields replaced by the new values.
  NirniqLegacyMapping copyWith({
    String? nirniqId,
    String? kithLocalUserId,
    String? kithEffectiveAccountId,
    String? supabaseAuthUid,
    NirniqMigrationState? migrationState,
    DateTime? createdAt,
    DateTime? linkedAt,
  }) {
    return NirniqLegacyMapping(
      nirniqId: nirniqId ?? this.nirniqId,
      kithLocalUserId: kithLocalUserId ?? this.kithLocalUserId,
      kithEffectiveAccountId:
          kithEffectiveAccountId ?? this.kithEffectiveAccountId,
      supabaseAuthUid: supabaseAuthUid ?? this.supabaseAuthUid,
      migrationState: migrationState ?? this.migrationState,
      createdAt: createdAt ?? this.createdAt,
      linkedAt: linkedAt ?? this.linkedAt,
    );
  }

  /// Serializes this [NirniqLegacyMapping] to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'nirniqId': nirniqId,
        'kithLocalUserId': kithLocalUserId,
        'kithEffectiveAccountId': kithEffectiveAccountId,
        'supabaseAuthUid': supabaseAuthUid,
        'migrationState': migrationState.name,
        'createdAt': createdAt.toIso8601String(),
        'linkedAt': linkedAt?.toIso8601String(),
      };

  /// Deserializes a [NirniqLegacyMapping] from a JSON map.
  factory NirniqLegacyMapping.fromJson(Map<String, dynamic> json) {
    return NirniqLegacyMapping(
      nirniqId: json['nirniqId'] as String,
      kithLocalUserId: json['kithLocalUserId'] as String,
      kithEffectiveAccountId: json['kithEffectiveAccountId'] as String,
      supabaseAuthUid: json['supabaseAuthUid'] as String?,
      migrationState: json['migrationState'] != null
          ? NirniqMigrationState.values.firstWhere(
              (e) => e.name == json['migrationState'],
              orElse: () => NirniqMigrationState.mappingCreated,
            )
          : NirniqMigrationState.mappingCreated,
      createdAt: DateTime.parse(json['createdAt'] as String),
      linkedAt: json['linkedAt'] != null
          ? DateTime.parse(json['linkedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NirniqLegacyMapping &&
          runtimeType == other.runtimeType &&
          nirniqId == other.nirniqId &&
          kithLocalUserId == other.kithLocalUserId &&
          kithEffectiveAccountId == other.kithEffectiveAccountId &&
          supabaseAuthUid == other.supabaseAuthUid &&
          migrationState == other.migrationState &&
          createdAt == other.createdAt &&
          linkedAt == other.linkedAt;

  @override
  int get hashCode => Object.hash(
        nirniqId,
        kithLocalUserId,
        kithEffectiveAccountId,
        supabaseAuthUid,
        migrationState,
        createdAt,
        linkedAt,
      );

  @override
  String toString() =>
      'NirniqLegacyMapping(nirniqId: $nirniqId, kithLocalUserId: $kithLocalUserId, kithEffectiveAccountId: $kithEffectiveAccountId, supabaseAuthUid: $supabaseAuthUid, migrationState: $migrationState, createdAt: $createdAt, linkedAt: $linkedAt)';
}
