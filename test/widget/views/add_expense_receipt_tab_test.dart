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
import 'package:kith_app/domain/models/receipt_data.dart';
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
    id: 'trip_receipt_test',
    name: 'Bengaluru Trip',
    emoji: '☕',
    creatorId: 'user_darpan',
    inviteCode: 'BLR123',
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
    addTearDown(() {
      tripDetailVm.stopHeartbeat();
    });
  });

  tearDown(() {
    tripDetailVm.dispose();
    homeVm.dispose();
    addVm.dispose();
    authVm.dispose();
    currencyVm.dispose();
    widgetService.dispose();
  });

  Widget createAddExpenseScreen({int initialTab = 1}) {
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
          tripId: 'trip_receipt_test',
          initialTab: initialTab,
        ),
      ),
    );
  }

  group('AddExpenseView Receipt Scanner Integration Tests', () {
    testWidgets('renders Receipt Scanner Tab when initialTab is 1', (tester) async {
      await tester.pumpWidget(createAddExpenseScreen(initialTab: 1));
      await tester.pumpAndSettle();

      expect(find.text('Scan Any Receipt or Bill'), findsOneWidget);
      expect(find.text('Scan with Camera'), findsOneWidget);
      expect(find.text('Import from Gallery'), findsOneWidget);
      expect(find.text('TIPS FOR BEST ACCURACY'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      tripDetailVm.stopHeartbeat();
    });

    testWidgets('switching between tabs updates displayed view', (tester) async {
      await tester.pumpWidget(createAddExpenseScreen(initialTab: 1));
      await tester.pumpAndSettle();

      expect(find.text('Scan Any Receipt or Bill'), findsOneWidget);

      // Tap "Manual" tab
      final manualTab = find.text('Manual');
      expect(manualTab, findsOneWidget);
      await tester.tap(manualTab);
      await tester.pumpAndSettle();

      // Manual form should now be visible
      expect(find.text('Scan Any Receipt or Bill'), findsNothing);
      expect(find.textContaining('Save Expense'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      tripDetailVm.stopHeartbeat();
    });

    testWidgets('applyReceiptData pre-fills form, displays attached badge, and sets receiptUrl', (tester) async {
      await tester.pumpWidget(createAddExpenseScreen(initialTab: 1));
      await tester.pumpAndSettle();

      final confirmedReceipt = ReceiptData(
        id: 'rcpt-applied',
        imagePath: '/tmp/receipt_file.jpg',
        merchant: const ReceiptMerchant(name: 'Empire Restaurant', address: 'Church Street'),
        receipt: ReceiptMetadata(
          receiptNumber: 'EMP-901',
          date: DateTime(2024, 11, 10),
        ),
        items: const [
          ReceiptItem(
            id: 'item-1',
            name: 'Chicken Biryani',
            quantity: 2,
            unitPriceInPaise: 25000,
            totalPriceInPaise: 50000,
          ),
        ],
        summary: const ReceiptSummary(
          subtotalInPaise: 50000,
          totalInPaise: 50000,
        ),
        predictedCategory: ExpenseCategory.food,
      );

      // Apply receipt data through ViewModel
      addVm.applyReceiptData(confirmedReceipt);
      await tester.pumpAndSettle();

      // View should have transitioned to Manual tab with attached badge
      expect(addVm.currentTab, 2);
      expect(addVm.amountInPaise, 50000);
      expect(addVm.title, 'Empire Restaurant');
      expect(addVm.receiptUrl, '/tmp/receipt_file.jpg');
      expect(addVm.category, ExpenseCategory.food);

      expect(find.text('Receipt Attached'), findsOneWidget);
      expect(find.textContaining('500'), findsWidgets);

      await tester.pump(const Duration(seconds: 3));
      tripDetailVm.stopHeartbeat();
    });

    testWidgets('saves expense with receiptUrl and commits to repository', (tester) async {
      await tester.pumpWidget(createAddExpenseScreen(initialTab: 1));
      await tester.pumpAndSettle();

      final confirmedReceipt = ReceiptData(
        id: 'rcpt-save-test',
        imagePath: '/tmp/receipt_stored.jpg',
        merchant: const ReceiptMerchant(name: 'Corner House Ice Cream'),
        receipt: const ReceiptMetadata(receiptNumber: 'CH-404'),
        summary: const ReceiptSummary(totalInPaise: 35000),
        predictedCategory: ExpenseCategory.food,
      );

      addVm.applyReceiptData(confirmedReceipt);
      await tester.pumpAndSettle();

      final savedExpense = await addVm.saveExpense('trip_receipt_test');
      expect(savedExpense, isNotNull);
      expect(savedExpense!.title, 'Corner House Ice Cream');
      expect(savedExpense.amountInPaise, 35000);
      expect(savedExpense.receiptUrl, '/tmp/receipt_stored.jpg');

      final cached = expenseRepo.getCachedExpenses('trip_receipt_test');
      expect(cached.any((e) => e.receiptUrl == '/tmp/receipt_stored.jpg'), isTrue);

      await tester.pump(const Duration(seconds: 3));
      tripDetailVm.stopHeartbeat();
    });
  });
}
