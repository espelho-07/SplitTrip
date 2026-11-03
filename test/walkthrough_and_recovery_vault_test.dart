import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/presentation/views/onboarding/walkthrough_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Walkthrough & Recovery Vault Tests', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
    });

    test('1. Recovery Vault saves and retrieves user by normalized recovery key', () async {
      final user = GuestUser(
        id: 'usr_vault_test',
        displayName: 'Darpan Parmar',
        recoveryKey: 'KITH-AB12-CD34',
        anonymousToken: 'sess_123',
        createdAt: DateTime.now(),
      );

      await storage.saveUser(user.toJson());

      // Retrieve via exact key
      final found1 = storage.getUserByRecoveryKey('KITH-AB12-CD34');
      expect(found1, isNotNull);
      expect(found1!['displayName'], 'Darpan Parmar');

      // Retrieve via lowercase / stripped key
      final found2 = storage.getUserByRecoveryKey('ab12cd34');
      expect(found2, isNotNull);
      expect(found2!['id'], 'usr_vault_test');

      // Retrieve via space-separated key
      final found3 = storage.getUserByRecoveryKey('AB12-CD34');
      expect(found3, isNotNull);
      expect(found3!['id'], 'usr_vault_test');
    });

    test('2. AuthService.normalizeRecoveryKey normalizes raw keys accurately', () {
      expect(AuthService.normalizeRecoveryKey('kith-1234-5678'), 'KITH-1234-5678');
      expect(AuthService.normalizeRecoveryKey('12345678'), 'KITH-1234-5678');
      expect(AuthService.normalizeRecoveryKey(' 1234-5678 '), 'KITH-1234-5678');
      expect(AuthService.normalizeRecoveryKey('KITH 1234 5678'), 'KITH-1234-5678');
      expect(AuthService.normalizeRecoveryKey(''), '');
    });

    test('3. GuestUser.fromJson never produces null or dummy recovery keys', () {
      final jsonWithoutKey = {
        'id': 'usr_no_key',
        'displayName': 'Traveler',
        'anonymousToken': 'token_abc',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final user = GuestUser.fromJson(jsonWithoutKey);
      expect(user.recoveryKey.startsWith('KITH-'), isTrue);
      expect(user.recoveryKey.length, 14); // KITH-XXXX-YYYY
    });

    testWidgets('4. WalkthroughView renders Slide 1, allows swiping to Slide 2 & 3', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 2400));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<LocalStorageService>.value(value: storage),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [
              Locale('en'),
              Locale('hi'),
              Locale('gu'),
            ],
            home: WalkthroughView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header and Slide 1 Content
      expect(find.text('KITH'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('SMART GROUP EXPENSES'), findsOneWidget);
      expect(find.textContaining('Split Trips'), findsOneWidget);
      expect(find.text('Continue →'), findsOneWidget);

      // Tap Continue -> advances to Slide 2
      await tester.tap(find.text('Continue →'));
      await tester.pumpAndSettle();

      expect(find.text('OFFLINE P2P RADAR'), findsOneWidget);
      expect(find.text('Nearby Friends &\nOffline P2P Sync'), findsOneWidget);

      // Tap Continue -> advances to Slide 3
      await tester.tap(find.text('Continue →'));
      await tester.pumpAndSettle();

      expect(find.text('INSTANT UPI PAYMENTS'), findsOneWidget);
      expect(find.textContaining('1-Tap UPI Settlements'), findsOneWidget);
      expect(find.text('Start Exploring Kith →'), findsOneWidget);
    });
  });
}
