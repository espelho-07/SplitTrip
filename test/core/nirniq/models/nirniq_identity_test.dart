import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/nirniq/models/nirniq_identity.dart';
import 'package:kith_app/core/nirniq/models/nirniq_migration_state.dart';

void main() {
  group('NirniqIdentity', () {
    final fixedCreatedAt = DateTime.utc(2026, 11, 5, 10, 0, 0);
    const validUuid = '123e4567-e89b-12d3-a456-426614174000';

    test('constructor creates valid identity with expected fields', () {
      final identity = NirniqIdentity(
        nirniqId: validUuid,
        googleSubject: 'google-sub-998877',
        email: 'test@nirniq.com',
        displayName: 'Nirniq Traveler',
        createdAt: fixedCreatedAt,
        migrationState: NirniqMigrationState.googleLinked,
      );

      expect(identity.nirniqId, validUuid);
      expect(identity.googleSubject, 'google-sub-998877');
      expect(identity.email, 'test@nirniq.com');
      expect(identity.displayName, 'Nirniq Traveler');
      expect(identity.createdAt, fixedCreatedAt);
      expect(identity.migrationState, NirniqMigrationState.googleLinked);
    });

    test('migrationState defaults correctly to mappingCreated', () {
      final identity = NirniqIdentity(
        nirniqId: validUuid,
        createdAt: fixedCreatedAt,
      );

      expect(identity.migrationState, NirniqMigrationState.mappingCreated);
      expect(identity.googleSubject, isNull);
      expect(identity.email, isNull);
      expect(identity.displayName, isNull);
    });

    test('fromJson and toJson round-trip preserves all fields', () {
      final original = NirniqIdentity(
        nirniqId: validUuid,
        googleSubject: 'google-sub-12345',
        email: 'traveler@example.com',
        displayName: 'Atlas Voyager',
        createdAt: fixedCreatedAt,
        migrationState: NirniqMigrationState.fullyMigrated,
      );

      final json = original.toJson();
      final reconstructed = NirniqIdentity.fromJson(json);

      expect(reconstructed, equals(original));
      expect(reconstructed.nirniqId, original.nirniqId);
      expect(reconstructed.googleSubject, original.googleSubject);
      expect(reconstructed.email, original.email);
      expect(reconstructed.displayName, original.displayName);
      expect(reconstructed.createdAt, original.createdAt);
      expect(reconstructed.migrationState, original.migrationState);
    });

    test('fromJson defaults migrationState to mappingCreated if omitted', () {
      final json = {
        'nirniqId': validUuid,
        'createdAt': fixedCreatedAt.toIso8601String(),
      };

      final parsed = NirniqIdentity.fromJson(json);
      expect(parsed.migrationState, NirniqMigrationState.mappingCreated);
    });

    test('copyWith creates new instance with changed fields without mutating original', () {
      final original = NirniqIdentity(
        nirniqId: validUuid,
        displayName: 'Original Name',
        createdAt: fixedCreatedAt,
        migrationState: NirniqMigrationState.mappingCreated,
      );

      final updated = original.copyWith(
        displayName: 'Updated Name',
        email: 'updated@example.com',
        migrationState: NirniqMigrationState.googleLinked,
      );

      expect(original.displayName, 'Original Name');
      expect(original.email, isNull);
      expect(original.migrationState, NirniqMigrationState.mappingCreated);

      expect(updated.nirniqId, original.nirniqId);
      expect(updated.displayName, 'Updated Name');
      expect(updated.email, 'updated@example.com');
      expect(updated.migrationState, NirniqMigrationState.googleLinked);
      expect(updated.createdAt, original.createdAt);
    });

    test('== and hashCode work correctly for equality comparison', () {
      final instance1 = NirniqIdentity(
        nirniqId: validUuid,
        googleSubject: 'sub-1',
        email: 'a@b.com',
        displayName: 'User',
        createdAt: fixedCreatedAt,
        migrationState: NirniqMigrationState.mappingCreated,
      );

      final instance2 = NirniqIdentity(
        nirniqId: validUuid,
        googleSubject: 'sub-1',
        email: 'a@b.com',
        displayName: 'User',
        createdAt: fixedCreatedAt,
        migrationState: NirniqMigrationState.mappingCreated,
      );

      final different = instance1.copyWith(displayName: 'Different User');

      expect(instance1, equals(instance2));
      expect(instance1.hashCode, equals(instance2.hashCode));
      expect(instance1, isNot(equals(different)));
      expect(instance1.hashCode, isNot(equals(different.hashCode)));
    });

    test('toString contains class name and key identity attributes', () {
      final identity = NirniqIdentity(
        nirniqId: validUuid,
        displayName: 'Atlas',
        createdAt: fixedCreatedAt,
      );

      final str = identity.toString();
      expect(str, contains('NirniqIdentity'));
      expect(str, contains(validUuid));
      expect(str, contains('Atlas'));
    });
  });
}
