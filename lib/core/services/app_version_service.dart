import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/sync_service.dart';
import '../../domain/models/app_version_info.dart';

/// Service managing client-side version checks, server configuration fetching,
/// SemVer evaluations, dismissal throttling, and store update navigation.
class AppVersionService {
  final ApiClient apiClient;
  final LocalStorageService storage;
  final SyncService syncService;

  DateTime? _lastCheckTimestamp;
  AppVersionCheckResult? _lastResult;

  /// Throttling cooldown between background version checks (30 minutes)
  static const Duration backgroundCheckCooldown = Duration(minutes: 30);

  /// Dismissal cooldown for optional updates (48 hours)
  static const Duration dismissalCooldown = Duration(hours: 48);

  AppVersionService({
    required this.apiClient,
    required this.storage,
    required this.syncService,
  });

  AppVersionCheckResult? get lastResult => _lastResult;

  /// Checks the current application version against the server configuration.
  ///
  /// [forceRefresh]: bypasses the 30-minute background check throttle.
  /// [overrideInstalledVersion]: permits injecting arbitrary version string for unit testing.
  Future<AppVersionCheckResult> checkVersion({
    bool forceRefresh = false,
    String? overrideInstalledVersion,
  }) async {
    final installedStr = overrideInstalledVersion ?? AppConfig.appVersion;
    final currentSemVer = SemanticVersion.parse(installedStr);

    // 1. Throttling check
    if (!forceRefresh &&
        _lastCheckTimestamp != null &&
        _lastResult != null &&
        DateTime.now().difference(_lastCheckTimestamp!) < backgroundCheckCooldown &&
        overrideInstalledVersion == null) {
      return _lastResult!;
    }

    AppVersionConfig config;
    bool isOffline = false;

    // 2. Fetch latest version config from backend with 5-second timeout
    try {
      final res = await apiClient.get(
        '/app/version?clientVersion=${currentSemVer.raw}',
      ).timeout(const Duration(seconds: 5));

      if (res is Map<String, dynamic>) {
        final data = res.containsKey('data') && res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
        config = AppVersionConfig.fromJson(data);
        await storage.saveCachedVersionConfig(config.toJson());
      } else {
        config = _loadCachedConfigOrDefault();
      }
    } catch (e) {
      debugPrint('[AppVersionService] Version check network notice: $e');
      // Network failure / offline: fall back to cached config
      isOffline = true;
      config = _loadCachedConfigOrDefault();
    }

    // 3. Evaluate UpdateType
    UpdateType updateType;
    bool isUpdateRequired;
    bool isUpdateAvailable;

    if (currentSemVer < config.minimumSupportedVersion) {
      updateType = UpdateType.required;
      isUpdateRequired = true;
      isUpdateAvailable = true;
    } else if (currentSemVer < config.latestVersion) {
      updateType = UpdateType.optional;
      isUpdateRequired = false;
      isUpdateAvailable = true;
    } else {
      updateType = UpdateType.none;
      isUpdateRequired = false;
      isUpdateAvailable = false;
    }

    // 4. Evaluate Dismissal State (Only applicable for Optional updates)
    bool isDismissed = false;
    if (updateType == UpdateType.optional) {
      final lastDismissedVer = storage.getLastDismissedVersion();
      final dismissedAt = storage.getLastDismissedTimestamp();

      if (lastDismissedVer != null &&
          lastDismissedVer == config.latestVersion.toString() &&
          dismissedAt != null &&
          DateTime.now().difference(dismissedAt) < dismissalCooldown) {
        isDismissed = true;
      }
    }

    // 5. Query Unsynced Offline Operations Count
    final unsyncedCount = syncService.pendingCount;

    final result = AppVersionCheckResult(
      currentVersion: currentSemVer,
      config: config,
      updateType: updateType,
      isUpdateRequired: isUpdateRequired,
      isUpdateAvailable: isUpdateAvailable,
      isDismissed: isDismissed,
      unsyncedOperationsCount: unsyncedCount,
      isOffline: isOffline,
    );

    _lastCheckTimestamp = DateTime.now();
    _lastResult = result;

    return result;
  }

  /// Records user dismissal of an optional update ("Later" action).
  Future<void> dismissOptionalUpdate(SemanticVersion version) async {
    await storage.saveDismissedVersion(version.toString());
    if (_lastResult != null) {
      _lastResult = AppVersionCheckResult(
        currentVersion: _lastResult!.currentVersion,
        config: _lastResult!.config,
        updateType: _lastResult!.updateType,
        isUpdateRequired: _lastResult!.isUpdateRequired,
        isUpdateAvailable: _lastResult!.isUpdateAvailable,
        isDismissed: true,
        unsyncedOperationsCount: _lastResult!.unsyncedOperationsCount,
        isOffline: _lastResult!.isOffline,
      );
    }
  }

  /// Opens the official store listing URL.
  Future<bool> launchStoreUrl([String? customUrl]) async {
    final targetUrl = customUrl ?? _lastResult?.config.storeUrl ?? 'https://play.google.com/store/apps/details?id=com.nirniq.kith';
    try {
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[AppVersionService] Error launching store URL: $e');
    }
    return false;
  }

  AppVersionConfig _loadCachedConfigOrDefault() {
    final cached = storage.getCachedVersionConfig();
    if (cached != null) {
      try {
        return AppVersionConfig.fromJson(cached);
      } catch (_) {}
    }
    return AppVersionConfig.fallback;
  }
}
