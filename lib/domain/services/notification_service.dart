import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/network/api_client.dart';
import '../../data/services/local_storage_service.dart';

enum NotificationCategory {
  expenseActivity,
  tripActivity,
  settlementActivity,
  ipoActivity,
  systemActivity,
}

enum NotificationType {
  expense,
  settlement,
  trip,
  ipo,
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
  static const String _prefIpoKey = 'notif_pref_ipo';

  final LocalStorageService? _storage;
  final StreamController<AppNotificationItem> _notificationStreamController =
      StreamController<AppNotificationItem>.broadcast();

  NotificationService([this._storage]);

  Stream<AppNotificationItem> get onNotification => _notificationStreamController.stream;

  bool _expenseNotificationsEnabled = true;
  bool _tripNotificationsEnabled = true;
  bool _settlementNotificationsEnabled = true;
  bool _ipoNotificationsEnabled = true;

  bool get expenseNotificationsEnabled => _expenseNotificationsEnabled;
  bool get tripNotificationsEnabled => _tripNotificationsEnabled;
  bool get settlementNotificationsEnabled => _settlementNotificationsEnabled;
  bool get ipoNotificationsEnabled => _ipoNotificationsEnabled;

  Future<void> init() async {
    _expenseNotificationsEnabled = _storage?.getBool(_prefExpenseKey) ?? true;
    _tripNotificationsEnabled = _storage?.getBool(_prefTripKey) ?? true;
    _settlementNotificationsEnabled = _storage?.getBool(_prefSettlementKey) ?? true;
    _ipoNotificationsEnabled = _storage?.getBool(_prefIpoKey) ?? true;
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
      case NotificationCategory.ipoActivity:
        _ipoNotificationsEnabled = enabled;
        await _storage?.setBool(_prefIpoKey, enabled);
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
      case NotificationCategory.ipoActivity:
        if (!_ipoNotificationsEnabled) return false;
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
    if (type == NotificationType.ipo && !_ipoNotificationsEnabled) return;

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

  /// Syncs notifications from the backend server into local storage
  Future<void> syncServerNotifications(ApiClient apiClient) async {
    try {
      final res = await apiClient.get('/notifications');
      if (res is List) {
        for (final item in res) {
          if (item is Map) {
            final notifMap = Map<String, dynamic>.from(item);
            final typeStr = notifMap['type'] as String? ?? '';
            final isExpense = typeStr.toLowerCase().contains('expense');
            final notifType = isExpense
                ? NotificationType.expense
                : typeStr.toLowerCase().contains('trip')
                    ? NotificationType.trip
                    : NotificationType.settlement;

            String actionLabel = 'Open';
            if (typeStr == 'PAYMENT_CONFIRMATION_REQUIRED') {
              actionLabel = 'Verify Payment';
            } else if (typeStr == 'EXPENSE_CREATED' || typeStr == 'EXPENSE_UPDATED') {
              actionLabel = 'View Expense';
            } else if (typeStr == 'EXPENSE_DELETED') {
              actionLabel = 'View Trip';
            }

            final parsedItem = AppNotificationItem(
              id: notifMap['id'] as String? ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
              title: notifMap['title'] as String? ?? 'Notification',
              description: notifMap['description'] as String? ?? notifMap['body'] as String? ?? '',
              timestamp: notifMap['createdAt'] != null
                  ? DateTime.tryParse(notifMap['createdAt'] as String) ?? DateTime.now()
                  : DateTime.now(),
              type: notifType,
              isRead: notifMap['isRead'] as bool? ?? false,
              route: notifMap['route'] as String?,
              actionLabel: actionLabel,
              idempotencyKey: notifMap['id'] as String? ?? (notifMap['expenseId'] != null ? '${notifMap['expenseId']}_$typeStr' : (notifMap['settlementId'] != null ? '${notifMap['settlementId']}_$typeStr' : null)),
            );

            // Add without popping extra system status bar notification if syncing historical records
            await _storage?.addNotification(parsedItem.toJson());
          }
        }
      }
    } catch (_) {
      // Non-blocking background sync
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
      description: '$payerName says they paid you $amtFormatted.',
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

  /// Checks milestones for given IPOs and dispatches idempotent notifications
  Future<void> checkAndDispatchIpoReminders({
    required List<dynamic> ipos,
    List<dynamic>? applications,
  }) async {
    if (!_ipoNotificationsEnabled) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayStr = '${now.year}_${now.month}_${now.day}';

    for (final rawIpo in ipos) {
      try {
        final ipoId = rawIpo.id as String;
        final ipoName = rawIpo.name as String;
        final symbol = rawIpo.symbol as String?;
        final symbolTag = symbol?.isNotEmpty == true ? ' ($symbol)' : '';
        final priceBandFormatted = rawIpo.priceBandFormatted as String? ?? 'Cutoff Price';
        final minInvestment = rawIpo.minInvestmentRupees as int? ?? 0;
        final openDate = rawIpo.openDate as DateTime;
        final closeDate = rawIpo.closeDate as DateTime;
        final allotmentDate = rawIpo.allotmentDate as DateTime?;
        final listingDate = rawIpo.listingDate as DateTime?;

        final open = DateTime(openDate.year, openDate.month, openDate.day);
        final close = DateTime(closeDate.year, closeDate.month, closeDate.day);

        // 1. Opens today
        if (open.isAtSameMomentAs(today)) {
          await addNotification(
            title: 'IPO Opens Today • $ipoName$symbolTag',
            description: '$ipoName is now open for bidding ($priceBandFormatted, min ₹$minInvestment).',
            type: NotificationType.ipo,
            route: '/ipo/$ipoId',
            actionLabel: 'View IPO',
            idempotencyKey: 'ipo_open_${ipoId}_$todayStr',
          );
        }

        // 2. Closes tomorrow
        if (close.isAtSameMomentAs(tomorrow)) {
          await addNotification(
            title: 'IPO Closes Tomorrow ⚠️ • $ipoName',
            description: 'Bidding for $ipoName closes tomorrow. Don\'t miss applying if interested.',
            type: NotificationType.ipo,
            route: '/ipo/$ipoId',
            actionLabel: 'Apply Now',
            idempotencyKey: 'ipo_close_tomorrow_${ipoId}_$todayStr',
          );
        }

        // 3. Last day to apply (Closes today)
        if (close.isAtSameMomentAs(today)) {
          await addNotification(
            title: 'Last Day to Apply ⏳ • $ipoName',
            description: 'Today is the final day to submit your bid for $ipoName (closes by 5:00 PM).',
            type: NotificationType.ipo,
            route: '/ipo/$ipoId',
            actionLabel: 'Apply Now',
            idempotencyKey: 'ipo_close_today_${ipoId}_$todayStr',
          );
        }

        // 4. Allotment expected today
        if (allotmentDate != null) {
          final allot = DateTime(allotmentDate.year, allotmentDate.month, allotmentDate.day);
          if (allot.isAtSameMomentAs(today)) {
            await addNotification(
              title: 'Allotment Expected Today 🎯 • $ipoName',
              description: 'Allotment status for $ipoName is scheduled to be finalized today.',
              type: NotificationType.ipo,
              route: '/ipo/$ipoId',
              actionLabel: 'Check Status',
              idempotencyKey: 'ipo_allotment_${ipoId}_$todayStr',
            );
          }
        }

        // 5. Listing today
        if (listingDate != null) {
          final list = DateTime(listingDate.year, listingDate.month, listingDate.day);
          if (list.isAtSameMomentAs(today)) {
            await addNotification(
              title: 'IPO Listing Today 🚀 • $ipoName',
              description: '$ipoName$symbolTag is scheduled to list on the stock exchanges today.',
              type: NotificationType.ipo,
              route: '/ipo/$ipoId',
              actionLabel: 'View Listing',
              idempotencyKey: 'ipo_listing_${ipoId}_$todayStr',
            );
          }
        }
      } catch (_) {}
    }
  }

  /// Dispatches an application status update notification
  Future<void> notifyIpoApplicationUpdated({
    required String ipoId,
    required String ipoName,
    required String statusDisplayName,
    required String applicationId,
  }) async {
    await addNotification(
      title: 'IPO Application: $ipoName',
      description: 'Your application status for $ipoName was updated to $statusDisplayName.',
      type: NotificationType.ipo,
      route: '/ipo/$ipoId',
      actionLabel: 'View Application',
      idempotencyKey: 'ipo_app_${applicationId}_${statusDisplayName}_${DateTime.now().day}_${DateTime.now().hour}',
    );
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
