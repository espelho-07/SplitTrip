import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
import 'package:kith_app/core/services/security_lock_service.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/app_experience_mode.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/personal_expense_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/theme_viewmodel.dart';
import 'package:kith_app/presentation/views/home/home_view.dart';
import 'package:kith_app/presentation/views/profile/profile_home_tab.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late SecurityLockService securityService;
  late SyncService syncService;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late PersonalRepository personalRepo;
  late KithWidgetService widgetService;
  late UserRepository userRepo;
  late AuthViewModel authVm;
  late HomeViewModel homeVm;
  late PersonalExpenseViewModel personalVm;
  late ThemeViewModel themeVm;
  late GuestUser testUser;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    securityService = SecurityLockService(storage);
    apiClient = ApiClient();
    final authService = AuthService(apiClient: apiClient, storage: storage);
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
    personalRepo = PersonalRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    widgetService = KithWidgetService(storage: storage);
    homeVm = HomeViewModel(
      tripRepo: tripRepo,
      expenseRepo: expenseRepo,
    );
    personalVm = PersonalExpenseViewModel(
      personalRepo: personalRepo,
      tripRepo: tripRepo,
      expenseRepo: expenseRepo,
    );
    themeVm = ThemeViewModel(storage: storage);

    testUser = GuestUser(
      id: 'usr_darpan_01',
      displayName: 'Darpan Parmar',
      recoveryKey: 'KITH-TEST-1234',
      anonymousToken: 'anon_tok_123',
      createdAt: DateTime.now(),
    );
    await storage.saveUser(testUser.toJson());
    await authVm.initSession();
  });

  Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: securityService),
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: homeVm),
        ChangeNotifierProvider.value(value: personalVm),
        ChangeNotifierProvider.value(value: themeVm),
        ChangeNotifierProvider.value(value: widgetService),
        Provider.value(value: storage),
        Provider.value(value: apiClient),
        Provider.value(value: syncService),
        Provider.value(value: tripRepo),
        Provider.value(value: expenseRepo),
        Provider.value(value: personalRepo),
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

  group('Experience Mode & Profile Header Verification Suite', () {
    test('1. AppExperienceMode updates and persists in LocalStorageService', () async {
      expect(authVm.appExperienceMode, AppExperienceMode.all);

      await authVm.setAppExperienceMode(AppExperienceMode.tripsOnly);
      expect(authVm.appExperienceMode, AppExperienceMode.tripsOnly);

      // Verify persistence
      final restoredKey = userRepo.getAppExperienceMode();
      expect(AppExperienceMode.fromKey(restoredKey), AppExperienceMode.tripsOnly);

      await authVm.setAppExperienceMode(AppExperienceMode.all);
      expect(authVm.appExperienceMode, AppExperienceMode.all);
    });

    testWidgets('2. HomeView dynamically renders 3 tabs in Trips Only mode and 4 tabs in All mode',
        (tester) async {
      await tester.pumpWidget(wrapWithProviders(const HomeView()));
      await tester.pumpAndSettle();

      // Default: All mode -> 4 tabs: Home, Trips, Expenses, Profile
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Switch to Trips Only mode
      await authVm.setAppExperienceMode(AppExperienceMode.tripsOnly);
      await tester.pumpAndSettle();

      // Trips Only mode -> 3 tabs: Home, Trips, Profile (Expenses hidden)
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Expenses'), findsNothing);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('3. ProfileHomeTab displays email vertically stacked below Google Connected badge',
        (tester) async {
      // Simulate Google connected user
      final googleUser = testUser.copyWith(
        email: 'darpanparmar1707@gmail.com',
        googleId: 'google_oauth_999',
      );
      await storage.saveUser(googleUser.toJson());
      await authVm.initSession();

      await tester.pumpWidget(wrapWithProviders(const Scaffold(body: ProfileHomeTab())));
      await tester.pumpAndSettle();

      expect(find.text('Darpan Parmar'), findsOneWidget);
      expect(find.text('Connected with Google'), findsOneWidget);
      expect(find.text('darpanparmar1707@gmail.com'), findsOneWidget);

      // Verify vertical layout ordering: Name -> Badge -> Email
      final nameY = tester.getTopLeft(find.text('Darpan Parmar')).dy;
      final badgeY = tester.getTopLeft(find.text('Connected with Google')).dy;
      final emailY = tester.getTopLeft(find.text('darpanparmar1707@gmail.com')).dy;

      expect(badgeY, greaterThan(nameY));
      expect(emailY, greaterThan(badgeY));
    });

    test('4. Fresh Theme initialization strictly defaults to ThemeMode.light', () {
      final freshThemeVm = ThemeViewModel(storage: storage);
      expect(freshThemeVm.themeMode, ThemeMode.light);
      expect(freshThemeVm.isDarkMode, isFalse);
    });

    testWidgets('5. Home Dashboard renders QR scanner button adjacent to notifications button',
        (tester) async {
      await tester.pumpWidget(wrapWithProviders(const HomeView()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

      final scannerX = tester.getTopLeft(find.byIcon(Icons.qr_code_scanner_rounded)).dx;
      final notifX = tester.getTopLeft(find.byIcon(Icons.notifications_outlined)).dx;
      expect(notifX, greaterThan(scannerX));
    });
  });
}
