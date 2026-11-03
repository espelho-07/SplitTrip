import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
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
import 'package:kith_app/presentation/views/widgets/widget_gallery_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late SyncService syncService;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late KithWidgetService widgetService;
  late AuthViewModel authVm;
  late HomeViewModel homeVm;
  late ThemeViewModel themeVm;
  late LocaleViewModel localeVm;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    apiClient = ApiClient();
    final authService = AuthService(apiClient: apiClient, storage: storage);
    final userRepo = UserRepository(authService: authService);
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
    widgetService = KithWidgetService(storage: storage);
    homeVm = HomeViewModel(
      tripRepo: tripRepo,
      expenseRepo: expenseRepo,
    );
    themeVm = ThemeViewModel(storage: storage);
    localeVm = LocaleViewModel(storage: storage);
  });

  Widget createWidgetStudioScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widgetService),
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: homeVm),
        ChangeNotifierProvider.value(value: themeVm),
        ChangeNotifierProvider.value(value: localeVm),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en'),
          Locale('hi'),
          Locale('gu'),
        ],
        home: WidgetGalleryView(),
      ),
    );
  }

  group('Master Widget Studio Suite', () {
    testWidgets('1. Renders Master TopBar, Kith Logo, brand header, and control strip', (tester) async {
      await tester.pumpWidget(createWidgetStudioScreen());
      await tester.pumpAndSettle();

      expect(find.text('KITH · WIDGET STUDIO'), findsOneWidget);
      expect(find.text('Demo'), findsOneWidget);
      expect(find.text('Privacy Mode'), findsOneWidget);
    });

    testWidgets('2. Renders Master Android Widget Cards with badges and preview frames', (tester) async {
      await tester.pumpWidget(createWidgetStudioScreen());
      await tester.pumpAndSettle();

      expect(find.text('Kith Snapshot'), findsOneWidget);
      expect(find.text('HERO'), findsOneWidget);

      final scrollableFinder = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(find.text('Quick Add Capsule'), 100, scrollable: scrollableFinder);
      expect(find.text('Quick Add Capsule'), findsOneWidget);
      expect(find.text('FASTEST'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Budget Health Runway'), 100, scrollable: scrollableFinder);
      expect(find.text('Budget Health Runway'), findsOneWidget);
      expect(find.text('ESSENTIAL'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Debts & Lending Matrix'), 100, scrollable: scrollableFinder);
      expect(find.text('Debts & Lending Matrix'), findsOneWidget);
      expect(find.text('BALANCE'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Active Trip Companion'), 100, scrollable: scrollableFinder);
      expect(find.text('Active Trip Companion'), findsOneWidget);
      expect(find.text('TRAVEL'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Smart Kith Adaptive AI'), 100, scrollable: scrollableFinder);
      expect(find.text('Smart Kith Adaptive AI'), findsOneWidget);
      expect(find.text('SIGNATURE'), findsOneWidget);
    });

    testWidgets('3. Tapping Live Data pill switches mode between Demo Mode and Live Data', (tester) async {
      await tester.pumpWidget(createWidgetStudioScreen());
      await tester.pumpAndSettle();

      expect(find.text('Demo'), findsOneWidget);
      await tester.tap(find.text('Demo'));
      await tester.pumpAndSettle();

      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('4. Toggling Privacy Mode switch updates state and masks amounts in previews', (tester) async {
      await tester.pumpWidget(createWidgetStudioScreen());
      await tester.pumpAndSettle();

      expect(widgetService.isPrivacyMode, false);
      expect(find.text('₹12,450'), findsOneWidget);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(widgetService.isPrivacyMode, true);
      expect(find.text('₹••••'), findsWidgets);
    });

    testWidgets('5. Renders manual launcher step guide at the bottom of the studio', (tester) async {
      await tester.pumpWidget(createWidgetStudioScreen());
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('How to add manually from Launcher:'), 150, scrollable: scrollableFinder);

      expect(find.text('How to add manually from Launcher:'), findsOneWidget);
      expect(find.text('Long press any empty area on your Android Home Screen'), findsOneWidget);
      expect(find.text('Select Widgets and scroll down to find Kith'), findsOneWidget);
    });
  });
}
