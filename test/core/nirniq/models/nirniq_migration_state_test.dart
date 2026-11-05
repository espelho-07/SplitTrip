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
  });
}
