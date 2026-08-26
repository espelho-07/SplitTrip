import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_language.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/localization/translations/en.dart';
import 'package:kith_app/core/localization/translations/gu.dart';
import 'package:kith_app/core/localization/translations/hi.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/presentation/viewmodels/locale_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multilingual Translation Dictionaries', () {
    test('English dictionary contains all required core keys', () {
      expect(enTranslations['language_select_title'], isNotEmpty);
      expect(enTranslations['onboarding_title'], isNotEmpty);
      expect(enTranslations['tab_expense'], isNotEmpty);
      expect(enTranslations['tab_trips'], isNotEmpty);
      expect(enTranslations['personal_add_expense'], isNotEmpty);
      expect(enTranslations['trips_create'], isNotEmpty);
      expect(enTranslations['trips_join'], isNotEmpty);
      expect(enTranslations['auth_sign_out'], isNotEmpty);
      expect(enTranslations['guide_title'], isNotEmpty);
    });

    test('Hindi dictionary matches English key completeness', () {
      for (final key in enTranslations.keys) {
        expect(
          hiTranslations.containsKey(key),
          isTrue,
          reason: 'Missing Hindi translation for key: $key',
        );
        expect(
          hiTranslations[key],
          isNotEmpty,
          reason: 'Empty Hindi translation for key: $key',
        );
      }
    });

    test('Gujarati dictionary matches English key completeness', () {
      for (final key in enTranslations.keys) {
        expect(
          guTranslations.containsKey(key),
          isTrue,
          reason: 'Missing Gujarati translation for key: $key',
        );
        expect(
          guTranslations[key],
          isNotEmpty,
          reason: 'Empty Gujarati translation for key: $key',
        );
      }
    });

    test('AppLanguage.fromCode resolves correctly and defaults to English', () {
      expect(AppLanguage.fromCode('en'), equals(AppLanguage.english));
      expect(AppLanguage.fromCode('EN'), equals(AppLanguage.english));
      expect(AppLanguage.fromCode('hi'), equals(AppLanguage.hindi));
      expect(AppLanguage.fromCode('HI'), equals(AppLanguage.hindi));
      expect(AppLanguage.fromCode('gu'), equals(AppLanguage.gujarati));
      expect(AppLanguage.fromCode('GU'), equals(AppLanguage.gujarati));
      expect(AppLanguage.fromCode('fr'), equals(AppLanguage.english));
      expect(AppLanguage.fromCode(null), equals(AppLanguage.english));
    });

    test('AppLocalizations falls back to English when key is missing in custom map', () {
      final loc = AppLocalizations(const Locale('en'));
      expect(loc.translate('non_existent_key_xyz'), equals('non_existent_key_xyz'));
      expect(loc.tabExpense, equals('Expense'));

      final hiLoc = AppLocalizations(const Locale('hi'));
      expect(hiLoc.tabExpense, equals('खर्च'));

      final guLoc = AppLocalizations(const Locale('gu'));
      expect(guLoc.tabExpense, equals('ખર્ચ'));
    });
  });

  group('LocaleViewModel & Language Persistence', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
    });

    test('Loads default English when nothing saved', () {
      final vm = LocaleViewModel(storage: storage);
      expect(vm.currentLanguage, equals(AppLanguage.english));
      expect(vm.locale.languageCode, equals('en'));
      expect(vm.hasSelectedInitialLanguage, isFalse);
    });

    test('Persists language choice across restarts and updates state', () async {
      final vm = LocaleViewModel(storage: storage);
      await vm.setLanguage(AppLanguage.hindi);

      expect(vm.currentLanguage, equals(AppLanguage.hindi));
      expect(vm.locale.languageCode, equals('hi'));
      expect(vm.hasSelectedInitialLanguage, isTrue);
      expect(storage.getSavedLanguage(), equals('hi'));
      expect(storage.hasSelectedInitialLanguage(), isTrue);

      // Simulate app cold restart
      final vm2 = LocaleViewModel(storage: storage);
      expect(vm2.currentLanguage, equals(AppLanguage.hindi));
      expect(vm2.hasSelectedInitialLanguage, isTrue);
    });

    test('clearAllUserData preserves device-level language and theme preferences', () async {
      await storage.saveLanguage('gu');
      await storage.saveThemeMode('dark');
      await storage.saveUser({'id': 'u123', 'displayName': 'Alice'});

      expect(storage.getSavedLanguage(), equals('gu'));
      expect(storage.getSavedUser(), isNotNull);

      await storage.clearAllUserData();

      // User session wiped
      expect(storage.getSavedUser(), isNull);

      // Device preferences preserved
      expect(storage.getSavedLanguage(), equals('gu'));
      expect(storage.getSavedThemeMode(), equals('dark'));
    });
  });
}
