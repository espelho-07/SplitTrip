import 'package:flutter/material.dart';

/// Grouping categories for language presentation in selectors
enum LanguageCategory {
  indic,
  eastAsian,
}

/// Supported application languages in Kith.
enum AppLanguage {
  // Indian & Regional Languages
  english(
    code: 'en',
    nativeName: 'English',
    englishName: 'English',
    category: LanguageCategory.indic,
  ),
  hindi(
    code: 'hi',
    nativeName: 'हिन्दी',
    englishName: 'Hindi',
    category: LanguageCategory.indic,
  ),
  gujarati(
    code: 'gu',
    nativeName: 'ગુજરાતી',
    englishName: 'Gujarati',
    category: LanguageCategory.indic,
  ),
  marathi(
    code: 'mr',
    nativeName: 'मराठी',
    englishName: 'Marathi',
    category: LanguageCategory.indic,
  ),
  tamil(
    code: 'ta',
    nativeName: 'தமிழ்',
    englishName: 'Tamil',
    category: LanguageCategory.indic,
  ),
  telugu(
    code: 'te',
    nativeName: 'తెలుగు',
    englishName: 'Telugu',
    category: LanguageCategory.indic,
  ),
  kannada(
    code: 'kn',
    nativeName: 'ಕನ್ನಡ',
    englishName: 'Kannada',
    category: LanguageCategory.indic,
  ),
  bengali(
    code: 'bn',
    nativeName: 'বাংলা',
    englishName: 'Bengali',
    category: LanguageCategory.indic,
  ),
  punjabi(
    code: 'pa',
    nativeName: 'ਪੰਜਾਬੀ',
    englishName: 'Punjabi',
    category: LanguageCategory.indic,
  ),
  assamese(
    code: 'as',
    nativeName: 'অসমীয়া',
    englishName: 'Assamese',
    category: LanguageCategory.indic,
  ),
  odia(
    code: 'or',
    nativeName: 'ଓଡ଼ିଆ',
    englishName: 'Odia',
    category: LanguageCategory.indic,
  ),
  malayalam(
    code: 'ml',
    nativeName: 'മലയാളം',
    englishName: 'Malayalam',
    category: LanguageCategory.indic,
  ),

  // East Asian Languages
  chinese(
    code: 'zh',
    nativeName: '中文',
    englishName: 'Chinese (Simplified)',
    category: LanguageCategory.eastAsian,
  ),
  japanese(
    code: 'ja',
    nativeName: '日本語',
    englishName: 'Japanese',
    category: LanguageCategory.eastAsian,
  ),
  korean(
    code: 'ko',
    nativeName: '한국어',
    englishName: 'Korean',
    category: LanguageCategory.eastAsian,
  );

  final String code;
  final String nativeName;
  final String englishName;
  final LanguageCategory category;

  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.category,
  });

  Locale get locale => Locale(code);

  bool matchesQuery(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase().trim();
    return nativeName.toLowerCase().contains(q) ||
        englishName.toLowerCase().contains(q) ||
        code.toLowerCase().contains(q);
  }

  static List<AppLanguage> get indicLanguages =>
      AppLanguage.values.where((l) => l.category == LanguageCategory.indic).toList();

  static List<AppLanguage> get eastAsianLanguages =>
      AppLanguage.values.where((l) => l.category == LanguageCategory.eastAsian).toList();

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.english;
    return AppLanguage.values.firstWhere(
      (lang) => lang.code.toLowerCase() == code.toLowerCase(),
      orElse: () => AppLanguage.english,
    );
  }
}
