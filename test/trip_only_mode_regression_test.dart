import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
import 'package:kith_app/core/services/security_lock_service.dart';
import 'package:kith_app/core/theme/app_theme.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/app_experience_mode.dart';
import 'package:kith_app/domain/enums/kith_app_mode.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/services/notification_service.dart';
import 'package:kith_app/presentation/router/app_router.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/currency_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/theme_viewmodel.dart';
import 'package:kith_app/presentation/views/home/home_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplitTrip Trip-Only Mode Regression & Architecture Suite', () {
    late LocalStorageService storage;
    late ApiClient apiClient;
    late AuthService authService;
    late UserRepository userRepo;
    late AuthViewModel authVm;
    late SyncService syncService;
    late TripRepository tripRepo;
    late ExpenseRepository expenseRepo;
    late HomeViewModel homeVm;
    late ThemeViewModel themeVm;
    late KithWidgetService widgetService;
    late NotificationService notificationService;
    late SecurityLockService securityService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      apiClient = ApiClient();
      authService = AuthService(storage: storage, apiClient: apiClient);
      userRepo = UserRepository(authService: authService);
      authVm = AuthViewModel(userRepo: userRepo);
      syncService = SyncService(storage);
      tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
      expenseRepo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
      homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
      themeVm = ThemeViewModel(storage: storage);
      widgetService = KithWidgetService(storage: storage);
      notificationService = NotificationService(storage);
      securityService = SecurityLockService(storage);

      final user = GuestUser(
        id: 'usr_trip_dev',
        displayName: 'Trip Traveler',
        recoveryKey: 'KITH-TRIP-TEST-1234',
        anonymousToken: 'tok_trip_test',
        createdAt: DateTime.now(),
      );
      await storage.saveUser(user.toJson());
      await authVm.initSession();
    });

    test('1. KithAppMode and AppExperienceMode are strictly locked to Trip Mode', () async {
      // fromKey always resolves to trip
      expect(KithAppMode.fromKey('personal'), equals(KithAppMode.trip));
      expect(KithAppMode.fromKey('finance'), equals(KithAppMode.trip));
      expect(KithAppMode.fromKey('all'), equals(KithAppMode.trip));
      expect(KithAppMode.fromKey('trip'), equals(KithAppMode.trip));

      // AuthViewModel enforces trip mode permanently
      expect(authVm.primaryAppMode, equals(KithAppMode.trip));
      expect(authVm.appExperienceMode, equals(AppExperienceMode.tripsOnly));

      // Attempting to change mode is a no-op
      await authVm.setPrimaryAppMode(KithAppMode.financial);
      expect(authVm.primaryAppMode, equals(KithAppMode.trip));

      await authVm.setAppExperienceMode(AppExperienceMode.all);
      expect(authVm.appExperienceMode, equals(AppExperienceMode.tripsOnly));

      await authVm.setAppExperienceMode(AppExperienceMode.tripsAndIpo);
      expect(authVm.appExperienceMode, equals(AppExperienceMode.tripsOnly));
    });

    test('2. Local storage retains legacy finance getters for backward compatibility', () {
      // Verify legacy personal expense and debt getters exist and return empty lists without throwing
      expect(storage.getSavedPersonalExpenses(), isEmpty);
      expect(storage.getSavedPersonalDebts(), isEmpty);
    });

    test('3. AppRouter deep linking safely handles trip and legacy finance links', () {
      final safeLinks = [
        'kith://home',
        'kith://trips',
        'kith://create-trip',
        'kith://trip/trip_123',
        'kith://join?code=KITH99',
        // Legacy finance links must not crash the application
        'kith://expense/add',
        'kith://budgets',
        'kith://debts',
        'kith://ipos',
      ];

      for (final link in safeLinks) {
        expect(() => AppRouter.handleDeepLink(link), returnsNormally);
      }
    });

    testWidgets('4. HomeView renders strictly 3 navigation destinations (Home, Trips, Profile)',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<LocalStorageService>.value(value: storage),
            Provider<NotificationService>.value(value: notificationService),
            ChangeNotifierProvider<SecurityLockService>.value(value: securityService),
            ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
            ChangeNotifierProvider<HomeViewModel>.value(value: homeVm),
            ChangeNotifierProvider<ThemeViewModel>.value(value: themeVm),
            ChangeNotifierProvider(create: (_) => CurrencyViewModel(storage: storage)),
            ChangeNotifierProvider<KithWidgetService>.value(value: widgetService),
            Provider<ApiClient>.value(value: apiClient),
            Provider<SyncService>.value(value: syncService),
            Provider<TripRepository>.value(value: tripRepo),
            Provider<ExpenseRepository>.value(value: expenseRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const HomeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly 3 tabs exist in SplitTrip
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Financial Mode and IPO tabs are completely absent
      expect(find.text('Expenses'), findsNothing);
      expect(find.text('IPO'), findsNothing);
      expect(find.text('Budgets'), findsNothing);
    });
  });
}
