import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/locale_viewmodel.dart';
import 'package:kith_app/presentation/views/onboarding/onboarding_view.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late AuthViewModel authVm;
  late LocaleViewModel localeVm;
  late KithWidgetService widgetService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    apiClient = ApiClient(httpClient: MockClient((req) async => throw const SocketException("No Internet")));
    final authService = AuthService(apiClient: apiClient, storage: storage);
    final userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);
    localeVm = LocaleViewModel(storage: storage);
    await localeVm.markInitialLanguageSelected();
    widgetService = KithWidgetService(storage: storage);
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

  group('Original Kith Login & Welcome Experience Tests', () {
    testWidgets('1. Renders brand mark, headline, subtitle, and interactive scene', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createOnboardingScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('KITH'), findsOneWidget);
      expect(find.textContaining('Your money'), findsOneWidget);
    });

    testWidgets('2. Renders Continue as Guest and Recover using Kith Recovery Key (Zero Google Auth)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createOnboardingScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.text('Recover using Kith Recovery Key'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('3. Tapping Continue as Guest opens name input sheet and creates guest session', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createOnboardingScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(authVm.isAuthenticated, isFalse);
      await tester.tap(find.text('Continue as Guest'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // GuestSetupSheet should be shown with name input
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Darpan');
      await tester.pump();

      // Tap CTA to start
      await tester.tap(find.text('Start Exploring'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(authVm.isAuthenticated, isTrue);
      expect(authVm.currentUser, isNotNull);
      expect(authVm.currentUser!.displayName, equals('Darpan'));
    });
  });
}
