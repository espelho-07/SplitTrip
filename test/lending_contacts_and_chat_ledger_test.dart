import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/personal_debt.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/person_ledger_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/personal_expense_viewmodel.dart';
import 'package:kith_app/presentation/views/personal/person_ledger_view.dart';
import 'package:kith_app/presentation/views/personal/widgets/add_personal_expense_sheet.dart';
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
  late PersonLedgerViewModel ledgerVm;

  final testUser = GuestUser(
    id: 'user_123',
    displayName: 'Darpan',
    avatarUrl: '',
    recoveryKey: 'KITH-1234-5678-ABCD',
    anonymousToken: 'anon_token_123',
    createdAt: DateTime.now(),
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
    ledgerVm = PersonLedgerViewModel(
      personalRepo: personalRepo,
      expenseRepo: expenseRepo,
      tripRepo: tripRepo,
      storage: storage,
    );
  });

  Widget createTestApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
        ChangeNotifierProvider<PersonalExpenseViewModel>.value(value: personalVm),
        ChangeNotifierProvider<PersonLedgerViewModel>.value(value: ledgerVm),
        ChangeNotifierProvider<HomeViewModel>.value(value: homeVm),
        Provider<LocalStorageService>.value(value: storage),
        Provider<PersonalRepository>.value(value: personalRepo),
        Provider<ExpenseRepository>.value(value: expenseRepo),
        Provider<TripRepository>.value(value: tripRepo),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('1. AddPersonalExpenseSheet Lending-Only Mode', () {
    testWidgets('Shows ONLY "I Lent" and "I Borrowed" when lendingOnly is true', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const AddPersonalExpenseSheet(
            lendingOnly: true,
            initialPersonName: 'Aarav',
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Should show Lent and Borrowed tabs
      expect(find.text('I Lent'), findsOneWidget);
      expect(find.text('I Borrowed'), findsOneWidget);

      // Should NOT show Personal tab
      expect(find.text('Personal'), findsNothing);

      // Should show Lending & Borrowing badge
      expect(find.text('Lending & Borrowing · 1-on-1 Ledger'), findsOneWidget);

      // Should have pre-filled Aarav in Person field
      expect(find.text('Aarav'), findsOneWidget);

      // Should have Contact Picker button icon
      expect(find.byIcon(Icons.contacts_rounded), findsOneWidget);
    });

    testWidgets('Shows "Personal", "I Lent", and "I Borrowed" when lendingOnly is false', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const AddPersonalExpenseSheet(
            lendingOnly: false,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('I Lent'), findsOneWidget);
      expect(find.text('I Borrowed'), findsOneWidget);
    });
  });

  group('2. WhatsApp Chat-Style PersonLedgerView', () {
    testWidgets('Renders WhatsApp chat conversation with bubbles and bottom action bar', (tester) async {
      // Seed debt records with Aarav
      await personalVm.addDebt(
        userId: testUser.id,
        personName: 'Aarav',
        debtType: PersonalDebtType.lent,
        amountInPaise: 50000,
        description: 'Dinner at Bistro',
        date: DateTime.now(),
      );

      await personalVm.addDebt(
        userId: testUser.id,
        personName: 'Aarav',
        debtType: PersonalDebtType.borrowed,
        amountInPaise: 20000,
        description: 'Metro Ticket',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestApp(
          const PersonLedgerView(
            personName: 'Aarav',
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Header should show person name and net receivable
      expect(find.text('Aarav'), findsWidgets);
      expect(find.textContaining('You will get'), findsWidgets);

      // Share on WhatsApp button
      expect(find.byIcon(Icons.share_rounded), findsWidgets);

      // Chat bubbles
      expect(find.text('You Paid / Lent'), findsOneWidget);
      expect(find.text('Aarav Paid / You Borrowed'), findsOneWidget);
      expect(find.text('Dinner at Bistro'), findsOneWidget);
      expect(find.text('Metro Ticket'), findsOneWidget);

      // Bottom WhatsApp Action Bar
      expect(find.text('You Gave (₹)'), findsOneWidget);
      expect(find.text('You Got (₹)'), findsOneWidget);
    });

    testWidgets('Tapping "You Gave" opens quick in-app keypad sheet', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const PersonLedgerView(
            personName: 'Rohan',
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // Tap "You Gave (₹)"
      await tester.tap(find.text('You Gave (₹)'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('You Paid Rohan'), findsOneWidget);
      expect(find.text('Add a note (e.g. Dinner, Rent, Fuel)...'), findsOneWidget);

      // Numeric keypad should be visible with numbers
      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });
  });
}
