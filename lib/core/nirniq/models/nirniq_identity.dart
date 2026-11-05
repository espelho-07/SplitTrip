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

  const NirniqIdentity({
    required this.nirniqId,
    this.googleSubject,
    this.email,
    this.displayName,
    required this.createdAt,
    this.migrationState = NirniqMigrationState.mappingCreated,
  });

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
    return NirniqIdentity(
      nirniqId: json['nirniqId'] as String,
      googleSubject: json['googleSubject'] as String?,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      migrationState: json['migrationState'] != null
          ? NirniqMigrationState.values.firstWhere(
              (e) => e.name == json['migrationState'],
              orElse: () => NirniqMigrationState.mappingCreated,
            )
          : NirniqMigrationState.mappingCreated,
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
