import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/translations/en.dart';
import 'package:kith_app/core/localization/translations/gu.dart';
import 'package:kith_app/core/localization/translations/hi.dart';

void main() {
  group('Localization Completeness Tests', () {
    test('enTranslations should have comprehensive key inventory', () {
      expect(enTranslations.isNotEmpty, isTrue);
      expect(enTranslations.length, greaterThanOrEqualTo(100));
    });

    test('guTranslations must contain ALL keys from enTranslations with non-empty values', () {
      final missingKeys = <String>[];
      final emptyKeys = <String>[];

      for (final key in enTranslations.keys) {
        if (!guTranslations.containsKey(key)) {
          missingKeys.add(key);
        } else if (guTranslations[key] == null || guTranslations[key]!.trim().isEmpty) {
          emptyKeys.add(key);
        }
      }

      expect(missingKeys, isEmpty, reason: 'Missing keys in Gujarati (gu.dart): $missingKeys');
      expect(emptyKeys, isEmpty, reason: 'Empty values in Gujarati (gu.dart): $emptyKeys');
    });

    test('hiTranslations must contain ALL keys from enTranslations with non-empty values', () {
      final missingKeys = <String>[];
      final emptyKeys = <String>[];

      for (final key in enTranslations.keys) {
        if (!hiTranslations.containsKey(key)) {
          missingKeys.add(key);
        } else if (hiTranslations[key] == null || hiTranslations[key]!.trim().isEmpty) {
          emptyKeys.add(key);
        }
      }

      expect(missingKeys, isEmpty, reason: 'Missing keys in Hindi (hi.dart): $missingKeys');
      expect(emptyKeys, isEmpty, reason: 'Empty values in Hindi (hi.dart): $emptyKeys');
    });
  });
}
