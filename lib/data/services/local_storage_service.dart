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

  static const String _recoveryVaultKey = 'kith_recovery_vault';

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
    final saved = await _prefs.setString(_userKey, jsonEncode(userJson));
    await saveUserToRecoveryVault(userJson);
    return saved;
  }

  Future<bool> clearUser() async {
    return _prefs.remove(_userKey);
  }

  // --- Recovery Vault (Cross-session offline recovery key backup) ---
  Map<String, dynamic> _getRecoveryVault() {
    final raw = _prefs.getString(_recoveryVaultKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveUserToRecoveryVault(Map<String, dynamic> userJson) async {
    final key = userJson['recoveryKey'] as String?;
    if (key == null || key.isEmpty) return;
    final normalized = _cleanRecoveryKey(key);
    if (normalized.isEmpty) return;

    final vault = _getRecoveryVault();
    vault[normalized] = userJson;
    await _prefs.setString(_recoveryVaultKey, jsonEncode(vault));
  }

  Map<String, dynamic>? getUserByRecoveryKey(String recoveryKey) {
    final normalized = _cleanRecoveryKey(recoveryKey);
    if (normalized.isEmpty) return null;
    final vault = _getRecoveryVault();
    if (vault.containsKey(normalized)) {
      return vault[normalized] as Map<String, dynamic>?;
    }
    for (final entry in vault.entries) {
      if (_cleanRecoveryKey(entry.key) == normalized) {
        return entry.value as Map<String, dynamic>?;
      }
    }
    return null;
  }

  String _cleanRecoveryKey(String raw) {
    final trimmed = raw.trim().toUpperCase();
    String clean = trimmed.replaceAll(RegExp(r'[\s\-_:\r\n]'), '');
    if (clean.startsWith('KITH')) {
      clean = clean.substring(4);
    }
    if (clean.length == 8) {
      return 'KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}';
    }
    return clean.isEmpty ? '' : (clean.length > 8 ? 'KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}' : clean);
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

  // --- Payment Methods & Receiving UPI ---
  static const String savedUpiItemsKey = 'kith_saved_upi_items';
  static const String _primaryUpiKey = 'kith_primary_upi';
  static const String _paymentPromptDismissedKey = 'kith_payment_prompt_dismissed';

  String? getPrimaryUpiId() {
    final explicit = _prefs.getString(_primaryUpiKey);
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final raw = _prefs.getString(savedUpiItemsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        if (list.isNotEmpty) {
          final first = list.firstWhere(
            (item) => item is Map && item['isDefault'] == true,
            orElse: () => list.first,
          );
          if (first is Map && first['vpa'] != null) {
            return first['vpa'] as String;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool> setPrimaryUpiId(String? upiId) async {
    if (upiId == null || upiId.isEmpty) {
      return _prefs.remove(_primaryUpiKey);
    }
    return _prefs.setString(_primaryUpiKey, upiId.trim().toLowerCase());
  }

  bool hasPaymentMethodConfigured() {
    final upi = getPrimaryUpiId();
    return upi != null && upi.trim().isNotEmpty;
  }

  bool isPaymentPromptDismissed() {
    return _prefs.getBool(_paymentPromptDismissedKey) ?? false;
  }

  Future<bool> dismissPaymentPrompt() async {
    return _prefs.setBool(_paymentPromptDismissedKey, true);
  }

  // --- In-App Real Notifications ---
  static const String _notificationsKey = 'kith_notifications';

  List<Map<String, dynamic>> getSavedNotifications() {
    final raw = _prefs.getString(_notificationsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveNotifications(List<Map<String, dynamic>> notificationsJson) async {
    return _prefs.setString(_notificationsKey, jsonEncode(notificationsJson));
  }

  Future<void> addNotification(Map<String, dynamic> notifJson) async {
    final current = getSavedNotifications();
    current.removeWhere((n) => n['id'] == notifJson['id']);
    current.insert(0, notifJson);
    // Keep last 100 notifications
    if (current.length > 100) {
      current.removeRange(100, current.length);
    }
    await saveNotifications(current);
  }

  Future<void> markAllNotificationsAsRead() async {
    final current = getSavedNotifications();
    for (final n in current) {
      n['isRead'] = true;
    }
    await saveNotifications(current);
  }

  Future<void> markNotificationAsRead(String notifId) async {
    final current = getSavedNotifications();
    final idx = current.indexWhere((n) => n['id'] == notifId);
    if (idx != -1) {
      current[idx]['isRead'] = true;
      await saveNotifications(current);
    }
  }

  int getUnreadNotificationCount() {
    final current = getSavedNotifications();
    return current.where((n) => n['isRead'] != true).length;
  }

  // --- Version & Update Management Keys ---
  static const String _versionConfigCacheKey = 'kith_version_config_cache';
  static const String _versionLastDismissedKey = 'kith_version_last_dismissed';
  static const String _versionDismissedAtKey = 'kith_version_dismissed_at';
  static const String _localSchemaVersionKey = 'kith_local_schema_version';

  // --- Version & Update Management Methods ---
  Map<String, dynamic>? getCachedVersionConfig() {
    final raw = _prefs.getString(_versionConfigCacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedVersionConfig(Map<String, dynamic> configJson) async {
    await _prefs.setString(_versionConfigCacheKey, jsonEncode(configJson));
  }

  String? getLastDismissedVersion() => _prefs.getString(_versionLastDismissedKey);

  DateTime? getLastDismissedTimestamp() {
    final raw = _prefs.getString(_versionDismissedAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveDismissedVersion(String version) async {
    await _prefs.setString(_versionLastDismissedKey, version);
    await _prefs.setString(_versionDismissedAtKey, DateTime.now().toIso8601String());
  }

  Future<void> clearDismissedVersion() async {
    await _prefs.remove(_versionLastDismissedKey);
    await _prefs.remove(_versionDismissedAtKey);
  }

  // --- Local Database & Storage Schema Migration ---
  int getLocalSchemaVersion() => _prefs.getInt(_localSchemaVersionKey) ?? 0;

  Future<void> setLocalSchemaVersion(int version) async {
    await _prefs.setInt(_localSchemaVersionKey, version);
  }

  /// Wipes all user-specific data on logout while preserving app settings (language, theme, hints)
  Future<void> clearAllUserData() async {
    await clearUser();
    await _prefs.remove(_tripsKey);
    await _prefs.remove(_mutationQueueKey);
    await _prefs.remove(_personalExpensesKey);
    await _prefs.remove(_personalDebtsKey);
    await _prefs.remove(_lastSyncTimeKey);
    await _prefs.remove(_notificationsKey);
    
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
