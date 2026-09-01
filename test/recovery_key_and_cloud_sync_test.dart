import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/recovery_key_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';

void main() {
  group('RecoveryKeyService Cryptography & Security Tests', () {
    test('generateKey creates valid 16-char Crockford Base32 keys in 4 groups', () {
      final key = RecoveryKeyService.generateKey();
      expect(key.startsWith('KITH-'), isTrue);
      expect(key.length, equals(24)); // KITH-XXXX-XXXX-XXXX-XXXX = 4+1+4+1+4+1+4+1+4 = 24 chars
      expect(RecoveryKeyService.isValidKeyFormat(key), isTrue);

      // Verify no ambiguous characters (0, O, 1, I, L)
      final body = key.replaceAll('KITH-', '').replaceAll('-', '');
      expect(body.contains('0'), isFalse);
      expect(body.contains('O'), isFalse);
      expect(body.contains('1'), isFalse);
      expect(body.contains('I'), isFalse);
      expect(body.contains('L'), isFalse);
    });

    test('normalizeKey handles arbitrary case, whitespace, dashes, and missing KITH- prefix', () {
      const raw1 = '  kith-7x4m-9q2p-l8vn-3r6t  ';
      expect(RecoveryKeyService.normalizeKey(raw1), equals('KITH-7X4M-9Q2P-L8VN-3R6T'));

      const raw2 = '7X4M9Q2PL8VN3R6T';
      expect(RecoveryKeyService.normalizeKey(raw2), equals('KITH-7X4M-9Q2P-L8VN-3R6T'));

      const raw3 = 'kith:7x4m_9q2p_l8vn_3r6t';
      expect(RecoveryKeyService.normalizeKey(raw3), equals('KITH-7X4M-9Q2P-L8VN-3R6T'));
    });

    test('hashKey and verifyKey compute deterministic salted hashes and constant-time verify', () {
      final salt = RecoveryKeyService.generateSalt();
      expect(salt.length, equals(32));

      const key = 'KITH-7X4M-9Q2P-L8VN-3R6T';
      final hash1 = RecoveryKeyService.hashKey(key, salt);
      final hash2 = RecoveryKeyService.hashKey('7x4m9q2pl8vn3r6t', salt); // normalized key match

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 hex length

      // Verification
      expect(RecoveryKeyService.verifyKey(key, hash1, salt), isTrue);
      expect(RecoveryKeyService.verifyKey('7x4m-9q2p-l8vn-3r6t', hash1, salt), isTrue);
      expect(RecoveryKeyService.verifyKey('KITH-WRONG-KEY-1111-2222', hash1, salt), isFalse);
    });

    test('Rate-limiting restricts brute-force attempts after 5 failures', () {
      const testDevice = 'test_device_rate_limit_123';
      RecoveryKeyService.recordRecoveryAttempt(testDevice, success: true); // reset
      expect(RecoveryKeyService.canAttemptRecovery(testDevice), isTrue);

      // Record 5 failed attempts
      for (int i = 0; i < 5; i++) {
        RecoveryKeyService.recordRecoveryAttempt(testDevice, success: false);
      }

      expect(RecoveryKeyService.canAttemptRecovery(testDevice), isFalse);
      expect(RecoveryKeyService.getRemainingCooldown(testDevice).inSeconds > 0, isTrue);

      // Successful recovery resets history
      RecoveryKeyService.recordRecoveryAttempt(testDevice, success: true);
      expect(RecoveryKeyService.canAttemptRecovery(testDevice), isTrue);
    });
  });

  group('GuestUser Account ID & Serialization Tests', () {
    test('GuestUser preserves accountId and provides effectiveAccountId', () {
      final user = GuestUser(
        id: 'usr_abc123',
        accountId: 'acc_xyz789',
        displayName: 'Aarav',
        recoveryKey: 'KITH-7X4M-9Q2P-L8VN-3R6T',
        anonymousToken: 'tok_123',
        createdAt: DateTime(2026, 9, 1),
      );

      expect(user.effectiveAccountId, equals('acc_xyz789'));

      final json = user.toJson();
      expect(json['accountId'], equals('acc_xyz789'));

      final reconstructed = GuestUser.fromJson(json);
      expect(reconstructed.id, equals('usr_abc123'));
      expect(reconstructed.accountId, equals('acc_xyz789'));
      expect(reconstructed.effectiveAccountId, equals('acc_xyz789'));
      expect(reconstructed.recoveryKey, equals('KITH-7X4M-9Q2P-L8VN-3R6T'));
    });

    test('GuestUser falls back to id when accountId is omitted', () {
      final user = GuestUser(
        id: 'usr_standalone',
        displayName: 'Guest',
        recoveryKey: 'KITH-7X4M-9Q2P-L8VN-3R6T',
        anonymousToken: 'tok_123',
        createdAt: DateTime(2026, 9, 1),
      );

      expect(user.effectiveAccountId, equals('usr_standalone'));
    });
  });
}
