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

    final notifType = eventType.contains('expense')
        ? NotificationType.expense
        : eventType.contains('trip')
            ? NotificationType.trip
            : NotificationType.settlement;

    _notificationService.addNotification(
      title: title,
      description: body,
      type: notifType,
      route: route,
      actionLabel: _actionLabelForType(eventType),
      idempotencyKey: idempotencyKey,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null && route.isNotEmpty && onNavigate != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        onNavigate?.call(route);
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

      await _apiClient.post('/auth/fcm-token', body: {
        'token': token,
        'deviceId': deviceId,
        'platform': 'android',
      });
      debugPrint('[FCM] Token registered with server');
    } catch (e) {
      debugPrint('[FCM] Token registration failed (will retry on next launch): $e');
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


