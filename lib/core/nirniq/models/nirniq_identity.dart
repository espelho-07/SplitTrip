import 'package:flutter/foundation.dart';
import 'nirniq_migration_state.dart';

/// Represents a canonical Nirniq identity.
///
/// This is an ISOLATED model — it has no dependency on Supabase Auth,
/// Google Auth, or any external SDK. It is a pure value object.
///
/// [PHASE 1 — SCAFFOLD ONLY]
/// The [AppConfig.enableNirniqIdentity] flag must be false.
/// This model is not used in any active authentication path.
@immutable
class NirniqIdentity {
  /// Canonical Nirniq identity UUID.
  final String nirniqId;

  /// Linked Google identity subject ID (nullable, may not be linked yet).
  final String? googleSubject;

  /// Verified email address (nullable).
  final String? email;

  /// Display name of the user (nullable).
  final String? displayName;

  /// Timestamp when this Nirniq identity was created.
  final DateTime createdAt;

  /// Current migration state of this identity.
  final NirniqMigrationState migrationState;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// The standard RFC 4122 Nil UUID (all zeros).
  /// Disallowed as a valid canonical Nirniq ID.
  static const String _nilUuid = '00000000-0000-0000-0000-000000000000';

  NirniqIdentity({
    required this.nirniqId,
    this.googleSubject,
    this.email,
    this.displayName,
    required this.createdAt,
    this.migrationState = NirniqMigrationState.mappingCreated,
  }) {
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
  NirniqIdentity copyWith({
    String? nirniqId,
    String? googleSubject,
    String? email,
    String? displayName,
    DateTime? createdAt,
    NirniqMigrationState? migrationState,
  }) {
    return NirniqIdentity(
      nirniqId: nirniqId ?? this.nirniqId,
      googleSubject: googleSubject ?? this.googleSubject,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      migrationState: migrationState ?? this.migrationState,
    );
  }

  /// Serializes this [NirniqIdentity] to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'nirniqId': nirniqId,
        'googleSubject': googleSubject,
        'email': email,
        'displayName': displayName,
        'createdAt': createdAt.toIso8601String(),
        'migrationState': migrationState.name,
      };

  /// Deserializes a [NirniqIdentity] from a JSON map.
  factory NirniqIdentity.fromJson(Map<String, dynamic> json) {
    final rawNirniqId = json['nirniqId'] ?? json['nirniq_id'];
    if (rawNirniqId == null || rawNirniqId is! String) {
      throw ArgumentError.value(
        rawNirniqId,
        'nirniqId',
        'Missing or invalid nirniqId in JSON',
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

    final rawMigrationState = json['migrationState'] ?? json['migration_state'];

    return NirniqIdentity(
      nirniqId: rawNirniqId,
      googleSubject: (json['googleSubject'] ?? json['google_subject']) as String?,
      email: json['email'] as String?,
      displayName: (json['displayName'] ?? json['display_name']) as String?,
      createdAt: DateTime.parse(rawCreatedAt),
      migrationState: NirniqMigrationState.fromString(
        rawMigrationState as String?,
        fallback: NirniqMigrationState.mappingCreated,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NirniqIdentity &&
          runtimeType == other.runtimeType &&
          nirniqId == other.nirniqId &&
          googleSubject == other.googleSubject &&
          email == other.email &&
          displayName == other.displayName &&
          createdAt == other.createdAt &&
          migrationState == other.migrationState;

  @override
  int get hashCode => Object.hash(
        nirniqId,
        googleSubject,
        email,
        displayName,
        createdAt,
        migrationState,
      );

  @override
  String toString() =>
      'NirniqIdentity(nirniqId: $nirniqId, googleSubject: $googleSubject, email: $email, displayName: $displayName, createdAt: $createdAt, migrationState: $migrationState)';
}
