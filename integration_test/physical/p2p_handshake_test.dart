import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/data/services/p2p_sync_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 4: P2P Mutual HMAC Authentication & Downgrade Prevention', () {
    const tripId = 'trip-auth-uuid-4444';
    const inviteCode = 'KITH44';
    const validSecret = '1234567890abcdef1234567890abcdef';
    const attackerSecret = 'badbadbadbadbadbadbadbadbadbad00';
    const protocol = P2PSyncService.protocolTag;
    const checksum = 'checksum_sha256_mock_value';

    final validAuthKey = P2PSyncService.deriveTripAuthKey(
      tripId,
      inviteCode,
      p2pTripSecret: validSecret,
    );

    final legacyAuthKey = P2PSyncService.deriveTripAuthKey(
      tripId,
      inviteCode,
      p2pTripSecret: null, // Legacy v1
    );

    testWidgets('verifies valid HMAC signature using modern v2 secret', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final signature = P2PSyncService.computeP2POperationSignature(
        authKey: validAuthKey,
        protocolVersion: protocol,
        tripId: tripId,
        operationId: 'op-001',
        senderDeviceId: 'device-a',
        payloadChecksum: checksum,
        timestampMs: now,
      );

      final isValid = P2PSyncService.verifyP2POperationSignature(
        authKey: validAuthKey,
        protocolVersion: protocol,
        tripId: tripId,
        operationId: 'op-001',
        senderDeviceId: 'device-a',
        payloadChecksum: checksum,
        timestampMs: now,
        signature: signature,
      );

      expect(isValid, isTrue);
    });

    testWidgets('rejects invalid signature, tampered checksum, or attacker key', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final signature = P2PSyncService.computeP2POperationSignature(
        authKey: validAuthKey,
        protocolVersion: protocol,
        tripId: tripId,
        operationId: 'op-002',
        senderDeviceId: 'device-a',
        payloadChecksum: checksum,
        timestampMs: now,
      );

      // Tampered checksum
      final isValidTampered = P2PSyncService.verifyP2POperationSignature(
        authKey: validAuthKey,
        protocolVersion: protocol,
        tripId: tripId,
        operationId: 'op-002',
        senderDeviceId: 'device-a',
        payloadChecksum: 'tampered_checksum_value',
        timestampMs: now,
        signature: signature,
      );
      expect(isValidTampered, isFalse);

      // Attacker key verification
      final attackerKey = P2PSyncService.deriveTripAuthKey(
        tripId,
        inviteCode,
        p2pTripSecret: attackerSecret,
      );
      final isValidAttacker = P2PSyncService.verifyP2POperationSignature(
        authKey: attackerKey,
        protocolVersion: protocol,
        tripId: tripId,
        operationId: 'op-002',
        senderDeviceId: 'device-a',
        payloadChecksum: checksum,
        timestampMs: now,
        signature: signature,
      );
      expect(isValidAttacker, isFalse);
    });

    testWidgets('strict protocol separation: modern trip NEVER validates with legacy key', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Signature computed with modern v2 key
      final modernSig = P2PSyncService.computeP2POperationSignature(
        authKey: validAuthKey,
        protocolVersion: protocol,
        tripId: tripId,
        operationId: 'op-003',
        senderDeviceId: 'device-a',
        payloadChecksum: checksum,
        timestampMs: now,
      );

      // Verifying modern signature with legacy key MUST fail
      final isLegacyDowngrade = P2PSyncService.verifyP2POperationSignature(
        authKey: legacyAuthKey,
        protocolVersion: protocol,
        tripId: tripId,
        operationId: 'op-003',
        senderDeviceId: 'device-a',
        payloadChecksum: checksum,
        timestampMs: now,
        signature: modernSig,
      );
      expect(isLegacyDowngrade, isFalse);
    });
  });
}
