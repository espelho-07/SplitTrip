import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/p2p_sync_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/presentation/views/trip/widgets/trip_sync_sheet.dart';
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
    p2pService = P2PSyncService(storage, syncService);
  });

  tearDown(() async {
    await p2pService.stop();
  });

  group('1. Offline Sync Invariants & Multi-Source Reconciliation', () {
    test('reconcileTripWithAllSources marks offline state and queued count when offline', () async {
      // Seed an offline mutation
      await syncService.enqueueMutation(
        MutationType.addExpense,
        {
          'id': 'exp_123',
          'tripId': 'trip_abc',
          'amountInPaise': 50000,
          'title': 'Dinner',
        },
      );

      // Reconcile with null ApiClient (offline)
      final report = await syncService.reconcileTripWithAllSources(
        tripId: 'trip_abc',
        apiClient: null,
        p2pService: p2pService,
      );

      expect(report.isFullySynced, isFalse);
      expect(report.pendingChangesCount, 1);
      expect(report.sources.length, 1);
      expect(report.sources.first.type, SyncSourceType.cloud);
      expect(report.sources.first.status, 'offline');
      expect(report.sources.first.isSuccess, isFalse);
    });

    test('reconcileTripWithAllSources records structured sync logs', () async {
      await syncService.reconcileTripWithAllSources(
        tripId: 'trip_test_logs',
        apiClient: null,
        p2pService: p2pService,
      );

      final logs = storage.getSyncLogs(tripId: 'trip_test_logs');
      expect(logs.isNotEmpty, isTrue);
      expect(logs.first['tripId'], 'trip_test_logs');
      expect(logs.first['status'], 'offline');
    });

    test('Sync logs persistence limit and retrieval', () async {
      for (int i = 0; i < 15; i++) {
        await storage.addSyncLog(
          source: 'Test Source',
          status: 'synced',
          changesSent: i,
          changesReceived: i * 2,
          tripId: 'trip_$i',
          details: 'Details for log $i',
        );
      }

      final allLogs = storage.getSyncLogs(limit: 50);
      expect(allLogs.length, 15);
      expect(allLogs.first['changesSent'], 14);

      final specificTripLogs = storage.getSyncLogs(tripId: 'trip_5');
      expect(specificTripLogs.length, 1);
      expect(specificTripLogs.first['changesSent'], 5);

      await storage.clearSyncLogs();
      expect(storage.getSyncLogs(), isEmpty);
    });
  });

  group('2. P2P Sync Service & Pairing Verification', () {
    test('Pairing code is deterministic for any pair of device IDs', () {
      const devA = 'dev_alpha_111';
      const devB = 'dev_beta_222';

      final code1 = P2PSyncService.derivePairingCode(devA, devB);
      final code2 = P2PSyncService.derivePairingCode(devB, devA);

      expect(code1, equals(code2));
      expect(code1.length, 7); // 'XXX XXX' format
    });

    test('deriveTripToken produces same token for matching trip ID and invite code', () {
      const tripId = 'trip_goa_2026';
      const code = 'GOA999';

      final token1 = P2PSyncService.deriveTripToken(tripId, code);
      final token2 = P2PSyncService.deriveTripToken(tripId, code);
      final tokenDiff = P2PSyncService.deriveTripToken(tripId, 'OTHER');

      expect(token1, equals(token2));
      expect(token1, isNot(equals(tokenDiff)));
    });

    test('applyRemoteP2PMutation applies createTrip and addExpense idempotently without duplication', () async {
      final tripMutation = SyncMutation(
        id: 'mut_create_trip_1',
        type: MutationType.createTrip,
        payload: {
          'id': 'trip_p2p_1',
          'name': 'P2P Trek',
          'currencyCode': 'INR',
          'members': [
            {'id': 'mbr_1', 'displayName': 'Alice', 'role': 'creator'},
          ],
        },
        createdAt: DateTime.now(),
      );

      final appliedFirst = await syncService.applyRemoteP2PMutation(tripMutation, storage);
      expect(appliedFirst, isTrue);

      final trips = storage.getSavedTrips();
      expect(trips.any((t) => t['id'] == 'trip_p2p_1'), isTrue);

      // Second application is blocked by idempotency replay protection
      final appliedSecond = await syncService.applyRemoteP2PMutation(tripMutation, storage);
      expect(appliedSecond, isFalse);

      // Now apply an expense for this trip
      final expenseMutation = SyncMutation(
        id: 'mut_exp_p2p_1',
        type: MutationType.addExpense,
        payload: {
          'id': 'exp_p2p_1',
          'tripId': 'trip_p2p_1',
          'title': 'Rafting Ticket',
          'amountInPaise': 250000,
        },
        createdAt: DateTime.now(),
      );

      final expApplied = await syncService.applyRemoteP2PMutation(expenseMutation, storage);
      expect(expApplied, isTrue);

      final savedExpenses = storage.getSavedExpenses('trip_p2p_1');
      expect(savedExpenses.length, 1);
      expect(savedExpenses.first['title'], 'Rafting Ticket');
    });
  });

  group('3. TripSyncSheet UI Rendering', () {
    testWidgets('TripSyncSheet renders offline banner when offline without fake synced message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSyncSheet(
              tripId: 'trip_sheet_test',
              syncService: syncService,
              p2pService: p2pService,
              apiClient: null,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Trip Synchronization'), findsOneWidget);
      expect(find.text('Kith Cloud (Supabase)'), findsOneWidget);
      expect(find.text('Offline Mode • Changes Queued'), findsOneWidget);
      expect(find.text('All Sources Synchronized 🎉'), findsNothing);
      expect(find.text('Search Nearby / Bluetooth Devices'), findsOneWidget);
    });
  });
}
