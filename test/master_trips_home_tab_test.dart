import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
import 'package:kith_app/core/widgets/kith_brand.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/personal_expense_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/theme_viewmodel.dart';
import 'package:kith_app/presentation/views/home/home_view.dart';
import 'package:kith_app/presentation/views/trip/trips_home_tab.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late SyncService syncService;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late PersonalRepository personalRepo;
  late KithWidgetService widgetService;
  late AuthViewModel authVm;
  late HomeViewModel homeVm;
  late PersonalExpenseViewModel personalVm;
  late ThemeViewModel themeVm;
  late GuestUser testUser;

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
      displayName: 'Darpan',
      recoveryKey: 'KITH-TEST-1234',
      anonymousToken: 'anon_tok_123',
      createdAt: DateTime.now(),
    );

    await storage.saveUser(testUser.toJson());
    await authVm.initSession();
  });

  Widget createTripsHomeScreen({Widget? child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: homeVm),
        ChangeNotifierProvider.value(value: personalVm),
        ChangeNotifierProvider.value(value: themeVm),
        ChangeNotifierProvider.value(value: widgetService),
        Provider.value(value: apiClient),
        Provider.value(value: syncService),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, theme, _) {
          return MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: theme.themeMode,
            localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('hi'),
          Locale('gu'),
        ],
        home: child ?? const Scaffold(body: TripsHomeTab()),
          );
        },
      ),
    );
  }

  group('Master Trips Home Tab Suite (Specification Match)', () {
    testWidgets('1. Renders Hero Financial Card with TOTAL SPENT ON TRIPS, 0 Trips counter, ₹0 amount, and settled status', (tester) async {
      await tester.pumpWidget(createTripsHomeScreen());
      await tester.pumpAndSettle();

      expect(find.text('TOTAL SPENT ON TRIPS'), findsOneWidget);
      expect(find.text('0 Trips'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);
      expect(find.text('All trip balances settled up'), findsOneWidget);
    });

    testWidgets('2. Renders Section Header with "Your Group Trips" and "+ Join Trip"', (tester) async {
      await tester.pumpWidget(createTripsHomeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Your Group Trips'), findsOneWidget);
      expect(find.text('Join Trip'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
    });

    testWidgets('3. Renders Empty State with circular map badge, "No trips yet", subtitle, and "+ New Trip" button', (tester) async {
      await tester.pumpWidget(createTripsHomeScreen());
      await tester.pumpAndSettle();

      expect(find.text('🗺️'), findsOneWidget);
      expect(find.text('No trips yet'), findsOneWidget);
      expect(find.text('Create a trip when you\'re ready to split group expenses with friends.'), findsOneWidget);
      expect(find.text('New Trip'), findsOneWidget);
    });

    testWidgets('4. Populated trips state renders trip card with gradient cover, members, and balance', (tester) async {
      final now = DateTime.now();
      final sampleTrip = Trip(
        id: 'trip_goa_01',
        name: 'Goa Trip 2026',
        emoji: '🏖️',
        creatorId: 'usr_darpan_01',
        coverGradientIndex: 1,
        currencyCode: 'INR',
        inviteCode: 'GOA123',
        members: [
          TripMember(id: 'm1', userId: 'usr_darpan_01', displayName: 'Darpan', joinedAt: now),
          TripMember(id: 'm2', userId: 'usr_rahul_02', displayName: 'Rahul', joinedAt: now),
          TripMember(id: 'm3', userId: 'usr_priya_03', displayName: 'Priya', joinedAt: now),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await storage.saveTrips([sampleTrip.toJson()]);
      await homeVm.loadTrips('usr_darpan_01');

      await tester.pumpWidget(createTripsHomeScreen());
      await tester.pumpAndSettle();

      expect(find.text('TOTAL SPENT ON TRIPS'), findsOneWidget);
      expect(find.text('1 Trip'), findsOneWidget);
      expect(find.text('Goa Trip 2026'), findsOneWidget);
      expect(find.text('🏖️'), findsOneWidget);
      expect(find.text('3 members'), findsOneWidget);
    });

    testWidgets('5. HomeView renders user greeting, notification bell, and 4 navigation destinations', (tester) async {
      await tester.pumpWidget(createTripsHomeScreen(child: const HomeView()));
      await tester.pumpAndSettle();

      expect(find.text('Hi, Darpan'), findsOneWidget);
      expect(find.text("What's the plan today?"), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('6. KithLogoMark renders the official app logo asset gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: KithLogoMark(size: 80, isDark: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KithLogoMark), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
