import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/services/notification_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/views/notifications/notifications_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createNotificationTestWidget({
  required LocalStorageService storage,
  required NotificationService notificationService,
}) {
  return MultiProvider(
    providers: [
      Provider<LocalStorageService>.value(value: storage),
      Provider<NotificationService>.value(value: notificationService),
      Provider<ApiClient?>.value(value: null),
      Provider<AuthViewModel?>.value(value: null),
      Provider<ExpenseRepository?>.value(value: null),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      supportedLocales: [Locale('en')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: NotificationsView(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late NotificationService notificationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    await storage.setBool('notif_pref_push', false);
    notificationService = NotificationService(storage);
    await notificationService.init();

    const channel = MethodChannel('com.nirniq.kith/notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null;
    });
  });

  group('NotificationsView Widget & UX Verification Suite', () {
    testWidgets('1. Renders 4-event sequence strictly newest-first in TODAY section', (tester) async {
      final now = DateTime.now();

      // Seed 4 events in order: 10:00, 10:05, 10:10, 10:15
      final base = DateTime(now.year, now.month, now.day, 10, 0, 0);

      await notificationService.addNotification(
        title: 'Amit joined the trip',
        description: 'Amit joined Goa Trip',
        type: NotificationType.trip,
        timestamp: base,
      );

      await notificationService.addNotification(
        title: 'Dinner expense added',
        description: 'Priya added ₹3,000 for Seafood Dinner',
        type: NotificationType.expense,
        timestamp: base.add(const Duration(minutes: 5)),
        amountInPaise: 300000,
      );

      await notificationService.addNotification(
        title: 'Rohan joined the trip',
        description: 'Rohan joined Goa Trip',
        type: NotificationType.trip,
        timestamp: base.add(const Duration(minutes: 10)),
      );

      await notificationService.addNotification(
        title: 'Settlement completed',
        description: 'Rahul sent ₹1,500 to Priya',
        type: NotificationType.settlement,
        timestamp: base.add(const Duration(minutes: 15)),
        amountInPaise: 150000,
      );

      await tester.pumpWidget(createNotificationTestWidget(
        storage: storage,
        notificationService: notificationService,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Section header TODAY should appear
      expect(find.text('TODAY'), findsOneWidget);

      // Verify all 4 titles exist
      expect(find.text('Settlement completed'), findsOneWidget);
      expect(find.text('Rohan joined the trip'), findsOneWidget);
      expect(find.text('Dinner expense added'), findsOneWidget);
      expect(find.text('Amit joined the trip'), findsOneWidget);

      // Verify vertical ordering: Settlement (top) < Rohan < Dinner < Amit (bottom)
      final settlePos = tester.getTopLeft(find.text('Settlement completed')).dy;
      final rohanPos = tester.getTopLeft(find.text('Rohan joined the trip')).dy;
      final dinnerPos = tester.getTopLeft(find.text('Dinner expense added')).dy;
      final amitPos = tester.getTopLeft(find.text('Amit joined the trip')).dy;

      expect(settlePos < rohanPos, isTrue);
      expect(rohanPos < dinnerPos, isTrue);
      expect(dinnerPos < amitPos, isTrue);
    });

    testWidgets('2. Filter tabs filter correctly and returning to ALL preserves newest-first order', (tester) async {
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day, 10, 0, 0);

      await notificationService.addNotification(
        title: 'Trip Event A',
        description: 'Trip notice',
        type: NotificationType.trip,
        timestamp: base,
      );

      await notificationService.addNotification(
        title: 'Expense Event B',
        description: 'Food ₹500',
        type: NotificationType.expense,
        timestamp: base.add(const Duration(minutes: 5)),
        amountInPaise: 50000,
      );

      await tester.pumpWidget(createNotificationTestWidget(
        storage: storage,
        notificationService: notificationService,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Trip Event A'), findsOneWidget);
      expect(find.text('Expense Event B'), findsOneWidget);

      // Tap "Expenses" tab
      await tester.tap(find.text('Expenses'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Expense Event B'), findsOneWidget);
      expect(find.text('Trip Event A'), findsNothing);

      // Tap "All" tab again
      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Expense Event B'), findsOneWidget);
      expect(find.text('Trip Event A'), findsOneWidget);

      // Ordering maintained: Expense B is above Trip A
      final posB = tester.getTopLeft(find.text('Expense Event B')).dy;
      final posA = tester.getTopLeft(find.text('Trip Event A')).dy;
      expect(posB < posA, isTrue);
    });

    testWidgets('3. Mark all as read updates unread counter and UI', (tester) async {
      await notificationService.addNotification(
        title: 'Unread 1',
        description: 'Testing unread',
        type: NotificationType.expense,
      );
      await notificationService.addNotification(
        title: 'Unread 2',
        description: 'Testing unread',
        type: NotificationType.settlement,
      );

      await tester.pumpWidget(createNotificationTestWidget(
        storage: storage,
        notificationService: notificationService,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Mark all as read action icon
      final markReadBtn = find.byIcon(Icons.done_all_rounded);
      expect(markReadBtn, findsOneWidget);
      await tester.tap(markReadBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(storage.getUnreadNotificationCount(), equals(0));
    });

    testWidgets('4. Realtime notification insertion updates list dynamically in newest-first order', (tester) async {
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day, 10, 0, 0);

      await notificationService.addNotification(
        title: 'Older Event',
        description: 'Created first',
        type: NotificationType.expense,
        timestamp: base,
      );

      await tester.pumpWidget(createNotificationTestWidget(
        storage: storage,
        notificationService: notificationService,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Older Event'), findsOneWidget);
      expect(find.text('Realtime New Event'), findsNothing);

      // Push realtime notification
      await notificationService.addNotification(
        title: 'Realtime New Event',
        description: 'Arrived right now',
        type: NotificationType.settlement,
        timestamp: base.add(const Duration(minutes: 30)),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Realtime New Event'), findsOneWidget);
      expect(find.text('Older Event'), findsOneWidget);

      final realTimePos = tester.getTopLeft(find.text('Realtime New Event')).dy;
      final olderPos = tester.getTopLeft(find.text('Older Event')).dy;
      expect(realTimePos < olderPos, isTrue);
    });
  });
}
