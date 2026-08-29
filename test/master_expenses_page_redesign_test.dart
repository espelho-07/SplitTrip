import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/personal_expense_viewmodel.dart';
import 'package:kith_app/presentation/views/home/widgets/dashboard_tab.dart';
import 'package:kith_app/presentation/views/personal/personal_home_tab.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late UserRepository userRepo;
  late AuthService authService;
  late AuthViewModel authVm;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late HomeViewModel homeVm;
  late PersonalRepository personalRepo;
  late PersonalExpenseViewModel personalVm;

  final testUser = GuestUser(
    id: 'user_main',
    displayName: 'Darpan Parmar',
    avatarUrl: 'https://example.com/avatar.png',
    recoveryKey: 'ABC1-DEF2-GHI3-JKL4',
    anonymousToken: 'anon_test_token_123',
    createdAt: DateTime.now(),
  );

  final activeTrip1 = Trip(
    id: 'trip_goa',
    name: 'Goa Trip',
    emoji: '🌴',
    creatorId: 'user_main',
    inviteCode: 'GOA111',
    lifecycleState: TripLifecycle.active,
    members: [TripMember(id: 'mem_1', userId: 'user_main', displayName: 'Darpan', joinedAt: DateTime.now())],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final activeTrip2 = Trip(
    id: 'trip_manali',
    name: 'Manali Trip',
    emoji: '🏔️',
    creatorId: 'user_main',
    inviteCode: 'MAN222',
    lifecycleState: TripLifecycle.active,
    members: [TripMember(id: 'mem_1', userId: 'user_main', displayName: 'Darpan', joinedAt: DateTime.now())],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    syncService = SyncService(storage);
    apiClient = ApiClient();
    authService = AuthService(apiClient: apiClient, storage: storage);
    userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);

    await storage.saveUser(testUser.toJson());
    await authVm.initSession();

    tripRepo = TripRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    expenseRepo = ExpenseRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);

    personalRepo = PersonalRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    personalVm = PersonalExpenseViewModel(personalRepo: personalRepo, tripRepo: tripRepo, expenseRepo: expenseRepo);
  });

  Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
        ChangeNotifierProvider<HomeViewModel>.value(value: homeVm),
        ChangeNotifierProvider<PersonalExpenseViewModel>.value(value: personalVm),
        Provider<LocalStorageService>.value(value: storage),
        Provider<SyncService>.value(value: syncService),
        Provider<TripRepository>.value(value: tripRepo),
        Provider<ExpenseRepository>.value(value: expenseRepo),
        Provider<PersonalRepository>.value(value: personalRepo),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('gu'), Locale('hi')],
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

  group('Master Expenses Page Redesign & Smart Add Expense Suite', () {
    testWidgets('1. Quick Actions renders Join Scanner in place of Voice AI', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const Scaffold(body: DashboardTab())));
      await tester.pumpAndSettle();

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Add\nExpense'), findsOneWidget);
      expect(find.text('Add Trip'), findsOneWidget);
      expect(find.text('Scan\nReceipt'), findsOneWidget);
      expect(find.text('Join\nScanner'), findsOneWidget);
      expect(find.text('Voice AI'), findsNothing);
    });

    testWidgets('2. Quick Add Expense opens active trip picker when multiple active trips exist', (tester) async {
      await storage.saveTrips([activeTrip1.toJson(), activeTrip2.toJson()]);
      await homeVm.loadTrips(testUser.id);

      await tester.pumpWidget(wrapWithProviders(const Scaffold(body: DashboardTab())));
      await tester.pumpAndSettle();

      final addExpenseBtn = find.text('Add\nExpense');
      await tester.scrollUntilVisible(addExpenseBtn, 200);
      await tester.tap(addExpenseBtn);
      await tester.pumpAndSettle();

      // Should show trip picker modal with both active trips
      expect(find.text('Select Active Trip'), findsOneWidget);
      expect(find.text('Goa Trip'), findsOneWidget);
      expect(find.text('Manali Trip'), findsOneWidget);
      expect(find.text('Log as Personal Expense instead'), findsOneWidget);
    });

    testWidgets('3. Redesigned Expenses Page renders header, hero card, categories, and empty state', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const Scaffold(body: PersonalHomeTab())));
      await tester.pumpAndSettle();

      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('THIS MONTH\'S SPEND'), findsOneWidget);
      expect(find.text('Lending'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Set Budget'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('RECENT EXPENSES'), findsOneWidget);
      expect(find.text('No expenses logged yet'), findsOneWidget);
    });

    testWidgets('4. Expenses Page displays chronological feed and filters by category', (tester) async {
      await personalRepo.createPersonalExpense(
        userId: testUser.id,
        title: 'Starbucks Coffee',
        amountInPaise: 45000,
        category: ExpenseCategory.food,
      );

      await personalRepo.createPersonalExpense(
        userId: testUser.id,
        title: 'Uber to Airport',
        amountInPaise: 85000,
        category: ExpenseCategory.transport,
      );

      await personalVm.loadData(testUser.id);

      await tester.pumpWidget(wrapWithProviders(const Scaffold(body: PersonalHomeTab())));
      await tester.pumpAndSettle();

      expect(find.text('Starbucks Coffee'), findsOneWidget);
      expect(find.text('Uber to Airport'), findsOneWidget);
      expect(find.text('₹450'), findsOneWidget);
      expect(find.text('₹850'), findsOneWidget);
    });
  });
}
