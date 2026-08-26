import 'package:flutter/material.dart';
import '../../core/localization/app_language.dart';
import '../../data/services/local_storage_service.dart';

/// ViewModel managing reactive application locale and language persistence.
class LocaleViewModel extends ChangeNotifier {
  final LocalStorageService storage;
  AppLanguage _currentLanguage = AppLanguage.english;
  bool _hasSelectedInitialLanguage = false;

  LocaleViewModel({required this.storage}) {
    _loadPersistedLanguage();
  }

  AppLanguage get currentLanguage => _currentLanguage;
  Locale get locale => _currentLanguage.locale;
  bool get hasSelectedInitialLanguage => _hasSelectedInitialLanguage;

  void _loadPersistedLanguage() {
    final savedCode = storage.getSavedLanguage();
    if (savedCode != null && savedCode.isNotEmpty) {
      _currentLanguage = AppLanguage.fromCode(savedCode);
    }
    _hasSelectedInitialLanguage = storage.hasSelectedInitialLanguage();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    _hasSelectedInitialLanguage = true;
    await storage.saveLanguage(language.code);
    await storage.setHasSelectedInitialLanguage(true);
    notifyListeners();
  }

  Future<void> markInitialLanguageSelected() async {
    _hasSelectedInitialLanguage = true;
    await storage.setHasSelectedInitialLanguage(true);
    notifyListeners();
  }
}
