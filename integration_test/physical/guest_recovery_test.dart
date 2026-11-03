import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/core/services/recovery_key_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 11: Guest Account Recovery Mnemonic Validation', () {
    testWidgets('verifies valid recovery key format and rejects invalid formats', (tester) async {
      // Valid key
      final validKey = RecoveryKeyService.generateKey();
      expect(RecoveryKeyService.isValidKeyFormat(validKey), isTrue);

      final salt = RecoveryKeyService.generateSalt();
      final validHash = RecoveryKeyService.hashKey(validKey, salt);
      expect(validHash.length, equals(64));

      // Invalid key (too short / wrong characters)
      expect(RecoveryKeyService.isValidKeyFormat('KITH-123'), isFalse);
      expect(RecoveryKeyService.isValidKeyFormat('INVALID_KEY_NOT_CROCKFORD'), isFalse);

      // Invariant: constant-time key verification
      expect(RecoveryKeyService.verifyKey(validKey, validHash, salt), isTrue);
      expect(RecoveryKeyService.verifyKey('KITH-WRNG-KEY1-2345-6789', validHash, salt), isFalse);
    });
  });
}
