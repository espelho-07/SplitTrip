import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_language.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/create_trip_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/locale_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/theme_viewmodel.dart';
import 'package:kith_app/presentation/views/home/widgets/profile_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0 Regression Recovery & Stabilization', () {
    late LocalStorageService storage;
    late UserRepository userRepo;
    late AuthViewModel authVm;
    late LocaleViewModel localeVm;
    late ThemeViewModel themeVm;
    late CreateTripViewModel createVm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      final apiClient = ApiClient();
      final authService = AuthService(apiClient: apiClient, storage: storage);
      userRepo = UserRepository(authService: authService);
      authVm = AuthViewModel(userRepo: userRepo);
      localeVm = LocaleViewModel(storage: storage);
      themeVm = ThemeViewModel(storage: storage);
      final syncService = SyncService(storage);
      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );
      createVm = CreateTripViewModel(tripRepo: tripRepo);
    });

    testWidgets('MaterialApp supports Gujarati and Hindi without throwing missing localization errors', (tester) async {
      for (final lang in AppLanguage.values) {
        await tester.pumpWidget(
          MaterialApp(
            locale: lang.locale,
            supportedLocales: AppLanguage.values.map((l) => l.locale).toList(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) {
                final l10n = context.l10n;
                return Scaffold(
                  body: Column(
                    children: [
                      Text(l10n.languageSelectTitle),
                      Text(l10n.tabExpense),
                      Text(l10n.tabTrips),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('ProfileSheet renders gracefully when user is null (guest/uninitialized)', (tester) async {
      final syncService = SyncService(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authVm),
            ChangeNotifierProvider.value(value: localeVm),
            ChangeNotifierProvider.value(value: themeVm),
            Provider<SyncService>.value(value: syncService),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: ProfileSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Traveler'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    test('CreateTripViewModel resetForm clears state completely', () {
      createVm.setName('Goa Roadtrip');
      createVm.addFriendName('Alice');
      createVm.addFriendName('Bob');
      expect(createVm.name, equals('Goa Roadtrip'));
      expect(createVm.friendNames.length, equals(2));
      expect(createVm.isValid, isTrue);

      createVm.reset();
      expect(createVm.name, isEmpty);
      expect(createVm.friendNames, isEmpty);
      expect(createVm.isValid, isFalse);
    });

    test('AppLocalizations delegate accepts any locale and resolves to fallback', () {
      final locEn = AppLocalizations(const Locale('en', 'US'));
      expect(locEn.tabExpense, equals('Expense'));

      final locHi = AppLocalizations(const Locale('hi', 'IN'));
      expect(locHi.tabExpense, equals('खर्च'));

      final locGu = AppLocalizations(const Locale('gu', 'IN'));
      expect(locGu.tabExpense, equals('ખર્ચ'));

      final locUnknown = AppLocalizations(const Locale('fr', 'FR'));
      expect(locUnknown.tabExpense, equals('Expense'));
    });
  });
}
