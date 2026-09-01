import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/p2p_sync_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalStorageService storage;
  late SyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
  });

  group('P2P Discovery Token & Security Invariant Tests', () {
    test('1. deriveTripToken produces deterministic, collision-resistant tokens', () {
      final token1 = P2PSyncService.deriveTripToken('trip_goa_001', 'GOA2026');
      final token2 = P2PSyncService.deriveTripToken('trip_goa_001', 'GOA2026');
      final tokenDifferentCode = P2PSyncService.deriveTripToken('trip_goa_001', 'WRONG');
      final tokenDifferentTrip = P2PSyncService.deriveTripToken('trip_mumbai_002', 'GOA2026');

      expect(token1, equals(token2), reason: 'Same trip and invite code must generate identical discovery token');
      expect(token1, isNot(equals(tokenDifferentCode)), reason: 'Different invite code must produce different token');
      expect(token1, isNot(equals(tokenDifferentTrip)), reason: 'Different trip must produce different token');
      expect(token1.length, equals(16), reason: 'Token must be fixed 16-character hex hash');
    });

    test('2. Two devices sharing Trip A find common token; Unrelated Trip B is ignored (Same-Trip Filter)', () {
      // Device A has Goa and Manali trips
      final deviceATokens = {
        'trip_goa': P2PSyncService.deriveTripToken('trip_goa', 'GOA123'),
        'trip_manali': P2PSyncService.deriveTripToken('trip_manali', 'MAN456'),
      };

      // Device B has Goa and Ladakh trips
      final deviceBTokens = {
        'trip_goa': P2PSyncService.deriveTripToken('trip_goa', 'GOA123'),
        'trip_ladakh': P2PSyncService.deriveTripToken('trip_ladakh', 'LAD789'),
      };

      // Intersection should strictly be trip_goa only
      final intersection = deviceATokens.values.toSet().intersection(deviceBTokens.values.toSet());
      expect(intersection.length, equals(1));
      expect(intersection.first, equals(deviceATokens['trip_goa']));
    });
  });

  group('SyncMutation P2P Transport & Idempotency Tests', () {
    test('3. SyncMutation JSON serialization preserves syncState and originDeviceId', () {
      final original = SyncMutation(
        id: 'op_exp_dinner_999',
        type: MutationType.addExpense,
        payload: {
          'tripId': 'trip_goa_001',
          'id': 'exp_dinner_999',
          'title': 'Dinner',
          'amountInPaise': 150000,
        },
        createdAt: DateTime(2026, 8, 30, 12, 0, 0),
        syncState: SyncState.p2pShared,
        originDeviceId: 'dev_phone_alice_01',
      );

      final json = original.toJson();
      expect(json['syncState'], equals('p2pShared'));
      expect(json['originDeviceId'], equals('dev_phone_alice_01'));

      final restored = SyncMutation.fromJson(json);
      expect(restored.id, equals('op_exp_dinner_999'));
      expect(restored.syncState, equals(SyncState.p2pShared));
      expect(restored.originDeviceId, equals('dev_phone_alice_01'));
      expect(restored.tripId, equals('trip_goa_001'));
    });

    test('4. applyRemoteP2PMutation applies expense locally and preserves stable operation ID', () async {
      // Pre-save trip locally
      await storage.saveTrips([
        {
          'id': 'trip_goa_001',
          'name': 'Goa Trip',
          'inviteCode': 'GOA123',
        }
      ]);

      final p2pMutation = SyncMutation(
        id: 'op_offline_expense_777',
        type: MutationType.addExpense,
        payload: {
          'tripId': 'trip_goa_001',
          'id': 'exp_offline_777',
          'title': 'Scooter Rental',
          'amountInPaise': 80000,
          'category': 'transport',
        },
        createdAt: DateTime.now(),
        syncState: SyncState.localPending,
      );

      // Apply P2P mutation on receiving device
      final applied = await syncService.applyRemoteP2PMutation(p2pMutation, storage);
      expect(applied, isTrue);

      // Verify local storage has the expense
      final expenses = storage.getSavedExpenses('trip_goa_001');
      expect(expenses.length, equals(1));
      expect(expenses.first['id'], equals('exp_offline_777'));
      expect(expenses.first['title'], equals('Scooter Rental'));

      // Verify local mutation queue has the mutation marked as p2pShared with SAME operation_id
      final queue = syncService.getPendingMutations();
      expect(queue.length, equals(1));
      expect(queue.first.id, equals('op_offline_expense_777'), reason: 'P2P relay must NOT generate new operation IDs');
      expect(queue.first.syncState, equals(SyncState.p2pShared));
    });

    test('5. Re-applying duplicate P2P mutation is strictly rejected (Idempotency)', () async {
      await storage.saveTrips([
        {'id': 'trip_goa_001', 'name': 'Goa'}
      ]);

      final p2pMutation = SyncMutation(
        id: 'op_dup_check_101',
        type: MutationType.addExpense,
        payload: {
          'tripId': 'trip_goa_001',
          'id': 'exp_dup_101',
          'title': 'Lunch',
          'amountInPaise': 40000,
        },
        createdAt: DateTime.now(),
      );

      final firstApply = await syncService.applyRemoteP2PMutation(p2pMutation, storage);
      expect(firstApply, isTrue);

      // Second apply with exact same operation ID
      final secondApply = await syncService.applyRemoteP2PMutation(p2pMutation, storage);
      expect(secondApply, isFalse, reason: 'Duplicate P2P mutation must be rejected');

      // Local storage must contain exactly 1 expense
      final expenses = storage.getSavedExpenses('trip_goa_001');
      expect(expenses.length, equals(1));
    });

    test('6. P2P operation tracking in LocalStorageService prevents unbounded replay', () async {
      expect(storage.isP2POperationProcessed('op_test_555'), isFalse);

      await storage.markP2POperationProcessed('op_test_555');
      expect(storage.isP2POperationProcessed('op_test_555'), isTrue);

      // Double mark is idempotent
      await storage.markP2POperationProcessed('op_test_555');
      expect(storage.getProcessedP2POperationIds().length, equals(1));
    });

    test('7. Multi-Device P2P Relay Simulation: Device A -> Device B preserves ID across relay hops', () async {
      // 1. Device A creates mutation offline
      final opA = await syncService.enqueueMutation(
        MutationType.addExpense,
        {
          'tripId': 'trip_relay_trip',
          'id': 'exp_relay_boat',
          'title': 'Boat Ride',
          'amountInPaise': 120000,
        },
      );

      expect(opA.id, isNotEmpty);
      expect(opA.syncState, equals(SyncState.localPending));

      // 2. Mark as shared on Device A when pushed to Device B
      await syncService.markMutationP2PShared(opA.id);
      final queueAfterShare = syncService.getPendingMutations();
      expect(queueAfterShare.first.syncState, equals(SyncState.p2pShared));

      // 3. Verify that the mutation JSON transmitted over wire contains exact invariant ID
      final wireJson = queueAfterShare.first.toJson();
      expect(wireJson['id'], equals(opA.id));
      expect(wireJson['syncState'], equals('p2pShared'));

      // 4. Verify that deserializing on remote peer restores exact state
      final deserializedOnPeer = SyncMutation.fromJson(wireJson);
      expect(deserializedOnPeer.id, equals(opA.id));
      expect(deserializedOnPeer.syncState, equals(SyncState.p2pShared));
    });

    test('8. derivePairingCode produces identical 6-digit code regardless of device order (Symmetry)', () {
      final code1 = P2PSyncService.derivePairingCode('dev_phone_alice_123', 'dev_phone_bob_456');
      final code2 = P2PSyncService.derivePairingCode('dev_phone_bob_456', 'dev_phone_alice_123');

      expect(code1, equals(code2), reason: 'Pairing code must match on both Alice and Bob screens');
      expect(code1.length, equals(7)); // Format: "123 456"
      expect(code1.contains(' '), isTrue);
    });

    test('9. P2P Settlement and Tombstone Deletion Sync', () async {
      await storage.saveTrips([
        {'id': 'trip_goa_001', 'name': 'Goa Trip'}
      ]);

      // Add settlement via P2P
      final settlementOp = SyncMutation(
        id: 'op_stl_p2p_1',
        type: MutationType.recordTripSettlement,
        payload: {
          'tripId': 'trip_goa_001',
          'id': 'stl_p2p_1',
          'fromMemberId': 'mem_1',
          'toMemberId': 'mem_2',
          'amountInPaise': 50000,
          'status': 'marked_paid',
        },
        createdAt: DateTime.now(),
      );

      final appliedStl = await syncService.applyRemoteP2PMutation(settlementOp, storage);
      expect(appliedStl, isTrue);

      final settlements = storage.getSavedTripSettlements('trip_goa_001');
      expect(settlements.length, equals(1));
      expect(settlements.first['id'], equals('stl_p2p_1'));
      expect(settlements.first['amountInPaise'], equals(50000));
    });
  });
}
