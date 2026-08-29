import 'package:flutter/foundation.dart';
import '../../core/services/app_version_service.dart';
import '../../domain/models/app_version_info.dart';

/// ViewModel managing reactive app version state, update checks, dismissal,
/// and store navigation.
class VersionViewModel extends ChangeNotifier {
  final AppVersionService versionService;

  AppVersionCheckResult? _status;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isReleaseNotesExpanded = false;

  VersionViewModel({
    required this.versionService,
  });

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

  /// Checks for application updates from the backend.
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
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
}
