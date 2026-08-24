import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local offline persistence service.
/// Uses SharedPreferences with structured JSON serialization to ensure zero data loss
/// and instant cold start without network latency.
class LocalStorageService {
  static const String _userKey = 'kith_guest_user';
  static const String _tripsKey = 'kith_trips';
  static const String _expensesPrefix = 'kith_expenses_';
  static const String _mutationQueueKey = 'kith_sync_mutations';
  static const String _themeModeKey = 'kith_theme_mode';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  // --- User Session ---
  Map<String, dynamic>? getSavedUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveUser(Map<String, dynamic> userJson) async {
    return _prefs.setString(_userKey, jsonEncode(userJson));
  }

  Future<bool> clearUser() async {
    return _prefs.remove(_userKey);
  }

  // --- Trips ---
  List<Map<String, dynamic>> getSavedTrips() {
    final raw = _prefs.getString(_tripsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveTrips(List<Map<String, dynamic>> tripsJson) async {
    return _prefs.setString(_tripsKey, jsonEncode(tripsJson));
  }

  // --- Expenses for Trip ---
  List<Map<String, dynamic>> getSavedExpenses(String tripId) {
    final raw = _prefs.getString('$_expensesPrefix$tripId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveExpenses(String tripId, List<Map<String, dynamic>> expensesJson) async {
    return _prefs.setString('$_expensesPrefix$tripId', jsonEncode(expensesJson));
  }

  // --- Mutation Queue ---
  List<Map<String, dynamic>> getMutationQueue() {
    final raw = _prefs.getString(_mutationQueueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveMutationQueue(List<Map<String, dynamic>> queue) async {
    return _prefs.setString(_mutationQueueKey, jsonEncode(queue));
  }

  // --- Theme Mode ---
  String? getSavedThemeMode() {
    return _prefs.getString(_themeModeKey);
  }

  Future<bool> saveThemeMode(String mode) async {
    return _prefs.setString(_themeModeKey, mode);
  }

  // --- Personal Expenses ---
  static const String _personalExpensesKey = 'kith_personal_expenses';
  static const String _personalDebtsKey = 'kith_personal_debts';
  static const String _personalBudgetKeyPrefix = 'kith_personal_budget_';

  List<Map<String, dynamic>> getSavedPersonalExpenses() {
    final raw = _prefs.getString(_personalExpensesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> savePersonalExpenses(List<Map<String, dynamic>> expensesJson) async {
    return _prefs.setString(_personalExpensesKey, jsonEncode(expensesJson));
  }

  // --- Personal Debts (Lending / Borrowing) ---
  List<Map<String, dynamic>> getSavedPersonalDebts() {
    final raw = _prefs.getString(_personalDebtsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> savePersonalDebts(List<Map<String, dynamic>> debtsJson) async {
    return _prefs.setString(_personalDebtsKey, jsonEncode(debtsJson));
  }

  // --- Personal Budget ---
  Map<String, dynamic>? getSavedPersonalBudget(String monthYear) {
    final raw = _prefs.getString('$_personalBudgetKeyPrefix$monthYear');
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> savePersonalBudget(String monthYear, Map<String, dynamic> budgetJson) async {
    return _prefs.setString('$_personalBudgetKeyPrefix$monthYear', jsonEncode(budgetJson));
  }
}
