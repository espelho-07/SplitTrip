import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'local_storage_service.dart';

/// Summary metadata for a personal financial data export from SplitTrip.
class FinanceExportSummary {
  final int personalExpensesCount;
  final int personalDebtsCount;
  final int personalBudgetsCount;
  final int ipoAccountsCount;
  final int ipoApplicationsCount;
  final int trackedIposCount;
  final int cachedIposCount;
  final int paymentVerificationsCount;
  final int totalRecords;
  final String checksum;
  final DateTime exportedAt;
  final String? savedFilePath;

  const FinanceExportSummary({
    required this.personalExpensesCount,
    required this.personalDebtsCount,
    required this.personalBudgetsCount,
    required this.ipoAccountsCount,
    required this.ipoApplicationsCount,
    required this.trackedIposCount,
    required this.cachedIposCount,
    required this.paymentVerificationsCount,
    required this.totalRecords,
    required this.checksum,
    required this.exportedAt,
    this.savedFilePath,
  });

  Map<String, dynamic> toMap() => {
        'personalExpenses': personalExpensesCount,
        'personalDebts': personalDebtsCount,
        'personalBudgets': personalBudgetsCount,
        'ipoAccounts': ipoAccountsCount,
        'ipoApplications': ipoApplicationsCount,
        'trackedIpos': trackedIposCount,
        'cachedIpos': cachedIposCount,
        'paymentVerifications': paymentVerificationsCount,
        'totalRecords': totalRecords,
        'checksum': checksum,
        'exportedAt': exportedAt.toIso8601String(),
        'savedFilePath': savedFilePath,
      };
}

/// Service responsible for extracting personal financial records from SplitTrip
/// into a tamper-evident, versioned, checksum-protected migration bridge archive.
///
/// STRICT INVARIANTS:
/// 1. Trip expenses, trip settlements, and trip members are NEVER exported as personal finance.
/// 2. Source data is strictly read-only and never modified or deleted during export.
/// 3. All exported records preserve their canonical IDs, currency, and timestamps.
class FinanceExportBridgeService {
  final LocalStorageService storage;

  FinanceExportBridgeService({required this.storage});

  static const String bridgeSchemaVersion = 'kith_finance_bridge_v1';
  static const String bridgeExportVersion = '1.0';

  /// Deterministically computes a SHA-256 integrity checksum over the canonical JSON payload.
  static String computeChecksum(Map<String, dynamic> data) {
    final canonicalJson = jsonEncode(data);
    return sha256.convert(utf8.encode(canonicalJson)).toString();
  }

  /// Builds the structured payload dictionary containing ONLY personal finance artifacts.
  Map<String, dynamic> buildExportPayload() {
    // 1. Personal Expenses
    final personalExpenses = storage.getSavedPersonalExpenses();

    // 2. Personal Debts (Lending / Borrowing ledger)
    final personalDebts = storage.getSavedPersonalDebts();

    // 3. Budgets & Auto-budgeting preferences
    final personalBudgets = <Map<String, dynamic>>[];
    final autoBudgeting = <String, bool>{};

    final allKeys = storage.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('kith_personal_budget_')) {
        final monthYear = key.replaceFirst('kith_personal_budget_', '');
        final budget = storage.getSavedPersonalBudget(monthYear);
        if (budget != null) {
          final budgetMap = Map<String, dynamic>.from(budget);
          budgetMap['monthYear'] ??= monthYear;
          personalBudgets.add(budgetMap);
        }
      } else if (key.startsWith('kith_auto_budgeting_')) {
        final cleanKey = key.replaceFirst('kith_auto_budgeting_', '');
        final enabled = storage.getBool(key) ?? false;
        autoBudgeting[cleanKey] = enabled;
      }
    }

    // 4. IPO Guru Records
    final rawAccounts = storage.getString('kith_ipo_accounts_v1');
    final ipoAccounts = (rawAccounts != null && rawAccounts.isNotEmpty)
        ? storage.getSavedIpoAccounts()
        : <Map<String, dynamic>>[];
    final ipoApplications = storage.getSavedIpoApplications();
    final trackedIpoIds = storage.getTrackedIpoIds().toList();
    final cachedIpos = storage.getSavedIpos();
    final iposLastUpdated = storage.getIposLastUpdated()?.toIso8601String();

    // 5. Payment Verifications
    final paymentVerifications = storage.getSavedPaymentVerifications();

    // User metadata (public profile only; NO auth tokens or passwords)
    final userMap = storage.getSavedUser();
    final sourceUserId = userMap?['id'] as String? ?? 'guest';
    final sourceDisplayName = userMap?['displayName'] as String? ??
        userMap?['display_name'] as String? ??
        'Guest User';

    // Invariant Enforcement: Trip expenses or settlements must NEVER be included.
    for (final pe in personalExpenses) {
      if (pe.containsKey('tripId') || pe.containsKey('trip_id')) {
        throw StateError(
          'CRITICAL ARCHITECTURE VIOLATION: Trip-bound expense detected in personal finance export!',
        );
      }
    }

    final dataPayload = {
      'personalExpenses': personalExpenses,
      'personalDebts': personalDebts,
      'personalBudgets': personalBudgets,
      'autoBudgeting': autoBudgeting,
      'ipoAccounts': ipoAccounts,
      'ipoApplications': ipoApplications,
      'trackedIpoIds': trackedIpoIds,
      'cachedIpos': cachedIpos,
      'iposLastUpdated': iposLastUpdated,
      'paymentVerifications': paymentVerifications,
    };

    final checksum = computeChecksum(dataPayload);
    final exportedAt = DateTime.now().toUtc();

    final totalRecords = personalExpenses.length +
        personalDebts.length +
        personalBudgets.length +
        ipoAccounts.length +
        ipoApplications.length +
        trackedIpoIds.length;

    return {
      'schemaVersion': bridgeSchemaVersion,
      'exportVersion': bridgeExportVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'sourceApp': 'SplitTrip',
      'sourceUserId': sourceUserId,
      'sourceDisplayName': sourceDisplayName,
      'checksum': checksum,
      'stats': {
        'personalExpenses': personalExpenses.length,
        'personalDebts': personalDebts.length,
        'personalBudgets': personalBudgets.length,
        'ipoAccounts': ipoAccounts.length,
        'ipoApplications': ipoApplications.length,
        'trackedIpos': trackedIpoIds.length,
        'cachedIpos': cachedIpos.length,
        'paymentVerifications': paymentVerifications.length,
        'totalRecords': totalRecords,
      },
      'data': dataPayload,
    };
  }

  /// Exports the financial archive to a formatted JSON string.
  String exportToJsonString() {
    final payload = buildExportPayload();
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Exports the payload and safely writes it to a file on local storage.
  Future<({String filePath, String jsonString, FinanceExportSummary summary})>
      exportToFile({
    String? customDirectoryPath,
  }) async {
    final payload = buildExportPayload();
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final stats = payload['stats'] as Map<String, dynamic>;
    final checksum = payload['checksum'] as String;
    final exportedAt = DateTime.parse(payload['exportedAt'] as String);

    String dirPath = customDirectoryPath ?? '';
    if (dirPath.isEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${appDir.path}/exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      dirPath = exportDir.path;
    }

    final timestamp = exportedAt.millisecondsSinceEpoch;
    final file = File('$dirPath/kith_finance_migration_$timestamp.json');
    await file.writeAsString(jsonString);

    final summary = FinanceExportSummary(
      personalExpensesCount: stats['personalExpenses'] as int? ?? 0,
      personalDebtsCount: stats['personalDebts'] as int? ?? 0,
      personalBudgetsCount: stats['personalBudgets'] as int? ?? 0,
      ipoAccountsCount: stats['ipoAccounts'] as int? ?? 0,
      ipoApplicationsCount: stats['ipoApplications'] as int? ?? 0,
      trackedIposCount: stats['trackedIpos'] as int? ?? 0,
      cachedIposCount: stats['cachedIpos'] as int? ?? 0,
      paymentVerificationsCount: stats['paymentVerifications'] as int? ?? 0,
      totalRecords: stats['totalRecords'] as int? ?? 0,
      checksum: checksum,
      exportedAt: exportedAt,
      savedFilePath: file.path,
    );

    return (filePath: file.path, jsonString: jsonString, summary: summary);
  }

  /// Non-destructive check of how many personal financial records exist locally in SplitTrip.
  FinanceExportSummary inspectLocalFinancialRecords() {
    final personalExpenses = storage.getSavedPersonalExpenses();
    final personalDebts = storage.getSavedPersonalDebts();

    int budgetCount = 0;
    for (final key in storage.getKeys()) {
      if (key.startsWith('kith_personal_budget_')) {
        budgetCount++;
      }
    }

    final rawAccounts = storage.getString('kith_ipo_accounts_v1');
    final ipoAccounts = (rawAccounts != null && rawAccounts.isNotEmpty)
        ? storage.getSavedIpoAccounts()
        : <Map<String, dynamic>>[];
    final ipoApplications = storage.getSavedIpoApplications();
    final trackedIpoIds = storage.getTrackedIpoIds().toList();
    final cachedIpos = storage.getSavedIpos();
    final paymentVerifications = storage.getSavedPaymentVerifications();

    final total = personalExpenses.length +
        personalDebts.length +
        budgetCount +
        ipoAccounts.length +
        ipoApplications.length +
        trackedIpoIds.length;

    return FinanceExportSummary(
      personalExpensesCount: personalExpenses.length,
      personalDebtsCount: personalDebts.length,
      personalBudgetsCount: budgetCount,
      ipoAccountsCount: ipoAccounts.length,
      ipoApplicationsCount: ipoApplications.length,
      trackedIposCount: trackedIpoIds.length,
      cachedIposCount: cachedIpos.length,
      paymentVerificationsCount: paymentVerifications.length,
      totalRecords: total,
      checksum: '',
      exportedAt: DateTime.now(),
    );
  }
}
