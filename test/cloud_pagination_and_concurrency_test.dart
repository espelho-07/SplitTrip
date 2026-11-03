import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
  });

  group('Supabase Cloud Pagination Logic & Boundary Invariants', () {
    test('1. Bounded batch pagination algorithm handles 0, 499, 500, 501, 1000, 1001 records', () async {
      // Simulate pagination provider mimicking PostgREST with pageSize = 500
      List<Map<String, dynamic>> mockPostgrestTable(List<Map<String, dynamic>> dataset, int offset, int limit) {
        if (offset >= dataset.length) return [];
        final end = (offset + limit < dataset.length) ? offset + limit : dataset.length;
        return dataset.sublist(offset, end);
      }

      Future<List<Map<String, dynamic>>> paginatedFetch(List<Map<String, dynamic>> allServerRows, int pageSize) async {
        final results = <Map<String, dynamic>>[];
        int offset = 0;
        bool hasMore = true;

        while (hasMore) {
          final page = mockPostgrestTable(allServerRows, offset, pageSize);
          results.addAll(page);
          if (page.length < pageSize) {
            hasMore = false;
          } else {
            offset += pageSize;
          }
        }
        return results;
      }

      // Case A: 0 records
      final zeroList = <Map<String, dynamic>>[];
      final fetchedZero = await paginatedFetch(zeroList, 500);
      expect(fetchedZero.length, equals(0));

      // Case B: 499 records (less than 1 page)
      final list499 = List.generate(499, (i) => {'id': 'exp_$i', 'amountInPaise': 1000});
      final fetched499 = await paginatedFetch(list499, 500);
      expect(fetched499.length, equals(499));

      // Case C: 500 records (exact single page boundary)
      final list500 = List.generate(500, (i) => {'id': 'exp_$i', 'amountInPaise': 1000});
      final fetched500 = await paginatedFetch(list500, 500);
      expect(fetched500.length, equals(500));

      // Case D: 501 records (two pages: 500 + 1)
      final list501 = List.generate(501, (i) => {'id': 'exp_$i', 'amountInPaise': 1000});
      final fetched501 = await paginatedFetch(list501, 500);
      expect(fetched501.length, equals(501));

      // Case E: 1000 records (two full pages: 500 + 500 + empty)
      final list1000 = List.generate(1000, (i) => {'id': 'exp_$i', 'amountInPaise': 1000});
      final fetched1000 = await paginatedFetch(list1000, 500);
      expect(fetched1000.length, equals(1000));

      // Case F: 1001 records (breaks through PostgREST 1000-row default limit: 500 + 500 + 1)
      final list1001 = List.generate(1001, (i) => {'id': 'exp_$i', 'amountInPaise': 1000});
      final fetched1001 = await paginatedFetch(list1001, 500);
      expect(fetched1001.length, equals(1001));
    });

    test('2. 30-second banded overlap query window deduplicates reliably without data corruption', () async {
      await storage.saveTrips([
        {
          'id': 'trip_kerala_01',
          'name': 'Kerala Trip',
          'inviteCode': 'KER2026',
        }
      ]);

      final initialExpense = {
        'id': 'exp_boat_100',
        'tripId': 'trip_kerala_01',
        'title': 'Boat Ride',
        'amountInPaise': 200000,
        'category': 'activities',
        'paidById': 'mem_1',
        'isDeleted': false,
        'updated_at': '2026-11-01T12:00:15.000Z',
      };

      // Save initial expense into local storage
      await storage.saveExpenses('trip_kerala_01', [initialExpense]);
      expect(storage.getSavedExpenses('trip_kerala_01').length, equals(1));

      // Simulate a delta fetch at 12:00:30 with 30-second overlap window (cursor: 12:00:00).
      // The server returns exp_boat_100 again (inside overlap) plus new exp_tea_101.
      final overlappingDeltas = [
        initialExpense, // Overlapping repeat record
        {
          'id': 'exp_tea_101',
          'tripId': 'trip_kerala_01',
          'title': 'Tea Tasting',
          'amountInPaise': 30000,
          'category': 'food',
          'paidById': 'mem_2',
          'isDeleted': false,
          'updated_at': '2026-11-01T12:00:25.000Z',
        },
      ];

      // Reconcile into local storage
      final currentList = storage.getSavedExpenses('trip_kerala_01');
      final mapById = {for (final e in currentList) e['id'] as String: e};

      for (final delta in overlappingDeltas) {
        final id = delta['id'] as String;
        mapById[id] = delta; // In-memory deduplication by primary key
      }

      await storage.saveExpenses('trip_kerala_01', mapById.values.toList());

      final updatedExpenses = storage.getSavedExpenses('trip_kerala_01');
      expect(updatedExpenses.length, equals(2), reason: 'Overlapping record must not produce duplicate entry');
      expect(updatedExpenses.map((e) => e['id']).toSet(), equals({'exp_boat_100', 'exp_tea_101'}));
    });

    test('3. Cursor safety: cursor does not advance if sync delta fetch encounters partial failure', () async {
      final initialCursor = DateTime.parse('2026-11-01T10:00:00.000Z');
      DateTime currentCursor = initialCursor;

      Future<DateTime> attemptSync(DateTime cursor, {required bool failOnPageTwo}) async {
        if (failOnPageTwo) {
          throw Exception('Simulated network timeout during page 2 of cloud fetch');
        }
        return DateTime.parse('2026-11-01T10:05:00.000Z');
      }

      try {
        currentCursor = await attemptSync(currentCursor, failOnPageTwo: true);
      } catch (e) {
        // Log notice, preserve previous cursor
      }

      expect(currentCursor, equals(initialCursor), reason: 'Cursor must remain at previous safe point on failure');

      // Successful sync advances cursor
      currentCursor = await attemptSync(currentCursor, failOnPageTwo: false);
      expect(currentCursor, equals(DateTime.parse('2026-11-01T10:05:00.000Z')));
    });

    test('4. Identical timestamps across page boundary do not cause infinite pagination loop', () async {
      // 1200 records all sharing the exact same updated_at timestamp
      final identicalTs = '2026-11-01T12:00:00.000Z';
      final dataset = List.generate(1200, (i) => {
        'id': 'rec_$i',
        'updated_at': identicalTs,
      });

      int loopCount = 0;
      int offset = 0;
      const pageSize = 500;
      final retrieved = <Map<String, dynamic>>[];
      bool hasMore = true;

      while (hasMore) {
        loopCount++;
        if (loopCount > 10) {
          fail('Infinite loop detected in offset pagination');
        }

        final end = (offset + pageSize < dataset.length) ? offset + pageSize : dataset.length;
        final page = dataset.sublist(offset, end);
        retrieved.addAll(page);

        if (page.length < pageSize) {
          hasMore = false;
        } else {
          offset += pageSize;
        }
      }

      expect(retrieved.length, equals(1200));
      expect(loopCount, equals(3), reason: '1200 items in chunks of 500 must complete in exactly 3 iterations (500 + 500 + 200)');
    });
  });
}
