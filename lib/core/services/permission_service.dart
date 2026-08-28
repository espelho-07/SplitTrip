import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages on-demand, contextual runtime permissions in strict compliance
/// with Google Play Permissions and Data Minimization policies.
///
/// Permissions are NEVER requested in batch or on initial app startup.
/// Each permission is requested only when the user explicitly invokes the corresponding feature.
class PermissionService {
  PermissionService._();

  /// Explicitly requests Microphone permission ONLY when user initiates voice expense recording.
  static Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) return true;

    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;

      final result = await Permission.microphone.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('[PermissionService] Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Explicitly requests Camera permission ONLY when user opens QR Scanner or Receipt Scanner.
  static Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true;

    try {
      final status = await Permission.camera.status;
      if (status.isGranted) return true;

      final result = await Permission.camera.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('[PermissionService] Error requesting camera permission: $e');
      return false;
    }
  }

  /// Explicitly requests Notification permission ONLY when user enables cloud sync or notifications.
  /// Explicitly requests Location permission ONLY when user adds a journey location pin.
  static Future<bool> requestLocationPermission() async {
    if (kIsWeb) return true;

    try {
      final status = await Permission.locationWhenInUse.status;
      if (status.isGranted) return true;

      final result = await Permission.locationWhenInUse.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('[PermissionService] Error requesting location permission: $e');
      return false;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;

    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;

      final result = await Permission.notification.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('[PermissionService] Error requesting notification permission: $e');
      return false;
    }
  }
}
