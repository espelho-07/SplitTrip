import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/data/services/local_database_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 9: Duplicate Operation Prevention & Idempotency', () {
    testWidgets('enforces idempotency key checks and ignores duplicate operations', (tester) async {
      final dbService = LocalDatabaseService.inMemory();

      const opId = 'op-unique-uuid-999';
      const checksum = 'checksum_sha256_hash_value';
      final now = DateTime.now().toIso8601String();

      // First insertion into processed_operations
      dbService.rawDb.execute('''
        INSERT OR IGNORE INTO processed_operations (operation_id, payload_checksum, processed_at, source)
        VALUES ('$opId', '$checksum', '$now', 'p2p');
      ''');

      // Attempt duplicate insertion
      dbService.rawDb.execute('''
        INSERT OR IGNORE INTO processed_operations (operation_id, payload_checksum, processed_at, source)
        VALUES ('$opId', '$checksum', '$now', 'p2p');
      ''');

      // Query processed count
      final res = dbService.rawDb.select(
        'SELECT COUNT(*) as count FROM processed_operations WHERE operation_id = ?;',
        [opId],
      );

      expect(res.first['count'], equals(1));

      final ledger = dbService.getProcessedOperationsLedger();
      expect(ledger.containsKey(opId), isTrue);

      dbService.dispose();
    });
  });
}
