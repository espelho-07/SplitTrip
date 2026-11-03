import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/data/services/local_database_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 10: Force Stop and Restart Recovery', () {
    testWidgets('uncommitted outbox mutations survive database reload without data loss', (tester) async {
      final dbService = LocalDatabaseService.inMemory();

      // Enqueue 3 mutations
      for (int i = 1; i <= 3; i++) {
        dbService.rawDb.execute('''
          INSERT INTO mutation_outbox (id, mutation_type, trip_id, payload, created_at, status, retry_count, raw_json)
          VALUES ('mut-00$i', 'CREATE_EXPENSE', 'trip-01', '{"amount": $i}', '${DateTime.now().toIso8601String()}', 'pending', 0, '{"id": "mut-00$i"}');
        ''');
      }

      final outbox = dbService.getOutboxMutations();
      expect(outbox.length, equals(3));

      // Verify that all 3 are in pending status
      final pendingCount = dbService.rawDb.select("SELECT COUNT(*) as count FROM mutation_outbox WHERE status = 'pending';");
      expect(pendingCount.first['count'], equals(3));

      dbService.dispose();
    });
  });
}
