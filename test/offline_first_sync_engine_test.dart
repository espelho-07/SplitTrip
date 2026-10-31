import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    syncService = SyncService(storage);
  });

  group('Offline-First Sync Engine — Unit & Integration Test Suite', () {
    test('1. Transactional Atomic Multi-Store Commit guarantees consistency', () async {
      final tripId = 'trip_atomic_1';
      final initialTrips = [
        {'id': tripId, 'name': 'Manali Expedition', 'creatorId': 'u1'}
      ];
      final initialExpenses = [
        {
          'id': 'exp_1',
          'tripId': tripId,
          'title': 'Hotel Booking',
          'amountInPaise': 450000,
          'payerId': 'u1',
          'splits': [
            {'userId': 'u1', 'amountInPaise': 225000},
            {'userId': 'u2', 'amountInPaise': 225000},
          ],
        }
      ];
      final initialSettlements = [
        {
          'id': 'stl_1',
          'tripId': tripId,
          'payerId': 'u2',
          'payeeId': 'u1',
          'amountInPaise': 225000,
          'isSettled': true,
        }
      ];
      final processedRecord = ProcessedOperationRecord(
        operationId: 'op_init_100',
        payloadChecksum: 'chk_12345',
        processedAt: DateTime.now(),
        source: 'local',
      );

      final ok = await storage.commitAtomicMutationBatch(
        updatedTrips: initialTrips,
        updatedExpensesByTrip: {tripId: initialExpenses},
        updatedSettlementsByTrip: {tripId: initialSettlements},
        recordToMarkProcessed: processedRecord,
        tombstoneToAdd: {'tripId': tripId, 'expenseId': 'exp_old_deleted'},
      );

      expect(ok, isTrue);

      // Verify all stores updated in exact atomic batch
      expect(storage.getSavedTrips().length, 1);
      expect(storage.getSavedTrips().first['name'], 'Manali Expedition');
      expect(storage.getSavedExpenses(tripId).length, 1);
      expect(storage.getSavedExpenses(tripId).first['title'], 'Hotel Booking');
      expect(storage.getSavedTripSettlements(tripId).length, 1);
      expect(storage.isExpenseTombstoned(tripId, 'exp_old_deleted'), isTrue);

      // Check authoritative ledger
      final opStatus = storage.checkOperationStatus('op_init_100', 'chk_12345');
      expect(opStatus.isProcessed, isTrue);
      expect(opStatus.isMismatch, isFalse);
    });

    test('2. Idempotency & SHA-256 Checksum Tampering Protection', () {
      final payload1 = {
        'id': 'exp_sha_1',
        'tripId': 'trip_1',
        'title': 'Rafting',
        'amountInPaise': 120000,
      };

      // Inverted key order should produce EXACT same canonical checksum
      final payload2 = {
        'amountInPaise': 120000,
        'title': 'Rafting',
        'tripId': 'trip_1',
        'id': 'exp_sha_1',
      };

      final checksum1 = SyncMutation.computePayloadChecksum(payload1);
      final checksum2 = SyncMutation.computePayloadChecksum(payload2);

      expect(checksum1, equals(checksum2));
      expect(checksum1.length, 64); // Valid SHA-256 hex string

      // Modifying financial amount changes the checksum
      final tamperedPayload = {
        'id': 'exp_sha_1',
        'tripId': 'trip_1',
        'title': 'Rafting',
        'amountInPaise': 999999, // Tampered paise amount!
      };
      final tamperedChecksum = SyncMutation.computePayloadChecksum(tamperedPayload);
      expect(tamperedChecksum, isNot(equals(checksum1)));
    });

    test('3. Ledger detects payload mismatch for reused operation IDs', () async {
      final opId = 'mutation_uuid_999';
      final validChecksum = 'checksum_original_sha256';

      await storage.recordProcessedOperation(ProcessedOperationRecord(
        operationId: opId,
        payloadChecksum: validChecksum,
        processedAt: DateTime.now(),
        source: 'cloud',
      ));

      // Re-applying with identical checksum is recognized as processed without error
      final statusMatch = storage.checkOperationStatus(opId, validChecksum);
      expect(statusMatch.isProcessed, isTrue);
      expect(statusMatch.isMismatch, isFalse);

      // Re-applying with a mismatched checksum indicates payload tampering / conflicting reuse
      final statusMismatch = storage.checkOperationStatus(opId, 'checksum_tampered_different');
      expect(statusMismatch.isProcessed, isTrue);
      expect(statusMismatch.isMismatch, isTrue);
    });

    test('4. Per-Trip Mutex Locking serializes same trip and parallels distinct trips', () async {
      final tripAEvents = <String>[];
      final tripBEvents = <String>[];

      // Two operations on Trip A: should execute strictly sequentially
      final tripAFuture1 = syncService.runWithTripLock('trip_A', () async {
        tripAEvents.add('A1_start');
        await Future.delayed(const Duration(milliseconds: 30));
        tripAEvents.add('A1_end');
      });

      final tripAFuture2 = syncService.runWithTripLock('trip_A', () async {
        tripAEvents.add('A2_start');
        await Future.delayed(const Duration(milliseconds: 10));
        tripAEvents.add('A2_end');
      });

      // An operation on Trip B: should execute concurrently with Trip A without being blocked
      final tripBFuture = syncService.runWithTripLock('trip_B', () async {
        tripBEvents.add('B1_start');
        await Future.delayed(const Duration(milliseconds: 15));
        tripBEvents.add('B1_end');
      });

      await Future.wait([tripAFuture1, tripAFuture2, tripBFuture]);

      // Trip A was strictly serialized: A1 completed before A2 started
      expect(tripAEvents, ['A1_start', 'A1_end', 'A2_start', 'A2_end']);
      // Trip B executed independently
      expect(tripBEvents, ['B1_start', 'B1_end']);
    });

    test('5. P2P Mesh Loop Prevention drops packets that traversed this node', () async {
      final myDeviceId = storage.getDeviceId();

      // Mutation that includes myDeviceId in forwardedBy
      final loopedMutation = SyncMutation(
        id: 'op_loop_1',
        type: MutationType.addExpense,
        payload: {'tripId': 'trip_mesh', 'id': 'e1', 'amountInPaise': 5000},
        createdAt: DateTime.now(),
        forwardedBy: ['device_peer_1', myDeviceId, 'device_peer_2'],
      );

      final applied = await syncService.applyRemoteP2PMutation(loopedMutation, storage);
      expect(applied, isFalse, reason: 'Must drop looped packet containing current deviceId');

      // Mutation originating from this device
      final selfOriginMutation = SyncMutation(
        id: 'op_self_1',
        type: MutationType.addExpense,
        payload: {'tripId': 'trip_mesh', 'id': 'e2', 'amountInPaise': 5000},
        createdAt: DateTime.now(),
        originDeviceId: myDeviceId,
      );

      final appliedSelf = await syncService.applyRemoteP2PMutation(selfOriginMutation, storage);
      expect(appliedSelf, isFalse, reason: 'Must drop packet originating from this device');
    });

    test('6. P2P Mesh Hop Count Limit drops packets exceeding 5 hops', () async {
      // 5 hops reached (exceeds mesh propagation radius)
      final maxHopMutation = SyncMutation(
        id: 'op_hop_max',
        type: MutationType.addExpense,
        payload: {'tripId': 'trip_mesh', 'id': 'e3', 'amountInPaise': 5000},
        createdAt: DateTime.now(),
        hopCount: 5,
        forwardedBy: ['d1', 'd2', 'd3', 'd4', 'd5'],
      );

      final applied = await syncService.applyRemoteP2PMutation(maxHopMutation, storage);
      expect(applied, isFalse, reason: 'Must drop mutation with hopCount >= 5');
    });

    test('7. P2P Store-and-Forward relays mutations to outbox with incremented hop count', () async {
      final peerMutation = SyncMutation(
        id: 'op_relay_1',
        type: MutationType.addExpense,
        payload: {
          'id': 'exp_relay_100',
          'tripId': 'trip_relay',
          'title': 'Chai & Snacks',
          'amountInPaise': 18000,
          'payerId': 'user_peer',
        },
        createdAt: DateTime.now(),
        hopCount: 1,
        forwardedBy: ['device_peer_A'],
      );

      final applied = await syncService.applyRemoteP2PMutation(peerMutation, storage);
      expect(applied, isTrue);

      // Verify domain state applied locally
      final expenses = storage.getSavedExpenses('trip_relay');
      expect(expenses.length, 1);
      expect(expenses.first['title'], 'Chai & Snacks');

      // Verify enqueued into local outbox for store-and-forward to other peers and cloud
      final pendingQueue = syncService.getPendingMutations();
      final relayed = pendingQueue.firstWhere((m) => m.id == 'op_relay_1');
      expect(relayed.syncState, SyncState.p2pShared);
      expect(relayed.hopCount, 2); // Incremented hop count
      expect(relayed.forwardedBy.contains(storage.getDeviceId()), isTrue);

      // Verify recorded in authoritative ledger
      final opStatus = storage.checkOperationStatus('op_relay_1', peerMutation.payloadChecksum);
      expect(opStatus.isProcessed, isTrue);
    });

    test('8. Deletion Tombstone protects against stale P2P/Cloud resurrection', () async {
      final tripId = 'trip_tombstone_test';
      final expId = 'exp_deleted_permanent';

      // Tombstone marked locally
      await storage.markExpenseTombstoned(tripId, expId);
      expect(storage.isExpenseTombstoned(tripId, expId), isTrue);

      // Stale peer arrives with an older version of the deleted expense
      final staleAddMutation = SyncMutation(
        id: 'op_stale_resurrect',
        type: MutationType.addExpense,
        payload: {
          'id': expId,
          'tripId': tripId,
          'title': 'Resurrected Ghost Expense',
          'amountInPaise': 75000,
        },
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final applied = await syncService.applyRemoteP2PMutation(staleAddMutation, storage);
      expect(applied, isFalse, reason: 'Must never resurrect a tombstoned expense');

      final expenses = storage.getSavedExpenses(tripId);
      expect(expenses.any((e) => e['id'] == expId), isFalse);
    });

    test('9. Five-Device Mesh Convergence Simulation (Zero Lost Paise, Deterministic State)', () async {
      // Simulation:
      // Phone A is offline in mountains, records Expense 1 (₹1,500)
      // Phone A connects to Phone B via P2P -> Phone B learns Expense 1
      // Phone B connects to Phone C via P2P -> Phone C learns Expense 1
      // Phone C connects to Phone D and Phone E -> all receive Expense 1
      // Verify:
      // 1. All devices have exact same expense ID and paise amount
      // 2. Hop count accurately tracks propagation
      // 3. No device accepts duplicates or double-charges balance

      // Phone A
      SharedPreferences.setMockInitialValues({});
      final storageA = await LocalStorageService.init();
      await storageA.saveDeviceId('device_A');
      final syncA = SyncService(storageA);

      final expA = {
        'id': 'exp_mountain_lunch',
        'tripId': 'trip_himalaya',
        'title': 'Mountain Dhaba Lunch',
        'amountInPaise': 150000,
        'payerId': 'user_A',
      };
      await syncA.enqueueMutation(MutationType.addExpense, expA);
      await storageA.saveExpenses('trip_himalaya', [expA]);

      final mutationA = syncA.getPendingMutations().first;

      // Phone B
      SharedPreferences.setMockInitialValues({});
      final storageB = await LocalStorageService.init();
      await storageB.saveDeviceId('device_B');
      final syncB = SyncService(storageB);

      // Sync A -> B
      final appliedB = await syncB.applyRemoteP2PMutation(mutationA, storageB);
      expect(appliedB, isTrue);
      final mutationB = syncB.getPendingMutations().firstWhere((m) => m.id == mutationA.id);
      expect(mutationB.hopCount, 1);

      // Phone C
      SharedPreferences.setMockInitialValues({});
      final storageC = await LocalStorageService.init();
      await storageC.saveDeviceId('device_C');
      final syncC = SyncService(storageC);

      // Sync B -> C
      final appliedC = await syncC.applyRemoteP2PMutation(mutationB, storageC);
      expect(appliedC, isTrue);
      final mutationC = syncC.getPendingMutations().firstWhere((m) => m.id == mutationA.id);
      expect(mutationC.hopCount, 2);

      // Phone D
      SharedPreferences.setMockInitialValues({});
      final storageD = await LocalStorageService.init();
      await storageD.saveDeviceId('device_D');
      final syncD = SyncService(storageD);

      // Sync C -> D
      final appliedD = await syncD.applyRemoteP2PMutation(mutationC, storageD);
      expect(appliedD, isTrue);
      final mutationD = syncD.getPendingMutations().firstWhere((m) => m.id == mutationA.id);
      expect(mutationD.hopCount, 3);

      // Phone E
      SharedPreferences.setMockInitialValues({});
      final storageE = await LocalStorageService.init();
      await storageE.saveDeviceId('device_E');
      final syncE = SyncService(storageE);

      // Sync D -> E
      final appliedE = await syncE.applyRemoteP2PMutation(mutationD, storageE);
      expect(appliedE, isTrue);
      final mutationE = syncE.getPendingMutations().firstWhere((m) => m.id == mutationA.id);
      expect(mutationE.hopCount, 4);

      // Verify convergence: Every phone has exactly 1 expense with ₹1500 (150000 paise)
      for (final s in [storageA, storageB, storageC, storageD, storageE]) {
        final list = s.getSavedExpenses('trip_himalaya');
        expect(list.length, 1);
        expect(list.first['id'], 'exp_mountain_lunch');
        expect(list.first['amountInPaise'], 150000);
      }

      // If Phone E attempts to send back to Phone A, Phone A rejects it immediately (loop prevention)
      final reAppliedA = await syncA.applyRemoteP2PMutation(mutationE, storageA);
      expect(reAppliedA, isFalse, reason: 'Phone A rejects looped mutation with its deviceId in forwardedBy or origin');
    });
  });
}
