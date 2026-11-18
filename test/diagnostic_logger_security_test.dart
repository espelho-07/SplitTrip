import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/logging/diagnostic_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Diagnostic Logger & Zero-Exposure Security Suite', () {
    late DiagnosticLogger logger;

    setUp(() {
      logger = DiagnosticLogger.instance;
      logger.clearLogs();
    });

    test('1. Secret Redaction: Automatically masks JWT tokens, session tokens, and recovery keys', () {
      logger.logAuthFailure(
        correlationId: 'corr_test_001',
        accountId: 'acc_alice',
        reason: 'Failed token check for eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.doNotLeakThis and recovery key KITH-ABCD-1234 with session kith_sess_secret_string_999',
      );

      final logs = logger.recentLogs;
      expect(logs.length, equals(1));
      final entry = logs.first;
      final loggedReason = entry.metadata['reason'] as String;

      // Verifies complete redaction
      expect(loggedReason, contains('[REDACTED_JWT]'));
      expect(loggedReason, contains('[REDACTED_RECOVERY_KEY]'));
      expect(loggedReason, contains('[REDACTED_SESSION_TOKEN]'));
      expect(loggedReason, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      expect(loggedReason, isNot(contains('KITH-ABCD-1234')));
      expect(loggedReason, isNot(contains('kith_sess_secret_string_999')));
    });

    test('2. Structured Database Logging: Records table, action, and correlation ID', () {
      logger.logDatabaseOp(
        correlationId: 'corr_db_002',
        tripId: 'trip_100',
        table: 'expenses',
        action: 'UPSERT',
        affectedRows: 3,
      );

      final logs = logger.recentLogs;
      expect(logs.length, equals(1));
      final entry = logs.first;
      expect(entry.correlationId, equals('corr_db_002'));
      expect(entry.tripId, equals('trip_100'));
      expect(entry.operationType, equals('DB_UPSERT'));
      expect(entry.syncState, equals('COMMITTED'));
      expect(entry.metadata['table'], equals('expenses'));
      expect(entry.metadata['affectedRows'], equals(3));
    });

    test('3. Sync Request & Response Logging: Accurately records lifecycle transitions', () {
      logger.logSyncRequest(
        correlationId: 'corr_sync_003',
        operationId: 'op_mut_100',
        tripId: 'trip_100',
        deviceId: 'dev_pixel_9',
        mutationType: 'addExpense',
        retryCount: 0,
      );

      logger.logSyncResponse(
        correlationId: 'corr_sync_003',
        operationId: 'op_mut_100',
        tripId: 'trip_100',
        statusCode: 201,
        isSuccess: true,
      );

      final logs = logger.recentLogs;
      expect(logs.length, equals(2));
      expect(logs[0].operationType, equals('SYNC_DISPATCH'));
      expect(logs[0].syncState, equals('SYNCING'));
      expect(logs[1].operationType, equals('SYNC_RESPONSE'));
      expect(logs[1].syncState, equals('SYNCED'));
    });

    test('4. Conflict Logging: Captures revision mismatch details safely', () {
      logger.logConflict(
        correlationId: 'corr_conflict_004',
        tripId: 'trip_100',
        operationId: 'op_mut_101',
        localRevision: 3,
        serverRevision: 5,
      );

      final logs = logger.recentLogs;
      expect(logs.length, equals(1));
      final entry = logs.first;
      expect(entry.operationType, equals('CONFLICT_DETECTED'));
      expect(entry.syncState, equals('CONFLICT'));
      expect(entry.errorCategory, equals('CONFLICT'));
      expect(entry.metadata['localRevision'], equals(3));
      expect(entry.metadata['serverRevision'], equals(5));
    });
  });
}
