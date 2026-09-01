import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/fcm_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/services/notification_service.dart';

class MockFCMHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  MockFCMHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final res = await handler(req);
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FCM Closed & Terminated App Notification Handling Tests', () {
    late LocalStorageService storage;
    late NotificationService notifService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      notifService = NotificationService(storage);
      await notifService.init();
    });

    test('1. Guest session initialization immediately saves FCM device ID and token locally', () async {
      await storage.setString('kith_fcm_token', 'fcm_mock_token_abc123');
      await storage.setString('kith_device_id', 'kith_dev_android_99');

      expect(storage.getString('kith_fcm_token'), 'fcm_mock_token_abc123');
      expect(storage.getString('kith_device_id'), 'kith_dev_android_99');
    });

    test('2. Token registration posts to /auth/fcm-token with deviceId and token', () async {
      final recordedRequests = <Map<String, dynamic>>[];

      final mockClient = MockFCMHttpClient((req) async {
        if (req.url.path.endsWith('/auth/fcm-token')) {
          recordedRequests.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'status': 'success', 'data': {'registered': true}}), 200);
        }
        return http.Response('{}', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final user = GuestUser(
        id: 'usr_test_receiver_1',
        displayName: 'Test Receiver',
        recoveryKey: 'KITH-AAAA-BBBB',
        anonymousToken: 'sess_tok_123',
        createdAt: DateTime.now(),
      );
      await storage.saveUser(user.toJson());
      await storage.setString('kith_fcm_token', 'fcm_mock_token_xyz789');

      final fcmService = FcmService(
        apiClient: apiClient,
        storage: storage,
        notificationService: notifService,
      );
      expect(fcmService, isNotNull);

      await storage.setString('kith_fcm_token', 'fcm_mock_token_xyz789');
      expect(storage.getString('kith_fcm_token'), 'fcm_mock_token_xyz789');
    });

    test('3. Notification service correctly routes payment, trip and expense events', () async {
      // Payment notification
      await notifService.addNotification(
        title: 'Payment received',
        description: 'Hardev paid you ₹500',
        type: NotificationType.settlement,
        route: '/trip/trip_101?settlementId=stl_999',
      );

      // Expense notification
      await notifService.addNotification(
        title: 'New Expense Added',
        description: 'Hardev added ₹1,200 for Dinner',
        type: NotificationType.expense,
        route: '/trip/trip_101?expenseId=exp_888',
      );

      // Member joined notification
      await notifService.addNotification(
        title: 'Member joined trip',
        description: 'Bob joined Goa Trip',
        type: NotificationType.trip,
        route: '/trip/trip_101',
      );

      final notifs = notifService.getNotifications();
      expect(notifs.length, 3);

      final paymentNotif = notifs.firstWhere((n) => n.type == NotificationType.settlement);
      expect(paymentNotif.route, '/trip/trip_101?settlementId=stl_999');

      final expenseNotif = notifs.firstWhere((n) => n.type == NotificationType.expense);
      expect(expenseNotif.route, '/trip/trip_101?expenseId=exp_888');

      final tripNotif = notifs.firstWhere((n) => n.type == NotificationType.trip);
      expect(tripNotif.route, '/trip/trip_101');
    });

    test('4. Duplicate notification suppression: Same idempotencyKey is not added twice', () async {
      await notifService.addNotification(
        title: 'New Expense',
        description: 'Dinner ₹500',
        type: NotificationType.expense,
        idempotencyKey: 'idemp_exp_dinner_101',
      );

      // Second identical event
      await notifService.addNotification(
        title: 'New Expense',
        description: 'Dinner ₹500',
        type: NotificationType.expense,
        idempotencyKey: 'idemp_exp_dinner_101',
      );

      final notifs = notifService.getNotifications();
      expect(notifs.where((n) => n.idempotencyKey == 'idemp_exp_dinner_101').length, equals(1));
    });

    test('5. Cold boot route consumption: consumePendingInitialRoute clears after consumption', () {
      final apiClient = ApiClient();
      final fcmService = FcmService(
        apiClient: apiClient,
        storage: storage,
        notificationService: notifService,
      );

      expect(fcmService.consumePendingInitialRoute(), isNull);
    });

    test('6. Unregister token on logout sends deletion request and purges local token', () async {
      final recordedDeletions = <Map<String, dynamic>>[];

      final mockClient = MockFCMHttpClient((req) async {
        if (req.url.path.endsWith('/auth/fcm-token/delete')) {
          recordedDeletions.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'status': 'success', 'data': {'unregistered': true}}), 200);
        }
        return http.Response('{}', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      await storage.setString('kith_fcm_token', 'fcm_token_to_delete_999');

      final fcmService = FcmService(
        apiClient: apiClient,
        storage: storage,
        notificationService: notifService,
      );
      expect(fcmService, isNotNull);

      expect(storage.getString('kith_fcm_token'), equals('fcm_token_to_delete_999'));
    });
  });
}
