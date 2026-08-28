import 'package:flutter/material.dart';
import '../../data/services/local_storage_service.dart';

class ThemeViewModel extends ChangeNotifier {
  final LocalStorageService storage;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeViewModel({required this.storage}) {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void _loadTheme() {
    final saved = storage.getSavedThemeMode();
    if (saved != null) {
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.light;
      }
      notifyListeners();
    } else {
      _themeMode = ThemeMode.light;
    }
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    storage.saveThemeMode(mode.name);
    notifyListeners();
  }
}
