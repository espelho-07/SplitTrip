import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/add_expense_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/currency_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/trip_detail_viewmodel.dart';
import 'package:kith_app/presentation/views/add_expense/add_expense_view.dart';

void main() {
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
  late CurrencyViewModel currencyVm;

  final testTrip = Trip(
    id: 'trip_calc_test',
    name: 'Goa Trip',
    emoji: '🏖️',
    creatorId: 'user_darpan',
    inviteCode: 'GOA123',
    members: [
      TripMember(id: 'mem_1', userId: 'user_darpan', displayName: 'Darpan Parmar', joinedAt: DateTime.now()),
      TripMember(id: 'mem_2', userId: 'user_rahul', displayName: 'Rahul Verma', joinedAt: DateTime.now()),
    ],
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
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
    currencyVm = CurrencyViewModel(storage: storage);

    await authVm.createGuestSession('Darpan Parmar');
    await storage.saveTrips([testTrip.toJson()]);
  });

  Widget createAddExpenseScreen({Expense? existingExpense}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: homeVm),
        ChangeNotifierProvider.value(value: tripDetailVm),
        ChangeNotifierProvider.value(value: addVm),
        ChangeNotifierProvider.value(value: currencyVm),
        Provider.value(value: tripRepo),
        Provider.value(value: expenseRepo),
        ChangeNotifierProvider.value(value: widgetService),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AddExpenseView(
          tripId: 'trip_calc_test',
          initialTab: 2, // Manual form
          existingExpense: existingExpense,
        ),
      ),
    );
  }

  group('AddExpenseView Smart Keyboard & Expression Calculator Tests', () {
    testWidgets('evaluates expression 100+23 and saves expense with 12300 paise', (tester) async {
      await tripDetailVm.loadTrip('trip_calc_test', 'user_darpan');
      await tester.pumpWidget(createAddExpenseScreen());
      await tester.pumpAndSettle();

      // Find amount input (first TextField in Amount Calculator)
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Enter expression '100+23' in amount field
      await tester.enterText(textFields.first, '100+23');
      await tester.pumpAndSettle();

      // Live preview should show 123
      expect(find.textContaining('123'), findsWidgets);

      // Enter description
      await tester.enterText(textFields.at(1), 'Lunch Express');
      await tester.pumpAndSettle();

      // Find the bottom save button
      final saveBtn = find.textContaining('Save Expense');
      expect(saveBtn, findsOneWidget);

      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify expense was committed with 12300 paise
      final savedExpenses = expenseRepo.getCachedExpenses('trip_calc_test');
      expect(savedExpenses.isNotEmpty, isTrue);
      expect(savedExpenses.first.amountInPaise, 12300);
      expect(savedExpenses.first.title, 'Lunch Express');

      // Await timer cleanup in test harness
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('evaluates multiplication expression 23*5 and saves with 11500 paise', (tester) async {
      await tripDetailVm.loadTrip('trip_calc_test', 'user_darpan');
      await tester.pumpWidget(createAddExpenseScreen());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, '23*5');
      await tester.pumpAndSettle();

      expect(find.textContaining('115'), findsWidgets);

      await tester.enterText(textFields.at(1), 'Taxi Ride');
      await tester.pumpAndSettle();

      final saveBtn = find.textContaining('Save Expense');
      expect(saveBtn, findsOneWidget);

      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final savedExpenses = expenseRepo.getCachedExpenses('trip_calc_test');
      expect(savedExpenses.any((e) => e.amountInPaise == 11500), isTrue);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('editing existing expense pre-populates amount & description and preserves them', (tester) async {
      final existing = Expense(
        id: 'exp_edit_test',
        tripId: 'trip_calc_test',
        title: 'Original Dinner',
        amountInPaise: 45000,
        category: ExpenseCategory.food,
        paidById: 'mem_1',
        splitType: SplitType.equal,
        splits: [
          ExpenseSplit(memberId: 'mem_1', amountInPaise: 22500),
          ExpenseSplit(memberId: 'mem_2', amountInPaise: 22500),
        ],
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await tripDetailVm.loadTrip('trip_calc_test', 'user_darpan');
      await tester.pumpWidget(createAddExpenseScreen(existingExpense: existing));
      await tester.pumpAndSettle();

      // Check pre-populated values
      expect(find.text('450'), findsOneWidget);
      expect(find.text('Original Dinner'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('division by zero expression shows validation error and blocks saving', (tester) async {
      await tripDetailVm.loadTrip('trip_calc_test', 'user_darpan');
      await tester.pumpWidget(createAddExpenseScreen());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, '10/0');
      await tester.pumpAndSettle();

      // Should show 'Cannot divide by zero'
      expect(find.text('Cannot divide by zero'), findsOneWidget);

      // Attempt save
      final saveBtn = find.textContaining('Save Expense');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Error snackbar should be displayed
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Cannot divide by zero'), findsWidgets);

      await tester.pump(const Duration(seconds: 3));
    });
  });
}
