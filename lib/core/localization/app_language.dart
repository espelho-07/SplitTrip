import 'package:flutter/material.dart';

/// Supported application languages in Kith.
enum AppLanguage {
  english(
    code: 'en',
    nativeName: 'English',
    englishName: 'English',
    flagEmoji: '🇬🇧',
  ),
  hindi(
    code: 'hi',
    nativeName: 'हिन्दी',
    englishName: 'Hindi',
    flagEmoji: '🇮🇳',
  ),
  gujarati(
    code: 'gu',
    nativeName: 'ગુજરાતી',
    englishName: 'Gujarati',
    flagEmoji: '🇮🇳',
  );

  final String code;
  final String nativeName;
  final String englishName;
  final String flagEmoji;

  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.flagEmoji,
  });

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.english;
    return AppLanguage.values.firstWhere(
      (lang) => lang.code.toLowerCase() == code.toLowerCase(),
      orElse: () => AppLanguage.english,
    );
  }
}
