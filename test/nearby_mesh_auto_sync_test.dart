import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/p2p_sync_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/presentation/views/trip/widgets/nearby_trip_friends_radar_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late P2PSyncService p2pService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
    p2pService = P2PSyncService(storage, syncService, deviceId: 'test_dev_01');

    // Seed mock trip with 10 members
    final tripJson = {
      'id': 'trip_mesh_101',
      'name': 'Himalayan Trek 2026',
      'inviteCode': 'TREK99',
      'currency': 'INR',
      'lifecycleState': 'active',
      'members': [
        {'id': 'u1', 'displayName': 'Rahul', 'role': 'admin', 'joinedAt': DateTime.now().toIso8601String()},
        {'id': 'u2', 'displayName': 'Priya', 'role': 'member', 'joinedAt': DateTime.now().toIso8601String()},
        {'id': 'u3', 'displayName': 'Aditya', 'role': 'member', 'joinedAt': DateTime.now().toIso8601String()},
        {'id': 'u4', 'displayName': 'Sneha', 'role': 'member', 'joinedAt': DateTime.now().toIso8601String()},
        {'id': 'u5', 'displayName': 'Vikram', 'role': 'member', 'joinedAt': DateTime.now().toIso8601String()},
        {'id': 'u6', 'displayName': 'Ananya', 'role': 'member', 'joinedAt': DateTime.now().toIso8601String()},
        {'id': 'u7', 'displayName': 'Rohan', 'role': 'member', 'joinedAt': DateTime.now().toIso8601String()},
        {'id': 'u8', 'displayName': 'Tanvi', 'role': 'member', 'joinedAt': DateTime.now().toIso8601String()},
        {'id': 'u9', 'displayName': 'Kunal', 'role': 'member', 'joinedAt': DateTime.now().toIso8601String()},
        {'id': 'u10', 'displayName': 'Meera', 'role': 'member', 'joinedAt': DateTime.now().toIso8601String()},
      ],
      'creatorId': 'u1',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await storage.saveTrips([tripJson]);
    await storage.saveUser({
      'id': 'u1',
      'displayName': 'Rahul',
      'email': 'rahul@kith.local',
    });
  });

  tearDown(() async {
    await p2pService.stop();
  });

  group('Offline Mesh & Nearby Sync Engine Unit Tests', () {
    test('1. Derives deterministic trip token and pairing code', () {
      final token1 = P2PSyncService.deriveTripToken('trip_mesh_101', 'TREK99');
      final token2 = P2PSyncService.deriveTripToken('trip_mesh_101', 'TREK99');
      expect(token1, equals(token2));
      expect(token1.length, 16);

      final pairCode = P2PSyncService.derivePairingCode('device_A', 'device_B');
      expect(pairCode.length, 7); // 'XXX XXX'
    });

    test('2. Prevents duplicate expenses and enforces tombstone delete protection', () async {
      final tripId = 'trip_mesh_101';

      // 1. Add expense via P2P mutation
      final expMutation = SyncMutation(
        id: 'exp_mesh_001',
        type: MutationType.addExpense,
        payload: {
          'id': 'exp_mesh_001',
          'tripId': tripId,
          'title': 'Campfire Wood',
          'amountInPaise': 45000,
          'paidByMemberId': 'u1',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      );

      final appliedFirst = await syncService.applyRemoteP2PMutation(expMutation, storage);
      expect(appliedFirst, isTrue);

      final savedExpenses = storage.getSavedExpenses(tripId);
      expect(savedExpenses.length, 1);
      expect(savedExpenses.first['title'], 'Campfire Wood');

      // 2. Replay same mutation -> Should be idempotently rejected (zero duplication)
      await storage.markP2POperationProcessed(expMutation.id);
      final appliedSecond = await syncService.applyRemoteP2PMutation(expMutation, storage);
      expect(appliedSecond, isFalse);
      expect(storage.getSavedExpenses(tripId).length, 1);

      // 3. Delete expense -> Creates tombstone
      final delMutation = SyncMutation(
        id: 'del_mesh_001',
        type: MutationType.deleteExpense,
        payload: {
          'id': 'exp_mesh_001',
          'tripId': tripId,
        },
        createdAt: DateTime.now(),
      );

      final delApplied = await syncService.applyRemoteP2PMutation(delMutation, storage);
      expect(delApplied, isTrue);
      expect(storage.getSavedExpenses(tripId).isEmpty, isTrue);
      expect(storage.isExpenseTombstoned(tripId, 'exp_mesh_001'), isTrue);

      // 4. Stale peer re-sends original addExpense -> Tombstone rejects resurrection!
      final staleResurrect = SyncMutation(
        id: 'exp_mesh_001_stale_replay',
        type: MutationType.addExpense,
        payload: {
          'id': 'exp_mesh_001',
          'tripId': tripId,
          'title': 'Campfire Wood',
        },
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      final resurrectApplied = await syncService.applyRemoteP2PMutation(staleResurrect, storage);
      expect(resurrectApplied, isFalse);
      expect(storage.getSavedExpenses(tripId).isEmpty, isTrue);
    });

    test('3. syncAllNearbyPeers returns empty result when no peers in range', () async {
      final res = await p2pService.syncAllNearbyPeers(targetTripId: 'trip_mesh_101');
      expect(res.success, isTrue);
      expect(res.totalPeersSynced, 0);
      expect(res.operationsSent, 0);
      expect(res.operationsReceived, 0);
    });
  });

  group('NearbyTripFriendsRadarSheet UI Widget Tests', () {
    testWidgets('4. Renders radar graphic, 10 trip members, and Sync All button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final trips = storage.getSavedTrips();
      final trip = Trip.fromJson(trips.first);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearbyTripFriendsRadarSheet(
              trip: trip,
              p2pService: p2pService,
              syncService: syncService,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Radar title, trip name, member count
      expect(find.text('Nearby Trip Friends'), findsOneWidget);
      expect(find.text('Himalayan Trek 2026 • 0 in range'), findsOneWidget);
      expect(find.text('ELIGIBLE KITH MEMBERS (10)'), findsOneWidget);

      // Verify members are displayed
      expect(find.text('Rahul'), findsOneWidget);
      expect(find.text('Priya'), findsOneWidget);
      expect(find.text('Aditya'), findsOneWidget);

      // Verify bottom button
      expect(find.text('No Friends in Range'), findsOneWidget);
    });
  });
}
