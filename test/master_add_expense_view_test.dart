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
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/add_expense_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/trip_detail_viewmodel.dart';
import 'package:kith_app/presentation/views/add_expense/add_expense_view.dart';
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
  late TripDetailViewModel tripDetailVm;
  late AddExpenseViewModel addVm;
  late HomeViewModel homeVm;
  late KithWidgetService widgetService;

  final testTrip = Trip(
    id: 'trip_add_expense_orig_test',
    name: 'Goa Holiday',
    emoji: '🌴',
    creatorId: 'user_darpan',
    inviteCode: 'GOA777',
    members: [
      TripMember(id: 'mem_1', userId: 'user_darpan', displayName: 'Darpan Parmar', joinedAt: DateTime.now()),
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
    tripDetailVm = TripDetailViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
    addVm = AddExpenseViewModel(expenseRepo: expenseRepo);
    widgetService = KithWidgetService(storage: storage);

    await authVm.createGuestSession('Darpan Parmar');
    await storage.saveTrips([testTrip.toJson()]);
  });

  Widget createAddExpenseScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: homeVm),
        ChangeNotifierProvider.value(value: tripDetailVm),
        ChangeNotifierProvider.value(value: addVm),
        Provider.value(value: tripRepo),
        Provider.value(value: expenseRepo),
        ChangeNotifierProvider.value(value: widgetService),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AddExpenseView(tripId: 'trip_add_expense_orig_test'),
      ),
    );
  }

  group('Master Redesigned AddExpenseView Suite', () {
    testWidgets('1. Renders redesigned Add Expense view with hero amount, quick presets, payer, and save button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tripDetailVm.loadTrip('trip_add_expense_orig_test', 'user_darpan');
      await tester.pumpWidget(createAddExpenseScreen());
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Voice AI'), findsOneWidget);
      expect(find.text('Scan Receipt'), findsOneWidget);
      expect(find.text('AMOUNT'), findsOneWidget);
      expect(find.text('QUICK SUGGESTIONS'), findsOneWidget);
      expect(find.text('PAID BY'), findsOneWidget);
      expect(find.text('SPLIT TYPE'), findsOneWidget);
      expect(find.text('Save Expense'), findsOneWidget);
    });

    testWidgets('2. Entering amount and title updates add expense form state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tripDetailVm.loadTrip('trip_add_expense_orig_test', 'user_darpan');
      await tester.pumpWidget(createAddExpenseScreen());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '1250');
      await tester.enterText(textFields.at(1), 'Seafood Dinner');
      await tester.pumpAndSettle();

      expect(addVm.amountInPaise, 125000);
      expect(addVm.title, 'Seafood Dinner');
    });

    testWidgets('3. Tapping quick preset populates title and sets category', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tripDetailVm.loadTrip('trip_add_expense_orig_test', 'user_darpan');
      await tester.pumpWidget(createAddExpenseScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();

      expect(addVm.title, 'Dinner');
    });
  });
}
