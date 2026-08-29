import 'dart:async';
import 'package:flutter/services.dart';
import '../../data/services/local_storage_service.dart';

enum NotificationCategory {
  expenseActivity,
  tripActivity,
  settlementActivity,
  systemActivity,
}

enum NotificationType {
  expense,
  settlement,
  trip,
  system,
}

class AppNotificationItem {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final NotificationType type;
  bool isRead;
  final String? route;
  final String? actionLabel;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.route,
    this.actionLabel,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'isRead': isRead,
    'route': route,
    'actionLabel': actionLabel,
  };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id'] as String? ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Notification',
      description: json['description'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      isRead: json['isRead'] as bool? ?? false,
      route: json['route'] as String?,
      actionLabel: json['actionLabel'] as String?,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class AppNotificationPayload {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final String? tripId;
  final String? expenseId;
  final String? settlementId;
  final DateTime createdAt;

  AppNotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.tripId,
    this.expenseId,
    this.settlementId,
    required this.createdAt,
  });

  String? get targetRoute {
    if (tripId != null) return '/trip/$tripId';
    if (settlementId != null) return '/personal/balances';
    return null;
  }
}

/// Notification manager with persistence, preference filtering and deep link routing.
class NotificationService {
  static const String _prefExpenseKey = 'notif_pref_expense';
  static const String _prefTripKey = 'notif_pref_trip';
  static const String _prefSettlementKey = 'notif_pref_settlement';

  final LocalStorageService? _storage;
  final StreamController<AppNotificationItem> _notificationStreamController =
      StreamController<AppNotificationItem>.broadcast();

  NotificationService([this._storage]);

  Stream<AppNotificationItem> get onNotification => _notificationStreamController.stream;

  bool _expenseNotificationsEnabled = true;
  bool _tripNotificationsEnabled = true;
  bool _settlementNotificationsEnabled = true;

  bool get expenseNotificationsEnabled => _expenseNotificationsEnabled;
  bool get tripNotificationsEnabled => _tripNotificationsEnabled;
  bool get settlementNotificationsEnabled => _settlementNotificationsEnabled;

  Future<void> init() async {
    _expenseNotificationsEnabled = _storage?.getBool(_prefExpenseKey) ?? true;
    _tripNotificationsEnabled = _storage?.getBool(_prefTripKey) ?? true;
    _settlementNotificationsEnabled = _storage?.getBool(_prefSettlementKey) ?? true;
  }

  Future<void> setPreference(NotificationCategory category, bool enabled) async {
    switch (category) {
      case NotificationCategory.expenseActivity:
        _expenseNotificationsEnabled = enabled;
        await _storage?.setBool(_prefExpenseKey, enabled);
        break;
      case NotificationCategory.tripActivity:
        _tripNotificationsEnabled = enabled;
        await _storage?.setBool(_prefTripKey, enabled);
        break;
      case NotificationCategory.settlementActivity:
        _settlementNotificationsEnabled = enabled;
        await _storage?.setBool(_prefSettlementKey, enabled);
        break;
      case NotificationCategory.systemActivity:
        break;
    }
  }

  bool dispatchNotification(AppNotificationPayload payload) {
    switch (payload.category) {
      case NotificationCategory.expenseActivity:
        if (!_expenseNotificationsEnabled) return false;
        break;
      case NotificationCategory.tripActivity:
        if (!_tripNotificationsEnabled) return false;
        break;
      case NotificationCategory.settlementActivity:
        if (!_settlementNotificationsEnabled) return false;
        break;
      case NotificationCategory.systemActivity:
        break;
    }
    return true;
  }

  List<AppNotificationItem> getNotifications() {
    final raw = _storage?.getSavedNotifications() ?? [];
    return raw.map((json) => AppNotificationItem.fromJson(json)).toList();
  }

  int get unreadCount => _storage?.getUnreadNotificationCount() ?? 0;

  Future<void> addNotification({
    required String title,
    required String description,
    required NotificationType type,
    String? route,
    String? actionLabel,
  }) async {
    // Check preference
    if (type == NotificationType.expense && !_expenseNotificationsEnabled) return;
    if (type == NotificationType.trip && !_tripNotificationsEnabled) return;
    if (type == NotificationType.settlement && !_settlementNotificationsEnabled) return;

    final item = AppNotificationItem(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
      route: route,
      actionLabel: actionLabel,
    );

    await _storage?.addNotification(item.toJson());
    _notificationStreamController.add(item);

    // Push to Android System Status Bar
    final pushEnabled = _storage?.getBool('notif_pref_push') ?? true;
    if (pushEnabled) {
      try {
        const platform = MethodChannel('com.nirniq.kith/notifications');
        final notifId = (DateTime.now().millisecondsSinceEpoch % 100000);
        await platform.invokeMethod('showNotification', {
          'id': notifId,
          'title': title,
          'body': description,
          'route': route,
        });
      } catch (_) {
        // Fallback or non-Android platform
      }
    }
  }

  Future<void> markAllAsRead() async {
    await _storage?.markAllNotificationsAsRead();
  }

  Future<void> markAsRead(String id) async {
    await _storage?.markNotificationAsRead(id);
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
