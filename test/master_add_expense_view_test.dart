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
import 'package:kith_app/domain/enums/split_type.dart';
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

  group('Master Clean AddExpenseView Suite', () {
    testWidgets('1. Renders clean Add Group Expense view with amount card, payer, category, split method, and bottom dock', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tripDetailVm.loadTrip('trip_add_expense_orig_test', 'user_darpan');
      await tester.pumpWidget(createAddExpenseScreen());
      await tester.pumpAndSettle();

      expect(find.text('Add Group Expense'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Voice'), findsOneWidget);
      expect(find.text('Receipt'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('What was this for?'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Who Paid?'), findsOneWidget);
      expect(find.text('Split Method'), findsOneWidget);
      expect(find.text('Save Expense'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
    });

    testWidgets('2. Entering amount and title updates add expense form state and bottom total', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tripDetailVm.loadTrip('trip_add_expense_orig_test', 'user_darpan');
      await tester.pumpWidget(createAddExpenseScreen());
      await tester.pumpAndSettle();

      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '1000');
      await tester.pumpAndSettle();

      final titleField = find.widgetWithText(TextField, 'e.g. Train tickets, Dinner, Groceries');
      if (titleField.evaluate().isNotEmpty) {
        await tester.enterText(titleField, 'Dinner');
        await tester.pumpAndSettle();
      }

      expect(addVm.amountInPaise, 100000);
      expect(addVm.title, 'Dinner');
      expect(find.text('₹1,000'), findsWidgets);
    });

    testWidgets('3. Renders Question Mark (?) button and Split Method Dropdown, opens explainer on tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tripDetailVm.loadTrip('trip_add_expense_orig_test', 'user_darpan');
      await tester.pumpWidget(createAddExpenseScreen());
      await tester.pumpAndSettle();

      // Verify Split Method header, Question Mark icon, and Dropdown
      expect(find.text('Split Method'), findsOneWidget);
      expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);
      expect(find.text('Equally'), findsOneWidget);
      expect(find.byType(DropdownButton<SplitType>), findsOneWidget);

      // Tap Question Mark (?) icon
      await tester.tap(find.byIcon(Icons.question_mark_rounded));
      await tester.pumpAndSettle();

      // Should open Split Methods Explained sheet with all 4 methods
      expect(find.text('Split Methods Explained'), findsOneWidget);
      expect(find.text('How Kith divides trip expenses'), findsOneWidget);
      expect(find.text('Exact Amounts (₹)'), findsOneWidget);
      expect(find.text('By Percentage (%)'), findsOneWidget);
      expect(find.text('By Shares / Ratios'), findsOneWidget);

      // Tap 'By Percentage (%)' card to select it directly from explainer
      await tester.tap(find.text('By Percentage (%)'));
      await tester.pumpAndSettle();

      // Verify active split method changed to percentage
      expect(addVm.splitType, SplitType.percentage);
    });
  });
}
