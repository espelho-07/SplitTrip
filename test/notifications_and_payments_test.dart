import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/join_trip_viewmodel.dart';
import 'package:kith_app/presentation/views/notifications/notifications_view.dart';
import 'package:kith_app/presentation/views/payment/payment_methods_view.dart';
import 'package:kith_app/presentation/views/trip/trip_preview_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late AuthViewModel authVm;
  late HomeViewModel homeVm;
  late JoinTripViewModel joinVm;

  final testTrip = Trip(
    id: 'trip_preview_test_id',
    name: 'Goa Holiday',
    emoji: '🌴',
    creatorId: 'user_darpan',
    inviteCode: 'GOA777',
    members: [
      TripMember(id: 'mem_1', userId: 'user_darpan', displayName: 'Darpan Parmar', joinedAt: DateTime.now(), role: 'creator'),
      TripMember(id: 'mem_2', userId: 'user_rohan', displayName: 'Rohan Sharma', joinedAt: DateTime.now()),
    ],
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    syncService = SyncService(storage);
    apiClient = ApiClient();
    final authService = AuthService(apiClient: apiClient, storage: storage);
    final userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);
    tripRepo = TripRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    expenseRepo = ExpenseRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
    joinVm = JoinTripViewModel(tripRepo: tripRepo);

    await authVm.createGuestSession('Darpan Parmar');
    await storage.saveTrips([testTrip.toJson()]);
    await storage.saveNotifications([
      {
        'id': 'notif_1',
        'title': 'Settlement Payment Received',
        'description': 'Rohan Sharma recorded a settlement payment.',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'settlement',
        'isRead': false,
      },
      {
        'id': 'notif_2',
        'title': 'New Expense Added',
        'description': 'Priya added an expense.',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'expense',
        'isRead': false,
      },
    ]);
  });

  Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: storage),
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: homeVm),
        ChangeNotifierProvider.value(value: joinVm),
        Provider.value(value: tripRepo),
        Provider.value(value: expenseRepo),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('gu')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }

  group('Notifications Center Suite', () {
    testWidgets('1. Renders notifications list and filter chips', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithProviders(const NotificationsView()));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Settlements'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Settlement Payment Received'), findsOneWidget);
      expect(find.text('New Expense Added'), findsOneWidget);
    });

    testWidgets('2. Filter chips switch notification categories', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithProviders(const NotificationsView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();

      expect(find.text('New Expense Added'), findsOneWidget);
      expect(find.text('Settlement Payment Received'), findsNothing);
    });
  });

  group('Payment Methods Suite', () {
    testWidgets('1. Renders empty payment method state when unconfigured, and saved UPIs when configured', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. Fresh state - Empty state card
      await tester.pumpWidget(wrapWithProviders(const PaymentMethodsView()));
      await tester.pumpAndSettle();

      expect(find.text('Payment Methods'), findsOneWidget);
      expect(find.text('No Payment Method Added'), findsOneWidget);
      expect(find.text('Add Receiving UPI ID'), findsOneWidget);

      // 2. Save receiving UPI
      await storage.setPrimaryUpiId('darpan@okhdfcbank');
      await tester.pumpWidget(wrapWithProviders(const PaymentMethodsView(key: ValueKey('configured'))));
      await tester.pumpAndSettle();

      expect(find.text('Payment Methods'), findsOneWidget);
      expect(find.text('LIVE UPI'), findsOneWidget);
      expect(find.text('darpan@okhdfcbank'), findsWidgets);
    });
  });

  group('Trip Preview Suite', () {
    testWidgets('1. Renders trip preview with host info and join button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithProviders(const TripPreviewView(code: 'GOA777')));
      await tester.pumpAndSettle();

      expect(find.text('Trip Invitation Preview'), findsOneWidget);
      expect(find.text('Goa Holiday'), findsOneWidget);
      expect(find.text('Hosted by Darpan Parmar'), findsOneWidget);
      expect(find.text('Join Trip Now'), findsOneWidget);
    });
  });
}
