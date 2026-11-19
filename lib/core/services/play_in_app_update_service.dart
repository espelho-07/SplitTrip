import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// State of the Google Play In-App Update flow.
enum PlayUpdateState {
  idle,
  checking,
  available,
  downloading,
  downloaded,
  completed,
  failed,
  notAvailable,
}

/// Production service managing official Android Google Play In-App Updates
/// (Flexible and Immediate flows) with safe fallbacks and zero user disruption.
class PlayInAppUpdateService extends ChangeNotifier {
  PlayUpdateState _state = PlayUpdateState.idle;
  AppUpdateInfo? _updateInfo;
  String? _errorMessage;
  StreamSubscription<InstallStatus>? _installSubscription;

  PlayInAppUpdateService();

  PlayUpdateState get state => _state;
  AppUpdateInfo? get updateInfo => _updateInfo;
  String? get errorMessage => _errorMessage;

  bool get isUpdateAvailable =>
      _updateInfo?.updateAvailability == UpdateAvailability.updateAvailable;

  bool get isFlexibleAllowed => _updateInfo?.flexibleUpdateAllowed ?? false;
  bool get isImmediateAllowed => _updateInfo?.immediateUpdateAllowed ?? false;
  bool get isDownloaded => _state == PlayUpdateState.downloaded;
  bool get isDownloading => _state == PlayUpdateState.downloading;

  /// Checks Google Play for an available in-app update.
  /// Safely catches platform exceptions when running outside Play Store (e.g. debug/sideload).
  Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _state = PlayUpdateState.notAvailable;
      notifyListeners();
      return null;
    }

    _state = PlayUpdateState.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final info = await InAppUpdate.checkForUpdate();
      _updateInfo = info;

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        _state = PlayUpdateState.available;
      } else {
        _state = PlayUpdateState.notAvailable;
      }
      notifyListeners();
      return info;
    } catch (e) {
      debugPrint('[PlayInAppUpdateService] In-App Update check notice (non-fatal): $e');
      _errorMessage = e.toString();
      _state = PlayUpdateState.notAvailable;
      notifyListeners();
      return null;
    }
  }

  /// Initiates a background Flexible Update:
  /// Downloads update in background while user continues using Kith.
  Future<bool> startFlexibleUpdate() async {
    if (!isFlexibleAllowed) {
      debugPrint('[PlayInAppUpdateService] Flexible update is not allowed or unavailable.');
      return false;
    }

    try {
      _state = PlayUpdateState.downloading;
      notifyListeners();

      // Listen for download completion
      _installSubscription?.cancel();
      _installSubscription = InAppUpdate.installUpdateListener.listen((status) {
        debugPrint('[PlayInAppUpdateService] Install status: $status');
        if (status == InstallStatus.downloaded) {
          _state = PlayUpdateState.downloaded;
          notifyListeners();
        } else if (status == InstallStatus.failed || status == InstallStatus.canceled) {
          _state = PlayUpdateState.failed;
          notifyListeners();
        }
      });

      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.userDeniedUpdate) {
        _state = PlayUpdateState.idle;
        notifyListeners();
        return false;
      } else if (result == AppUpdateResult.inAppUpdateFailed) {
        _state = PlayUpdateState.failed;
        notifyListeners();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[PlayInAppUpdateService] Flexible update error: $e');
      _errorMessage = e.toString();
      _state = PlayUpdateState.failed;
      notifyListeners();
      return false;
    }
  }

  /// Finalizes a downloaded flexible update:
  /// Triggers app restart to apply the new version.
  Future<void> completeFlexibleUpdate() async {
    if (_state != PlayUpdateState.downloaded) return;

    try {
      await InAppUpdate.completeFlexibleUpdate();
      _state = PlayUpdateState.completed;
      notifyListeners();
    } catch (e) {
      debugPrint('[PlayInAppUpdateService] Error completing flexible update: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Initiates an Immediate Update flow (full-screen blocking Play Store UI).
  /// Used for critical security patches and breaking API transitions.
  Future<bool> performImmediateUpdate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      if (result == AppUpdateResult.success) {
        _state = PlayUpdateState.completed;
        notifyListeners();
        return true;
      } else if (result == AppUpdateResult.userDeniedUpdate) {
        _state = PlayUpdateState.available;
      } else {
        _state = PlayUpdateState.failed;
      }
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[PlayInAppUpdateService] Immediate update error: $e');
      _errorMessage = e.toString();
      _state = PlayUpdateState.failed;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _installSubscription?.cancel();
    super.dispose();
  }
}
