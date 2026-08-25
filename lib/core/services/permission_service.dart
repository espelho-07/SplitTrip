import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static const String _keyInitialPermissionsRequested = 'kith_initial_permissions_requested';

  /// Requests core app permissions (Location, Microphone, Camera, Notifications) on first launch.
  static Future<void> requestInitialPermissions({bool force = false}) async {
    if (kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRequested = prefs.getBool(_keyInitialPermissionsRequested) ?? false;

      if (!hasRequested || force) {
        // Request essential permissions together on first app launch / onboarding
        await [
          Permission.locationWhenInUse,
          Permission.microphone,
          Permission.camera,
          Permission.notification,
        ].request();

        await prefs.setBool(_keyInitialPermissionsRequested, true);
      }
    } catch (e) {
      debugPrint('[PermissionService] Error requesting initial permissions: $e');
    }
  }

  /// Explicitly requests Microphone permission when user taps on voice input.
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

  /// Explicitly requests Camera permission when user taps on receipt scanner.
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

  /// Explicitly requests Location permission ONLY when user opts in to auto-journey on a trip.
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
}
