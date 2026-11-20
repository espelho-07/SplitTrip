import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/sync_service.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';

/// Top-level background callback dispatcher for Android WorkManager.
/// Executed in an isolated headless VM when Android wakes up the background worker.
@pragma('vm:entry-point')
void kithWorkmanagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[BackgroundSyncWorker] Executing background task: $taskName');
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize persistent local storage
      final storage = await LocalStorageService.init();

      // Restore custom server URL if configured
      final savedServerUrl = storage.getSavedServerUrl();
      if (savedServerUrl != null && savedServerUrl.isNotEmpty) {
        AppConfig.setCustomServerUrl(savedServerUrl);
      }

      // Check for user credentials to authenticate sync
      final savedUser = storage.getSavedUser();
      final token = savedUser?['anonymousToken'] as String? ??
          savedUser?['token'] as String?;

      final apiClient = ApiClient();
      if (token != null && token.isNotEmpty) {
        apiClient.setAuthToken(token);
      }

      // Initialize sync service and flush pending outbox queue
      final syncService = SyncService(storage);
      await syncService.flushQueue(apiClient, force: true);

      debugPrint('[BackgroundSyncWorker] Periodic sync task successfully completed.');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[BackgroundSyncWorker] Periodic sync task failed: $e\n$stackTrace');
      return false;
    }
  });
}

/// Service managing periodic WorkManager registration and background synchronization.
class BackgroundSyncWorker {
  static const String periodicSyncUniqueId = 'com.nirniq.kith.periodic_sync';
  static const String periodicSyncTaskName = 'kithPeriodicSync';

  static bool _isInitialized = false;

  /// Initializes the WorkManager plugin with the top-level callback dispatcher.
  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await Workmanager().initialize(kithWorkmanagerCallbackDispatcher);
        _isInitialized = true;
        debugPrint('[BackgroundSyncWorker] WorkManager initialized.');
      }
    } catch (e) {
      debugPrint('[BackgroundSyncWorker] Initialization error: $e');
    }
  }

  /// Registers a periodic background task running every 15 minutes
  /// (minimum interval enforced by Android WorkManager).
  static Future<void> registerPeriodicSync({
    Duration frequency = const Duration(minutes: 15),
  }) async {
    if (kIsWeb) return;
    try {
      if (!_isInitialized) {
        await initialize();
      }
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await Workmanager().registerPeriodicTask(
          periodicSyncUniqueId,
          periodicSyncTaskName,
          frequency: frequency,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          backoffPolicy: BackoffPolicy.exponential,
          backoffPolicyDelay: const Duration(seconds: 30),
        );
        debugPrint(
            '[BackgroundSyncWorker] Periodic sync scheduled every ${frequency.inMinutes} minutes.');
      }
    } catch (e) {
      debugPrint(
          '[BackgroundSyncWorker] Failed to register periodic sync task: $e');
    }
  }

  /// Triggers an immediate one-off background sync task.
  static Future<void> triggerImmediateOneOffSync() async {
    if (kIsWeb) return;
    try {
      if (!_isInitialized) {
        await initialize();
      }
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await Workmanager().registerOneOffTask(
          'one_off_sync_${DateTime.now().millisecondsSinceEpoch}',
          periodicSyncTaskName,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
          existingWorkPolicy: ExistingWorkPolicy.keep,
        );
      }
    } catch (e) {
      debugPrint(
          '[BackgroundSyncWorker] Failed to register one-off sync task: $e');
    }
  }

  /// Cancels all scheduled background WorkManager tasks.
  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await Workmanager().cancelAll();
      debugPrint('[BackgroundSyncWorker] All WorkManager tasks cancelled.');
    } catch (e) {
      debugPrint('[BackgroundSyncWorker] Failed to cancel tasks: $e');
    }
  }
}
