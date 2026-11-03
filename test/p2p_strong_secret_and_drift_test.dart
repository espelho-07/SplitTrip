import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/config/app_config.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/p2p_sync_service.dart';
import 'package:kith_app/domain/engine/qr_code_parser.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Priority 1: Strong P2P Pairing Security Tests', () {
    test(
      '1. 128-bit P2P trip secret generation has minimum 128-bit entropy',
      () {
        final secureRandom = Random.secure();
        final secretBytes = List<int>.generate(
          16,
          (_) => secureRandom.nextInt(256),
        );
        final secret = secretBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();

        expect(
          secret.length,
          equals(32),
        ); // 16 bytes * 2 hex chars = 32 chars = 128 bits
        expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(secret), isTrue);

        // Verify two generated secrets are never identical (cryptographic randomness)
        final secretBytes2 = List<int>.generate(
          16,
          (_) => secureRandom.nextInt(256),
        );
        final secret2 = secretBytes2
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        expect(secret, isNot(equals(secret2)));
      },
    );

    test('2. QR code encodes 128-bit P2P trip secret and QrCodeParser decodes it securely', () {
      const inviteCode = 'KITH99';
      const p2pSecret = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

      final link = AppConfig.buildInviteLink(
        inviteCode,
        p2pTripSecret: p2pSecret,
      );
      expect(link, contains('code=KITH99'));
      expect(link, contains('secret=a1b2c3d4e5f60718293a4b5c6d7e8f90'));

      // Parse payload
      final parsed = QrCodeParser.parsePayload(link);
      expect(parsed, isNotNull);
      expect(parsed!.inviteCode, equals('KITH99'));
      expect(parsed.p2pTripSecret, equals(p2pSecret));

      // Direct invite code fallback without secret
      final legacyLink = AppConfig.buildInviteLink('LEGACY');
      final legacyParsed = QrCodeParser.parsePayload(legacyLink);
      expect(legacyParsed, isNotNull);
      expect(legacyParsed!.inviteCode, equals('LEGACY'));
      expect(legacyParsed.p2pTripSecret, isNull);
    });

    test('3. deriveTripAuthKey produces high-entropy v2 key with secret and backward-compatible v1 key', () {
      const tripId = 'trip_bali_2026';
      const inviteCode = 'BALI01';
      const p2pSecret = 'deadbeefcafebabe0123456789abcdef';

      // v2 key with 128-bit secret
      final keyV2 = P2PSyncService.deriveTripAuthKey(
        tripId,
        inviteCode,
        p2pTripSecret: p2pSecret,
      );
      expect(keyV2.length, equals(32));

      // v1 legacy key without secret
      final keyV1 = P2PSyncService.deriveTripAuthKey(tripId, inviteCode);
      expect(keyV1.length, equals(32));

      // Keys must be completely different to enforce cryptographic separation
      expect(keyV2, isNot(equals(keyV1)));

      // Deterministic reproduction: same secret produces exact same key
      final keyV2Repeat = P2PSyncService.deriveTripAuthKey(
        tripId,
        inviteCode,
        p2pTripSecret: p2pSecret,
      );
      expect(keyV2, equals(keyV2Repeat));
    });

    test('4. Trip domain model preserves p2pTripSecret across mergeWith and copyWith', () {
      final trip1 = Trip(
        id: 'trip_100',
        name: 'Himalayan Trek',
        creatorId: 'usr_alice',
        members: [],
        inviteCode: 'HIMA01',
        p2pTripSecret: '11112222333344445555666677778888',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final copy = trip1.copyWith(name: 'Updated Trek');
      expect(copy.p2pTripSecret, equals('11112222333344445555666677778888'));

      // Merge with remote trip that lacks secret retains local strong secret
      final remoteTrip = Trip(
        id: 'trip_100',
        name: 'Updated Trek on Server',
        creatorId: 'usr_alice',
        members: [],
        inviteCode: 'HIMA01',
        revision: 2,
        createdAt: trip1.createdAt,
        updatedAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      final merged = trip1.mergeWith(remoteTrip);
      expect(merged.name, equals('Updated Trek on Server'));
      expect(merged.p2pTripSecret, equals('11112222333344445555666677778888'));
    });
  });

  group('Priority 2: SQLite / Drift Transactional Migration & ACID Guarantees', () {
    late LocalDatabaseService dbService;

    setUp(() {
      dbService = LocalDatabaseService.inMemory();
    });

    tearDown(() {
      dbService.dispose();
    });

    test('5. SQLite engine executes with genuine relational schema and foreign keys', () {
      final res = dbService.rawDb.select('PRAGMA foreign_keys;');
      expect(res.first.values.first, equals(1));
    });

    test('6. commitAtomicMutationBatch executes entities, outbox, ops, and tombstones in single transaction', () {
      final ok = dbService.commitAtomicMutationBatch(
        updatedTrips: [
          {
            'id': 'trip_tokyo',
            'name': 'Tokyo Summit',
            'creatorId': 'usr_bob',
            'inviteCode': 'TOKYO1',
            'p2pTripSecret': 'secret_128bit_hex_value_here_000',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        ],
        updatedExpensesByTrip: {
          'trip_tokyo': [
            {
              'id': 'exp_ramen',
              'tripId': 'trip_tokyo',
              'title': 'Ramen Dinner',
              'amount': 3500.0,
              'currency': 'JPY',
              'paidByMemberId': 'mbr_bob',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            },
          ],
        },
        updatedOutbox: [
          {
            'id': 'mut_001',
            'type': 'addExpense',
            'tripId': 'trip_tokyo',
            'payload': {'title': 'Ramen Dinner'},
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
        recordToMarkProcessed: ProcessedOperationRecord(
          operationId: 'op_atomic_tokyo_001',
          payloadChecksum: 'chk_999',
          processedAt: DateTime.now(),
          source: 'local',
        ),
        tombstoneToAdd: {'tripId': 'trip_tokyo', 'expenseId': 'exp_old_coffee'},
      );

      expect(ok, isTrue);

      // Verify all 4 stores committed atomically
      final trips = dbService.getSavedTrips();
      expect(trips.length, equals(1));
      expect(trips.first['id'], equals('trip_tokyo'));

      final expenses = dbService.getSavedExpenses('trip_tokyo');
      expect(expenses.length, equals(1));
      expect(expenses.first['title'], equals('Ramen Dinner'));

      final outbox = dbService.getOutboxMutations();
      expect(outbox.length, equals(1));
      expect(outbox.first['id'], equals('mut_001'));

      final ledger = dbService.getProcessedOperationsLedger();
      expect(ledger.containsKey('op_atomic_tokyo_001'), isTrue);

      final tombstones = dbService.getDeletedExpenseTombstones('trip_tokyo');
      expect(tombstones.containsKey('exp_old_coffee'), isTrue);
    });

    test('7. Crash rollback verification: exception during transaction rolls back ALL stores', () {
      // 1. Initial stable state
      dbService.commitAtomicMutationBatch(
        updatedTrips: [
          {
            'id': 'trip_stable',
            'name': 'Initial Stable Trip',
            'creatorId': 'usr_stable',
            'inviteCode': 'STAB01',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        ],
      );

      expect(dbService.getSavedTrips().length, equals(1));

      // 2. Attempt a transaction that fails midway (simulating crash or constraint violation)
      expect(
        () => dbService.executeTransaction((db) {
          db.execute(
            "INSERT INTO trips (id, name, creator_id, invite_code, started_at, created_at, updated_at, raw_json) VALUES ('trip_crash', 'Crash Trip', 'usr_crash', 'CRSH01', 'now', 'now', 'now', '{}');",
          );
          // Throw simulated mid-batch process death / crash
          throw StateError('Simulated process crash / power loss mid-batch!');
        }),
        throwsA(isA<StateError>()),
      );

      // 3. Verify clean rollback: 'trip_crash' was NEVER committed!
      final tripsAfterCrash = dbService.getSavedTrips();
      expect(tripsAfterCrash.length, equals(1));
      expect(tripsAfterCrash.first['id'], equals('trip_stable'));
    });

    test('8. One-time resumable migration from SharedPreferences verifies counts, checksums, and zero duplicates', () async {
      SharedPreferences.setMockInitialValues({
        'kith_trips': jsonEncode([
          {
            'id': 'trip_paris',
            'name': 'Paris Getaway',
            'creatorId': 'usr_claire',
            'inviteCode': 'PARIS1',
            'members': [],
            'createdAt': '2026-05-01T10:00:00.000Z',
            'updatedAt': '2026-05-01T10:00:00.000Z',
          },
        ]),
        'kith_expenses_trip_paris': jsonEncode([
          {
            'id': 'exp_croissant',
            'tripId': 'trip_paris',
            'title': 'Croissant & Cafe',
            'amount': 15.5,
            'currency': 'EUR',
            'paidByMemberId': 'mbr_claire',
            'createdAt': '2026-05-01T11:00:00.000Z',
            'updatedAt': '2026-05-01T11:00:00.000Z',
          },
        ]),
        'kith_personal_expenses': jsonEncode([
          {
            'id': 'pe_metro',
            'title': 'Metro Ticket',
            'amount': 2.1,
            'currency': 'EUR',
            'spentAt': '2026-05-01T09:00:00.000Z',
          },
        ]),
        'kith_processed_ops_ledger': jsonEncode({
          'op_p1': {
            'operationId': 'op_p1',
            'payloadChecksum': 'chk_p1',
            'processedAt': '2026-05-01T10:00:00.000Z',
          },
        }),
      });

      final prefs = await SharedPreferences.getInstance();

      // Run migration
      final result = await dbService.migrateFromSharedPreferences(prefs);
      expect(result.isCompleted, isTrue);
      expect(result.alreadyMigrated, isFalse);
      expect(
        result.totalRecordsMigrated,
        equals(4),
      ); // 1 trip + 1 expense + 1 personal expense + 1 op
      expect(result.sourceChecksum.isNotEmpty, isTrue);

      // Verify records are present in SQLite
      expect(dbService.getSavedTrips().length, equals(1));
      expect(dbService.getSavedTrips().first['id'], equals('trip_paris'));
      expect(dbService.getSavedExpenses('trip_paris').length, equals(1));
      expect(dbService.getPersonalExpenses().length, equals(1));
      expect(dbService.getProcessedOperationsLedger().length, equals(1));

      // Verify SharedPreferences data was NOT deleted (30-day backup preserved)
      expect(prefs.getString('kith_trips'), isNotNull);

      // Idempotency test: Running migration a second time returns alreadyMigrated and creates NO duplicate records
      final result2 = await dbService.migrateFromSharedPreferences(prefs);
      expect(result2.isCompleted, isTrue);
      expect(result2.alreadyMigrated, isTrue);
      expect(dbService.getSavedTrips().length, equals(1));
      expect(dbService.getSavedExpenses('trip_paris').length, equals(1));
    });

    test('9. LocalStorageService routes personal expenses, debts, settlements and outbox directly to SQLite', () async {
      final dbService = LocalDatabaseService.inMemory();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await dbService.migrateFromSharedPreferences(prefs);

      final storage = LocalStorageService(prefs, databaseService: dbService);

      // Save personal expenses via LocalStorageService
      await storage.savePersonalExpenses([
        {
          'id': 'pe_01',
          'title': 'Coffee',
          'amount': 150.0,
          'currency': 'INR',
          'category': 'food',
          'spentAt': DateTime.now().toIso8601String(),
        },
      ]);

      // Verify authoritative SQLite read
      expect(storage.getSavedPersonalExpenses().length, equals(1));
      expect(dbService.getPersonalExpenses().length, equals(1));
      expect(dbService.getPersonalExpenses().first['id'], equals('pe_01'));

      // Save personal debts
      await storage.savePersonalDebts([
        {
          'id': 'pd_01',
          'personName': 'Alice',
          'amount': 500.0,
          'isOwedByMe': true,
          'isSettled': false,
        },
      ]);
      expect(storage.getSavedPersonalDebts().length, equals(1));
      expect(dbService.getPersonalDebts().length, equals(1));

      // Save settlements
      await storage.saveTripSettlements('trip_test', [
        {
          'id': 'stl_01',
          'tripId': 'trip_test',
          'fromMemberId': 'm1',
          'toMemberId': 'm2',
          'amount': 250.0,
          'isSettled': true,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      ]);
      expect(storage.getSavedTripSettlements('trip_test').length, equals(1));
      expect(dbService.getSavedSettlements('trip_test').length, equals(1));

      // Outbox queue clearance
      await storage.saveMutationQueue([
        {'id': 'mut_01', 'type': 'createTrip', 'tripId': 'trip_test'},
      ]);
      expect(dbService.getOutboxMutations().length, equals(1));
      await storage.clearMutationQueue();
      expect(dbService.getOutboxMutations().length, equals(0));
    });

    test('10. P2P secret rotation: Trip.mergeWith adopts newer rotated secret when revision increases', () {
      final oldTrip = Trip(
        id: 'trip_rot',
        name: 'Roadtrip',
        creatorId: 'u1',
        inviteCode: 'ROAD99',
        p2pTripSecret: '11111111111111111111111111111111',
        revision: 1,
        startedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        members: [],
      );

      final rotatedTrip = oldTrip.copyWith(
        p2pTripSecret: '22222222222222222222222222222222',
        revision: 2,
      );

      final merged = oldTrip.mergeWith(rotatedTrip);
      expect(merged.revision, equals(2));
      expect(merged.p2pTripSecret, equals('22222222222222222222222222222222'));

      // If other trip has older revision, our current secret is preserved
      final olderTrip = rotatedTrip.copyWith(
        p2pTripSecret: '00000000000000000000000000000000',
        revision: 1,
      );
      final merged2 = rotatedTrip.mergeWith(olderTrip);
      expect(merged2.revision, equals(2));
      expect(merged2.p2pTripSecret, equals('22222222222222222222222222222222'));
    });

    test('11. Downgrade attack prevention: modern v2 trip strictly rejects legacy v1 signature (No Downgrade)', () {
      final tripId = 'trip_modern_001';
      final inviteCode = 'SAFE99';
      final modernSecret = '0123456789abcdef0123456789abcdef';

      // Attacker has intercepted 6-character inviteCode, derives legacy v1 key
      final attackerV1Key = P2PSyncService.deriveTripAuthKey(
        tripId,
        inviteCode,
        p2pTripSecret: null,
      );
      final opId = 'op_attack_101';
      final payloadChecksum = 'checksum_tampered';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final forgedV1Sig = P2PSyncService.computeP2POperationSignature(
        authKey: attackerV1Key,
        protocolVersion: 'kith_p2p_v1',
        tripId: tripId,
        operationId: opId,
        senderDeviceId: 'dev_attacker',
        payloadChecksum: payloadChecksum,
        timestampMs: nowMs,
      );

      // Modern receiver has 128-bit secret
      final receiverV2Key = P2PSyncService.deriveTripAuthKey(
        tripId,
        inviteCode,
        p2pTripSecret: modernSecret,
      );

      // Modern receiver verifies with v2 key: MUST BE REJECTED
      final isAccepted = P2PSyncService.verifyP2POperationSignature(
        authKey: receiverV2Key,
        signature: forgedV1Sig,
        protocolVersion: 'kith_p2p_v1',
        tripId: tripId,
        operationId: opId,
        senderDeviceId: 'dev_attacker',
        payloadChecksum: payloadChecksum,
        timestampMs: nowMs,
      );
      expect(
        isAccepted,
        isFalse,
        reason: 'Modern trip must strictly reject v1 signatures and never downgrade',
      );
    });

    test('12. Secret rotation invalidates old v2 credentials (Old-secret replay rejection)', () {
      final tripId = 'trip_rot_002';
      final inviteCode = 'ROTA88';
      final oldSecret = '11111111111111111111111111111111';
      final newSecret = '22222222222222222222222222222222';

      // Operation signed with old secret before rotation
      final oldAuthKey = P2PSyncService.deriveTripAuthKey(
        tripId,
        inviteCode,
        p2pTripSecret: oldSecret,
      );
      final opId = 'op_stale_102';
      final payloadChecksum = 'checksum_stale';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final staleSig = P2PSyncService.computeP2POperationSignature(
        authKey: oldAuthKey,
        protocolVersion: 'kith_p2p_v1',
        tripId: tripId,
        operationId: opId,
        senderDeviceId: 'dev_stale_peer',
        payloadChecksum: payloadChecksum,
        timestampMs: nowMs,
      );

      // Receiver has rotated to new secret
      final rotatedAuthKey = P2PSyncService.deriveTripAuthKey(
        tripId,
        inviteCode,
        p2pTripSecret: newSecret,
      );

      final isStaleAccepted = P2PSyncService.verifyP2POperationSignature(
        authKey: rotatedAuthKey,
        signature: staleSig,
        protocolVersion: 'kith_p2p_v1',
        tripId: tripId,
        operationId: opId,
        senderDeviceId: 'dev_stale_peer',
        payloadChecksum: payloadChecksum,
        timestampMs: nowMs,
      );
      expect(
        isStaleAccepted,
        isFalse,
        reason: 'Rotated trip must reject signatures created with revoked old secret',
      );
    });

    test('13. Legitimate legacy trip compatibility: trip without p2pTripSecret authenticates via v1', () {
      final tripId = 'trip_legacy_003';
      final inviteCode = 'LEGA77';

      // Both legacy peers have no p2pTripSecret
      final legacySenderKey = P2PSyncService.deriveTripAuthKey(
        tripId,
        inviteCode,
        p2pTripSecret: null,
      );
      final opId = 'op_legacy_valid_103';
      final payloadChecksum = 'checksum_legit';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final legacySig = P2PSyncService.computeP2POperationSignature(
        authKey: legacySenderKey,
        protocolVersion: 'kith_p2p_v1',
        tripId: tripId,
        operationId: opId,
        senderDeviceId: 'dev_legacy_phone',
        payloadChecksum: payloadChecksum,
        timestampMs: nowMs,
      );

      final legacyReceiverKey = P2PSyncService.deriveTripAuthKey(
        tripId,
        inviteCode,
        p2pTripSecret: null,
      );

      final isLegacyAccepted = P2PSyncService.verifyP2POperationSignature(
        authKey: legacyReceiverKey,
        signature: legacySig,
        protocolVersion: 'kith_p2p_v1',
        tripId: tripId,
        operationId: opId,
        senderDeviceId: 'dev_legacy_phone',
        payloadChecksum: payloadChecksum,
        timestampMs: nowMs,
      );
      expect(
        isLegacyAccepted,
        isTrue,
        reason: 'Authentic legacy trip must accept valid v1 signatures',
      );
    });

    test('14. Legitimate legacy trip strictly rejects tampered payload or forged signature', () {
      final tripId = 'trip_legacy_004';
      final inviteCode = 'LEGA66';

      final legacyKey = P2PSyncService.deriveTripAuthKey(
        tripId,
        inviteCode,
        p2pTripSecret: null,
      );
      final opId = 'op_legacy_tamper_104';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final sig = P2PSyncService.computeP2POperationSignature(
        authKey: legacyKey,
        protocolVersion: 'kith_p2p_v1',
        tripId: tripId,
        operationId: opId,
        senderDeviceId: 'dev_legacy_phone',
        payloadChecksum: 'original_checksum',
        timestampMs: nowMs,
      );

      // Verifying with tampered payload checksum
      final isTamperAccepted = P2PSyncService.verifyP2POperationSignature(
        authKey: legacyKey,
        signature: sig,
        protocolVersion: 'kith_p2p_v1',
        tripId: tripId,
        operationId: opId,
        senderDeviceId: 'dev_legacy_phone',
        payloadChecksum: 'tampered_checksum_xyz',
        timestampMs: nowMs,
      );
      expect(
        isTamperAccepted,
        isFalse,
        reason: 'Legacy trip must reject tampered payload checksums',
      );
    });
  });
}
