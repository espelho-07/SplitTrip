import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class KithDeviceContact {
  final String name;
  final String phone;
  final String? photo;

  const KithDeviceContact({
    required this.name,
    required this.phone,
    this.photo,
  });

  factory KithDeviceContact.fromMap(Map<dynamic, dynamic> map) {
    return KithDeviceContact(
      name: (map['name'] as String?)?.trim() ?? '',
      phone: (map['phone'] as String?)?.trim() ?? '',
      photo: map['photo'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'photo': photo,
      };
}

class KithContactsService {
  static const MethodChannel _channel = MethodChannel('com.nirniq.kith/contacts');

  /// Checks and requests runtime Contacts permission.
  static Future<bool> requestPermission() async {
    try {
      final status = await Permission.contacts.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[KithContactsService] Permission error: $e');
      return false;
    }
  }

  /// Checks if contacts permission is granted.
  static Future<bool> hasPermission() async {
    try {
      final status = await Permission.contacts.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Opens the native OS contact picker and returns selected contact if any.
  static Future<KithDeviceContact?> pickContact() async {
    try {
      final granted = await hasPermission() || await requestPermission();
      if (!granted) return null;

      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickContact');
      if (res != null) {
        return KithDeviceContact.fromMap(res);
      }
    } catch (e) {
      debugPrint('[KithContactsService] pickContact error: $e');
    }
    return null;
  }

  /// Retrieves device contacts list matching query.
  static Future<List<KithDeviceContact>> getContacts({String? query, int limit = 50}) async {
    try {
      final granted = await hasPermission();
      if (!granted) return [];

      final res = await _channel.invokeListMethod<dynamic>('getContacts', {
        'query': query,
        'limit': limit,
      });

      if (res != null) {
        return res
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => KithDeviceContact.fromMap(m))
            .where((c) => c.name.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[KithContactsService] getContacts error: $e');
    }
    return [];
  }
}
