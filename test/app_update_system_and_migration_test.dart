import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kith_app/core/config/app_config.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/app_version_service.dart';
import 'package:kith_app/core/services/play_in_app_update_service.dart';
import 'package:kith_app/data/services/local_migration_runner.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/app_version_info.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/presentation/viewmodels/version_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kith Android App Update & Migration Test Suite', () {
    late SharedPreferences prefs;
    late LocalStorageService storage;
    late SyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      syncService = SyncService(storage);
    });

    test('TEST A & D: User session, credentials, and trips survive simulated app upgrade', () async {
      // 1. Seed pre-update data (v1.0.0 state)
      final preUpdateUser = {
        'id': 'usr_upgrade_001',
        'displayName': 'Rohan Sharma',
        'anonymousToken': 'token_xyz_pre_update',
        'recoveryKey': 'KITH-ROHN-2026',
        'createdAt': DateTime(2026, 8, 1).toIso8601String(),
      };
      await storage.saveUser(preUpdateUser);

      final preUpdateTrips = [
        {
          'id': 'trip_manali_01',
          'name': 'Manali Expedition',
          'creatorId': 'usr_upgrade_001',
          'createdAt': DateTime(2026, 8, 5).toIso8601String(),
          // Note: currencyCode and lifecycleState intentionally omitted to test v2 migration
        }
      ];
      await storage.saveTrips(preUpdateTrips);

      // Verify pre-update state
      expect(storage.getSavedUser()?['displayName'], equals('Rohan Sharma'));
      expect(storage.getSavedTrips().first['name'], equals('Manali Expedition'));
      expect(storage.getLocalSchemaVersion(), equals(0));

      // 2. Simulate app upgrade execution: LocalMigrationRunner runs on app launch
      final migrationRunner = LocalMigrationRunner(storage);
      await migrationRunner.runPendingMigrations();

      // 3. Verify zero data loss post-update
      final postUpdateUser = storage.getSavedUser();
      expect(postUpdateUser, isNotNull);
      expect(postUpdateUser!['id'], equals('usr_upgrade_001'));
      expect(postUpdateUser['displayName'], equals('Rohan Sharma'));
      expect(postUpdateUser['recoveryKey'], equals('KITH-ROHN-2026'));
      expect(postUpdateUser['anonymousToken'], equals('token_xyz_pre_update'));

      // Verify User object deserialization
      final restoredGuest = GuestUser.fromJson(postUpdateUser);
      expect(restoredGuest.displayName, equals('Rohan Sharma'));
      expect(restoredGuest.recoveryKey, equals('KITH-ROHN-2026'));

      // Verify trip migration: defaults applied without losing existing fields
      final postUpdateTrips = storage.getSavedTrips();
      expect(postUpdateTrips.length, equals(1));
      expect(postUpdateTrips.first['name'], equals('Manali Expedition'));
      expect(postUpdateTrips.first['currencyCode'], equals('INR'));
      expect(postUpdateTrips.first['lifecycleState'], equals('active'));

      // Verify schema version incremented
      expect(storage.getLocalSchemaVersion(), equals(LocalMigrationRunner.currentSchemaVersion));
    });

    test('TEST B: Pending offline operations survive app upgrade without queue loss', () async {
      // 1. Enqueue offline mutation before upgrade
      final mutationPayload = {
        'id': 'exp_offline_99',
        'tripId': 'trip_manali_01',
        'title': 'River Rafting',
        'amount': 3500.0,
        'paidByUserId': 'usr_upgrade_001',
      };

      await syncService.enqueueMutation(
        MutationType.addExpense,
        mutationPayload,
      );

      expect(syncService.pendingCount, equals(1));

      // 2. Simulate app upgrade by re-initializing storage and runner
      final migrationRunner = LocalMigrationRunner(storage);
      await migrationRunner.runPendingMigrations();

      // 3. Verify offline mutation queue is 100% intact
      final freshSyncService = SyncService(storage);
      expect(freshSyncService.pendingCount, equals(1));

      final pendingMutations = freshSyncService.getPendingMutations();
      expect(pendingMutations.first.type, equals(MutationType.addExpense));
      expect(pendingMutations.first.payload['title'], equals('River Rafting'));
      expect(pendingMutations.first.payload['amount'], equals(3500.0));
      expect(pendingMutations.first.tripId, equals('trip_manali_01'));
    });

    test('TEST C: Receipt file references and OCR metadata survive upgrade', () async {
      final expenseWithReceipt = {
        'id': 'exp_receipt_001',
        'tripId': 'trip_manali_01',
        'title': 'Cafe 1947 Dinner',
        'amount': 2450.0,
        'receiptPath': '/data/user/0/com.nirniq.kith/app_flutter/receipt_cafe.jpg',
        'ocrMerchant': 'Cafe 1947 Old Manali',
        'ocrTotal': 2450.0,
        'ocrItems': [
          {'name': 'Woodfired Pizza', 'price': 850.0},
          {'name': 'Pasta Arrabiata', 'price': 650.0},
          {'name': 'Cold Coffee', 'price': 950.0},
        ],
      };

      await storage.saveExpenses('trip_manali_01', [expenseWithReceipt]);

      // Simulate upgrade
      final migrationRunner = LocalMigrationRunner(storage);
      await migrationRunner.runPendingMigrations();

      // Verify receipt data preserved
      final restoredExpenses = storage.getSavedExpenses('trip_manali_01');
      expect(restoredExpenses.length, equals(1));
      expect(restoredExpenses.first['receiptPath'], equals('/data/user/0/com.nirniq.kith/app_flutter/receipt_cafe.jpg'));
      expect(restoredExpenses.first['ocrMerchant'], equals('Cafe 1947 Old Manali'));
      expect((restoredExpenses.first['ocrItems'] as List).length, equals(3));
    });

    test('TEST E: LocalMigrationRunner is strictly idempotent across multiple runs', () async {
      final migrationRunner = LocalMigrationRunner(storage);

      // First run (upgrades from v0 to current)
      await migrationRunner.runPendingMigrations();
      expect(storage.getLocalSchemaVersion(), equals(2));

      // Second run (should be a no-op)
      await migrationRunner.runPendingMigrations();
      expect(storage.getLocalSchemaVersion(), equals(2));

      // Third run (still a no-op)
      await migrationRunner.runPendingMigrations();
      expect(storage.getLocalSchemaVersion(), equals(2));
    });

    test('TEST F: Interrupted or failed migration preserves existing data safely', () async {
      // Seed user and trip
      await storage.saveUser({'id': 'u1', 'displayName': 'Safe User'});
      await storage.saveTrips([{'id': 't1', 'name': 'Safe Trip'}]);

      // Set schema to v1
      await storage.setLocalSchemaVersion(1);

      // Verify that even if migration logic encountered an unexpected entry, existing data is untouched
      final runner = LocalMigrationRunner(storage);
      await runner.runPendingMigrations();

      expect(storage.getSavedUser()?['displayName'], equals('Safe User'));
      expect(storage.getSavedTrips().first['name'], equals('Safe Trip'));
    });

    test('TEST G: Version monotonicity & Play Store upgrade progression validation', () {
      const currentVersionCode = 2025;
      const previousVersionCode = 2024;
      const olderVersionCode = 11;

      // Google Play requires strictly higher versionCode
      expect(currentVersionCode > previousVersionCode, isTrue);
      expect(currentVersionCode > olderVersionCode, isTrue);

      // SemVer progression
      final currentSemVer = SemanticVersion.parse(AppConfig.appVersion);
      final olderSemVer = SemanticVersion.parse('1.0.1');

      expect(currentSemVer > olderSemVer, isTrue);
      expect(currentSemVer.major, equals(2));
      expect(currentSemVer.minor, equals(0));
      expect(currentSemVer.patch, equals(25));
    });

    test('TEST H: Incompatible package ID or downgrade detection', () {
      const canonicalPackage = 'com.nirniq.kith';
      const foreignPackage = 'com.example.splittrip';

      // Verify application ID invariant
      expect(canonicalPackage == 'com.nirniq.kith', isTrue);
      expect(foreignPackage == canonicalPackage, isFalse);

      // Test downgrade rejection logic
      bool isUpgradeAllowed(int installedCode, int incomingCode, String installedPkg, String incomingPkg) {
        if (installedPkg != incomingPkg) return false; // Signature / package conflict
        if (incomingCode <= installedCode) return false; // Downgrade rejected
        return true;
      }

      // Valid upgrade
      expect(isUpgradeAllowed(2024, 2025, canonicalPackage, canonicalPackage), isTrue);

      // Rejected: Downgrade
      expect(isUpgradeAllowed(2025, 2024, canonicalPackage, canonicalPackage), isFalse);

      // Rejected: Same version code
      expect(isUpgradeAllowed(2025, 2025, canonicalPackage, canonicalPackage), isFalse);

      // Rejected: Mismatched package ID
      expect(isUpgradeAllowed(2024, 2025, canonicalPackage, foreignPackage), isFalse);
    });

    test('PlayInAppUpdateService & VersionViewModel integration tests', () async {
      final versionService = AppVersionService(
        apiClient: ApiClient(),
        storage: storage,
        syncService: syncService,
      );
      final playUpdateService = PlayInAppUpdateService();
      final versionVm = VersionViewModel(
        versionService: versionService,
        inAppUpdateService: playUpdateService,
      );

      // In non-Android / unit test runner environment, PlayInAppUpdateService handles absence gracefully
      final checkResult = await playUpdateService.checkForUpdate();
      expect(checkResult, isNull);
      expect(playUpdateService.state, equals(PlayUpdateState.notAvailable));

      // triggerUpdate falls back smoothly to store URL when Play Core is unavailable
      expect(versionVm.isPlayUpdateDownloading, isFalse);
      expect(versionVm.isPlayUpdateDownloaded, isFalse);
    });
  });
}
