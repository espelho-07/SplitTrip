// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../data/services/local_storage_service.dart';
import '../../domain/services/notification_service.dart';
import '../network/api_client.dart';

/// FCM background message handler — MUST be a top-level function.
@pragma('vm:entry-point')
Future<void> kithFcmBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message received: ${message.messageId}');
  // Background/terminated notifications with a notification payload
  // are displayed automatically by the FCM SDK.
}

/// Service that manages Firebase Cloud Messaging for Kith.
class FcmService {
  final ApiClient _apiClient;
  final LocalStorageService _storage;
  final NotificationService _notificationService;

  /// Called when a notification tap should navigate to a route.
  void Function(String route)? onNavigate;

  FcmService({
    required ApiClient apiClient,
    required LocalStorageService storage,
    required NotificationService notificationService,
  })  : _apiClient = apiClient,
        _storage = storage,
        _notificationService = notificationService;

  static void registerBackgroundHandler() {

    FirebaseMessaging.onBackgroundMessage(kithFcmBackgroundHandler);
  }

  Future<void> init() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

      // Suppress FCM auto-display in foreground — we render our own styled notification
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerTokenWithServer(token);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _registerTokenWithServer(newToken);
      });

      // Foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background tap (app was backgrounded)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Terminated tap (app was killed)
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('[FCM] Init error (non-fatal): $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] as String? ?? 'Kith';
    final body = notification?.body ?? data['body'] as String? ?? '';
    final route = data['route'] as String?;
    final eventType = data['type'] as String? ?? 'settlement';
    final idempotencyKey = data['idempotencyKey'] as String?;
    final tripId = data['tripId'] as String?;
    final settlementId = data['settlementId'] as String?;
    final expenseId = data['expenseId'] as String?;

    final notifType = eventType.contains('ipo')
        ? NotificationType.ipo
        : eventType.contains('expense') || eventType.contains('debt')
            ? NotificationType.expense
            : (eventType.contains('trip') || eventType.contains('member'))
                ? NotificationType.trip
                : NotificationType.settlement;

    if (eventType == 'settlement_marked_paid' && settlementId != null) {
      // Store payment verification in local vault for immediate foreground prompt
      _storage.addPaymentVerification({
        'id': 'pvr_$settlementId',
        'settlementId': settlementId,
        'tripId': tripId ?? '',
        'tripName': data['tripName'] ?? 'Trip',
        'payerMemberId': data['payerMemberId'],
        'payerUserId': data['payerUserId'],
        'payerName': data['payerName'] ?? title,
        'receiverUserId': _storage.getSavedUser()?['id'],
        'receiverName': _storage.getSavedUser()?['displayName'] ?? 'You',
        'amountInPaise': int.tryParse(data['amountInPaise']?.toString() ?? '0') ?? 0,
        'paymentMethod': 'Direct',
        'status': 'pending_verification',
        'markedAt': DateTime.now().toIso8601String(),
      });
    }

    final ipoId = data['ipoId'] as String?;
    final personName = data['personName'] as String?;

    final targetRoute = route ??
        (tripId != null
            ? (expenseId != null
                ? '/trip/$tripId?expenseId=$expenseId'
                : (settlementId != null ? '/trip/$tripId?settlementId=$settlementId' : '/trip/$tripId'))
            : (ipoId != null
                ? '/ipo/$ipoId'
                : (personName != null
                    ? '/personal/person?name=${Uri.encodeComponent(personName)}'
                    : null)));

    _notificationService.addNotification(
      title: title,
      description: body,
      type: notifType,
      route: targetRoute,
      actionLabel: _actionLabelForType(eventType),
      idempotencyKey: idempotencyKey ??
          (expenseId != null
              ? '${expenseId}_$eventType'
              : (settlementId != null
                  ? '${settlementId}_$eventType'
                  : (ipoId != null ? '${ipoId}_$eventType' : null))),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final route = data['route'] as String?;
    final tripId = data['tripId'] as String?;
    final settlementId = data['settlementId'] as String?;
    final expenseId = data['expenseId'] as String?;
    final ipoId = data['ipoId'] as String?;
    final personName = data['personName'] as String?;

    final targetRoute = route ??
        (tripId != null
            ? (expenseId != null
                ? '/trip/$tripId?expenseId=$expenseId'
                : (settlementId != null ? '/trip/$tripId?settlementId=$settlementId' : '/trip/$tripId'))
            : (ipoId != null
                ? '/ipo/$ipoId'
                : (personName != null
                    ? '/personal/person?name=${Uri.encodeComponent(personName)}'
                    : null)));

    if (targetRoute != null && targetRoute.isNotEmpty && onNavigate != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        onNavigate?.call(targetRoute);
      });
    }
  }

  String _actionLabelForType(String eventType) {
    switch (eventType) {
      case 'settlement_marked_paid':
        return 'Confirm';
      case 'settlement_confirmed':
        return 'View';
      case 'settlement_disputed':
        return 'Resolve';
      case 'payment_proof_submitted':
        return 'Review';
      case 'expense_created':
      case 'expense_updated':
        return 'View Expense';
      case 'expense_deleted':
      case 'member_joined':
      case 'trip_completed':
        return 'View Trip';
      case 'ipo_open':
      case 'ipo_allotment':
      case 'ipo_listing':
      case 'ipo_close':
        return 'View IPO';
      case 'debt_added':
      case 'debt_repaid':
        return 'View Balance';
      default:
        return 'Open';
    }
  }

  Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerTokenWithServer(token);
      }
    } catch (e) {
      debugPrint('[FCM] registerToken error: $e');
    }
  }

  Future<void> _registerTokenWithServer(String token) async {
    try {
      var deviceId = _storage.getString('kith_device_id');
      if (deviceId == null || deviceId.isEmpty) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        deviceId = 'kith_dev_${base64Encode(ts.toString().codeUnits).replaceAll("=", "").substring(0, 12)}';
        await _storage.setString('kith_device_id', deviceId);
      }
      await _storage.setString('kith_fcm_token', token);

      final user = _storage.getSavedUser();
      if (user != null && user['id'] != null) {
        await _apiClient.post('/auth/fcm-token', body: {
          'token': token,
          'deviceId': deviceId,
          'platform': 'android',
        });
        debugPrint('[FCM] Token registered with server for user ${user['id']}');
      } else {
        debugPrint('[FCM] Token saved locally, will register once user session is active');
      }
    } catch (e) {
      debugPrint('[FCM] Token registration notice: $e');
    }
  }

  Future<void> unregisterToken() async {
    try {
      final token = _storage.getString('kith_fcm_token');
      if (token != null) {
        await _apiClient.post('/auth/fcm-token/delete', body: {'token': token});
      }
      await _storage.remove('kith_fcm_token');
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[FCM] Token unregister failed: $e');
    }
  }
}


