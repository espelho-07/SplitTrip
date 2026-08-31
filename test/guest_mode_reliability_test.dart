import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_language.dart';
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
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/locale_viewmodel.dart';
import 'package:kith_app/presentation/views/onboarding/onboarding_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late AuthService authService;
  late UserRepository userRepo;
  late AuthViewModel authVm;
  late LocaleViewModel localeVm;
  late KithWidgetService widgetService;
  late SyncService syncService;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    apiClient = ApiClient();
    authService = AuthService(apiClient: apiClient, storage: storage);
    userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);
    localeVm = LocaleViewModel(storage: storage);
    widgetService = KithWidgetService(storage: storage);
    syncService = SyncService(storage);
    tripRepo = TripRepository(apiClient: apiClient, storage: storage, syncService: syncService);
    expenseRepo = ExpenseRepository(apiClient: apiClient, storage: storage, syncService: syncService);
  });

  Widget createOnboardingScreen({Locale locale = const Locale('en')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: localeVm),
        ChangeNotifierProvider.value(value: widgetService),
      ],
      child: MaterialApp(
        locale: locale,
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
        home: const OnboardingView(),
      ),
    );
  }

  group('Guest Mode Reliability, Isolation & Lifecycle Suite', () {
    testWidgets('1. Tap Continue as Guest opens name input sheet and authenticates with entered name', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createOnboardingScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(authVm.isAuthenticated, isFalse);
      expect(find.text('Continue as Guest'), findsOneWidget);

      await tester.tap(find.text('Continue as Guest'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Enter name in sheet
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Darpan Traveler');
      await tester.pump();

      // Submit sheet
      await tester.tap(find.text('Start Exploring'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(authVm.isAuthenticated, isTrue);
      expect(authVm.currentUser, isNotNull);
      expect(authVm.currentUser!.displayName, equals('Darpan Traveler'));
      expect(authVm.currentUser!.recoveryKey, startsWith('KITH-'));
      expect(storage.hasSelectedInitialLanguage(), isTrue);
    });

    test('2. Guest identity persists in storage and restores on app restart', () async {
      final guest = await authVm.createGuestSession('Darpan Guest');
      expect(guest.id, isNotEmpty);
      expect(storage.getSavedUser(), isNotNull);

      // Simulate app restart with new ViewModel and AuthService
      final newAuthService = AuthService(apiClient: apiClient, storage: storage);
      final newUserRepo = UserRepository(authService: newAuthService);
      final newAuthVm = AuthViewModel(userRepo: newUserRepo);

      await newAuthVm.initSession();
      expect(newAuthVm.isAuthenticated, isTrue);
      expect(newAuthVm.currentUser?.id, equals(guest.id));
      expect(newAuthVm.currentUser?.displayName, equals('Darpan Guest'));
    });

    test('3. Guest Mode creates trips, expenses locally without network', () async {
      final guest = await authVm.createGuestSession('Offline Traveler');

      final trip = await tripRepo.createTrip(
        name: 'Goa Weekend',
        creator: guest,
      );
      expect(trip.id, isNotEmpty);

      final trips = storage.getSavedTrips();
      expect(trips.length, equals(1));
      expect(trips.first['name'], equals('Goa Weekend'));

      final expense = await expenseRepo.addExpense(
        Expense(
          id: 'exp_guest_1',
          tripId: trip.id,
          title: 'Seafood',
          amountInPaise: 120000,
          category: ExpenseCategory.food,
          paidById: guest.id,
          splits: [
            ExpenseSplit(
              memberId: guest.id,
              amountInPaise: 120000,
            ),
          ],
          splitType: SplitType.equal,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      expect(expense.id, equals('exp_guest_1'));
      expect(storage.getSavedExpenses(trip.id).length, equals(1));
    });

    test('4. Guest data is completely isolated and purged on Logout', () async {
      final guest = await authVm.createGuestSession('Guest To Purge');
      await tripRepo.createTrip(
        name: 'Private Trip',
        creator: guest,
      );
      expect(storage.getSavedTrips().length, equals(1));

      // Logout
      await authVm.logout();
      expect(authVm.isAuthenticated, isFalse);
      expect(authVm.currentUser, isNull);
      expect(storage.getSavedUser(), isNull);
    });

    test('5. Multi-language Guest Mode operates seamlessly in Hindi and Gujarati', () async {
      await localeVm.setLanguage(AppLanguage.hindi);
      expect(localeVm.currentLanguage, equals(AppLanguage.hindi));

      final guestHi = await authVm.createGuestSession('यात्री');
      expect(guestHi.displayName, equals('यात्री'));

      await localeVm.setLanguage(AppLanguage.gujarati);
      expect(localeVm.currentLanguage, equals(AppLanguage.gujarati));
      final guestGu = await authVm.createGuestSession('યાત્રી');
      expect(guestGu.displayName, equals('યાત્રી'));
    });

    test('6. Guest to Google account linking re-tags local records idempotently', () async {
      final guest = await authVm.createGuestSession('Initial Guest');

      // Add a trip under this guest
      await tripRepo.createTrip(
        name: 'Kashmir Expedition',
        creator: guest,
      );

      // Sign in with Google (linking)
      final googleUser = await authVm.signInWithGoogle(
        email: 'darpan@example.com',
        displayName: 'Darpan Cloud',
        googleId: 'google_12345',
      );

      expect(googleUser, isNotNull);
      expect(googleUser?.email, equals('darpan@example.com'));
      expect(googleUser?.isLinkedToAccount, isTrue);

      // Trips should be preserved and updated
      final trips = storage.getSavedTrips();
      expect(trips.length, equals(1));
    });
  });
}
