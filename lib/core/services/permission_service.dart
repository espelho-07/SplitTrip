import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages runtime permissions in Kith.
///
/// 1. Prompts for core permissions (Notifications, Camera, Microphone, Location) on first app opening.
/// 2. If any permission is denied, features gracefully fallback and re-request permissions contextually
///    when the user explicitly invokes the corresponding feature.
class PermissionService {
  PermissionService._();

  /// Requests all necessary permissions sequentially on first launch.
  /// Non-blocking: failures or denials never block the app.
  static Future<void> requestInitialAppPermissions() async {
    if (kIsWeb) return;

    try {
      final permissions = [
        Permission.notification,
        Permission.camera,
        Permission.microphone,
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
      ];
      await permissions.request();
    } catch (e) {
      debugPrint('[PermissionService] Error during initial permissions request: $e');
    }
  }

  /// Explicitly requests Nearby P2P & Bluetooth permissions when user searches for nearby devices.
  static Future<bool> requestNearbyPermissions() async {
    if (kIsWeb) return true;

    try {
      final statuses = await [
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
      ].request();

      return statuses.values.any((s) => s.isGranted);
    } catch (e) {
      debugPrint('[PermissionService] Error requesting nearby permissions: $e');
      return false;
    }
  }

  /// Explicitly requests Microphone permission when user initiates voice expense recording.
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

  /// Explicitly requests Camera permission when user opens QR Scanner or Receipt Scanner.
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

  /// Explicitly requests Location permission when user fetches nearby location or merchant.
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

  /// Explicitly requests Notification permission when user enables cloud sync or notifications.
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
