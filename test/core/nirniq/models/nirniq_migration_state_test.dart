import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/nirniq/models/nirniq_migration_state.dart';

void main() {
  group('NirniqMigrationState and NirniqMigrationStateX', () {
    test('isLegacy returns true only for legacyOnly', () {
      expect(NirniqMigrationState.legacyOnly.isLegacy, isTrue);
      expect(NirniqMigrationState.mappingCreated.isLegacy, isFalse);
      expect(NirniqMigrationState.googleLinked.isLegacy, isFalse);
      expect(NirniqMigrationState.fullyMigrated.isLegacy, isFalse);
    });

    test('hasNirniqId returns false for legacyOnly, true for all other states', () {
      expect(NirniqMigrationState.legacyOnly.hasNirniqId, isFalse);
      expect(NirniqMigrationState.mappingCreated.hasNirniqId, isTrue);
      expect(NirniqMigrationState.googleLinked.hasNirniqId, isTrue);
      expect(NirniqMigrationState.fullyMigrated.hasNirniqId, isTrue);
    });

    test('isFullyMigrated returns true only for fullyMigrated', () {
      expect(NirniqMigrationState.legacyOnly.isFullyMigrated, isFalse);
      expect(NirniqMigrationState.mappingCreated.isFullyMigrated, isFalse);
      expect(NirniqMigrationState.googleLinked.isFullyMigrated, isFalse);
      expect(NirniqMigrationState.fullyMigrated.isFullyMigrated, isTrue);
    });

    test('displayName returns non-empty string for all states', () {
      for (final state in NirniqMigrationState.values) {
        expect(state.displayName, isNotEmpty);
      }
      expect(NirniqMigrationState.legacyOnly.displayName, 'Legacy Only');
      expect(NirniqMigrationState.mappingCreated.displayName, 'Mapping Created');
      expect(NirniqMigrationState.googleLinked.displayName, 'Google Linked');
      expect(NirniqMigrationState.fullyMigrated.displayName, 'Fully Migrated');
    });

    group('State transition monotonicity guard (W5)', () {
      test('permits forward transition by single step', () {
        expect(
          NirniqMigrationState.legacyOnly.canTransitionTo(NirniqMigrationState.mappingCreated),
          isTrue,
        );
        expect(
          NirniqMigrationState.mappingCreated.canTransitionTo(NirniqMigrationState.googleLinked),
          isTrue,
        );
        expect(
          NirniqMigrationState.googleLinked.canTransitionTo(NirniqMigrationState.fullyMigrated),
          isTrue,
        );
      });

      test('permits skipping intermediate states forward', () {
        expect(
          NirniqMigrationState.legacyOnly.canTransitionTo(NirniqMigrationState.googleLinked),
          isTrue,
        );
        expect(
          NirniqMigrationState.legacyOnly.canTransitionTo(NirniqMigrationState.fullyMigrated),
          isTrue,
        );
        expect(
          NirniqMigrationState.mappingCreated.canTransitionTo(NirniqMigrationState.fullyMigrated),
          isTrue,
        );
      });

      test('permits idempotent self-transition', () {
        for (final state in NirniqMigrationState.values) {
          expect(state.canTransitionTo(state), isTrue);
        }
      });

      test('forbids backward transition', () {
        expect(
          NirniqMigrationState.fullyMigrated.canTransitionTo(NirniqMigrationState.legacyOnly),
          isFalse,
        );
        expect(
          NirniqMigrationState.fullyMigrated.canTransitionTo(NirniqMigrationState.mappingCreated),
          isFalse,
        );
        expect(
          NirniqMigrationState.fullyMigrated.canTransitionTo(NirniqMigrationState.googleLinked),
          isFalse,
        );
        expect(
          NirniqMigrationState.googleLinked.canTransitionTo(NirniqMigrationState.legacyOnly),
          isFalse,
        );
        expect(
          NirniqMigrationState.googleLinked.canTransitionTo(NirniqMigrationState.mappingCreated),
          isFalse,
        );
        expect(
          NirniqMigrationState.mappingCreated.canTransitionTo(NirniqMigrationState.legacyOnly),
          isFalse,
        );
      });
    });

    group('Centralized enum deserialization & fallback (W6)', () {
      test('fromString returns correct enum for valid names', () {
        for (final state in NirniqMigrationState.values) {
          expect(NirniqMigrationState.fromString(state.name), equals(state));
        }
      });

      test('fromString with unknown value returns specified fallback', () {
        expect(
          NirniqMigrationState.fromString('unknown_state'),
          equals(NirniqMigrationState.mappingCreated),
        );
        expect(
          NirniqMigrationState.fromString('corrupted', fallback: NirniqMigrationState.legacyOnly),
          equals(NirniqMigrationState.legacyOnly),
        );
      });

      test('fromString with null returns fallback', () {
        expect(
          NirniqMigrationState.fromString(null),
          equals(NirniqMigrationState.mappingCreated),
        );
        expect(
          NirniqMigrationState.fromString(null, fallback: NirniqMigrationState.fullyMigrated),
          equals(NirniqMigrationState.fullyMigrated),
        );
      });

      test('tryParse parses valid names and returns null for invalid or null', () {
        expect(
          NirniqMigrationState.tryParse('legacyOnly'),
          equals(NirniqMigrationState.legacyOnly),
        );
        expect(
          NirniqMigrationState.tryParse('fullyMigrated'),
          equals(NirniqMigrationState.fullyMigrated),
        );
        expect(NirniqMigrationState.tryParse('unknown_state'), isNull);
        expect(NirniqMigrationState.tryParse(null), isNull);
      });
    });
  });
}
