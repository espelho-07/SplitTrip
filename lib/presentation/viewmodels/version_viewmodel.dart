import 'package:flutter/foundation.dart';
import '../../core/services/app_version_service.dart';
import '../../core/services/play_in_app_update_service.dart';
import '../../domain/models/app_version_info.dart';

/// ViewModel managing reactive app version state, update checks, dismissal,
/// Google Play In-App Updates, and store navigation.
class VersionViewModel extends ChangeNotifier {
  final AppVersionService versionService;
  final PlayInAppUpdateService? inAppUpdateService;

  AppVersionCheckResult? _status;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isReleaseNotesExpanded = false;

  VersionViewModel({
    required this.versionService,
    this.inAppUpdateService,
  }) {
    inAppUpdateService?.addListener(_onInAppUpdateServiceChanged);
  }

  void _onInAppUpdateServiceChanged() {
    notifyListeners();
  }

  AppVersionCheckResult? get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isReleaseNotesExpanded => _isReleaseNotesExpanded;

  bool get shouldShowBanner => _status?.shouldShowBanner ?? false;
  bool get shouldBlockApp => _status?.shouldBlockApp ?? false;
  UpdateType get updateType => _status?.updateType ?? UpdateType.none;
  String get releaseNotes => _status?.config.releaseNotes ?? '';
  String get latestVersionString => _status?.config.latestVersion.toString() ?? '';
  String get currentVersionString => _status?.currentVersion.toString() ?? '';
  String get minVersionString => _status?.config.minimumSupportedVersion.toString() ?? '';
  int get unsyncedCount => _status?.unsyncedOperationsCount ?? 0;
  bool get isOffline => _status?.isOffline ?? false;

  // Google Play In-App Update states
  bool get isPlayUpdateDownloading => inAppUpdateService?.isDownloading ?? false;
  bool get isPlayUpdateDownloaded => inAppUpdateService?.isDownloaded ?? false;

  /// Checks for application updates from the backend and Google Play.
  Future<void> checkForUpdates({
    bool forceRefresh = false,
    String? overrideInstalledVersion,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await versionService.checkVersion(
        forceRefresh: forceRefresh,
        overrideInstalledVersion: overrideInstalledVersion,
      );
      _status = result;

      // Safely check Play Store in background
      if (inAppUpdateService != null && !kIsWeb) {
        try {
          await inAppUpdateService!.checkForUpdate();
        } catch (_) {}
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Triggers the optimal update flow:
  /// 1. If flexible update is downloaded, installs and restarts.
  /// 2. If immediate/mandatory, attempts Google Play immediate flow, falling back to Play Store URL.
  /// 3. If flexible/optional, attempts Google Play flexible flow, falling back to Play Store URL.
  Future<bool> triggerUpdate({bool forceStoreUrl = false}) async {
    if (forceStoreUrl || inAppUpdateService == null) {
      return await openStore();
    }

    // 1. Downloaded flexible update waiting for install
    if (inAppUpdateService!.isDownloaded) {
      await inAppUpdateService!.completeFlexibleUpdate();
      return true;
    }

    // 2. Immediate update for breaking/required updates
    if (shouldBlockApp && inAppUpdateService!.isImmediateAllowed) {
      final success = await inAppUpdateService!.performImmediateUpdate();
      if (success) return true;
    }

    // 3. Flexible update for optional updates
    if (inAppUpdateService!.isFlexibleAllowed) {
      final started = await inAppUpdateService!.startFlexibleUpdate();
      if (started) return true;
    }

    // 4. Graceful fallback to official Play Store listing
    return await openStore();
  }

  /// Dismisses the optional update banner ("Later" action).
  Future<void> dismissBanner() async {
    if (_status != null) {
      await versionService.dismissOptionalUpdate(_status!.config.latestVersion);
      _status = versionService.lastResult;
      notifyListeners();
    }
  }

  /// Opens the official store listing.
  Future<bool> openStore() async {
    return await versionService.launchStoreUrl(_status?.config.storeUrl);
  }

  /// Toggles the expandable release notes accordion.
  void toggleReleaseNotesExpanded() {
    _isReleaseNotesExpanded = !_isReleaseNotesExpanded;
    notifyListeners();
  }

  /// Returns whether a given feature flag is active on the server.
  bool isFeatureEnabled(String flagKey, {bool defaultValue = false}) {
    if (_status?.config.featureFlags.containsKey(flagKey) == true) {
      final val = _status!.config.featureFlags[flagKey];
      return val is bool ? val : defaultValue;
    }
    return defaultValue;
  }

  @override
  void dispose() {
    inAppUpdateService?.removeListener(_onInAppUpdateServiceChanged);
    super.dispose();
  }
}
