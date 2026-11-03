import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/theme/app_theme.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/theme_viewmodel.dart';
import 'package:kith_app/presentation/views/onboarding/widgets/recovery_key_sheet.dart';
import 'package:kith_app/presentation/views/profile/profile_home_tab.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late AuthService authService;
  late UserRepository userRepo;
  late AuthViewModel authVm;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late HomeViewModel homeVm;
  late SyncService syncService;
  late ThemeViewModel themeVm;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    apiClient = ApiClient();
    authService = AuthService(storage: storage, apiClient: apiClient);
    userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);
    syncService = SyncService(storage);
    tripRepo = TripRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    expenseRepo = ExpenseRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
    themeVm = ThemeViewModel(storage: storage);
  });

  group('Guest Profile Naming & Recovery Key Tests', () {
    test('1. Guest account has clean Profile & Identity title and Edit Profile button text', () {
      final guest = GuestUser(
        id: 'usr_guest_123',
        displayName: 'Aarav Mehta',
        recoveryKey: 'KITH-7K4M-9P2R',
        anonymousToken: 'kith_sess_123',
        createdAt: DateTime.now(),
        isLinkedToAccount: false,
      );

      expect(guest.isGuest, isTrue);
      expect(guest.isNirniqLinked, isFalse);

      final enL10n = AppLocalizations(const Locale('en'));
      expect(enL10n.profileIdentityTitle, equals('Profile & Identity'));
      expect(enL10n.profileEditProfileBtn, equals('Edit Profile'));
      expect(enL10n.profileSecCloudTitle, equals('Account & Cloud Sync'));
    });

    test('2. AuthService.normalizeRecoveryKey normalizes all formats without truncation', () {
      expect(AuthService.normalizeRecoveryKey('KITH-7K4M-9P2R'), equals('KITH-7K4M-9P2R'));
      expect(AuthService.normalizeRecoveryKey('7k4m-9p2r'), equals('KITH-7K4M-9P2R'));
      expect(AuthService.normalizeRecoveryKey('7K4M 9P2R'), equals('KITH-7K4M-9P2R'));
      expect(AuthService.normalizeRecoveryKey('7k4m9p2r'), equals('KITH-7K4M-9P2R'));
      expect(AuthService.normalizeRecoveryKey('kith_7k4m_9p2r'), equals('KITH-7K4M-9P2R'));
      expect(AuthService.normalizeRecoveryKey('KITH:7K4M:9P2R'), equals('KITH-7K4M-9P2R'));
      expect(AuthService.normalizeRecoveryKey('kith-aaaa-bbbb-cccc'), equals('KITH-AAAA-BBBB-CCCC'));
    });

    test('3. Recovery Key restores guest user session from local recovery vault', () async {
      // 1. Create a guest user
      final original = await authVm.createGuestSession('Rohan Sharma');
      final originalKey = original.recoveryKey;
      expect(originalKey, isNotEmpty);

      // 2. Clear current session to simulate reinstall / new device state
      await storage.clearUser();
      expect(storage.getSavedUser(), isNull);

      // 3. Restore session using lowercase un-hyphenated key
      final cleanRawKey = originalKey.replaceAll('KITH-', '').toLowerCase();
      final restored = await authVm.recoverSession(cleanRawKey);

      expect(restored, isNotNull);
      expect(restored!.id, equals(original.id));
      expect(restored.displayName, equals('Rohan Sharma'));
      expect(authVm.isAuthenticated, isTrue);
      expect(authVm.currentUser?.id, equals(original.id));
    });

    testWidgets('4. RecoveryKeySheet does NOT render any reviewer button or reviewer email', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authVm),
            ChangeNotifierProvider.value(value: homeVm),
            Provider.value(value: syncService),
            Provider.value(value: apiClient),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: RecoveryKeySheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restore Account'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('review.nirniq@gmail.com'), findsNothing);
      expect(find.textContaining('Reviewer Demo Access'), findsNothing);
    });

    testWidgets('5. ProfileHomeTab renders Profile & Identity and Restore Account options for guest', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final guest = GuestUser(
        id: 'usr_guest_priya',
        displayName: 'Priya Patel',
        recoveryKey: 'KITH-7K4M-9P2R',
        anonymousToken: 'kith_sess_priya',
        createdAt: DateTime.now(),
        isLinkedToAccount: false,
      );
      await storage.saveUser(guest.toJson());
      await authVm.initSession();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authVm),
            ChangeNotifierProvider.value(value: homeVm),
            Provider.value(value: syncService),
            ChangeNotifierProvider.value(value: themeVm),
            Provider.value(value: storage),
            Provider.value(value: apiClient),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: ProfileHomeTab(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('Guest Account'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
      expect(find.text('Restore Your Account'), findsOneWidget);
    });
  });
}
