import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationCategory {
  expenseActivity,
  tripActivity,
  settlementActivity,
}

class AppNotificationPayload {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final String tripId;
  final String? expenseId;
  final String? settlementId;
  final DateTime createdAt;

  const AppNotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.tripId,
    this.expenseId,
    this.settlementId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category.name,
    'tripId': tripId,
    'expenseId': expenseId,
    'settlementId': settlementId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppNotificationPayload.fromJson(Map<String, dynamic> json) {
    return AppNotificationPayload(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      category: NotificationCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => NotificationCategory.tripActivity,
      ),
      tripId: json['tripId'] as String,
      expenseId: json['expenseId'] as String?,
      settlementId: json['settlementId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Calculates the deep link navigation route for this notification.
  String get targetRoute {
    if (settlementId != null) {
      return '/trip/$tripId';
    }
    return '/trip/$tripId';
  }
}

/// Notification manager with preference filtering and deep link routing.
class NotificationService {
  static const String _prefExpenseKey = 'notif_pref_expense';
  static const String _prefTripKey = 'notif_pref_trip';
  static const String _prefSettlementKey = 'notif_pref_settlement';

  final StreamController<AppNotificationPayload> _notificationStreamController =
      StreamController<AppNotificationPayload>.broadcast();

  Stream<AppNotificationPayload> get onNotification => _notificationStreamController.stream;

  bool _expenseNotificationsEnabled = true;
  bool _tripNotificationsEnabled = true;
  bool _settlementNotificationsEnabled = true;

  bool get expenseNotificationsEnabled => _expenseNotificationsEnabled;
  bool get tripNotificationsEnabled => _tripNotificationsEnabled;
  bool get settlementNotificationsEnabled => _settlementNotificationsEnabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _expenseNotificationsEnabled = prefs.getBool(_prefExpenseKey) ?? true;
    _tripNotificationsEnabled = prefs.getBool(_prefTripKey) ?? true;
    _settlementNotificationsEnabled = prefs.getBool(_prefSettlementKey) ?? true;
  }

  Future<void> setPreference(NotificationCategory category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    switch (category) {
      case NotificationCategory.expenseActivity:
        _expenseNotificationsEnabled = enabled;
        await prefs.setBool(_prefExpenseKey, enabled);
        break;
      case NotificationCategory.tripActivity:
        _tripNotificationsEnabled = enabled;
        await prefs.setBool(_prefTripKey, enabled);
        break;
      case NotificationCategory.settlementActivity:
        _settlementNotificationsEnabled = enabled;
        await prefs.setBool(_prefSettlementKey, enabled);
        break;
    }
  }

  /// Dispatches a notification if the category is enabled in user preferences.
  bool dispatchNotification(AppNotificationPayload payload) {
    bool isAllowed = false;
    switch (payload.category) {
      case NotificationCategory.expenseActivity:
        isAllowed = _expenseNotificationsEnabled;
        break;
      case NotificationCategory.tripActivity:
        isAllowed = _tripNotificationsEnabled;
        break;
      case NotificationCategory.settlementActivity:
        isAllowed = _settlementNotificationsEnabled;
        break;
    }

    if (isAllowed) {
      _notificationStreamController.add(payload);
      return true;
    }
    return false;
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
