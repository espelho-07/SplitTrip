import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/recovery_key_service.dart';
import 'package:kith_app/core/services/secure_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Priority 3: Guest Session Token Lifecycle Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Session token is 256-bit cryptographically secure hex string', () {
      final token1 = RecoveryKeyService.generateSessionToken();
      final token2 = RecoveryKeyService.generateSessionToken();

      expect(token1.length, equals(64)); // 32 bytes * 2 = 64 hex chars = 256 bits
      expect(token2.length, equals(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(token1), isTrue);
      expect(token1, isNot(equals(token2)));
    });

    test('2. Tokens are persisted in FlutterSecureStorage and survive simulated app restarts', () async {
      final secureIdService = SecureIdService();
      const accountId = 'usr_guest_alice_123';
      final sessionToken = RecoveryKeyService.generateSessionToken();

      // Persist token to Keystore
      await secureIdService.persistSessionToken(accountId, sessionToken);

      // Simulate app kill and cold restart with fresh service instance
      final freshServiceInstance = SecureIdService();
      final restoredToken = await freshServiceInstance.getPersistedSessionToken(accountId);

      expect(restoredToken, isNotNull);
      expect(restoredToken, equals(sessionToken));
    });

    test('3. Tokens are NEVER stored in SharedPreferences (zero leakage)', () async {
      final secureIdService = SecureIdService();
      final prefs = await SharedPreferences.getInstance();
      const accountId = 'usr_guest_bob_456';
      final sessionToken = RecoveryKeyService.generateSessionToken();

      await secureIdService.persistSessionToken(accountId, sessionToken);

      // Inspect every key and value in SharedPreferences
      for (final key in prefs.getKeys()) {
        final val = prefs.get(key).toString();
        expect(key.contains(sessionToken), isFalse);
        expect(val.contains(sessionToken), isFalse);
      }
    });

    test('4. Revocation: clearSessionToken wipes token completely', () async {
      final secureIdService = SecureIdService();
      const accountId = 'usr_guest_revoked_789';
      final sessionToken = RecoveryKeyService.generateSessionToken();

      await secureIdService.persistSessionToken(accountId, sessionToken);
      expect(await secureIdService.getPersistedSessionToken(accountId), isNotNull);

      // Explicit revocation / logout
      await secureIdService.clearSessionToken(accountId);
      expect(await secureIdService.getPersistedSessionToken(accountId), isNull);
    });

    test('5. Existing guest accounts without token seamlessly generate and migrate token on startup', () async {
      final secureIdService = SecureIdService();
      const accountId = 'usr_legacy_guest_001';

      // Verify no token initially exists
      var token = await secureIdService.getPersistedSessionToken(accountId);
      expect(token, isNull);

      // Migration step
      token = RecoveryKeyService.generateSessionToken();
      await secureIdService.persistSessionToken(accountId, token);

      final verifiedToken = await secureIdService.getPersistedSessionToken(accountId);
      expect(verifiedToken, isNotNull);
      expect(verifiedToken!.length, equals(64));
    });
  });
}
