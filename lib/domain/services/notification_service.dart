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
  final String? idempotencyKey;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.route,
    this.actionLabel,
    this.idempotencyKey,
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
    if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
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
      idempotencyKey: json['idempotencyKey'] as String?,
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
    String? idempotencyKey,
  }) async {
    // Check preference
    if (type == NotificationType.expense && !_expenseNotificationsEnabled) return;
    if (type == NotificationType.trip && !_tripNotificationsEnabled) return;
    if (type == NotificationType.settlement && !_settlementNotificationsEnabled) return;

    // Idempotency: skip if a notification with this key already exists
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      final existing = getNotifications();
      final alreadyExists = existing.any((n) => n.idempotencyKey == idempotencyKey);
      if (alreadyExists) return;
    }

    final item = AppNotificationItem(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
      route: route,
      actionLabel: actionLabel,
      idempotencyKey: idempotencyKey,
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

  /// Dispatched when Payer marks payment as paid (Receiver receives this notice)
  Future<void> notifyPaymentMarkedPaid({
    required String tripName,
    required String payerName,
    required String receiverName,
    required int amountInPaise,
    required String verificationId,
    String? tripId,
  }) async {
    final amtFormatted = '₹${(amountInPaise / 100.0).toStringAsFixed(amountInPaise % 100 == 0 ? 0 : 2)}';
    await addNotification(
      title: 'Payment Verification • $tripName',
      description: '$payerName marked $amtFormatted as paid to $receiverName for $tripName. Tap to confirm receipt.',
      type: NotificationType.settlement,
      route: tripId != null ? '/trip/$tripId' : null,
      actionLabel: 'Verify Payment',
    );
  }

  /// Dispatched when Receiver confirms receipt (Payer receives this notice)
  Future<void> notifyPaymentConfirmed({
    required String tripName,
    required String payerName,
    required String receiverName,
    required int amountInPaise,
    String? tripId,
  }) async {
    final amtFormatted = '₹${(amountInPaise / 100.0).toStringAsFixed(amountInPaise % 100 == 0 ? 0 : 2)}';
    await addNotification(
      title: 'Payment Received ✓ • $tripName',
      description: '$receiverName confirmed receiving $amtFormatted for $tripName! All balances updated.',
      type: NotificationType.settlement,
      route: tripId != null ? '/trip/$tripId' : null,
      actionLabel: 'View Trip',
    );
  }

  /// Dispatched when Receiver disputes payment (Payer receives this notice)
  Future<void> notifyPaymentDisputed({
    required String tripName,
    required String payerName,
    required String receiverName,
    required int amountInPaise,
    String? tripId,
    String? reason,
  }) async {
    final amtFormatted = '₹${(amountInPaise / 100.0).toStringAsFixed(amountInPaise % 100 == 0 ? 0 : 2)}';
    await addNotification(
      title: 'Payment Not Received ⚠️ • $tripName',
      description: '$receiverName indicated they did not receive $amtFormatted for $tripName. Tap to submit proof or retry payment.',
      type: NotificationType.settlement,
      route: tripId != null ? '/trip/$tripId' : null,
      actionLabel: 'Send Proof',
    );
  }

  /// Dispatched when Payer submits payment proof (Receiver receives this notice)
  Future<void> notifyPaymentProofSubmitted({
    required String tripName,
    required String payerName,
    required String receiverName,
    required int amountInPaise,
    String? tripId,
    String? transactionRef,
  }) async {
    final amtFormatted = '₹${(amountInPaise / 100.0).toStringAsFixed(amountInPaise % 100 == 0 ? 0 : 2)}';
    final refStr = transactionRef != null && transactionRef.isNotEmpty ? ' (Ref: $transactionRef)' : '';
    await addNotification(
      title: 'Payment Proof Submitted 📄 • $tripName',
      description: '$payerName submitted payment proof for $amtFormatted$refStr. Tap to review and confirm receipt.',
      type: NotificationType.settlement,
      route: tripId != null ? '/trip/$tripId' : null,
      actionLabel: 'Review Proof',
    );
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
