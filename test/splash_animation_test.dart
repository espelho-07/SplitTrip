import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/locale_viewmodel.dart';
import 'package:kith_app/presentation/views/splash/splash_view.dart';
import 'package:provider/provider.dart';
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
    apiClient = ApiClient();
    final authService = AuthService(apiClient: apiClient, storage: storage);
    final userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);
    localeVm = LocaleViewModel(storage: storage);
    widgetService = KithWidgetService(storage: storage);
  });

  Widget createSplashScreen() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashView(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const Scaffold(body: Text('Onboarding View')),
        ),
        GoRoute(
          path: '/language-select',
          builder: (context, state) => const Scaffold(body: Text('Language Select View')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home View')),
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: localeVm),
        ChangeNotifierProvider.value(value: widgetService),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }

  group('Cinematic Splash Screen & Tagline Animation Suite', () {
    testWidgets('1. Renders Official Logo, Kith Wordmark, by Nirniq, and 4-Pillar Tagline: CREATE. SPLIT. TRACK. SETTLE.', (tester) async {
      await tester.pumpWidget(createSplashScreen());
      await tester.pump(); // Initial frame
      await tester.pump(const Duration(milliseconds: 600)); // Advance animation

      expect(find.text('Kith'), findsOneWidget);
      expect(find.text('CREATE.'), findsOneWidget);
      expect(find.text('SPLIT.'), findsOneWidget);
      expect(find.text('TRACK.'), findsOneWidget);
      expect(find.text('SETTLE.'), findsOneWidget);
      expect(find.text('by Nirniq'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3)); // Complete splash timer
      await tester.pumpAndSettle();
    });
  });
}
