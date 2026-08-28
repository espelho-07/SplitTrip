import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/security_lock_service.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/views/security/app_lock_screen.dart';
import 'package:kith_app/presentation/views/security/set_pin_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SecurityLockService securityService;
  late AuthViewModel authVm;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    securityService = SecurityLockService(storage);
    final apiClient = ApiClient();
    final authService = AuthService(apiClient: apiClient, storage: storage);
    final userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);
    await authVm.createGuestSession('Darpan Parmar');
  });

  Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: securityService),
        ChangeNotifierProvider.value(value: authVm),
        Provider.value(value: storage),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('gu')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }

  group('SecurityLockService Unit Tests', () {
    test('1. Setting and verifying 4-digit PIN works with SHA-256 hashing', () async {
      expect(securityService.hasPin, isFalse);
      expect(securityService.isAppLockEnabled, isFalse);

      final ok = await securityService.setPin('1234');
      expect(ok, isTrue);
      expect(securityService.hasPin, isTrue);
      expect(securityService.isAppLockEnabled, isTrue);

      // Verify PIN
      expect(securityService.verifyPin('9999'), isFalse);
      expect(securityService.verifyPin('1234'), isTrue);
    });

    test('2. Reset PIN with offline recovery key succeeds', () async {
      await securityService.setPin('1111');
      expect(securityService.verifyPin('1111'), isTrue);

      const actualKey = 'KITH-SEC-1234-5678';
      final resetOk = await securityService.resetPinWithRecoveryKey(
        enteredKey: 'kith-sec-1234-5678',
        actualRecoveryKey: actualKey,
        newPin: '5678',
      );

      expect(resetOk, isTrue);
      expect(securityService.verifyPin('5678'), isTrue);
      expect(securityService.verifyPin('1111'), isFalse);
    });

    test('3. Lock and unlock states behave deterministically', () async {
      await securityService.setPin('4321');
      securityService.lock();
      expect(securityService.isLocked, isTrue);

      securityService.unlock();
      expect(securityService.isLocked, isFalse);
    });
  });

  group('AppLockScreen Widget Suite', () {
    testWidgets('1. Renders obsidian vault lock screen and numeric keypad', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await securityService.setPin('1234');
      securityService.lock();

      await tester.pumpWidget(wrapWithProviders(const AppLockScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Kith Vault'), findsOneWidget);
      expect(find.text('Enter your 4-digit security PIN'), findsOneWidget);
      expect(find.text('Forgot PIN? Use Recovery Key'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('2. Entering correct PIN unlocks vault', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await securityService.setPin('2580');
      securityService.lock();

      await tester.pumpWidget(wrapWithProviders(const AppLockScreen()));
      await tester.pumpAndSettle();

      expect(securityService.isLocked, isTrue);

      // Tap 2, 5, 8, 0
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();

      expect(securityService.isLocked, isFalse);
    });

    testWidgets('3. Entering wrong PIN shows error feedback', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await securityService.setPin('9999');
      securityService.lock();

      await tester.pumpWidget(wrapWithProviders(const AppLockScreen()));
      await tester.pumpAndSettle();

      // Tap 1, 2, 3, 4
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      expect(securityService.isLocked, isTrue);
      expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
    });
  });

  group('SetPinSheet Widget Suite', () {
    testWidgets('1. Renders 2-step setup PIN and confirm PIN flow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool pinSetDone = false;

      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: SetPinSheet(
              onPinSet: () {
                pinSetDone = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create 4-Digit Security PIN'), findsOneWidget);
      expect(find.text('This PIN protects your Kith offline vault on launch'), findsOneWidget);

      // Enter Step 1 PIN: 7, 7, 7, 7
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('7'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // Step 2: Confirm PIN
      expect(find.text('Confirm 4-Digit PIN'), findsOneWidget);

      // Enter Step 2 PIN: 7, 7, 7, 7
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('7'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(pinSetDone, isTrue);
      expect(securityService.hasPin, isTrue);
      expect(securityService.verifyPin('7777'), isTrue);
    });
  });
}
