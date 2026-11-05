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

  /// The standard RFC 4122 Nil UUID (all zeros).
  /// Disallowed as a valid canonical Nirniq ID.
  static const String _nilUuid = '00000000-0000-0000-0000-000000000000';

  NirniqLegacyMapping({
    required this.nirniqId,
    required this.kithLocalUserId,
    required this.kithEffectiveAccountId,
    this.supabaseAuthUid,
    this.migrationState = NirniqMigrationState.mappingCreated,
    required this.createdAt,
    this.linkedAt,
  }) {
    if (!kithLocalUserId.startsWith('usr_')) {
      throw ArgumentError.value(
        kithLocalUserId,
        'kithLocalUserId',
        'Must start with "usr_" prefix (KITH local identity format)',
      );
    }
    if (kithLocalUserId.length <= 4) {
      throw ArgumentError.value(
        kithLocalUserId,
        'kithLocalUserId',
        'Must have content after "usr_" prefix',
      );
    }
    if (!_uuidRegex.hasMatch(nirniqId)) {
      throw ArgumentError.value(
        nirniqId,
        'nirniqId',
        'Must be a valid UUID (8-4-4-4-12 format)',
      );
    }
    if (nirniqId == _nilUuid) {
      throw ArgumentError.value(
        nirniqId,
        'nirniqId',
        'Nil UUID (all zeros) is not allowed as a canonical Nirniq ID',
      );
    }
  }

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
    final rawNirniqId = json['nirniqId'] ?? json['nirniq_id'];
    if (rawNirniqId == null || rawNirniqId is! String) {
      throw ArgumentError.value(
        rawNirniqId,
        'nirniqId',
        'Missing or invalid nirniqId in JSON',
      );
    }

    final rawKithLocalUserId =
        json['kithLocalUserId'] ?? json['kith_local_user_id'];
    if (rawKithLocalUserId == null || rawKithLocalUserId is! String) {
      throw ArgumentError.value(
        rawKithLocalUserId,
        'kithLocalUserId',
        'Missing or invalid kithLocalUserId in JSON',
      );
    }

    final rawCreatedAt = json['createdAt'] ?? json['created_at'];
    if (rawCreatedAt == null || rawCreatedAt is! String) {
      throw ArgumentError.value(
        rawCreatedAt,
        'createdAt',
        'Missing or invalid createdAt in JSON',
      );
    }

    final rawLinkedAt = json['linkedAt'] ?? json['linked_at'];
    final rawMigrationState =
        json['migrationState'] ?? json['migration_state'];

    return NirniqLegacyMapping(
      nirniqId: rawNirniqId,
      kithLocalUserId: rawKithLocalUserId,
      kithEffectiveAccountId: (json['kithEffectiveAccountId'] ??
          json['kith_effective_account_id'] ??
          rawKithLocalUserId) as String,
      supabaseAuthUid:
          (json['supabaseAuthUid'] ?? json['supabase_auth_uid']) as String?,
      migrationState: NirniqMigrationState.fromString(
        rawMigrationState as String?,
        fallback: NirniqMigrationState.mappingCreated,
      ),
      createdAt: DateTime.parse(rawCreatedAt),
      linkedAt: rawLinkedAt != null
          ? DateTime.parse(rawLinkedAt as String)
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
