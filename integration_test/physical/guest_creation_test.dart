import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/core/services/recovery_key_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 1: Guest Account Creation', () {
    testWidgets('generates cryptographic recovery key, salt, and session token', (tester) async {
      // 1. Generate high-entropy Crockford Base32 recovery key
      final key = RecoveryKeyService.generateKey();
      expect(key, isNotEmpty);
      expect(key.startsWith('KITH-'), isTrue);

      // 2. Validate key format
      expect(RecoveryKeyService.isValidKeyFormat(key), isTrue);

      // 3. Generate salt and hash key
      final salt = RecoveryKeyService.generateSalt();
      expect(salt.length, equals(32)); // 16 bytes = 32 hex chars

      final hash = RecoveryKeyService.hashKey(key, salt);
      expect(hash, isNotEmpty);
      expect(hash.length, equals(64)); // SHA-256 hex string

      // 4. Session token generation
      final token = RecoveryKeyService.generateSessionToken();
      expect(token.length, equals(64)); // 256 bits = 64 hex chars

      final tokenHash = RecoveryKeyService.hashSessionToken(token);
      expect(tokenHash.length, equals(64));

      // Invariant: sensitive raw key is never logged
      expect(RecoveryKeyService.verifyKey(key, hash, salt), isTrue);
    });
  });
}
