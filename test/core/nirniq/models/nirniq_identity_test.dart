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

    group('UUID validation (W1 & Release-mode safe)', () {
      test('rejects empty string nirniqId', () {
        expect(
          () => NirniqIdentity(
            nirniqId: '',
            createdAt: fixedCreatedAt,
          ),
          throwsArgumentError,
        );
      });

      test('rejects non-UUID string', () {
        expect(
          () => NirniqIdentity(
            nirniqId: 'not-a-uuid',
            createdAt: fixedCreatedAt,
          ),
          throwsArgumentError,
        );
      });

      test('rejects all-zeros UUID (nil UUID is disallowed for identity)', () {
        // Decision: Nil UUID (00000000-0000-0000-0000-000000000000) represents an uninitialized
        // identifier and MUST NOT be accepted as a canonical Nirniq Identity ID.
        expect(
          () => NirniqIdentity(
            nirniqId: '00000000-0000-0000-0000-000000000000',
            createdAt: fixedCreatedAt,
          ),
          throwsArgumentError,
        );
      });

      test('accepts valid lowercase UUID', () {
        expect(
          () => NirniqIdentity(
            nirniqId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
            createdAt: fixedCreatedAt,
          ),
          returnsNormally,
        );
      });

      test('accepts valid uppercase UUID', () {
        expect(
          () => NirniqIdentity(
            nirniqId: 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890',
            createdAt: fixedCreatedAt,
          ),
          returnsNormally,
        );
      });

      test('fromJson with invalid nirniqId throws ArgumentError', () {
        expect(
          () => NirniqIdentity.fromJson({
            'nirniq_id': 'bad-id',
            'created_at': fixedCreatedAt.toIso8601String(),
          }),
          throwsArgumentError,
        );
      });

      test('fromJson with missing/null nirniqId throws ArgumentError', () {
        expect(
          () => NirniqIdentity.fromJson({
            'created_at': fixedCreatedAt.toIso8601String(),
          }),
          throwsArgumentError,
        );
      });

      test('fromJson supports snake_case and defaults unknown migrationState safely', () {
        final parsed = NirniqIdentity.fromJson({
          'nirniq_id': validUuid,
          'google_subject': 'g-sub',
          'email': 'user@example.com',
          'display_name': 'Traveler',
          'created_at': fixedCreatedAt.toIso8601String(),
          'migration_state': 'non_existent_state_name',
        });

        expect(parsed.nirniqId, validUuid);
        expect(parsed.googleSubject, 'g-sub');
        expect(parsed.migrationState, NirniqMigrationState.mappingCreated);
      });
    });
  });
}
