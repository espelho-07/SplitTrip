import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/nirniq/models/nirniq_identity.dart';
import 'package:kith_app/core/services/nirniq_account_service.dart';

void main() {
  group('Nirniq Identity Symbol Collision Resolution (W4)', () {
    test('legacy NirniqAccountService model is accessible under LegacyNirniqAccountIdentity', () {
      const legacyModel = LegacyNirniqAccountIdentity(
        nirniqId: 'nrn_legacy_123',
        email: 'legacy@example.com',
        displayName: 'Legacy User',
        provider: 'google',
        connectedApps: ['kith'],
      );

      expect(legacyModel.nirniqId, 'nrn_legacy_123');
      expect(legacyModel.email, 'legacy@example.com');
      expect(legacyModel.displayName, 'Legacy User');

      final json = legacyModel.toJson();
      final restored = LegacyNirniqAccountIdentity.fromJson(json);
      expect(restored.nirniqId, 'nrn_legacy_123');
      expect(restored.email, 'legacy@example.com');
    });

    test('canonical NirniqIdentity and LegacyNirniqAccountIdentity coexist without collision', () {
      // Canonical domain model
      final canonical = NirniqIdentity(
        nirniqId: '123e4567-e89b-12d3-a456-426614174000',
        createdAt: DateTime.utc(2026, 11, 5),
      );

      // Legacy prototype model
      const legacy = LegacyNirniqAccountIdentity(
        nirniqId: 'nrn_google_sub_123',
        email: 'user@example.com',
        displayName: 'User',
      );

      expect(canonical.nirniqId, '123e4567-e89b-12d3-a456-426614174000');
      expect(legacy.nirniqId, 'nrn_google_sub_123');
    });
  });
}
