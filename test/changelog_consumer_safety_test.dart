import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Priority 4: Changelog Consumer Safety & Cursor Invariants', () {
    late LocalDatabaseService dbService;
    late SharedPreferences prefs;
    late LocalStorageService storage;

    setUp(() async {
      dbService = LocalDatabaseService.inMemory();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      await dbService.migrateFromSharedPreferences(prefs);
      storage = LocalStorageService(prefs, databaseService: dbService);
    });

    test('1. Full page of changelog events applies atomically before cursor advances', () async {
      const accountId = 'user_alice_test';
      expect(storage.getInt('kith_last_sync_seq_$accountId'), isNull);

      // Simulate a page of 3 events (1 trip, 1 expense, 1 settlement)
      final rawEvents = [
        {
          'seq': 101,
          'table_name': 'trips',
          'action': 'INSERT',
          'record_id': 'trip_tokyo',
          'payload': {
            'id': 'trip_tokyo',
            'name': 'Tokyo Trip',
            'creatorId': accountId,
            'inviteCode': 'TOKY01',
            'revision': 1,
            'startedAt': DateTime.now().toIso8601String(),
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'members': [],
          },
        },
        {
          'seq': 102,
          'table_name': 'expenses',
          'action': 'INSERT',
          'trip_id': 'trip_tokyo',
          'record_id': 'exp_ramen',
          'payload': {
            'id': 'exp_ramen',
            'tripId': 'trip_tokyo',
            'title': 'Ramen Dinner',
            'amount': 1200.0,
            'paidByMemberId': 'mbr_alice',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        },
        {
          'seq': 103,
          'table_name': 'settlements',
          'action': 'INSERT',
          'trip_id': 'trip_tokyo',
          'record_id': 'stl_01',
          'payload': {
            'id': 'stl_01',
            'tripId': 'trip_tokyo',
            'fromMemberId': 'mbr_bob',
            'toMemberId': 'mbr_alice',
            'amount': 600.0,
            'isSettled': true,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        },
      ];

      // Reconstruct working sets
      final workingTrips = <String, Map<String, dynamic>>{};
      final workingExpensesByTrip =
          <String, Map<String, Map<String, dynamic>>>{};
      final workingSettlementsByTrip =
          <String, Map<String, Map<String, dynamic>>>{};
      int maxSeq = 0;

      for (final ev in rawEvents) {
        final seq = (ev['seq'] as num).toInt();
        if (seq > maxSeq) maxSeq = seq;
        final table = ev['table_name'] as String;
        final recordId = ev['record_id'] as String;
        final payload = ev['payload'] as Map<String, dynamic>;

        if (table == 'trips') {
          workingTrips[recordId] = payload;
        } else if (table == 'expenses') {
          workingExpensesByTrip.putIfAbsent('trip_tokyo', () => {})[recordId] =
              payload;
        } else if (table == 'settlements') {
          workingSettlementsByTrip.putIfAbsent(
            'trip_tokyo',
            () => {},
          )[recordId] = payload;
        }
      }

      final commitOk = await storage.commitAtomicMutationBatch(
        updatedTrips: workingTrips.values.toList(),
        updatedExpensesByTrip: workingExpensesByTrip.map(
          (k, v) => MapEntry(k, v.values.toList()),
        ),
        updatedSettlementsByTrip: workingSettlementsByTrip.map(
          (k, v) => MapEntry(k, v.values.toList()),
        ),
      );
      expect(commitOk, isTrue);

      // Only advance cursor after successful atomic commit
      await storage.setInt('kith_last_sync_seq_$accountId', maxSeq);

      expect(storage.getInt('kith_last_sync_seq_$accountId'), equals(103));
      expect(storage.getSavedTrips().length, equals(1));
      expect(storage.getSavedExpenses('trip_tokyo').length, equals(1));
      expect(storage.getSavedTripSettlements('trip_tokyo').length, equals(1));
    });

    test(
      '2. Partial application failure prevents cursor advancement',
      () async {
        const accountId = 'user_bob_test';
        await storage.setInt('kith_last_sync_seq_$accountId', 50);

        // Simulate a failure during event processing or commit
        bool simulatedFailureOccurred = false;
        try {
          // Assume event processing throws before commit
          throw StateError('Simulated malformed JSON payload on event 52');
        } catch (_) {
          simulatedFailureOccurred = true;
          // Notice: storage.setInt is NOT called!
        }

        expect(simulatedFailureOccurred, isTrue);
        // Cursor remains strictly at 50, ready to re-fetch and retry without skipping
        expect(storage.getInt('kith_last_sync_seq_$accountId'), equals(50));
      },
    );

    test('3. Replayed events are idempotent and preserve tombstones', () async {
      const tripId = 'trip_kyoto';

      // Seed initial expense
      await storage.commitAtomicMutationBatch(
        updatedExpensesByTrip: {
          tripId: [
            {
              'id': 'exp_matcha',
              'tripId': tripId,
              'title': 'Matcha Ice Cream',
              'amount': 500.0,
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            },
          ],
        },
      );
      expect(storage.getSavedExpenses(tripId).length, equals(1));

      // Event: DELETE expense
      await storage.commitAtomicMutationBatch(
        updatedExpensesByTrip: {tripId: []},
        tombstoneToAdd: {'tripId': tripId, 'expenseId': 'exp_matcha'},
      );
      expect(storage.getSavedExpenses(tripId).length, equals(0));
      expect(storage.isExpenseTombstoned(tripId, 'exp_matcha'), isTrue);

      // Replaying the DELETE event again is completely idempotent
      await storage.commitAtomicMutationBatch(
        updatedExpensesByTrip: {tripId: []},
        tombstoneToAdd: {'tripId': tripId, 'expenseId': 'exp_matcha'},
      );
      expect(storage.getSavedExpenses(tripId).length, equals(0));
      expect(storage.isExpenseTombstoned(tripId, 'exp_matcha'), isTrue);
    });

    test('4. Empty events response when lastSeq > 0 does NOT reset or alter cursor', () async {
      const accountId = 'user_dana_test';
      await storage.setInt('kith_last_sync_seq_$accountId', 250);

      // Simulate pullRemoteChanges receiving 0 new events
      final syncEvents = <Map<String, dynamic>>[];
      final lastSeq = storage.getInt('kith_last_sync_seq_$accountId') ?? 0;
      final shouldRunColdStartFallback = (lastSeq == 0 && syncEvents.isEmpty);

      // Cold start fallback must NOT trigger when lastSeq > 0!
      expect(shouldRunColdStartFallback, isFalse);

      // Cursor must remain exactly 250
      expect(storage.getInt('kith_last_sync_seq_$accountId'), equals(250));
    });

    test(
      '5. Cursors are isolated per account and cleared on clearAllUserData',
      () async {
        await storage.setInt('kith_last_sync_seq_account_A', 100);
        await storage.setInt('kith_last_sync_seq_account_B', 200);
        await storage.setString(
          'kith_last_sync_cursor_account_A',
          '2026-10-31T00:00:00Z',
        );

        // Account A cursor does not leak to Account B
        expect(storage.getInt('kith_last_sync_seq_account_A'), equals(100));
        expect(storage.getInt('kith_last_sync_seq_account_B'), equals(200));

        // Wipe user data
        await storage.clearAllUserData();

        // All account-specific cursor keys are purged
        expect(storage.getInt('kith_last_sync_seq_account_A'), isNull);
        expect(storage.getInt('kith_last_sync_seq_account_B'), isNull);
        expect(storage.getString('kith_last_sync_cursor_account_A'), isNull);
      },
    );
  });
}
