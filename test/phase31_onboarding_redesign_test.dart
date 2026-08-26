import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_language.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/locale_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/personal_expense_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/theme_viewmodel.dart';
import 'package:kith_app/presentation/views/onboarding/onboarding_view.dart';
import 'package:kith_app/presentation/views/onboarding/widgets/guest_setup_sheet.dart';
import 'package:kith_app/presentation/views/onboarding/widgets/kith_google_button.dart';
import 'package:kith_app/presentation/views/onboarding/widgets/kith_hero_scene.dart';
import 'package:kith_app/presentation/views/onboarding/widgets/recovery_key_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 31: Kith Premium Sign-In & Onboarding Redesign Tests', () {
    late LocalStorageService storage;
    late UserRepository userRepo;
    late AuthViewModel authVm;
    late LocaleViewModel localeVm;
    late ThemeViewModel themeVm;
    late SyncService syncService;
    late ApiClient apiClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      apiClient = ApiClient();
      final authService = AuthService(apiClient: apiClient, storage: storage);
      userRepo = UserRepository(authService: authService);
      authVm = AuthViewModel(userRepo: userRepo);
      localeVm = LocaleViewModel(storage: storage);
      themeVm = ThemeViewModel(storage: storage);
      syncService = SyncService(storage);
    });

    Widget createTestWidget({Locale locale = const Locale('en')}) {
      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
      final expenseRepo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
      final personalRepo = PersonalRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
      final homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
      final personalVm = PersonalExpenseViewModel(personalRepo: personalRepo);

      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authVm),
          ChangeNotifierProvider.value(value: localeVm),
          ChangeNotifierProvider.value(value: themeVm),
          ChangeNotifierProvider.value(value: homeVm),
          ChangeNotifierProvider.value(value: personalVm),
          Provider<SyncService>.value(value: syncService),
          Provider<ApiClient>.value(value: apiClient),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLanguage.values.map((l) => l.locale).toList(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const OnboardingView(),
        ),
      );
    }

    testWidgets('1. Renders premium hero composition with brand mark and tagline', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('KITH'), findsOneWidget);
      expect(find.byType(KithHeroScene), findsOneWidget);
      expect(find.byType(KithGoogleAuthButton), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Explore as Guest'), findsOneWidget);
      expect(find.text('Restore with Recovery Key'), findsOneWidget);
    });

    testWidgets('2. Tapping Explore as Guest opens GuestSetupSheet', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 600));

      final guestBtn = find.text('Explore as Guest');
      expect(guestBtn, findsOneWidget);

      await tester.ensureVisible(guestBtn);
      await tester.tap(guestBtn);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(GuestSetupSheet), findsOneWidget);
      expect(find.text('Explore Kith as Guest'), findsOneWidget);
      expect(find.text('Start Exploring'), findsOneWidget);
    });

    testWidgets('3. Tapping Restore with Recovery Key opens RecoveryKeySheet', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 600));

      final recoveryLink = find.text('Restore with Recovery Key');
      expect(recoveryLink, findsOneWidget);

      await tester.ensureVisible(recoveryLink);
      await tester.tap(recoveryLink);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(RecoveryKeySheet), findsOneWidget);
      expect(find.text('Restore Your Account'), findsOneWidget);
      expect(find.text('Restore Account'), findsOneWidget);
    });

    testWidgets('4. Multilingual test in Hindi and Gujarati renders cleanly without error', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Test Hindi
      await tester.pumpWidget(createTestWidget(locale: const Locale('hi')));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Google के साथ आगे बढ़ें'), findsOneWidget);
      expect(find.text('अतिथि के रूप में एक्सप्लोर करें'), findsOneWidget);
      expect(find.text('रिकवरी की से खाता वापस लाएं'), findsOneWidget);

      // Test Gujarati
      await tester.pumpWidget(createTestWidget(locale: const Locale('gu')));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Google સાથે ચાલુ રાખો'), findsOneWidget);
      expect(find.text('મહેમાન તરીકે શરૂ કરો'), findsOneWidget);
      expect(find.text('રિકવરી કી વડે એકાઉન્ટ પાછું મેળવો'), findsOneWidget);
    });
  });
}
