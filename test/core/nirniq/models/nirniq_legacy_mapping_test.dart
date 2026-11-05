import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/nirniq/models/nirniq_legacy_mapping.dart';
import 'package:kith_app/core/nirniq/models/nirniq_migration_state.dart';

void main() {
  group('NirniqLegacyMapping', () {
    const validUuid = '123e4567-e89b-12d3-a456-426614174000';
    const validUserId = 'usr_abc123456789';
    const validAccountId = 'usr_abc123456789';
    final fixedCreatedAt = DateTime.utc(2026, 11, 5, 10, 0, 0);
    final fixedLinkedAt = DateTime.utc(2026, 11, 5, 10, 30, 0);

    test('valid usr_* prefix validation passes', () {
      expect(
        () => NirniqLegacyMapping(
          nirniqId: validUuid,
          kithLocalUserId: validUserId,
          kithEffectiveAccountId: validAccountId,
          createdAt: fixedCreatedAt,
        ),
        returnsNormally,
      );
    });

    test('invalid prefix (not usr_) throws ArgumentError', () {
      expect(
        () => NirniqLegacyMapping(
          nirniqId: validUuid,
          kithLocalUserId: 'invalid_user_id',
          kithEffectiveAccountId: validAccountId,
          createdAt: fixedCreatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('valid UUID passes nirniqId validation', () {
      expect(
        () => NirniqLegacyMapping(
          nirniqId: 'c56a4180-65aa-42ec-a945-5fd21dec0538',
          kithLocalUserId: validUserId,
          kithEffectiveAccountId: validAccountId,
          createdAt: fixedCreatedAt,
        ),
        returnsNormally,
      );
    });

    test('invalid UUID format throws ArgumentError', () {
      expect(
        () => NirniqLegacyMapping(
          nirniqId: 'not-a-valid-uuid',
          kithLocalUserId: validUserId,
          kithEffectiveAccountId: validAccountId,
          createdAt: fixedCreatedAt,
        ),
        throwsArgumentError,
      );
    });

    group('Runtime validation (W2, W3 & Release-mode safe)', () {
      test('rejects usr_ prefix only (empty suffix)', () {
        expect(
          () => NirniqLegacyMapping(
            nirniqId: validUuid,
            kithLocalUserId: 'usr_',
            kithEffectiveAccountId: validAccountId,
            createdAt: fixedCreatedAt,
          ),
          throwsArgumentError,
        );
      });

      test('rejects non-usr_ prefix', () {
        expect(
          () => NirniqLegacyMapping(
            nirniqId: validUuid,
            kithLocalUserId: 'abc_123',
            kithEffectiveAccountId: validAccountId,
            createdAt: fixedCreatedAt,
          ),
          throwsArgumentError,
        );
      });

      test('rejects empty kithLocalUserId', () {
        expect(
          () => NirniqLegacyMapping(
            nirniqId: validUuid,
            kithLocalUserId: '',
            kithEffectiveAccountId: validAccountId,
            createdAt: fixedCreatedAt,
          ),
          throwsArgumentError,
        );
      });

      test('rejects all-zeros nil UUID', () {
        // Decision: Nil UUID (00000000-0000-0000-0000-000000000000) represents an uninitialized
        // identifier and MUST NOT be accepted in a legacy mapping.
        expect(
          () => NirniqLegacyMapping(
            nirniqId: '00000000-0000-0000-0000-000000000000',
            kithLocalUserId: validUserId,
            kithEffectiveAccountId: validAccountId,
            createdAt: fixedCreatedAt,
          ),
          throwsArgumentError,
        );
      });

      test('fromJson with invalid kithLocalUserId throws ArgumentError', () {
        expect(
          () => NirniqLegacyMapping.fromJson({
            'nirniqId': validUuid,
            'kith_local_user_id': 'bad',
            'created_at': fixedCreatedAt.toIso8601String(),
          }),
          throwsArgumentError,
        );
      });

      test('fromJson with invalid nirniqId throws ArgumentError', () {
        expect(
          () => NirniqLegacyMapping.fromJson({
            'nirniq_id': 'not-uuid',
            'kith_local_user_id': 'usr_abc123',
            'created_at': fixedCreatedAt.toIso8601String(),
          }),
          throwsArgumentError,
        );
      });

      test('fromJson supports snake_case and defaults unknown migrationState safely', () {
        final parsed = NirniqLegacyMapping.fromJson({
          'nirniq_id': validUuid,
          'kith_local_user_id': validUserId,
          'kith_effective_account_id': validAccountId,
          'created_at': fixedCreatedAt.toIso8601String(),
          'migration_state': 'unknown_state',
        });

        expect(parsed.nirniqId, validUuid);
        expect(parsed.kithLocalUserId, validUserId);
        expect(parsed.migrationState, NirniqMigrationState.mappingCreated);
      });
    });

    test('fromJson and toJson round-trip preserves all fields', () {
      final original = NirniqLegacyMapping(
        nirniqId: validUuid,
        kithLocalUserId: validUserId,
        kithEffectiveAccountId: validAccountId,
        supabaseAuthUid: 'sb-auth-uid-001',
        migrationState: NirniqMigrationState.googleLinked,
        createdAt: fixedCreatedAt,
        linkedAt: fixedLinkedAt,
      );

      final json = original.toJson();
      final reconstructed = NirniqLegacyMapping.fromJson(json);

      expect(reconstructed, equals(original));
      expect(reconstructed.nirniqId, original.nirniqId);
      expect(reconstructed.kithLocalUserId, original.kithLocalUserId);
      expect(reconstructed.kithEffectiveAccountId, original.kithEffectiveAccountId);
      expect(reconstructed.supabaseAuthUid, original.supabaseAuthUid);
      expect(reconstructed.migrationState, original.migrationState);
      expect(reconstructed.createdAt, original.createdAt);
      expect(reconstructed.linkedAt, original.linkedAt);
    });

    test('copyWith works without mutating original instance', () {
      final original = NirniqLegacyMapping(
        nirniqId: validUuid,
        kithLocalUserId: validUserId,
        kithEffectiveAccountId: validAccountId,
        createdAt: fixedCreatedAt,
        migrationState: NirniqMigrationState.mappingCreated,
      );

      final updated = original.copyWith(
        supabaseAuthUid: 'new-sb-uid',
        migrationState: NirniqMigrationState.fullyMigrated,
        linkedAt: fixedLinkedAt,
      );

      expect(original.supabaseAuthUid, isNull);
      expect(original.migrationState, NirniqMigrationState.mappingCreated);
      expect(original.linkedAt, isNull);

      expect(updated.nirniqId, original.nirniqId);
      expect(updated.kithLocalUserId, original.kithLocalUserId);
      expect(updated.supabaseAuthUid, 'new-sb-uid');
      expect(updated.migrationState, NirniqMigrationState.fullyMigrated);
      expect(updated.linkedAt, fixedLinkedAt);
    });

    test('all 4 migration states are representable in NirniqLegacyMapping', () {
      for (final state in NirniqMigrationState.values) {
        final mapping = NirniqLegacyMapping(
          nirniqId: validUuid,
          kithLocalUserId: validUserId,
          kithEffectiveAccountId: validAccountId,
          migrationState: state,
          createdAt: fixedCreatedAt,
        );
        expect(mapping.migrationState, equals(state));

        final json = mapping.toJson();
        final reconstructed = NirniqLegacyMapping.fromJson(json);
        expect(reconstructed.migrationState, equals(state));
      }
    });

    test('== and hashCode work correctly', () {
      final m1 = NirniqLegacyMapping(
        nirniqId: validUuid,
        kithLocalUserId: validUserId,
        kithEffectiveAccountId: validAccountId,
        createdAt: fixedCreatedAt,
      );

      final m2 = NirniqLegacyMapping(
        nirniqId: validUuid,
        kithLocalUserId: validUserId,
        kithEffectiveAccountId: validAccountId,
        createdAt: fixedCreatedAt,
      );

      final m3 = m1.copyWith(supabaseAuthUid: 'other-uid');

      expect(m1, equals(m2));
      expect(m1.hashCode, equals(m2.hashCode));
      expect(m1, isNot(equals(m3)));
      expect(m1.hashCode, isNot(equals(m3.hashCode)));
    });

    test('toString includes key mapping fields', () {
      final mapping = NirniqLegacyMapping(
        nirniqId: validUuid,
        kithLocalUserId: validUserId,
        kithEffectiveAccountId: validAccountId,
        createdAt: fixedCreatedAt,
      );

      final str = mapping.toString();
      expect(str, contains('NirniqLegacyMapping'));
      expect(str, contains(validUuid));
      expect(str, contains(validUserId));
    });
  });
}
