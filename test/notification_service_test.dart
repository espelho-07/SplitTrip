import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Tests', () {
    late NotificationService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = NotificationService();
    });

    tearDown(() {
      service.dispose();
    });

    test('Initializes with all notification preferences enabled', () async {
      await service.init();
      expect(service.expenseNotificationsEnabled, true);
      expect(service.tripNotificationsEnabled, true);
      expect(service.settlementNotificationsEnabled, true);
    });

    test('Dispatches notification when preference is enabled', () async {
      await service.init();
      final payload = AppNotificationPayload(
        id: 'notif_1',
        title: 'New Expense',
        body: 'Train tickets added',
        category: NotificationCategory.expenseActivity,
        tripId: 'trip_goa',
        createdAt: DateTime.now(),
      );

      final dispatched = service.dispatchNotification(payload);
      expect(dispatched, true);
    });

    test('Blocks notification when preference is disabled by user', () async {
      await service.init();
      await service.setPreference(NotificationCategory.expenseActivity, false);

      final payload = AppNotificationPayload(
        id: 'notif_2',
        title: 'New Expense',
        body: 'Dinner added',
        category: NotificationCategory.expenseActivity,
        tripId: 'trip_goa',
        createdAt: DateTime.now(),
      );

      final dispatched = service.dispatchNotification(payload);
      expect(dispatched, false);
    });

    test('Computes deep link navigation route correctly', () {
      final payload = AppNotificationPayload(
        id: 'notif_3',
        title: 'Settlement Completed',
        body: 'Rahul settled ₹1,000',
        category: NotificationCategory.settlementActivity,
        tripId: 'trip_123',
        settlementId: 'stl_999',
        createdAt: DateTime.now(),
      );

      expect(payload.targetRoute, '/trip/trip_123');
    });
  });
}
