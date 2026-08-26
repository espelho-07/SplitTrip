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

  // --- Generic Helpers ---
  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);
  bool? getBool(String key) => _prefs.getBool(key);
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);
  Future<bool> remove(String key) => _prefs.remove(key);

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

  // --- Trip Activity Logs ---
  static const String _activityLogsPrefix = 'kith_activity_';

  List<Map<String, dynamic>> getSavedActivityLogs(String tripId) {
    final raw = _prefs.getString('$_activityLogsPrefix$tripId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveActivityLogs(String tripId, List<Map<String, dynamic>> logsJson) async {
    return _prefs.setString('$_activityLogsPrefix$tripId', jsonEncode(logsJson));
  }

  // --- Custom Server URL ---
  static const String _customServerUrlKey = 'kith_custom_server_url';

  String? getSavedServerUrl() {
    return _prefs.getString(_customServerUrlKey);
  }

  Future<bool> saveServerUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      return _prefs.remove(_customServerUrlKey);
    }
    return _prefs.setString(_customServerUrlKey, url.trim());
  }

  // --- App Experience Mode (Trips Only vs All Modules) ---
  static const String _appExperienceModeKey = 'kith_app_experience_mode';

  String? getSavedAppExperienceMode() {
    return _prefs.getString(_appExperienceModeKey);
  }

  Future<bool> saveAppExperienceMode(String mode) async {
    return _prefs.setString(_appExperienceModeKey, mode);
  }

  // --- Trip Journey Stops ---
  static const String _journeyStopsPrefix = 'kith_journey_';

  List<Map<String, dynamic>> getSavedJourneyStops(String tripId) {
    final raw = _prefs.getString('$_journeyStopsPrefix$tripId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveJourneyStops(String tripId, List<Map<String, dynamic>> stopsJson) async {
    return _prefs.setString('$_journeyStopsPrefix$tripId', jsonEncode(stopsJson));
  }

  // --- Trip Memories ---
  static const String _tripMemoriesPrefix = 'kith_memories_';

  List<Map<String, dynamic>> getSavedTripMemories(String tripId) {
    final raw = _prefs.getString('$_tripMemoriesPrefix$tripId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveTripMemories(String tripId, List<Map<String, dynamic>> memoriesJson) async {
    return _prefs.setString('$_tripMemoriesPrefix$tripId', jsonEncode(memoriesJson));
  }

  // --- Trip Journey Moments ---
  static const String _journeyMomentsPrefix = 'kith_moments_';

  List<Map<String, dynamic>> getSavedJourneyMoments(String tripId) {
    final raw = _prefs.getString('$_journeyMomentsPrefix$tripId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveJourneyMoments(String tripId, List<Map<String, dynamic>> momentsJson) async {
    return _prefs.setString('$_journeyMomentsPrefix$tripId', jsonEncode(momentsJson));
  }

  // --- Trip Settlements ---
  static const String _tripSettlementsPrefix = 'kith_settlements_';

  List<Map<String, dynamic>> getSavedTripSettlements(String tripId) {
    final raw = _prefs.getString('$_tripSettlementsPrefix$tripId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveTripSettlements(String tripId, List<Map<String, dynamic>> settlementsJson) async {
    return _prefs.setString('$_tripSettlementsPrefix$tripId', jsonEncode(settlementsJson));
  }

  // --- Onboarding & Tutorial ---
  static const String _onboardingCompletedKey = 'kith_onboarding_completed';

  bool hasCompletedOnboarding() {
    return _prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<bool> setOnboardingCompleted(bool completed) async {
    return _prefs.setBool(_onboardingCompletedKey, completed);
  }

  // --- Cloud Sync Metadata ---
  static const String _lastSyncTimeKey = 'kith_last_sync_time';
  static const String _autoSyncKey = 'kith_auto_sync_enabled';

  DateTime? getLastSyncTime() {
    final raw = _prefs.getString(_lastSyncTimeKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveLastSyncTime(DateTime time) async {
    return _prefs.setString(_lastSyncTimeKey, time.toIso8601String());
  }

  bool isAutoSyncEnabled() {
    return _prefs.getBool(_autoSyncKey) ?? true;
  }

  Future<bool> setAutoSyncEnabled(bool enabled) async {
    return _prefs.setBool(_autoSyncKey, enabled);
  }

  // --- Language & Localization (Device-level) ---
  static const String _languageKey = 'kith_selected_language';
  static const String _initialLanguageSelectedKey = 'kith_initial_language_selected';
  static const String _hintPrefix = 'kith_hint_dismissed_';

  String? getSavedLanguage() {
    return _prefs.getString(_languageKey);
  }

  Future<bool> saveLanguage(String languageCode) async {
    return _prefs.setString(_languageKey, languageCode);
  }

  bool hasSelectedInitialLanguage() {
    return _prefs.getBool(_initialLanguageSelectedKey) ?? false;
  }

  Future<bool> setHasSelectedInitialLanguage(bool selected) async {
    return _prefs.setBool(_initialLanguageSelectedKey, selected);
  }

  // --- Contextual Hints / Tooltips ---
  bool isHintDismissed(String hintKey) {
    return _prefs.getBool('$_hintPrefix$hintKey') ?? false;
  }

  Future<bool> dismissHint(String hintKey) async {
    return _prefs.setBool('$_hintPrefix$hintKey', true);
  }

  /// Wipes all user-specific data on logout while preserving app settings (language, theme, hints)
  Future<void> clearAllUserData() async {
    await clearUser();
    await _prefs.remove(_tripsKey);
    await _prefs.remove(_mutationQueueKey);
    await _prefs.remove(_personalExpensesKey);
    await _prefs.remove(_personalDebtsKey);
    await _prefs.remove(_lastSyncTimeKey);
    
    // Clear all prefixed keys
    final keys = _prefs.getKeys().toList();
    for (final k in keys) {
      if (k.startsWith(_expensesPrefix) ||
          k.startsWith(_personalBudgetKeyPrefix) ||
          k.startsWith(_journeyStopsPrefix) ||
          k.startsWith(_tripMemoriesPrefix) ||
          k.startsWith(_journeyMomentsPrefix)) {
        await _prefs.remove(k);
      }
    }
  }
}
