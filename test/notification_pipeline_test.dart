import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/services/notification_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Production Notification System & Pipeline Tests', () {
    test('1. NotificationService dispatches and persists notification correctly', () async {
      await notificationService.addNotification(
        title: 'Aditya added an expense',
        description: 'Dinner · ₹1,250 · Ahmedabad',
        type: NotificationType.expense,
        route: '/trip/trip_123?expenseId=exp_456',
        actionLabel: 'View Expense',
        idempotencyKey: 'exp_456_create_usr_1',
      );

      final notifs = notificationService.getNotifications();
      expect(notifs.length, equals(1));
      expect(notifs.first.title, equals('Aditya added an expense'));
      expect(notifs.first.description, equals('Dinner · ₹1,250 · Ahmedabad'));
      expect(notifs.first.route, equals('/trip/trip_123?expenseId=exp_456'));
      expect(notifs.first.type, equals(NotificationType.expense));
      expect(notifs.first.isRead, isFalse);
    });

    test('2. Idempotency: Duplicate events with the same idempotency key are strictly ignored', () async {
      const key = 'exp_repeat_123';

      // First add
      await notificationService.addNotification(
        title: 'New Expense',
        description: 'Coffee · ₹200',
        type: NotificationType.expense,
        idempotencyKey: key,
      );

      // Duplicate add
      await notificationService.addNotification(
        title: 'New Expense',
        description: 'Coffee · ₹200',
        type: NotificationType.expense,
        idempotencyKey: key,
      );

      final notifs = notificationService.getNotifications();
      expect(notifs.length, equals(1)); // Only 1 notification stored
    });

    test('3. Preference Filtering: Disabling category suppresses notification generation', () async {
      await notificationService.setPreference(NotificationCategory.expenseActivity, false);
      expect(notificationService.expenseNotificationsEnabled, isFalse);

      await notificationService.addNotification(
        title: 'Expense Added',
        description: 'Lunch · ₹500',
        type: NotificationType.expense,
      );

      expect(notificationService.getNotifications().isEmpty, isTrue);

      // Re-enable
      await notificationService.setPreference(NotificationCategory.expenseActivity, true);
      expect(notificationService.expenseNotificationsEnabled, isTrue);

      await notificationService.addNotification(
        title: 'Expense Added',
        description: 'Dinner · ₹1,000',
        type: NotificationType.expense,
      );

      expect(notificationService.getNotifications().length, equals(1));
    });

    test('4. Mark all as read updates notification statuses', () async {
      await notificationService.addNotification(
        title: 'Trip Invite',
        description: 'Rahul added you to Goa Trip',
        type: NotificationType.trip,
        route: '/trip/trip_goa',
      );

      await notificationService.addNotification(
        title: 'Payment Received',
        description: 'Rahul sent you ₹2,500',
        type: NotificationType.settlement,
        route: '/trip/trip_goa?settlementId=stl_789',
      );

      expect(storage.getUnreadNotificationCount(), equals(2));

      await storage.markAllNotificationsAsRead();
      expect(storage.getUnreadNotificationCount(), equals(0));

      final notifs = notificationService.getNotifications();
      expect(notifs.every((n) => n.isRead), isTrue);
    });

    test('5. Multi-type categorization maps appropriately', () {
      final itemExpense = AppNotificationItem(
        id: '1',
        title: 'Expense',
        description: 'Food',
        timestamp: DateTime.now(),
        type: NotificationType.expense,
      );
      expect(itemExpense.type, equals(NotificationType.expense));

      final itemSettlement = AppNotificationItem(
        id: '2',
        title: 'Payment',
        description: 'UPI ₹500',
        timestamp: DateTime.now(),
        type: NotificationType.settlement,
      );
      expect(itemSettlement.type, equals(NotificationType.settlement));
    });
  });
}
