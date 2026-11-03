import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/p2p_sync_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late SharedPreferences prefs;
  late LocalStorageService storage;
  late SyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
  });

  group('P2P HMAC Key Derivation & Cryptographic Invariants', () {
    test('1. deriveTripAuthKey produces deterministic 32-byte key from tripId and inviteCode', () {
      final key1 = P2PSyncService.deriveTripAuthKey('trip_kashmir_01', 'KASHMIR2026');
      final key2 = P2PSyncService.deriveTripAuthKey('trip_kashmir_01', 'KASHMIR2026');
      final keyWrongCode = P2PSyncService.deriveTripAuthKey('trip_kashmir_01', 'WRONG_CODE');
      final keyOtherTrip = P2PSyncService.deriveTripAuthKey('trip_goa_02', 'KASHMIR2026');

      expect(key1, equals(key2), reason: 'Identical parameters must yield identical auth key');
      expect(key1.length, equals(32), reason: 'HMAC-SHA256 must yield 32 bytes (256 bits)');
      expect(key1, isNot(equals(keyWrongCode)), reason: 'Wrong invite code must produce different key');
      expect(key1, isNot(equals(keyOtherTrip)), reason: 'Different tripId must produce different key');
    });

    test('2. computeP2POperationSignature and verifyP2POperationSignature validate authentic operations', () {
      final authKey = P2PSyncService.deriveTripAuthKey('trip_kashmir_01', 'KASHMIR2026');
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const protocol = 'kith_p2p_v1';
      const tripId = 'trip_kashmir_01';
      const opId = 'op_expense_shikara_001';
      const senderDeviceId = 'dev_device_alice';
      const checksum = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

      final sig = P2PSyncService.computeP2POperationSignature(
        authKey: authKey,
        protocolVersion: protocol,
        tripId: tripId,
        operationId: opId,
        senderDeviceId: senderDeviceId,
        payloadChecksum: checksum,
        timestampMs: nowMs,
      );

      final isValid = P2PSyncService.verifyP2POperationSignature(
        authKey: authKey,
        signature: sig,
        protocolVersion: protocol,
        tripId: tripId,
        operationId: opId,
        senderDeviceId: senderDeviceId,
        payloadChecksum: checksum,
        timestampMs: nowMs,
      );

      expect(isValid, isTrue, reason: 'Legitimate signature must verify successfully');
    });

    test('3. verifyP2POperationSignature rejects tampered payload checksum', () {
      final authKey = P2PSyncService.deriveTripAuthKey('trip_kashmir_01', 'KASHMIR2026');
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final sig = P2PSyncService.computeP2POperationSignature(
        authKey: authKey,
        protocolVersion: 'kith_p2p_v1',
        tripId: 'trip_kashmir_01',
        operationId: 'op_100',
        senderDeviceId: 'dev_alice',
        payloadChecksum: 'original_checksum_hash',
        timestampMs: nowMs,
      );

      final isTamperedValid = P2PSyncService.verifyP2POperationSignature(
        authKey: authKey,
        signature: sig,
        protocolVersion: 'kith_p2p_v1',
        tripId: 'trip_kashmir_01',
        operationId: 'op_100',
        senderDeviceId: 'dev_alice',
        payloadChecksum: 'tampered_checksum_hash', // Tampered!
        timestampMs: nowMs,
      );

      expect(isTamperedValid, isFalse, reason: 'Tampered payload checksum must fail signature verification');
    });

    test('4. verifyP2POperationSignature rejects spoofed sender device ID', () {
      final authKey = P2PSyncService.deriveTripAuthKey('trip_kashmir_01', 'KASHMIR2026');
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final sig = P2PSyncService.computeP2POperationSignature(
        authKey: authKey,
        protocolVersion: 'kith_p2p_v1',
        tripId: 'trip_kashmir_01',
        operationId: 'op_100',
        senderDeviceId: 'dev_alice',
        payloadChecksum: 'checksum_123',
        timestampMs: nowMs,
      );

      final isSpoofedValid = P2PSyncService.verifyP2POperationSignature(
        authKey: authKey,
        signature: sig,
        protocolVersion: 'kith_p2p_v1',
        tripId: 'trip_kashmir_01',
        operationId: 'op_100',
        senderDeviceId: 'dev_attacker_mallory', // Spoofed sender!
        payloadChecksum: 'checksum_123',
        timestampMs: nowMs,
      );

      expect(isSpoofedValid, isFalse, reason: 'Spoofed sender device ID must fail verification');
    });

    test('5. Replay attack rejection: expired timestamp (> 300 seconds) is rejected', () {
      final authKey = P2PSyncService.deriveTripAuthKey('trip_kashmir_01', 'KASHMIR2026');
      final now = DateTime.now();
      final expiredMs = now.subtract(const Duration(minutes: 6)).millisecondsSinceEpoch; // 360 seconds ago

      final sig = P2PSyncService.computeP2POperationSignature(
        authKey: authKey,
        protocolVersion: 'kith_p2p_v1',
        tripId: 'trip_kashmir_01',
        operationId: 'op_old_100',
        senderDeviceId: 'dev_alice',
        payloadChecksum: 'checksum_123',
        timestampMs: expiredMs,
      );

      final isExpiredValid = P2PSyncService.verifyP2POperationSignature(
        authKey: authKey,
        signature: sig,
        protocolVersion: 'kith_p2p_v1',
        tripId: 'trip_kashmir_01',
        operationId: 'op_old_100',
        senderDeviceId: 'dev_alice',
        payloadChecksum: 'checksum_123',
        timestampMs: expiredMs,
        maxSkewSeconds: 300,
        currentTimestampMs: now.millisecondsSinceEpoch,
      );

      expect(isExpiredValid, isFalse, reason: 'Replay packets older than 300 seconds must be rejected');
    });

    test('6. Unauthorized peer with wrong trip secret cannot forge valid signature', () {
      final legitKey = P2PSyncService.deriveTripAuthKey('trip_kashmir_01', 'KASHMIR2026');
      final unauthorizedKey = P2PSyncService.deriveTripAuthKey('trip_kashmir_01', 'WRONG_GUESS');
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Attacker signs with their key
      final forgedSig = P2PSyncService.computeP2POperationSignature(
        authKey: unauthorizedKey,
        protocolVersion: 'kith_p2p_v1',
        tripId: 'trip_kashmir_01',
        operationId: 'op_hack_01',
        senderDeviceId: 'dev_attacker',
        payloadChecksum: 'checksum_123',
        timestampMs: nowMs,
      );

      // Receiver checks against real trip authKey
      final isValidOnReceiver = P2PSyncService.verifyP2POperationSignature(
        authKey: legitKey,
        signature: forgedSig,
        protocolVersion: 'kith_p2p_v1',
        tripId: 'trip_kashmir_01',
        operationId: 'op_hack_01',
        senderDeviceId: 'dev_attacker',
        payloadChecksum: 'checksum_123',
        timestampMs: nowMs,
      );

      expect(isValidOnReceiver, isFalse, reason: 'Forged signature with invalid key must fail');
    });
  });

  group('P2P HTTP Server Security & Payload Verification', () {
    late P2PSyncService p2pService;
    late HttpClient httpClient;

    setUp(() async {
      await storage.saveTrips([
        {
          'id': 'trip_kashmir_01',
          'name': 'Kashmir Trip',
          'inviteCode': 'KASHMIR2026',
        }
      ]);

      p2pService = P2PSyncService(storage, syncService, deviceId: 'receiver_device_bob');
      await p2pService.start();
      httpClient = HttpClient();
    });

    tearDown(() async {
      httpClient.close();
      await p2pService.stop();
    });

    test('7. POST /kith-p2p/operations accepts valid signed operations and rejects unsigned or forged ones', () async {
      final port = p2pService.serverPort;
      expect(port, isNotNull);

      final authKey = P2PSyncService.deriveTripAuthKey('trip_kashmir_01', 'KASHMIR2026');
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final validMutation = SyncMutation(
        id: 'op_houseboat_001',
        type: MutationType.addExpense,
        payload: {
          'tripId': 'trip_kashmir_01',
          'id': 'exp_houseboat_001',
          'title': 'Houseboat Stay',
          'amountInPaise': 350000,
        },
        createdAt: DateTime.now(),
        originDeviceId: 'dev_alice_phone',
      );

      final validOpJson = validMutation.toJson();
      final validSig = P2PSyncService.computeP2POperationSignature(
        authKey: authKey,
        protocolVersion: P2PSyncService.protocolTag,
        tripId: 'trip_kashmir_01',
        operationId: validMutation.id,
        senderDeviceId: 'dev_alice_phone',
        payloadChecksum: validMutation.payloadChecksum,
        timestampMs: nowMs,
      );
      validOpJson['signature'] = validSig;
      validOpJson['signatureTimestamp'] = nowMs;

      final unsignedMutation = SyncMutation(
        id: 'op_unsigned_attack_002',
        type: MutationType.addExpense,
        payload: {
          'tripId': 'trip_kashmir_01',
          'id': 'exp_unsigned_002',
          'title': 'Unsigned Attack',
          'amountInPaise': 9999999,
        },
        createdAt: DateTime.now(),
        originDeviceId: 'dev_alice_phone',
      );
      final unsignedOpJson = unsignedMutation.toJson(); // Missing signature!

      final forgedMutation = SyncMutation(
        id: 'op_forged_attack_003',
        type: MutationType.addExpense,
        payload: {
          'tripId': 'trip_kashmir_01',
          'id': 'exp_forged_003',
          'title': 'Forged Attack',
          'amountInPaise': 8888888,
        },
        createdAt: DateTime.now(),
        originDeviceId: 'dev_alice_phone',
      );
      final forgedOpJson = forgedMutation.toJson();
      forgedOpJson['signature'] = 'invalid_tampered_hmac_signature';
      forgedOpJson['signatureTimestamp'] = nowMs;

      // Post all three operations to the receiver
      final uri = Uri.parse('http://127.0.0.1:$port/kith-p2p/operations');
      final req = await httpClient.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'protocol': P2PSyncService.protocolTag,
        'deviceId': 'dev_alice_phone',
        'tripId': 'trip_kashmir_01',
        'operations': [validOpJson, unsignedOpJson, forgedOpJson],
        'knownLocalOperations': [],
      }));

      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      final body = await utf8.decoder.bind(res).join();
      final resJson = jsonDecode(body) as Map<String, dynamic>;

      // Only the valid signed operation should have been applied!
      expect(resJson['appliedCount'], equals(1));
      expect(resJson['processedOperationIds'], contains('op_houseboat_001'));
      expect(resJson['processedOperationIds'], isNot(contains('op_unsigned_attack_002')));
      expect(resJson['processedOperationIds'], isNot(contains('op_forged_attack_003')));

      // Verify the expense actually exists in local storage
      final expenses = storage.getSavedExpenses('trip_kashmir_01');
      expect(expenses.any((e) => e['id'] == 'exp_houseboat_001'), isTrue);
      expect(expenses.any((e) => e['id'] == 'exp_unsigned_002'), isFalse);
      expect(expenses.any((e) => e['id'] == 'exp_forged_003'), isFalse);
    });

    test('8. POST /kith-p2p/operations rejects unauthorized trip with 403 Forbidden', () async {
      final port = p2pService.serverPort;
      final uri = Uri.parse('http://127.0.0.1:$port/kith-p2p/operations');
      final req = await httpClient.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'protocol': P2PSyncService.protocolTag,
        'deviceId': 'dev_stranger',
        'tripId': 'unauthorized_trip_999',
        'operations': [],
        'knownLocalOperations': [],
      }));

      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.forbidden));
    });

    test('9. GET /kith-p2p/watermark rejects unauthorized trip with 403 Forbidden', () async {
      final port = p2pService.serverPort;
      final uri = Uri.parse('http://127.0.0.1:$port/kith-p2p/watermark?tripId=unauthorized_trip_999&deviceId=dev_1');
      final req = await httpClient.getUrl(uri);
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.forbidden));
    });

    test('10. GET /kith-p2p/watermark accepts authorized trip with 200 OK and known operations', () async {
      final port = p2pService.serverPort;
      final uri = Uri.parse('http://127.0.0.1:$port/kith-p2p/watermark?tripId=trip_kashmir_01&deviceId=dev_1');
      final req = await httpClient.getUrl(uri);
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      final body = await utf8.decoder.bind(res).join();
      final resJson = jsonDecode(body) as Map<String, dynamic>;
      expect(resJson['tripId'], equals('trip_kashmir_01'));
      expect(resJson['knownOperations'], isA<List>());
    });
  });
}
