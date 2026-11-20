import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/background_sync_worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundSyncWorker & WorkManager Integration Tests', () {
    test('1. Constants and identifiers are correctly configured', () {
      expect(
        BackgroundSyncWorker.periodicSyncUniqueId,
        equals('com.nirniq.kith.periodic_sync'),
      );
      expect(
        BackgroundSyncWorker.periodicSyncTaskName,
        equals('kithPeriodicSync'),
      );
    });

    test('2. Initialization handles test environment without crashing', () async {
      await expectLater(
        BackgroundSyncWorker.initialize(),
        completes,
      );
    });

    test('3. Registering periodic sync with 15-minute cadence completes safely', () async {
      await expectLater(
        BackgroundSyncWorker.registerPeriodicSync(
          frequency: const Duration(minutes: 15),
        ),
        completes,
      );
    });

    test('4. Immediate one-off sync trigger completes safely', () async {
      await expectLater(
        BackgroundSyncWorker.triggerImmediateOneOffSync(),
        completes,
      );
    });

    test('5. Cancelling background tasks executes cleanly', () async {
      await expectLater(
        BackgroundSyncWorker.cancelAll(),
        completes,
      );
    });
  });
}
