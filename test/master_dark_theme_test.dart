import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
import 'package:kith_app/core/theme/app_theme.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/locale_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/theme_viewmodel.dart';
import 'package:kith_app/domain/services/notification_service.dart';
import 'package:kith_app/presentation/views/home/home_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late NotificationService notificationService;
  late SyncService syncService;
  late ApiClient apiClient;
  late UserRepository userRepo;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late AuthViewModel authVm;
  late HomeViewModel homeVm;
  late ThemeViewModel themeVm;
  late LocaleViewModel localeVm;
  late KithWidgetService widgetService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    notificationService = NotificationService(storage);
    syncService = SyncService(storage);
    apiClient = ApiClient();
    final authService = AuthService(apiClient: apiClient, storage: storage);
    userRepo = UserRepository(authService: authService);
    tripRepo = TripRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    expenseRepo = ExpenseRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    authVm = AuthViewModel(userRepo: userRepo);
    homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
    themeVm = ThemeViewModel(storage: storage);
    localeVm = LocaleViewModel(storage: storage);
    widgetService = KithWidgetService(storage: storage);

    await authVm.createGuestSession('Darpan Parmar');
    themeVm.setThemeMode(ThemeMode.dark);
  });

  Widget createDarkModeHomeScreen() {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: storage),
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: homeVm),
        ChangeNotifierProvider.value(value: themeVm),
        ChangeNotifierProvider.value(value: localeVm),
        Provider.value(value: apiClient),
        Provider.value(value: syncService),
        Provider.value(value: tripRepo),
        Provider.value(value: expenseRepo),
        ChangeNotifierProvider.value(value: widgetService),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, theme, child) {
          return MaterialApp(
            themeMode: ThemeMode.dark,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const HomeView(),
          );
        },
      ),
    );
  }

  group('Master OLED Obsidian Dark Theme Suite', () {
    testWidgets('1. Renders 5-tab HomeView in Dark Mode cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(createDarkModeHomeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Expenses'), findsNothing);
      expect(find.text('IPO'), findsNothing);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('My Balances'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
    });
  });
}
