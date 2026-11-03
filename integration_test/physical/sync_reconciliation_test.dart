import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/data/services/local_database_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 8: Reconnection and Synchronization Reconciliation', () {
    testWidgets('reconciles peer operations without duplicates and verifies balance equality', (tester) async {
      final dbServiceA = LocalDatabaseService.inMemory();
      final dbServiceB = LocalDatabaseService.inMemory();
      final nowStr = DateTime.now().toIso8601String();

      const tripId = 'trip-sync-test-88';
      dbServiceA.rawDb.execute('''
        INSERT OR REPLACE INTO trips (
          id, name, currency_code, creator_id, invite_code, started_at, created_at, updated_at, raw_json
        ) VALUES (
          '$tripId', 'Manali Trip', 'INR', 'u1', 'KITH88', '$nowStr', '$nowStr', '$nowStr', '{}'
        );
      ''');
      dbServiceB.rawDb.execute('''
        INSERT OR REPLACE INTO trips (
          id, name, currency_code, creator_id, invite_code, started_at, created_at, updated_at, raw_json
        ) VALUES (
          '$tripId', 'Manali Trip', 'INR', 'u1', 'KITH88', '$nowStr', '$nowStr', '$nowStr', '{}'
        );
      ''');

      // Device A creates an expense: Dinner Rs 2,000 (200000 paise)
      const opA = {
        'id': 'exp-sync-01',
        'trip_id': tripId,
        'title': 'Dinner',
        'amount': 200000,
        'paid_by_member_id': 'alice',
      };
      dbServiceA.rawDb.execute('''
        INSERT OR REPLACE INTO expenses (
          id, trip_id, title, amount, currency, paid_by_member_id, created_at, updated_at, raw_json
        ) VALUES (
          'exp-sync-01', '$tripId', 'Dinner', 200000, 'INR', 'alice', '$nowStr', '$nowStr', '${jsonEncode(opA)}'
        );
      ''');

      // Device B creates an expense: Taxi Rs 1,000 (100000 paise)
      const opB = {
        'id': 'exp-sync-02',
        'trip_id': tripId,
        'title': 'Taxi',
        'amount': 100000,
        'paid_by_member_id': 'bob',
      };
      dbServiceB.rawDb.execute('''
        INSERT OR REPLACE INTO expenses (
          id, trip_id, title, amount, currency, paid_by_member_id, created_at, updated_at, raw_json
        ) VALUES (
          'exp-sync-02', '$tripId', 'Taxi', 100000, 'INR', 'bob', '$nowStr', '$nowStr', '${jsonEncode(opB)}'
        );
      ''');

      // Simulate P2P exchange: Device A receives opB, Device B receives opA
      dbServiceA.rawDb.execute('''
        INSERT OR REPLACE INTO expenses (
          id, trip_id, title, amount, currency, paid_by_member_id, created_at, updated_at, raw_json
        ) VALUES (
          'exp-sync-02', '$tripId', 'Taxi', 100000, 'INR', 'bob', '$nowStr', '$nowStr', '${jsonEncode(opB)}'
        );
      ''');
      dbServiceB.rawDb.execute('''
        INSERT OR REPLACE INTO expenses (
          id, trip_id, title, amount, currency, paid_by_member_id, created_at, updated_at, raw_json
        ) VALUES (
          'exp-sync-01', '$tripId', 'Dinner', 200000, 'INR', 'alice', '$nowStr', '$nowStr', '${jsonEncode(opA)}'
        );
      ''');

      // Verify both databases now have exactly 2 expenses and total amount = 300000 paise
      final expensesA = dbServiceA.getSavedExpenses(tripId);
      final expensesB = dbServiceB.getSavedExpenses(tripId);

      expect(expensesA.length, equals(2));
      expect(expensesB.length, equals(2));

      final totalA = expensesA.fold<int>(0, (sum, e) => sum + ((e['amount'] as num?)?.toInt() ?? 0));
      final totalB = expensesB.fold<int>(0, (sum, e) => sum + ((e['amount'] as num?)?.toInt() ?? 0));

      expect(totalA, equals(300000));
      expect(totalB, equals(300000));
      expect(totalA, equals(totalB));

      dbServiceA.dispose();
      dbServiceB.dispose();
    });
  });
}
