import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/supabase_config.dart';
import '../../data/services/local_storage_service.dart';
import '../../domain/services/notification_service.dart';
import '../network/api_client.dart';
import 'supabase_cloud_sync.dart';

/// Top-level background message entry-point for Firebase Cloud Messaging.
/// Executed in an isolated headless VM when Android receives a background/terminated push.
@pragma('vm:entry-point')
Future<void> kithFcmBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background push received: messageId=${message.messageId}, data=${message.data}');
  // System-level notification payloads with android.notification.channel_id are posted
  // natively to the Android notification shade by Google Play Services without requiring Dart UI.
}

/// Production FCM Service managing token lifecycle, foreground/background dispatch,
/// cold-boot deep links, channel routing, and idempotent deduplication.
class FcmService {
  final ApiClient apiClient;
  final LocalStorageService storage;
  final NotificationService notificationService;
  final SupabaseCloudSync _cloudSync = SupabaseCloudSync();

  ApiClient get _apiClient => apiClient;
  LocalStorageService get _storage => storage;
  NotificationService get _notificationService => notificationService;

  void Function(String route)? _onNavigate;
  String? _pendingRoute;
  String? _pendingInitialRoute;

  final Set<String> _processedMessageIds = <String>{};

  FcmService({
    required this.apiClient,
    required this.storage,
    required this.notificationService,
  });

  void setNavigationHandler(void Function(String route) handler) {
    _onNavigate = handler;
    if (_pendingRoute != null) {
      final route = _pendingRoute!;
      _pendingRoute = null;
      Future.delayed(const Duration(milliseconds: 350), () {
        handler(route);
      });
    }
  }

  void Function(String route)? get onNavigate => _onNavigate;
  set onNavigate(void Function(String route)? handler) {
    if (handler != null) {
      setNavigationHandler(handler);
    } else {
      _onNavigate = null;
    }
  }

  /// Consumes and clears any initial route set when the app was launched by tapping
  /// a notification while the process was terminated/killed.
  String? consumePendingInitialRoute() {
    final route = _pendingInitialRoute;
    _pendingInitialRoute = null;
    return route;
  }

  /// Registers the top-level background handler. Must be called in main().
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(kithFcmBackgroundHandler);
  }

  /// Initializes FCM permissions, token registration, streams, and initial messages.
  Future<void> init() async {
    try {
      // 1. Android 13+ runtime POST_NOTIFICATIONS permission
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // Suppress FCM auto-banner in foreground — we display our own in-app notification
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      // 2. Initial token registration
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerTokenWithServer(token);
      }

      // 3. Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Token refreshed');
        await _registerTokenWithServer(newToken);
      });

      // 4. Foreground message listener
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 5. Background message opened listener (app backgrounded)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 6. Cold-boot message check (app was completely terminated/killed)
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App launched from cold-boot initial message: ${initialMessage.messageId}');
        final targetRoute = _extractRouteFromMessage(initialMessage);
        if (targetRoute != null && targetRoute.isNotEmpty) {
          _pendingInitialRoute = targetRoute;
        }
      }
    } catch (e) {
      debugPrint('[FCM] Init error (non-fatal): $e');
    }
  }

  String? _extractRouteFromMessage(RemoteMessage message) {
    final data = message.data;
    final explicitRoute = data['route'] as String?;
    if (explicitRoute != null && explicitRoute.isNotEmpty) {
      return explicitRoute;
    }

    final tripId = data['tripId'] as String?;
    final settlementId = data['settlementId'] as String?;
    final expenseId = data['expenseId'] as String?;
    final ipoId = data['ipoId'] as String?;
    final personName = data['personName'] as String?;

    if (tripId != null && tripId.isNotEmpty) {
      if (expenseId != null && expenseId.isNotEmpty) {
        return '/trip/$tripId?expenseId=$expenseId';
      }
      if (settlementId != null && settlementId.isNotEmpty) {
        return '/trip/$tripId?settlementId=$settlementId';
      }
      return '/trip/$tripId';
    }

    if (ipoId != null && ipoId.isNotEmpty) {
      return '/ipo/$ipoId';
    }

    if (personName != null && personName.isNotEmpty) {
      return '/person-ledger?name=${Uri.encodeComponent(personName)}';
    }

    final type = (data['type'] as String? ?? '').toLowerCase();
    if (type.contains('debt') || type.contains('lending') || type.contains('borrowing')) {
      return '/personal/debts';
    }
    if (type.contains('settle') || type.contains('payment')) {
      return '/balances';
    }

    return null;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final messageId = message.messageId ?? '';
    final data = message.data;
    final idempotencyKey = data['idempotencyKey'] as String? ?? messageId;

    if (idempotencyKey.isNotEmpty && _processedMessageIds.contains(idempotencyKey)) {
      debugPrint('[FCM] Duplicate message suppressed: $idempotencyKey');
      return;
    }
    if (idempotencyKey.isNotEmpty) {
      _processedMessageIds.add(idempotencyKey);
    }

    final notification = message.notification;
    final title = notification?.title ?? data['title'] as String? ?? 'Kith';
    final body = notification?.body ?? data['body'] as String? ?? '';
    final eventType = data['type'] as String? ?? 'activity';
    final targetRoute = _extractRouteFromMessage(message);

    final notifType = eventType.contains('ipo')
        ? NotificationType.ipo
        : (eventType.contains('expense') || eventType.contains('debt'))
            ? NotificationType.expense
            : (eventType.contains('trip') || eventType.contains('member'))
                ? NotificationType.trip
                : NotificationType.settlement;

    final tripId = data['tripId'] as String?;
    final settlementId = data['settlementId'] as String?;

    if ((eventType == 'settlement_marked_paid' || eventType == 'PAYMENT_RECEIVED') && settlementId != null) {
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
    } else if ((eventType == 'settlement_confirmed' || eventType == 'SETTLEMENT_CONFIRMED') && tripId != null) {
      final settlements = _storage.getSavedTripSettlements(tripId);
      final fromMemId = data['payerMemberId'] ?? data['fromMemberId'];
      final toMemId = data['receiverMemberId'] ?? data['toMemberId'];
      bool updated = false;

      final nowStr = DateTime.now().toIso8601String();
      for (int i = 0; i < settlements.length; i++) {
        final s = settlements[i];
        final matchesId = settlementId != null && s['id'] == settlementId;
        final matchesPair = fromMemId != null && toMemId != null &&
            s['fromMemberId'] == fromMemId && s['toMemberId'] == toMemId;
        if (matchesId || matchesPair) {
          settlements[i]['status'] = 'confirmed';
          settlements[i]['isSettled'] = true;
          settlements[i]['confirmedAt'] = nowStr;
          updated = true;
        }
      }

      if (!updated && settlementId != null) {
        settlements.insert(0, {
          'id': settlementId,
          'tripId': tripId,
          'fromMemberId': fromMemId,
          'toMemberId': toMemId,
          'amountInPaise': int.tryParse(data['amountInPaise']?.toString() ?? '0') ?? 0,
          'status': 'confirmed',
          'isSettled': true,
          'confirmedAt': nowStr,
          'createdAt': nowStr,
        });
      }
      _storage.saveTripSettlements(tripId, settlements);
    }

    _notificationService.addNotification(
      title: title,
      description: body,
      type: notifType,
      route: targetRoute,
      actionLabel: _actionLabelForType(eventType),
      idempotencyKey: idempotencyKey,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final targetRoute = _extractRouteFromMessage(message);
    if (targetRoute != null && targetRoute.isNotEmpty) {
      if (_onNavigate != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _onNavigate?.call(targetRoute);
        });
      } else {
        _pendingRoute = targetRoute;
      }
    }
  }

  String _actionLabelForType(String eventType) {
    final lower = eventType.toLowerCase();
    if (lower.contains('paid') || lower.contains('payment')) return 'Confirm';
    if (lower.contains('expense')) return 'View Expense';
    if (lower.contains('trip') || lower.contains('member')) return 'View Trip';
    if (lower.contains('ipo')) return 'View IPO';
    if (lower.contains('debt')) return 'View Balance';
    return 'Open';
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
        final userId = user['id'] as String;
        final accountId = user['accountId'] as String? ?? userId;
        final tokenStr = user['anonymousToken']?.toString() ?? user['token']?.toString();
        if (tokenStr != null && tokenStr.isNotEmpty) {
          _apiClient.setAuthToken(tokenStr);
        }

        // 1. Register with backend API
        try {
          await _apiClient.post('/auth/fcm-token', body: {
            'token': token,
            'deviceId': deviceId,
            'platform': 'android',
            'userId': userId,
            'accountId': accountId,
          });
        } catch (_) {}

        // 2. Register on Supabase user_fcm_tokens
        if (SupabaseConfig.isConfigured) {
          try {
            await _cloudSync.registerFcmToken(
              userId: accountId,
              deviceId: deviceId,
              token: token,
              platform: 'android',
            );
          } catch (e) {
            debugPrint('[FCM] Supabase token upsert notice (non-fatal): $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[FCM] Token registration notice: $e');
    }
  }

  Future<void> unregisterToken() async {
    try {
      final token = _storage.getString('kith_fcm_token');
      if (token != null) {
        try {
          await _apiClient.post('/auth/fcm-token/delete', body: {'token': token});
        } catch (_) {}

        if (SupabaseConfig.isConfigured) {
          try {
            await _cloudSync.unregisterFcmToken(token);
          } catch (_) {}
        }
      }
      await _storage.remove('kith_fcm_token');
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[FCM] Token unregister failed: $e');
    }
  }
}
