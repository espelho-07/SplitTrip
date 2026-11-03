import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel bridge interfacing native Android Storage Access Framework (SAF)
/// and system Share Intent for cross-app migration between SplitTrip and Finances.
class PlatformMigrationChannel {
  static const MethodChannel _channel = MethodChannel('com.kith.migration/channel');

  /// Checks if the native migration channel is supported on the current platform.
  static Future<bool> isPlatformChannelSupported() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final available = await _channel.invokeMethod<bool>('isAvailable');
        return available ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Prompts the user with Android's system document creator (SAF `ACTION_CREATE_DOCUMENT`),
  /// allowing them to choose any storage location (Downloads, Documents, Drive, SD card).
  ///
  /// Returns the target URI/path if saved successfully, or null if cancelled.
  static Future<String?> saveFileViaSAF({
    required String fileName,
    required String content,
    String mimeType = 'application/json',
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final uri = await _channel.invokeMethod<String>('saveFileViaSAF', {
          'fileName': fileName,
          'content': content,
          'mimeType': mimeType,
        });
        return uri;
      } catch (e) {
        debugPrint('[PlatformMigrationChannel] saveFileViaSAF error: $e');
        return null;
      }
    }
    return null;
  }

  /// Prompts the user with Android's system document picker (SAF `ACTION_OPEN_DOCUMENT`),
  /// allowing them to pick the migration file from any accessible directory.
  ///
  /// Returns the UTF-8 text content of the selected file, or null if cancelled.
  static Future<String?> pickFileViaSAF({
    String mimeType = '*/*',
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final content = await _channel.invokeMethod<String>('pickFileViaSAF', {
          'mimeType': mimeType,
        });
        return content;
      } catch (e) {
        debugPrint('[PlatformMigrationChannel] pickFileViaSAF error: $e');
        return null;
      }
    }
    return null;
  }

  /// Shares the migration payload directly via Android's system share sheet (`ACTION_SEND`).
  /// Users can directly select "Finances" from the share sheet, or share via Drive, Files, etc.
  static Future<bool> sharePayload({
    required String title,
    required String content,
    String? subject,
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final success = await _channel.invokeMethod<bool>('sharePayload', {
          'title': title,
          'content': content,
          'subject': subject ?? 'Kith Financial Migration Archive',
        });
        return success ?? false;
      } catch (e) {
        debugPrint('[PlatformMigrationChannel] sharePayload error: $e');
        return false;
      }
    }
    return false;
  }

  /// Retrieves any pending migration payload received when Finances was launched or resumed
  /// via an incoming Android `ACTION_SEND` Intent.
  static Future<String?> getSharedMigrationPayload() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final payload = await _channel.invokeMethod<String>('getSharedMigrationPayload');
        return payload;
      } catch (e) {
        debugPrint('[PlatformMigrationChannel] getSharedMigrationPayload error: $e');
        return null;
      }
    }
    return null;
  }
}
