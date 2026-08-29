import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/translations/as.dart';
import 'package:kith_app/core/localization/translations/bn.dart';
import 'package:kith_app/core/localization/translations/en.dart';
import 'package:kith_app/core/localization/translations/gu.dart';
import 'package:kith_app/core/localization/translations/hi.dart';
import 'package:kith_app/core/localization/translations/ja.dart';
import 'package:kith_app/core/localization/translations/kn.dart';
import 'package:kith_app/core/localization/translations/ko.dart';
import 'package:kith_app/core/localization/translations/ml.dart';
import 'package:kith_app/core/localization/translations/mr.dart';
import 'package:kith_app/core/localization/translations/or.dart';
import 'package:kith_app/core/localization/translations/pa.dart';
import 'package:kith_app/core/localization/translations/ta.dart';
import 'package:kith_app/core/localization/translations/te.dart';
import 'package:kith_app/core/localization/translations/zh.dart';

void main() {
  group('Localization Completeness Tests', () {
    test('enTranslations should have comprehensive key inventory', () {
      expect(enTranslations.isNotEmpty, isTrue);
      expect(enTranslations.length, greaterThanOrEqualTo(100));
    });

    final languages = <String, Map<String, String>>{
      'Hindi (hi.dart)': hiTranslations,
      'Gujarati (gu.dart)': guTranslations,
      'Marathi (mr.dart)': mrTranslations,
      'Tamil (ta.dart)': taTranslations,
      'Telugu (te.dart)': teTranslations,
      'Kannada (kn.dart)': knTranslations,
      'Bengali (bn.dart)': bnTranslations,
      'Punjabi (pa.dart)': paTranslations,
      'Assamese (as.dart)': asTranslations,
      'Odia (or.dart)': orTranslations,
      'Malayalam (ml.dart)': mlTranslations,
      'Chinese (zh.dart)': zhTranslations,
      'Japanese (ja.dart)': jaTranslations,
      'Korean (ko.dart)': koTranslations,
    };

    for (final entry in languages.entries) {
      test('${entry.key} must contain ALL keys from enTranslations with non-empty values', () {
        final missingKeys = <String>[];
        final emptyKeys = <String>[];

        for (final key in enTranslations.keys) {
          if (!entry.value.containsKey(key)) {
            missingKeys.add(key);
          } else if (entry.value[key] == null || entry.value[key]!.trim().isEmpty) {
            emptyKeys.add(key);
          }
        }

        expect(missingKeys, isEmpty, reason: 'Missing keys in ${entry.key}: $missingKeys');
        expect(emptyKeys, isEmpty, reason: 'Empty values in ${entry.key}: $emptyKeys');
      });
    }
  });
}
