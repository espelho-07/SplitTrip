import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/models/guest_user.dart';

void main() {
  group('Phase 28: Auth UX + Recovery Key + Identity Continuity Tests', () {
    test('1. GuestUser model supports googleId and isGoogleLinked getter', () {
      final guest = GuestUser(
        id: 'usr_guest_001',
        displayName: 'Guest Alex',
        recoveryKey: 'KITH-ABCD-1234',
        anonymousToken: 'anon_123',
        createdAt: DateTime.now(),
        isLinkedToAccount: false,
      );

      expect(guest.isGoogleLinked, isFalse);
      expect(guest.googleId, isNull);

      final linked = guest.copyWith(
        email: 'alex@gmail.com',
        googleId: 'g_sub_101',
        isLinkedToAccount: true,
      );

      expect(linked.isGoogleLinked, isTrue);
      expect(linked.email, 'alex@gmail.com');
      expect(linked.googleId, 'g_sub_101');
      expect(linked.id, 'usr_guest_001', reason: 'User ID preserved after Google linking');
    });

    test('2. GuestUser json serialization and deserialization with googleId', () {
      final now = DateTime.now();
      final user = GuestUser(
        id: 'usr_canonical_999',
        displayName: 'Rohan Google',
        email: 'rohan@gmail.com',
        googleId: 'g_rohan_999',
        recoveryKey: 'KITH-9999-8888',
        anonymousToken: 'tok_999',
        createdAt: now,
        isLinkedToAccount: true,
      );

      final json = user.toJson();
      expect(json['googleId'], 'g_rohan_999');
      expect(json['email'], 'rohan@gmail.com');
      expect(json['isLinkedToAccount'], isTrue);

      final reconstructed = GuestUser.fromJson(json);
      expect(reconstructed.id, user.id);
      expect(reconstructed.googleId, user.googleId);
      expect(reconstructed.email, user.email);
      expect(reconstructed.isGoogleLinked, isTrue);
    });

    test('3. Recovery key normalization handles various user input formats', () {
      final rawKey1 = 'kith-abcd-efgh';
      final rawKey2 = '  ABCD-EFGH  ';
      final rawKey3 = 'KITH-1234-5678';

      String normalize(String input) {
        final cleaned = input.trim().toUpperCase();
        if (cleaned.startsWith('KITH-')) return cleaned;
        return 'KITH-$cleaned';
      }

      expect(normalize(rawKey1), 'KITH-ABCD-EFGH');
      expect(normalize(rawKey2), 'KITH-ABCD-EFGH');
      expect(normalize(rawKey3), 'KITH-1234-5678');
    });

    test('4. Guest User copyWith preserves non-modified fields', () {
      final user = GuestUser(
        id: 'usr_init_123',
        displayName: 'Sam',
        recoveryKey: 'KITH-SAM-9999',
        anonymousToken: 'anon_sam',
        createdAt: DateTime(2026, 1, 1),
        isLinkedToAccount: false,
      );

      final updated = user.copyWith(displayName: 'Sam Updated');
      expect(updated.id, 'usr_init_123');
      expect(updated.displayName, 'Sam Updated');
      expect(updated.recoveryKey, 'KITH-SAM-9999');
      expect(updated.isLinkedToAccount, isFalse);
    });
  });
}
