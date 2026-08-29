import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/app_version_service.dart';
import 'package:kith_app/data/services/local_migration_runner.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/app_version_info.dart';
import 'package:kith_app/presentation/viewmodels/version_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SemanticVersion Unit Tests', () {
    test('1. Parses semantic version strings accurately', () {
      final v1 = SemanticVersion.parse('2.4.1');
      expect(v1.major, 2);
      expect(v1.minor, 4);
      expect(v1.patch, 1);
      expect(v1.buildNumber, isNull);

      final v2 = SemanticVersion.parse('v1.0.0+42');
      expect(v2.major, 1);
      expect(v2.minor, 0);
      expect(v2.patch, 0);
      expect(v2.buildNumber, 42);

      final v3 = SemanticVersion.parse('3.0.0-beta.1');
      expect(v3.major, 3);
      expect(v3.minor, 0);
      expect(v3.patch, 0);
    });

    test('2. Compares versions across major, minor, and patch correctly', () {
      final v210 = SemanticVersion.parse('2.1.0');
      final v211 = SemanticVersion.parse('2.1.1');
      final v220 = SemanticVersion.parse('2.2.0');
      final v300 = SemanticVersion.parse('3.0.0');

      expect(v210 < v211, isTrue);
      expect(v211 > v210, isTrue);
      expect(v210 <= v210, isTrue);
      expect(v211 < v220, isTrue);
      expect(v220 < v300, isTrue);
      expect(v300 > v220, isTrue);
      expect(v210 == SemanticVersion.parse('2.1.0'), isTrue);
    });
  });

  group('AppVersionService & Version Management Tests', () {
    late LocalStorageService storage;
    late SyncService syncService;
    late Map<String, dynamic> serverVersionConfig;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      syncService = SyncService(storage);

      serverVersionConfig = {
        'latestVersion': '2.4.1',
        'minimumSupportedVersion': '2.1.0',
        'releaseNotes': '• Faster sync\n• Better offline safety',
        'storeUrl': 'https://play.google.com/store/apps/details?id=com.nirniq.kith',
        'updatePriority': 'flexible',
        'featureFlags': {
          'new_settlement_flow': true,
          'new_sync_engine': true,
        },
      };
    });

    test('1. Optional Update: Supported older version receives optional update and banner recommendation', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'data': serverVersionConfig}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final apiClient = ApiClient(httpClient: mockClient);
      final service = AppVersionService(
        apiClient: apiClient,
        storage: storage,
        syncService: syncService,
      );

      // Client running 2.3.0 (between 2.1.0 and 2.4.1)
      final result = await service.checkVersion(overrideInstalledVersion: '2.3.0');

      expect(result.updateType, equals(UpdateType.optional));
      expect(result.isUpdateRequired, isFalse);
      expect(result.isUpdateAvailable, isTrue);
      expect(result.shouldShowBanner, isTrue);
      expect(result.shouldBlockApp, isFalse);
    });

    test('2. Required Update: Unsupported old version receives mandatory blocking update', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'data': serverVersionConfig}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final apiClient = ApiClient(httpClient: mockClient);
      final service = AppVersionService(
        apiClient: apiClient,
        storage: storage,
        syncService: syncService,
      );

      // Client running 2.0.5 (below 2.1.0 minimum)
      final result = await service.checkVersion(overrideInstalledVersion: '2.0.5');

      expect(result.updateType, equals(UpdateType.required));
      expect(result.isUpdateRequired, isTrue);
      expect(result.isUpdateAvailable, isTrue);
      expect(result.shouldShowBanner, isFalse);
      expect(result.shouldBlockApp, isTrue);
    });

    test('3. Up-to-Date: User on latest version receives no update prompt', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'data': serverVersionConfig}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final apiClient = ApiClient(httpClient: mockClient);
      final service = AppVersionService(
        apiClient: apiClient,
        storage: storage,
        syncService: syncService,
      );

      // Client running 2.4.1 (matching latest)
      final result = await service.checkVersion(overrideInstalledVersion: '2.4.1');

      expect(result.updateType, equals(UpdateType.none));
      expect(result.isUpdateRequired, isFalse);
      expect(result.isUpdateAvailable, isFalse);
      expect(result.shouldShowBanner, isFalse);
      expect(result.shouldBlockApp, isFalse);
    });

    test('4. Update Dismissal: User taps "Later" -> Banner is suppressed until newer release', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'data': serverVersionConfig}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final apiClient = ApiClient(httpClient: mockClient);
      final service = AppVersionService(
        apiClient: apiClient,
        storage: storage,
        syncService: syncService,
      );

      // Initial check for 2.3.0 -> Banner shows
      var res = await service.checkVersion(overrideInstalledVersion: '2.3.0', forceRefresh: true);
      expect(res.shouldShowBanner, isTrue);

      // Dismiss 2.4.1
      await service.dismissOptionalUpdate(SemanticVersion.parse('2.4.1'));

      // Next check for 2.3.0 -> Banner is dismissed
      res = await service.checkVersion(overrideInstalledVersion: '2.3.0', forceRefresh: true);
      expect(res.isDismissed, isTrue);
      expect(res.shouldShowBanner, isFalse);

      // Server bumps latest to 2.4.2 -> Dismissal expires and banner reappears
      serverVersionConfig['latestVersion'] = '2.4.2';
      res = await service.checkVersion(overrideInstalledVersion: '2.3.0', forceRefresh: true);
      expect(res.isDismissed, isFalse);
      expect(res.shouldShowBanner, isTrue);
    });

    test('5. Offline Resilience: Network error falls back to cache without blocking user', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network connection failed');
      });
      final apiClient = ApiClient(httpClient: mockClient);
      final service = AppVersionService(
        apiClient: apiClient,
        storage: storage,
        syncService: syncService,
      );

      // Add a pending offline mutation to ensure count is tracked
      await syncService.enqueueMutation(MutationType.createTrip, {'id': 'trip_off_1', 'name': 'Goa'});

      final result = await service.checkVersion(overrideInstalledVersion: '2.2.0');

      expect(result.isOffline, isTrue);
      expect(result.shouldBlockApp, isFalse); // Never block offline user unexpectedly
      expect(result.unsyncedOperationsCount, equals(1));
    });
  });

  group('LocalDatabaseMigrationRunner Tests', () {
    late LocalStorageService storage;
    late LocalMigrationRunner runner;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      runner = LocalMigrationRunner(storage);
    });

    test('1. Runs schema migrations and updates schema version without data loss', () async {
      expect(storage.getLocalSchemaVersion(), equals(0));

      // Seed pre-migration legacy data
      final legacyTrip = {
        'id': 'trip_legacy_01',
        'name': 'Himalayas Trek',
        'creatorId': 'usr_1',
        'inviteCode': 'HIM001',
        // Missing currencyCode and lifecycleState
      };
      await storage.saveTrips([legacyTrip]);

      await runner.runPendingMigrations();

      expect(storage.getLocalSchemaVersion(), equals(LocalMigrationRunner.currentSchemaVersion));

      // Verify migration upgraded data without deleting or corrupting it
      final upgradedTrips = storage.getSavedTrips();
      expect(upgradedTrips.length, equals(1));
      expect(upgradedTrips.first['id'], equals('trip_legacy_01'));
      expect(upgradedTrips.first['currencyCode'], equals('INR'));
      expect(upgradedTrips.first['lifecycleState'], equals('active'));
    });

    test('2. Migration runner is strictly idempotent', () async {
      await runner.runPendingMigrations();
      final versionAfterFirstRun = storage.getLocalSchemaVersion();

      await runner.runPendingMigrations();
      expect(storage.getLocalSchemaVersion(), equals(versionAfterFirstRun));
    });
  });

  group('VersionViewModel State Reactivity Tests', () {
    late LocalStorageService storage;
    late SyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      syncService = SyncService(storage);
    });

    test('1. VersionViewModel reacts to update check, dismissal, and feature flags', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': {
              'latestVersion': '2.5.0',
              'minimumSupportedVersion': '2.0.0',
              'releaseNotes': '• New features in 2.5',
              'storeUrl': 'https://play.google.com/store/apps/details?id=com.nirniq.kith',
              'featureFlags': {
                'new_settlement_flow': true,
              },
            }
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final service = AppVersionService(
        apiClient: apiClient,
        storage: storage,
        syncService: syncService,
      );

      final vm = VersionViewModel(versionService: service);

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      await vm.checkForUpdates(overrideInstalledVersion: '2.3.0');

      expect(vm.shouldShowBanner, isTrue);
      expect(vm.latestVersionString, equals('2.5.0'));
      expect(vm.isFeatureEnabled('new_settlement_flow'), isTrue);
      expect(vm.isFeatureEnabled('unknown_flag'), isFalse);
      expect(notifyCount, greaterThan(0));

      // Dismiss banner
      await vm.dismissBanner();
      expect(vm.shouldShowBanner, isFalse);

      // Release notes toggle
      expect(vm.isReleaseNotesExpanded, isFalse);
      vm.toggleReleaseNotesExpanded();
      expect(vm.isReleaseNotesExpanded, isTrue);
    });
  });
}
