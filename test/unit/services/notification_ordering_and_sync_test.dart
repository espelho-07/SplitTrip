import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockApiClient extends ApiClient {
  final dynamic mockResponse;
  MockApiClient(this.mockResponse) : super();

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    return mockResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late NotificationService notificationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    notificationService = NotificationService(storage);
    await notificationService.init();
  });

  group('Kith Notifications Canonical Ordering & Architecture Suite', () {
    test('1. Strictly enforces newest-first order for the 4-event sequence', () async {
      final base = DateTime(2026, 11, 20, 10, 0, 0);

      // Event 1 (10:00): Member joined trip
      await notificationService.addNotification(
        title: 'Amit joined the trip',
        description: 'Amit joined Goa Trip',
        type: NotificationType.trip,
        timestamp: base,
        actorName: 'Amit',
        tripName: 'Goa Trip',
      );

      // Event 2 (10:05): Expense added
      await notificationService.addNotification(
        title: 'Dinner expense added',
        description: 'Priya added ₹3,000 for Seafood Dinner',
        type: NotificationType.expense,
        timestamp: base.add(const Duration(minutes: 5)),
        amountInPaise: 300000,
        tripName: 'Goa Trip',
      );

      // Event 3 (10:10): Another member joined
      await notificationService.addNotification(
        title: 'Rohan joined the trip',
        description: 'Rohan joined Goa Trip',
        type: NotificationType.trip,
        timestamp: base.add(const Duration(minutes: 10)),
        actorName: 'Rohan',
        tripName: 'Goa Trip',
      );

      // Event 4 (10:15): Settlement completed
      await notificationService.addNotification(
        title: 'Settlement completed',
        description: 'Rahul sent ₹1,500 to Priya',
        type: NotificationType.settlement,
        timestamp: base.add(const Duration(minutes: 15)),
        amountInPaise: 150000,
        tripName: 'Goa Trip',
      );

      final notifs = notificationService.getNotifications();
      expect(notifs.length, equals(4));

      // Strictly newest first: 10:15 -> 10:10 -> 10:05 -> 10:00
      expect(notifs[0].title, equals('Settlement completed'));
      expect(notifs[0].timestamp, equals(base.add(const Duration(minutes: 15))));

      expect(notifs[1].title, equals('Rohan joined the trip'));
      expect(notifs[1].timestamp, equals(base.add(const Duration(minutes: 10))));

      expect(notifs[2].title, equals('Dinner expense added'));
      expect(notifs[2].timestamp, equals(base.add(const Duration(minutes: 5))));

      expect(notifs[3].title, equals('Amit joined the trip'));
      expect(notifs[3].timestamp, equals(base));
    });

    test('2. Deterministic ID tiebreaker for identical timestamps', () {
      final sameTime = DateTime(2026, 11, 20, 12, 0, 0);

      final itemA = AppNotificationItem(
        id: 'notif_001',
        title: 'A',
        description: 'Desc A',
        timestamp: sameTime,
        type: NotificationType.system,
      );

      final itemB = AppNotificationItem(
        id: 'notif_002',
        title: 'B',
        description: 'Desc B',
        timestamp: sameTime,
        type: NotificationType.system,
      );

      // compareNewestFirst: notif_002 should come before notif_001 (DESC)
      expect(AppNotificationItem.compareNewestFirst(itemB, itemA), isNegative);
      expect(AppNotificationItem.compareNewestFirst(itemA, itemB), isPositive);

      final list = [itemA, itemB];
      list.sort(AppNotificationItem.compareNewestFirst);
      expect(list.first.id, equals('notif_002'));
      expect(list.last.id, equals('notif_001'));
    });

    test('3. Timestamp parsing resilience across keys and formats', () {
      final item1 = AppNotificationItem.fromJson({
        'id': 'n1',
        'title': 'Test 1',
        'createdAt': '2026-11-20T10:15:00.000Z',
      });
      expect(item1.timestamp.year, equals(2026));

      final item2 = AppNotificationItem.fromJson({
        'id': 'n2',
        'title': 'Test 2',
        'created_at': '2026-11-20T10:10:00.000Z',
      });
      expect(item2.timestamp.year, equals(2026));

      final item3 = AppNotificationItem.fromJson({
        'id': 'n3',
        'title': 'Test 3',
        'timestamp': 1763633700000, // epoch millis
      });
      expect(item3.timestamp.millisecondsSinceEpoch, equals(1763633700000));
    });

    test('4. Server sync batching preserves order and local isRead state', () async {
      // User has a local notification marked read
      final base = DateTime(2026, 11, 20, 10, 0, 0);
      await notificationService.addNotification(
        idempotencyKey: 'srv_1',
        title: 'Local Item',
        description: 'Already read',
        type: NotificationType.expense,
        timestamp: base,
      );
      await notificationService.markAsRead('srv_1');
      expect(notificationService.getNotifications().first.isRead, isTrue);

      // Server returns results (where srv_1 is unread on server, plus srv_2 is newer)
      final mockServerList = [
        {
          'id': 'srv_2',
          'title': 'Newer Server Item',
          'description': 'From server',
          'type': 'EXPENSE_CREATED',
          'createdAt': base.add(const Duration(minutes: 10)).toIso8601String(),
          'isRead': false,
        },
        {
          'id': 'srv_1',
          'title': 'Local Item',
          'description': 'Already read',
          'type': 'EXPENSE_CREATED',
          'createdAt': base.toIso8601String(),
          'isRead': false, // Server says unread
        },
      ];

      final mockApi = MockApiClient({'data': mockServerList});
      await notificationService.syncServerNotifications(mockApi);

      final notifs = notificationService.getNotifications();
      expect(notifs.length, equals(2));

      // Ordered newest first
      expect(notifs[0].id, equals('srv_2'));
      expect(notifs[1].id, equals('srv_1'));

      // Preserved local isRead = true
      expect(notifs[1].isRead, isTrue);
    });

    test('5. Rich amount and currency formatting in paise', () {
      final item = AppNotificationItem(
        id: 'n_amt',
        title: 'Payment',
        description: 'Payment',
        timestamp: DateTime.now(),
        type: NotificationType.settlement,
        amountInPaise: 400000, // ₹4000
      );
      expect(item.formattedAmount, equals('₹4000'));

      final itemDecimal = AppNotificationItem(
        id: 'n_amt2',
        title: 'Payment',
        description: 'Payment',
        timestamp: DateTime.now(),
        type: NotificationType.settlement,
        amountInPaise: 400050, // ₹4000.50
      );
      expect(itemDecimal.formattedAmount, equals('₹4000.50'));
    });

    test('6. Realtime notification_created event ingestion and stream broadcast', () async {
      AppNotificationItem? streamedItem;
      final sub = notificationService.onNotification.listen((item) {
        streamedItem = item;
      });

      await notificationService.addNotification(
        title: 'Realtime Alert',
        description: 'Realtime notification arrived',
        type: NotificationType.trip,
        idempotencyKey: 'rt_notif_999',
      );

      expect(streamedItem?.id, equals('rt_notif_999'));
      final stored = notificationService.getNotifications();
      expect(stored.any((n) => n.id == 'rt_notif_999'), isTrue);

      await sub.cancel();
    });
  });
}
