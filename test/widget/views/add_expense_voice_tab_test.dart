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
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/add_expense_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/currency_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/trip_detail_viewmodel.dart';
import 'package:kith_app/presentation/views/add_expense/add_expense_view.dart';
import 'package:kith_app/presentation/views/add_expense/voice_review_view.dart';

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
    id: 'trip_voice_test',
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

  Widget createAddExpenseScreen({int initialTab = 0}) {
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
          tripId: 'trip_voice_test',
          initialTab: initialTab,
        ),
      ),
    );
  }

  group('AddExpenseView Voice Tab Tests', () {
    testWidgets('Renders Voice Multi-Expense tab with mic and examples', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createAddExpenseScreen(initialTab: 0));
      await tester.pumpAndSettle();

      expect(find.text('Voice Multi-Expense Entry'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsWidgets);
      expect(find.text('SPOKEN TRANSCRIPT'), findsOneWidget);
      expect(find.text('TRY SAYING'), findsOneWidget);
      expect(find.textContaining('Maine 4k train ke'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Tapping example chip populates transcript and enables process button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createAddExpenseScreen(initialTab: 0));
      await tester.pumpAndSettle();

      // Find example chip and tap it
      final example = find.textContaining('Maine 4k train ke');
      expect(example, findsOneWidget);
      await tester.tap(example);
      await tester.pumpAndSettle();

      // Verify transcript text is populated
      expect(find.textContaining('Maine 4k train ke, 5k club ke aur 800 food ke diye'), findsWidgets);

      // Verify Process Spoken Expenses button is clickable
      final processBtn = find.text('Process Spoken Expenses');
      expect(processBtn, findsOneWidget);

      await tester.tap(processBtn);
      await tester.pumpAndSettle();

      // Should transition to VoiceReviewView
      expect(find.byType(VoiceReviewView), findsOneWidget);
      expect(find.text('Review Spoken Expenses'), findsOneWidget);
      expect(find.text('DETECTED EXPENSES (3)'), findsOneWidget);
      expect(find.text('Confirm & Save (3)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Confirms and saves multi-expenses into trip repository', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createAddExpenseScreen(initialTab: 0));
      await tester.pumpAndSettle();

      // Enter a custom 2-expense transcript
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Train 4000, hotel 5000');
      await tester.pumpAndSettle();

      // Tap Process button
      await tester.tap(find.text('Process Spoken Expenses'));
      await tester.pumpAndSettle();

      // In VoiceReviewView, confirm and save
      expect(find.byType(VoiceReviewView), findsOneWidget);
      expect(find.text('Confirm & Save (2)'), findsOneWidget);

      await tester.tap(find.text('Confirm & Save (2)'));
      await tester.pumpAndSettle();

      // Verify expenses were saved to database / repository
      final storedExpenses = await expenseRepo.getExpenses('trip_voice_test');
      expect(storedExpenses.length, 2);
      expect(storedExpenses.any((e) => e.title == 'Train'), isTrue);
      expect(storedExpenses.any((e) => e.title == 'Hotel'), isTrue);

      await tester.pump(const Duration(seconds: 3));
    });
  });
}
