import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_database_service.dart';

/// Local offline persistence service.

/// Uses SharedPreferences with structured JSON serialization to ensure zero data loss

/// and instant cold start without network latency.

/// Immutable record of an operation that has been applied to local domain state.

/// Tracks operation ID, SHA-256 payload checksum, and processed timestamp

/// to enforce strict idempotency and detect payload tampering/mismatches.

class ProcessedOperationRecord {
  final String operationId;

  final String payloadChecksum;

  final DateTime processedAt;

  final String? source; // 'cloud', 'p2p', 'local'

  const ProcessedOperationRecord({
    required this.operationId,

    required this.payloadChecksum,

    required this.processedAt,

    this.source,
  });

  Map<String, dynamic> toJson() => {
    'operationId': operationId,

    'payloadChecksum': payloadChecksum,

    'processedAt': processedAt.toIso8601String(),

    'source': source,
  };

  factory ProcessedOperationRecord.fromJson(Map<String, dynamic> json) =>
      ProcessedOperationRecord(
        operationId: json['operationId'] as String,

        payloadChecksum: json['payloadChecksum'] as String? ?? '',

        processedAt: json['processedAt'] != null
            ? DateTime.tryParse(json['processedAt'] as String) ?? DateTime.now()
            : DateTime.now(),

        source: json['source'] as String?,
      );
}

class LocalStorageService {
  static const String _userKey = 'kith_guest_user';

  static const String _tripsKey = 'kith_trips';

  static const String _expensesPrefix = 'kith_expenses_';

  static const String _mutationQueueKey = 'kith_sync_mutations';

  static const String _themeModeKey = 'kith_theme_mode';

  static const String _initialPermissionsKey =
      'kith_has_requested_initial_permissions';

  static const String _processedOpsLedgerKey = 'kith_processed_ops_ledger';

  final SharedPreferences _prefs;

  LocalDatabaseService? databaseService;

  LocalStorageService(this._prefs, {this.databaseService});

  static Future<LocalStorageService> init({
    LocalDatabaseService? dbService,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    LocalDatabaseService? db = dbService;

    if (db == null) {
      try {
        db = await LocalDatabaseService.init();

        await db.migrateFromSharedPreferences(prefs);
      } catch (e) {
        debugPrint('[LocalStorageService] SQLite init/migration notice: $e');
      }
    }

    return LocalStorageService(prefs, databaseService: db);
  }

  // --- Generic Helpers ---

  String? getString(String key) => _prefs.getString(key);

  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  int? getInt(String key) => _prefs.getInt(key);

  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  bool? getBool(String key) => _prefs.getBool(key);

  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<bool> remove(String key) => _prefs.remove(key);

  Set<String> getKeys() => _prefs.getKeys();

  SharedPreferences get rawPrefs => _prefs;

  static const String _recoveryVaultKey = 'kith_recovery_vault';

  static const String _deletedRecoveryKeysKey = 'kith_deleted_recovery_keys';

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

    final sanitized = Map<String, dynamic>.from(userJson);
    sanitized.remove('anonymousToken');
    sanitized.remove('token');
    sanitized.remove('sessionToken');
    vault[normalized] = sanitized;

    await _prefs.setString(_recoveryVaultKey, jsonEncode(vault));
  }

  Future<void> removeUserFromRecoveryVault(String recoveryKey) async {
    final normalized = _cleanRecoveryKey(recoveryKey);

    if (normalized.isEmpty) return;

    final vault = _getRecoveryVault();

    vault.remove(normalized);

    vault.removeWhere((k, v) => _cleanRecoveryKey(k) == normalized);

    await _prefs.setString(_recoveryVaultKey, jsonEncode(vault));
  }

  Future<void> clearRecoveryVault() async {
    await _prefs.remove(_recoveryVaultKey);
  }

  // --- Deleted Accounts & Recovery Key Tombstones ---

  Set<String> _getDeletedRecoveryKeys() {
    final list = _prefs.getStringList(_deletedRecoveryKeysKey) ?? [];

    return list
        .map((k) => _cleanRecoveryKey(k))
        .where((k) => k.isNotEmpty)
        .toSet();
  }

  Future<void> markRecoveryKeyDeleted(String recoveryKey) async {
    final normalized = _cleanRecoveryKey(recoveryKey);

    if (normalized.isEmpty) return;

    final keys = _getDeletedRecoveryKeys();

    keys.add(normalized);

    await _prefs.setStringList(_deletedRecoveryKeysKey, keys.toList());
  }

  bool isRecoveryKeyDeleted(String recoveryKey) {
    final normalized = _cleanRecoveryKey(recoveryKey);

    if (normalized.isEmpty) return false;

    final keys = _getDeletedRecoveryKeys();

    return keys.contains(normalized);
  }

  Map<String, dynamic>? getUserByRecoveryKey(String recoveryKey) {
    final normalized = _cleanRecoveryKey(recoveryKey);

    if (normalized.isEmpty || isRecoveryKeyDeleted(normalized)) return null;

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

    if (clean.length == 12) {
      return 'KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}';
    }

    if (clean.length == 16) {
      return 'KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}-${clean.substring(12, 16)}';
    }

    return clean.isEmpty ? '' : 'KITH-$clean';
  }

  // --- Trips ---

  List<Map<String, dynamic>> getSavedTrips() {
    if (databaseService != null &&
        databaseService!.isMigratedFromSharedPreferences()) {
      return databaseService!.getSavedTrips();
    }

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
    if (databaseService != null) {
      databaseService!.commitAtomicMutationBatch(updatedTrips: tripsJson);
    }

    return _prefs.setString(_tripsKey, jsonEncode(tripsJson));
  }

  // --- Expenses for Trip ---

  List<Map<String, dynamic>> getSavedExpenses(String tripId) {
    if (databaseService != null &&
        databaseService!.isMigratedFromSharedPreferences()) {
      return databaseService!.getSavedExpenses(tripId);
    }

    final raw = _prefs.getString('$_expensesPrefix$tripId');

    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;

      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveExpenses(
    String tripId,
    List<Map<String, dynamic>> expensesJson,
  ) async {
    if (databaseService != null) {
      databaseService!.commitAtomicMutationBatch(
        updatedExpensesByTrip: {tripId: expensesJson},
      );
    }

    return _prefs.setString(
      '$_expensesPrefix$tripId',
      jsonEncode(expensesJson),
    );
  }

  // --- Deleted Expense Tombstones (Prevents stale P2P/Cloud resurrection) ---

  static const String _tombstonesPrefix = 'kith_tombstones_';

  Map<String, String> getDeletedExpenseTombstones(String tripId) {
    if (databaseService != null &&
        databaseService!.isMigratedFromSharedPreferences()) {
      return databaseService!.getDeletedExpenseTombstones(tripId);
    }

    final raw = _prefs.getString('$_tombstonesPrefix$tripId');

    if (raw == null || raw.isEmpty) return {};

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;

      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  bool isExpenseTombstoned(String tripId, String expenseId) {
    final tombstones = getDeletedExpenseTombstones(tripId);

    return tombstones.containsKey(expenseId);
  }

  Future<void> markExpenseTombstoned(
    String tripId,
    String expenseId, [
    DateTime? deletedAt,
  ]) async {
    if (databaseService != null) {
      databaseService!.commitAtomicMutationBatch(
        tombstoneToAdd: {'tripId': tripId, 'expenseId': expenseId},
      );
    }

    final tombstones = getDeletedExpenseTombstones(tripId);

    final timestamp = (deletedAt ?? DateTime.now()).toIso8601String();

    tombstones[expenseId] = timestamp;

    await _prefs.setString('$_tombstonesPrefix$tripId', jsonEncode(tombstones));
  }

  // --- Mutation Queue ---

  List<Map<String, dynamic>> getMutationQueue() {
    if (databaseService != null &&
        databaseService!.isMigratedFromSharedPreferences()) {
      return databaseService!.getOutboxMutations();
    }

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
    if (databaseService != null) {
      databaseService!.commitAtomicMutationBatch(updatedOutbox: queue);
    }

    return _prefs.setString(_mutationQueueKey, jsonEncode(queue));
  }

  Future<bool> clearMutationQueue() async {
    if (databaseService != null) {
      databaseService!.commitAtomicMutationBatch(updatedOutbox: []);
    }
    return _prefs.remove(_mutationQueueKey);
  }

  // --- Processed P2P Operations ---

  static const String _processedP2POpsKey = 'kith_processed_p2p_ops';

  List<String> getProcessedP2POperationIds() {
    final raw = _prefs.getString(_processedP2POpsKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;

      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markP2POperationProcessed(String opId) async {
    final list = getProcessedP2POperationIds();

    if (!list.contains(opId)) {
      list.add(opId);

      // Retain max 1000 recent P2P operation IDs to prevent unbounded cache growth

      if (list.length > 1000) {
        list.removeRange(0, list.length - 1000);
      }

      await _prefs.setString(_processedP2POpsKey, jsonEncode(list));
    }
  }

  bool isP2POperationProcessed(String opId) {
    return getProcessedP2POperationIds().contains(opId);
  }

  // --- Authoritative Processed Operations Ledger & Idempotency ---

  Map<String, ProcessedOperationRecord> getProcessedOperationsLedger() {
    if (databaseService != null &&
        databaseService!.isMigratedFromSharedPreferences()) {
      return databaseService!.getProcessedOperationsLedger();
    }

    final raw = _prefs.getString(_processedOpsLedgerKey);

    if (raw == null || raw.isEmpty) return {};

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;

      return map.map(
        (k, v) => MapEntry(
          k,
          ProcessedOperationRecord.fromJson(
            Map<String, dynamic>.from(v as Map),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  ({bool isProcessed, bool isMismatch}) checkOperationStatus(
    String opId,
    String payloadChecksum,
  ) {
    final ledger = getProcessedOperationsLedger();

    final record = ledger[opId];

    if (record == null) {
      final legacyProcessed = isP2POperationProcessed(opId);

      return (isProcessed: legacyProcessed, isMismatch: false);
    }

    if (payloadChecksum.isNotEmpty &&
        record.payloadChecksum.isNotEmpty &&
        record.payloadChecksum != payloadChecksum) {
      return (isProcessed: true, isMismatch: true);
    }

    return (isProcessed: true, isMismatch: false);
  }

  Future<void> recordProcessedOperation(ProcessedOperationRecord record) async {
    final ledger = getProcessedOperationsLedger();

    ledger[record.operationId] = record;

    if (ledger.length > 2000) {
      final sortedKeys = ledger.keys.toList()
        ..sort(
          (a, b) => ledger[a]!.processedAt.compareTo(ledger[b]!.processedAt),
        );

      final toRemove = sortedKeys.take(ledger.length - 2000);

      for (final k in toRemove) {
        ledger.remove(k);
      }
    }

    final encoded = {for (final e in ledger.entries) e.key: e.value.toJson()};

    await _prefs.setString(_processedOpsLedgerKey, jsonEncode(encoded));

    await markP2POperationProcessed(record.operationId);
  }

  /// Transactional atomic multi-store commit method.

  /// Applies domain entities, outbox mutations, tombstones, and processed ledger

  /// in a coordinated sequence to prevent partial or corrupted local state.

  Future<bool> commitAtomicMutationBatch({
    List<Map<String, dynamic>>? updatedTrips,

    Map<String, List<Map<String, dynamic>>>? updatedExpensesByTrip,

    Map<String, List<Map<String, dynamic>>>? updatedSettlementsByTrip,

    List<Map<String, dynamic>>? updatedPersonalExpenses,

    List<Map<String, dynamic>>? updatedPersonalDebts,

    List<Map<String, dynamic>>? updatedOutbox,

    ProcessedOperationRecord? recordToMarkProcessed,

    Map<String, String>? tombstoneToAdd,
  }) async {
    if (databaseService != null) {
      final ok = databaseService!.commitAtomicMutationBatch(
        updatedTrips: updatedTrips,

        updatedExpensesByTrip: updatedExpensesByTrip,

        updatedSettlementsByTrip: updatedSettlementsByTrip,

        updatedPersonalExpenses: updatedPersonalExpenses,

        updatedPersonalDebts: updatedPersonalDebts,

        updatedOutbox: updatedOutbox,

        recordToMarkProcessed: recordToMarkProcessed,

        tombstoneToAdd: tombstoneToAdd,
      );

      if (!ok) return false;

      if (recordToMarkProcessed != null) {
        await markP2POperationProcessed(recordToMarkProcessed.operationId);
      }
    }

    final updates = <String, String>{};

    if (updatedTrips != null) {
      updates[_tripsKey] = jsonEncode(updatedTrips);
    }

    if (updatedExpensesByTrip != null) {
      for (final entry in updatedExpensesByTrip.entries) {
        updates['$_expensesPrefix${entry.key}'] = jsonEncode(entry.value);
      }
    }

    if (updatedSettlementsByTrip != null) {
      for (final entry in updatedSettlementsByTrip.entries) {
        updates['$_tripSettlementsPrefix${entry.key}'] = jsonEncode(
          entry.value,
        );
      }
    }

    if (updatedPersonalExpenses != null) {
      updates[_personalExpensesKey] = jsonEncode(updatedPersonalExpenses);
    }

    if (updatedPersonalDebts != null) {
      updates[_personalDebtsKey] = jsonEncode(updatedPersonalDebts);
    }

    if (updatedOutbox != null) {
      updates[_mutationQueueKey] = jsonEncode(updatedOutbox);
    }

    if (tombstoneToAdd != null &&
        tombstoneToAdd['tripId'] != null &&
        tombstoneToAdd['expenseId'] != null) {
      final tId = tombstoneToAdd['tripId']!;

      final eId = tombstoneToAdd['expenseId']!;

      final existingTombstones = getDeletedExpenseTombstones(tId);

      existingTombstones[eId] = DateTime.now().toIso8601String();

      updates['$_tombstonesPrefix$tId'] = jsonEncode(existingTombstones);
    }

    if (recordToMarkProcessed != null) {
      final ledger = getProcessedOperationsLedger();

      ledger[recordToMarkProcessed.operationId] = recordToMarkProcessed;

      if (ledger.length > 2000) {
        final sortedKeys = ledger.keys.toList()
          ..sort(
            (a, b) => ledger[a]!.processedAt.compareTo(ledger[b]!.processedAt),
          );

        final toRemove = sortedKeys.take(ledger.length - 2000);

        for (final k in toRemove) {
          ledger.remove(k);
        }
      }

      final encoded = {for (final e in ledger.entries) e.key: e.value.toJson()};

      updates[_processedOpsLedgerKey] = jsonEncode(encoded);
    }

    try {
      for (final entry in updates.entries) {
        final ok = await _prefs.setString(entry.key, entry.value);

        if (!ok) return false;
      }

      if (recordToMarkProcessed != null) {
        await markP2POperationProcessed(recordToMarkProcessed.operationId);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // --- Device Identification ---

  static const String _deviceIdKey = 'kith_device_id';

  String getDeviceId() {
    var id = _prefs.getString(_deviceIdKey);

    if (id == null || id.isEmpty) {
      id =
          'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';

      _prefs.setString(_deviceIdKey, id);
    }

    return id;
  }

  Future<bool> saveDeviceId(String id) async {
    return _prefs.setString(_deviceIdKey, id);
  }

  // --- Sync Operation Logs ---

  static const String _syncLogsKey = 'kith_sync_logs';

  List<Map<String, dynamic>> getSyncLogs({String? tripId, int limit = 50}) {
    final raw = _prefs.getString(_syncLogsKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (tripId != null) {
        return list.where((l) => l['tripId'] == tripId).take(limit).toList();
      }

      return list.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addSyncLog({
    required String source,

    required String status,

    required int changesSent,

    required int changesReceived,

    String? tripId,

    String? details,
  }) async {
    final logs = getSyncLogs(limit: 200);

    logs.insert(0, {
      'id': 'log_${DateTime.now().millisecondsSinceEpoch}',

      'timestamp': DateTime.now().toIso8601String(),

      'source': source,

      'status': status,

      'changesSent': changesSent,

      'changesReceived': changesReceived,

      'tripId': tripId,

      'details': details,
    });

    if (logs.length > 100) {
      logs.removeRange(100, logs.length);
    }

    await _prefs.setString(_syncLogsKey, jsonEncode(logs));
  }

  Future<bool> clearSyncLogs() async {
    return _prefs.remove(_syncLogsKey);
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
    if (databaseService != null &&
        databaseService!.isMigratedFromSharedPreferences()) {
      return databaseService!.getPersonalExpenses();
    }
    final raw = _prefs.getString(_personalExpensesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> savePersonalExpenses(
    List<Map<String, dynamic>> expensesJson,
  ) async {
    if (databaseService != null) {
      databaseService!.commitAtomicMutationBatch(
        updatedPersonalExpenses: expensesJson,
      );
    }
    return _prefs.setString(_personalExpensesKey, jsonEncode(expensesJson));
  }

  // --- Personal Debts (Lending / Borrowing) ---

  List<Map<String, dynamic>> getSavedPersonalDebts() {
    if (databaseService != null &&
        databaseService!.isMigratedFromSharedPreferences()) {
      return databaseService!.getPersonalDebts();
    }
    final raw = _prefs.getString(_personalDebtsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> getPersonalDebts() => getSavedPersonalDebts();

  Future<bool> savePersonalDebts(List<Map<String, dynamic>> debtsJson) async {
    if (databaseService != null) {
      databaseService!.commitAtomicMutationBatch(
        updatedPersonalDebts: debtsJson,
      );
    }
    return _prefs.setString(_personalDebtsKey, jsonEncode(debtsJson));
  }

  /// Atomically commits both personal expenses and debts within a single SQLite transaction
  /// and updates SharedPreferences caches simultaneously.
  Future<bool> savePersonalExpensesAndDebts({
    required List<Map<String, dynamic>> expensesJson,
    required List<Map<String, dynamic>> debtsJson,
  }) async {
    if (databaseService != null) {
      databaseService!.commitAtomicMutationBatch(
        updatedPersonalExpenses: expensesJson,
        updatedPersonalDebts: debtsJson,
      );
    }
    final p1 = await _prefs.setString(_personalExpensesKey, jsonEncode(expensesJson));
    final p2 = await _prefs.setString(_personalDebtsKey, jsonEncode(debtsJson));
    return p1 && p2;
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

  Future<bool> savePersonalBudget(
    String monthYear,
    Map<String, dynamic> budgetJson,
  ) async {
    return _prefs.setString(
      '$_personalBudgetKeyPrefix$monthYear',
      jsonEncode(budgetJson),
    );
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

  Future<bool> saveActivityLogs(
    String tripId,
    List<Map<String, dynamic>> logsJson,
  ) async {
    return _prefs.setString(
      '$_activityLogsPrefix$tripId',
      jsonEncode(logsJson),
    );
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

  // --- Dual Mode Architecture (Trip Mode vs Financial Mode) ---

  static const String _primaryAppModeKey = 'kith_primary_app_mode';

  String? getSavedPrimaryAppMode() {
    return _prefs.getString(_primaryAppModeKey);
  }

  Future<bool> savePrimaryAppMode(String mode) async {
    return _prefs.setString(_primaryAppModeKey, mode);
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

  Future<bool> saveJourneyStops(
    String tripId,
    List<Map<String, dynamic>> stopsJson,
  ) async {
    return _prefs.setString(
      '$_journeyStopsPrefix$tripId',
      jsonEncode(stopsJson),
    );
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

  Future<bool> saveTripMemories(
    String tripId,
    List<Map<String, dynamic>> memoriesJson,
  ) async {
    return _prefs.setString(
      '$_tripMemoriesPrefix$tripId',
      jsonEncode(memoriesJson),
    );
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

  Future<bool> saveJourneyMoments(
    String tripId,
    List<Map<String, dynamic>> momentsJson,
  ) async {
    return _prefs.setString(
      '$_journeyMomentsPrefix$tripId',
      jsonEncode(momentsJson),
    );
  }

  // --- Trip Settlements ---

  static const String _tripSettlementsPrefix = 'kith_settlements_';

  List<Map<String, dynamic>> getSavedTripSettlements(String tripId) {
    if (databaseService != null &&
        databaseService!.isMigratedFromSharedPreferences()) {
      return databaseService!.getSavedSettlements(tripId);
    }
    final raw = _prefs.getString('$_tripSettlementsPrefix$tripId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveTripSettlements(
    String tripId,
    List<Map<String, dynamic>> settlementsJson,
  ) async {
    if (databaseService != null) {
      databaseService!.commitAtomicMutationBatch(
        updatedSettlementsByTrip: {tripId: settlementsJson},
      );
    }
    return _prefs.setString(
      '$_tripSettlementsPrefix$tripId',
      jsonEncode(settlementsJson),
    );
  }

  /// Deterministically translates member IDs across SQLite and SharedPreferences caches
  /// for a specific trip, ensuring multi-store consistency.
  Future<void> translateMemberIds({
    required String tripId,
    required Map<String, String> translationMap,
  }) async {
    if (translationMap.isEmpty) return;

    // 1. Transactionally update authoritative SQLite database
    if (databaseService != null) {
      databaseService!.translateMemberIds(
        tripId: tripId,
        translationMap: translationMap,
      );
    }

    // 2. Synchronize SharedPreferences Expenses Cache
    final rawExpenses = _prefs.getString('$_expensesPrefix$tripId');
    if (rawExpenses != null && rawExpenses.isNotEmpty) {
      try {
        final expList = jsonDecode(rawExpenses) as List<dynamic>;
        bool expModified = false;
        for (final item in expList) {
          if (item is Map<String, dynamic>) {
            final paidById = item['paidById']?.toString();
            if (paidById != null && translationMap.containsKey(paidById)) {
              item['paidById'] = translationMap[paidById];
              expModified = true;
            }
            if (item['paidByMemberId'] != null &&
                translationMap.containsKey(item['paidByMemberId'])) {
              item['paidByMemberId'] = translationMap[item['paidByMemberId']];
              expModified = true;
            }
            if (item['paidByMap'] is Map) {
              final oldMap = Map<String, dynamic>.from(item['paidByMap'] as Map);
              final newMap = <String, dynamic>{};
              bool mapChanged = false;
              for (final entry in oldMap.entries) {
                final translatedKey = translationMap[entry.key] ?? entry.key;
                if (translatedKey != entry.key) mapChanged = true;
                newMap[translatedKey] = entry.value;
              }
              if (mapChanged) {
                item['paidByMap'] = newMap;
                expModified = true;
              }
            }
            if (item['splits'] is List) {
              for (final split in item['splits'] as List<dynamic>) {
                if (split is Map<String, dynamic>) {
                  final mId = split['memberId']?.toString();
                  if (mId != null && translationMap.containsKey(mId)) {
                    split['memberId'] = translationMap[mId];
                    expModified = true;
                  }
                }
              }
            }
          }
        }
        if (expModified) {
          await _prefs.setString('$_expensesPrefix$tripId', jsonEncode(expList));
        }
      } catch (_) {}
    }

    // 3. Synchronize SharedPreferences Settlements Cache
    final rawSettlements = _prefs.getString('$_tripSettlementsPrefix$tripId');
    if (rawSettlements != null && rawSettlements.isNotEmpty) {
      try {
        final setList = jsonDecode(rawSettlements) as List<dynamic>;
        bool setModified = false;
        for (final item in setList) {
          if (item is Map<String, dynamic>) {
            final fromId = item['fromMemberId']?.toString();
            final toId = item['toMemberId']?.toString();
            if (fromId != null && translationMap.containsKey(fromId)) {
              item['fromMemberId'] = translationMap[fromId];
              setModified = true;
            }
            if (toId != null && translationMap.containsKey(toId)) {
              item['toMemberId'] = translationMap[toId];
              setModified = true;
            }
          }
        }
        if (setModified) {
          await _prefs.setString(
            '$_tripSettlementsPrefix$tripId',
            jsonEncode(setList),
          );
        }
      } catch (_) {}
    }

    // 4. Synchronize SharedPreferences Mutation Queue
    final rawQueue = _prefs.getString(_mutationQueueKey);
    if (rawQueue != null && rawQueue.isNotEmpty) {
      try {
        final queueList = jsonDecode(rawQueue) as List<dynamic>;
        bool queueModified = false;
        for (final item in queueList) {
          if (item is Map<String, dynamic>) {
            final tId = item['tripId']?.toString() ??
                (item['payload'] is Map ? (item['payload'] as Map)['tripId']?.toString() : null);
            if (tId == tripId && item['payload'] is Map) {
              final payload = item['payload'] as Map<String, dynamic>;
              bool payloadModified = false;

              if (payload.containsKey('paidById') &&
                  translationMap.containsKey(payload['paidById'])) {
                payload['paidById'] = translationMap[payload['paidById']];
                payloadModified = true;
              }
              if (payload.containsKey('paidByMemberId') &&
                  translationMap.containsKey(payload['paidByMemberId'])) {
                payload['paidByMemberId'] =
                    translationMap[payload['paidByMemberId']];
                payloadModified = true;
              }
              if (payload.containsKey('paidByMap') && payload['paidByMap'] is Map) {
                final oldMap = Map<String, dynamic>.from(payload['paidByMap'] as Map);
                final newMap = <String, dynamic>{};
                bool mapChanged = false;
                for (final entry in oldMap.entries) {
                  final translatedKey = translationMap[entry.key] ?? entry.key;
                  if (translatedKey != entry.key) mapChanged = true;
                  newMap[translatedKey] = entry.value;
                }
                if (mapChanged) {
                  payload['paidByMap'] = newMap;
                  payloadModified = true;
                }
              }
              if (payload.containsKey('splits') && payload['splits'] is List) {
                for (final split in payload['splits'] as List<dynamic>) {
                  if (split is Map<String, dynamic>) {
                    final mId = split['memberId']?.toString();
                    if (mId != null && translationMap.containsKey(mId)) {
                      split['memberId'] = translationMap[mId];
                      payloadModified = true;
                    }
                  }
                }
              }
              if (payload.containsKey('fromMemberId') &&
                  translationMap.containsKey(payload['fromMemberId'])) {
                payload['fromMemberId'] =
                    translationMap[payload['fromMemberId']];
                payloadModified = true;
              }
              if (payload.containsKey('toMemberId') &&
                  translationMap.containsKey(payload['toMemberId'])) {
                payload['toMemberId'] = translationMap[payload['toMemberId']];
                payloadModified = true;
              }

              if (payloadModified) {
                queueModified = true;
                if (item['syncState'] == 'quarantined' ||
                    item['syncState'] == 'failed' ||
                    item['status'] == 'quarantined' ||
                    item['status'] == 'failed') {
                  item['syncState'] = 'localPending';
                  item['status'] = 'pending';
                  item['retryCount'] = 0;
                  item['lastError'] = null;
                }
              }
            }
          }
        }
        if (queueModified) {
          await _prefs.setString(_mutationQueueKey, jsonEncode(queueList));
        }
      } catch (_) {}
    }
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

  static const String _initialLanguageSelectedKey =
      'kith_initial_language_selected';

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

  static const String _paymentPromptDismissedKey =
      'kith_payment_prompt_dismissed';

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

  Future<bool> saveNotifications(
    List<Map<String, dynamic>> notificationsJson,
  ) async {
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

  // --- 2-Sided Payment Verifications ---

  static const String _paymentVerificationsKey = 'kith_payment_verifications';

  List<Map<String, dynamic>> getSavedPaymentVerifications() {
    final raw = _prefs.getString(_paymentVerificationsKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;

      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> savePaymentVerifications(List<Map<String, dynamic>> list) async {
    return _prefs.setString(_paymentVerificationsKey, jsonEncode(list));
  }

  Future<void> addPaymentVerification(Map<String, dynamic> req) async {
    final current = getSavedPaymentVerifications();

    current.removeWhere((item) => item['id'] == req['id']);

    current.insert(0, req);

    if (current.length > 200) {
      current.removeRange(200, current.length);
    }

    await savePaymentVerifications(current);
  }

  Future<void> updatePaymentVerificationStatus(
    String id,

    String status, {

    String? reason,

    String? transactionRef,

    String? proofImageUrl,

    String? proofNote,
  }) async {
    final current = getSavedPaymentVerifications();

    final idx = current.indexWhere(
      (item) => item['id'] == id || item['settlementId'] == id,
    );

    if (idx != -1) {
      current[idx]['status'] = status;

      current[idx]['respondedAt'] = DateTime.now().toIso8601String();

      if (reason != null) {
        current[idx]['disputeReason'] = reason;
      }

      if (transactionRef != null) {
        current[idx]['transactionRef'] = transactionRef;
      }

      if (proofImageUrl != null) {
        current[idx]['proofImageUrl'] = proofImageUrl;
      }

      if (proofNote != null) {
        current[idx]['proofNote'] = proofNote;
      }

      await savePaymentVerifications(current);
    }
  }

  List<Map<String, dynamic>> getPendingVerificationsForReceiver({
    String? userId,

    String? memberId,

    String? name,
  }) {
    if (userId == null || userId.isEmpty) return const [];

    final current = getSavedPaymentVerifications();

    return current.where((item) {
      final st = item['status'];

      if (st != 'pending_verification' &&
          st != 'marked_paid' &&
          st != 'proof_submitted') {
        return false;
      }

      final rUserId = item['receiverUserId'] as String?;

      final rMemberId = item['receiverMemberId'] as String?;

      // Non-negotiable Rule: Strict authenticated User ID identity matching

      if (rUserId != null && rUserId == userId) return true;

      if (memberId != null && rMemberId != null && memberId == rMemberId) {
        return true;
      }

      return false;
    }).toList();
  }

  List<Map<String, dynamic>> getDisputedVerificationsForPayer({
    String? userId,

    String? memberId,

    String? name,
  }) {
    if (userId == null || userId.isEmpty) return const [];

    final current = getSavedPaymentVerifications();

    return current.where((item) {
      final st = item['status'];

      if (st != 'disputed' && st != 'not_received') return false;

      final pUserId = item['payerUserId'] as String?;

      final pMemberId = item['payerMemberId'] as String?;

      // Non-negotiable Rule: Strict authenticated User ID identity matching

      if (pUserId != null && pUserId == userId) return true;

      if (memberId != null && pMemberId != null && memberId == pMemberId) {
        return true;
      }

      return false;
    }).toList();
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

  String? getLastDismissedVersion() =>
      _prefs.getString(_versionLastDismissedKey);

  DateTime? getLastDismissedTimestamp() {
    final raw = _prefs.getString(_versionDismissedAtKey);

    if (raw == null || raw.isEmpty) return null;

    return DateTime.tryParse(raw);
  }

  Future<void> saveDismissedVersion(String version) async {
    await _prefs.setString(_versionLastDismissedKey, version);

    await _prefs.setString(
      _versionDismissedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> clearDismissedVersion() async {
    await _prefs.remove(_versionLastDismissedKey);

    await _prefs.remove(_versionDismissedAtKey);
  }

  // --- Auto Budgeting / Person Balance System ---

  static const String _autoBudgetingPrefix = 'kith_auto_budgeting_';

  bool isAutoBudgetingEnabled(String personKey) {
    final cleanKey = personKey.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]'),
      '_',
    );

    return _prefs.getBool('$_autoBudgetingPrefix$cleanKey') ?? false;
  }

  Future<bool> setAutoBudgetingEnabled(String personKey, bool enabled) {
    final cleanKey = personKey.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]'),
      '_',
    );

    return _prefs.setBool('$_autoBudgetingPrefix$cleanKey', enabled);
  }

  // --- IPO Money Manager & Multi-Account Persistence ---

  static const String _iposCacheKey = 'kith_ipos_cache_v1';

  static const String _ipoApplicationsKey = 'kith_ipo_applications_v1';

  static const String _ipoAccountsKey = 'kith_ipo_accounts_v1';

  static const String _iposLastUpdatedKey = 'kith_ipos_last_updated';

  static const String _trackedIposKey = 'kith_tracked_ipos_v1';

  List<Map<String, dynamic>> getSavedIpos() {
    final raw = _prefs.getString(_iposCacheKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<void> saveIpos(List<Map<String, dynamic>> ipos) async {
    await _prefs.setString(_iposCacheKey, jsonEncode(ipos));
  }

  List<Map<String, dynamic>> getSavedIpoApplications() {
    final raw = _prefs.getString(_ipoApplicationsKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<void> saveIpoApplications(List<Map<String, dynamic>> apps) async {
    await _prefs.setString(_ipoApplicationsKey, jsonEncode(apps));
  }

  List<Map<String, dynamic>> getSavedIpoAccounts() {
    final raw = _prefs.getString(_ipoAccountsKey);

    if (raw == null || raw.isEmpty) {
      // Default: Primary "Me" account

      return [
        {
          'id': 'me',

          'displayName': 'Me (Primary)',

          'maskedPan': '',

          'createdAt': DateTime.now().toIso8601String(),

          'updatedAt': DateTime.now().toIso8601String(),
        },
      ];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<void> saveIpoAccounts(List<Map<String, dynamic>> accounts) async {
    await _prefs.setString(_ipoAccountsKey, jsonEncode(accounts));
  }

  Set<String> getTrackedIpoIds() {
    final list = _prefs.getStringList(_trackedIposKey);

    return list != null ? list.toSet() : <String>{};
  }

  Future<void> setIpoTracked(String ipoId, bool isTracked) async {
    final tracked = getTrackedIpoIds();

    if (isTracked) {
      tracked.add(ipoId);
    } else {
      tracked.remove(ipoId);
    }

    await _prefs.setStringList(_trackedIposKey, tracked.toList());
  }

  DateTime? getIposLastUpdated() {
    final raw = _prefs.getString(_iposLastUpdatedKey);

    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<void> setIposLastUpdated(DateTime time) async {
    await _prefs.setString(_iposLastUpdatedKey, time.toIso8601String());
  }

  // --- Local Database & Storage Schema Migration ---

  int getLocalSchemaVersion() => _prefs.getInt(_localSchemaVersionKey) ?? 0;

  Future<void> setLocalSchemaVersion(int version) async {
    await _prefs.setInt(_localSchemaVersionKey, version);
  }

  bool hasRequestedInitialPermissions() {
    return _prefs.getBool(_initialPermissionsKey) ?? false;
  }

  Future<bool> setHasRequestedInitialPermissions(bool value) {
    return _prefs.setBool(_initialPermissionsKey, value);
  }

  bool isAdminModeEnabled() {
    return _prefs.getBool('kith_admin_mode_enabled') ?? false;
  }

  Future<bool> setAdminModeEnabled(bool value) {
    return _prefs.setBool('kith_admin_mode_enabled', value);
  }

  final List<VoidCallback> _onClearDataListeners = [];

  void addOnClearDataListener(VoidCallback listener) {
    if (!_onClearDataListeners.contains(listener)) {
      _onClearDataListeners.add(listener);
    }
  }

  void removeOnClearDataListener(VoidCallback listener) {
    _onClearDataListeners.remove(listener);
  }

  /// Wipes all user-specific data on logout/deletion while preserving app settings (language, theme, hints)
  Future<void> clearAllUserData() async {
    if (databaseService != null) {
      databaseService!.clearAllData();
    }
    await clearUser();
    await clearRecoveryVault();

    // Preserve strictly global device & app settings (e.g. theme, language, device ID)
    const preservedKeys = {
      _themeModeKey,
      _languageKey,
      _initialLanguageSelectedKey,
      _initialPermissionsKey,
      _deviceIdKey,
      _customServerUrlKey,
      _localSchemaVersionKey,
    };
    final allKeys = _prefs.getKeys().toList();
    for (final k in allKeys) {
      if (!preservedKeys.contains(k)) {
        await _prefs.remove(k);
      }
    }

    for (final listener in List<VoidCallback>.from(_onClearDataListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('[LocalStorageService] Error in clear data listener: $e');
      }
    }
  }
}
