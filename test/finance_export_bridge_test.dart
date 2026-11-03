import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/finance_export_bridge_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FinanceExportBridgeService - SplitTrip Migration Bridge Tests', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
    });

    test('1. Empty export produces valid schema, stats, and checksum', () async {
      final exportService = FinanceExportBridgeService(storage: storage);
      final payload = exportService.buildExportPayload();

      expect(payload['schemaVersion'], 'kith_finance_bridge_v1');
      expect(payload['exportVersion'], '1.0');
      expect(payload['sourceApp'], 'SplitTrip');
      expect(payload['sourceUserId'], 'guest');
      expect(payload['sourceDisplayName'], 'Guest User');

      final stats = payload['stats'] as Map<String, dynamic>;
      expect(stats['personalExpenses'], 0);
      expect(stats['personalDebts'], 0);
      expect(stats['personalBudgets'], 0);
      expect(stats['totalRecords'], 0);

      final data = payload['data'] as Map<String, dynamic>;
      expect(data['personalExpenses'], isEmpty);
      expect(data['personalDebts'], isEmpty);
      expect(data['personalBudgets'], isEmpty);

      // Verify SHA-256 Checksum
      final canonicalJson = jsonEncode(data);
      final expectedChecksum =
          sha256.convert(utf8.encode(canonicalJson)).toString();
      expect(payload['checksum'], expectedChecksum);
    });

    test('2. Populated export preserves all financial entities, IDs, and metadata', () async {
      // 1. Seed personal expenses
      final sampleExpenses = [
        {
          'id': 'pexp_001',
          'userId': 'usr_alice',
          'title': 'Groceries',
          'amountInPaise': 45000,
          'category': 'groceries',
          'date': '2026-10-15T12:00:00.000Z',
          'isDeleted': false,
          'createdAt': '2026-10-15T12:00:00.000Z',
          'updatedAt': '2026-10-15T12:00:00.000Z',
        },
        {
          'id': 'pexp_002',
          'userId': 'usr_alice',
          'title': 'Electricity Bill',
          'amountInPaise': 120000,
          'category': 'utilities',
          'date': '2026-10-18T16:30:00.000Z',
          'isDeleted': false,
          'createdAt': '2026-10-18T16:30:00.000Z',
          'updatedAt': '2026-10-18T16:30:00.000Z',
        },
      ];
      await storage.savePersonalExpenses(sampleExpenses);

      // 2. Seed personal debts
      final sampleDebts = [
        {
          'id': 'pdebt_001',
          'userId': 'usr_alice',
          'personName': 'Bob',
          'debtType': 'lent',
          'initialAmountInPaise': 500000,
          'remainingAmountInPaise': 200000,
          'description': 'Office lunch payment',
          'date': '2026-10-01T10:00:00.000Z',
          'isSettled': false,
          'isDeleted': false,
          'repayments': [
            {
              'id': 'prep_001',
              'debtId': 'pdebt_001',
              'userId': 'usr_alice',
              'amountInPaise': 300000,
              'date': '2026-10-05T10:00:00.000Z',
              'note': 'UPI Transfer',
              'createdAt': '2026-10-05T10:00:00.000Z',
            }
          ],
          'createdAt': '2026-10-01T10:00:00.000Z',
          'updatedAt': '2026-10-05T10:00:00.000Z',
        }
      ];
      await storage.savePersonalDebts(sampleDebts);

      // 3. Seed personal budgets
      await storage.savePersonalBudget('2026-10', {
        'monthYear': '2026-10',
        'monthlyLimitInPaise': 5000000,
        'spentInPaise': 165000,
        'remainingInPaise': 4835000,
        'hasBudget': true,
        'percentageUsed': 3,
      });
      await storage.setAutoBudgetingEnabled('usr_alice', true);

      // 4. Seed IPO records
      await storage.saveIpoAccounts([
        {
          'id': 'acc_001',
          'displayName': 'Alice Zerodha',
          'maskedPan': 'ABCDE1234F',
          'createdAt': '2026-09-01T00:00:00.000Z',
          'updatedAt': '2026-09-01T00:00:00.000Z',
        }
      ]);
      await storage.saveIpoApplications([
        {
          'id': 'app_001',
          'ipoId': 'ipo_tata_tech',
          'accountId': 'acc_001',
          'companyName': 'Tata Tech Ltd',
          'bidLots': 1,
          'status': 'applied',
          'appliedAt': '2026-10-10T11:00:00.000Z',
        }
      ]);
      await storage.setIpoTracked('ipo_tata_tech', true);
      await storage.setIpoTracked('ipo_swiggy', true);

      // Execute export
      final exportService = FinanceExportBridgeService(storage: storage);
      final payload = exportService.buildExportPayload();

      final stats = payload['stats'] as Map<String, dynamic>;
      expect(stats['personalExpenses'], 2);
      expect(stats['personalDebts'], 1);
      expect(stats['personalBudgets'], 1);
      expect(stats['ipoAccounts'], 1);
      expect(stats['ipoApplications'], 1);
      expect(stats['trackedIpos'], 2);
      expect(stats['totalRecords'], 8);

      final data = payload['data'] as Map<String, dynamic>;
      final expenses = data['personalExpenses'] as List;
      expect(expenses.length, 2);
      expect(expenses[0]['id'], 'pexp_001');
      expect(expenses[0]['amountInPaise'], 45000);
      expect(expenses[1]['id'], 'pexp_002');

      final debts = data['personalDebts'] as List;
      expect(debts.length, 1);
      expect(debts[0]['id'], 'pdebt_001');
      expect(debts[0]['personName'], 'Bob');
      expect(debts[0]['repayments'].length, 1);

      final budgets = data['personalBudgets'] as List;
      expect(budgets.length, 1);
      expect(budgets[0]['monthYear'], '2026-10');
      expect(budgets[0]['monthlyLimitInPaise'], 5000000);

      final autoBudgeting = data['autoBudgeting'] as Map<String, dynamic>;
      expect(autoBudgeting['usr_alice'], true);

      final ipoAccounts = data['ipoAccounts'] as List;
      expect(ipoAccounts[0]['displayName'], 'Alice Zerodha');

      final trackedIds = data['trackedIpoIds'] as List;
      expect(trackedIds, containsAll(['ipo_tata_tech', 'ipo_swiggy']));

      // Integrity Checksum
      final canonicalJson = jsonEncode(data);
      final expectedChecksum =
          sha256.convert(utf8.encode(canonicalJson)).toString();
      expect(payload['checksum'], expectedChecksum);
    });

    test('3. Non-destructive: Source records in storage remain completely unmodified', () async {
      final sample = [
        {
          'id': 'pexp_persistent',
          'userId': 'usr_user',
          'title': 'Dinner',
          'amountInPaise': 80000,
          'category': 'food',
          'date': '2026-10-20T20:00:00.000Z',
          'isDeleted': false,
          'createdAt': '2026-10-20T20:00:00.000Z',
          'updatedAt': '2026-10-20T20:00:00.000Z',
        }
      ];
      await storage.savePersonalExpenses(sample);

      final exportService = FinanceExportBridgeService(storage: storage);
      exportService.buildExportPayload();

      // Check source records in storage
      final retrieved = storage.getSavedPersonalExpenses();
      expect(retrieved.length, 1);
      expect(retrieved.first['id'], 'pexp_persistent');
      expect(retrieved.first['title'], 'Dinner');
    });

    test('4. Strict Isolation: Trip expenses and group trips NEVER appear in export', () async {
      // Seed a trip and trip expenses in storage
      await storage.setString('kith_trips', jsonEncode([
        {'id': 'trip_goa_2026', 'name': 'Goa Vacation'}
      ]));
      await storage.setString('kith_expenses_trip_goa_2026', jsonEncode([
        {'id': 'exp_resort', 'tripId': 'trip_goa_2026', 'title': 'Beach Villa', 'amountPaise': 3500000}
      ]));
      await storage.setString('trip_settlements_trip_goa_2026', jsonEncode([
        {'id': 'settle_01', 'tripId': 'trip_goa_2026', 'amountPaise': 500000}
      ]));

      final exportService = FinanceExportBridgeService(storage: storage);
      final payload = exportService.buildExportPayload();

      final jsonStr = jsonEncode(payload);

      // Assert that group trip data is NEVER leaked
      expect(jsonStr.contains('Goa Vacation'), isFalse);
      expect(jsonStr.contains('trip_goa_2026'), isFalse);
      expect(jsonStr.contains('Beach Villa'), isFalse);
      expect(jsonStr.contains('settle_01'), isFalse);
      expect(payload['data'].containsKey('trips'), isFalse);
      expect(payload['data'].containsKey('expenses'), isFalse);
      expect(payload['data'].containsKey('settlements'), isFalse);
    });

    test('5. File export writes valid, indented, checksum-verified JSON file', () async {
      await storage.savePersonalExpenses([
        {
          'id': 'pexp_file_test',
          'userId': 'usr_file',
          'title': 'Book',
          'amountInPaise': 50000,
          'category': 'education',
          'date': '2026-10-21T10:00:00.000Z',
          'isDeleted': false,
          'createdAt': '2026-10-21T10:00:00.000Z',
          'updatedAt': '2026-10-21T10:00:00.000Z',
        }
      ]);

      final tempDir = await Directory.systemTemp.createTemp('splittrip_bridge_test_');
      try {
        final exportService = FinanceExportBridgeService(storage: storage);
        final result = await exportService.exportToFile(customDirectoryPath: tempDir.path);

        expect(File(result.filePath).existsSync(), isTrue);
        final fileContent = await File(result.filePath).readAsString();
        final decoded = jsonDecode(fileContent) as Map<String, dynamic>;

        expect(decoded['schemaVersion'], 'kith_finance_bridge_v1');
        expect(decoded['checksum'], result.summary.checksum);
        expect(result.summary.personalExpensesCount, 1);
        expect(result.summary.totalRecords, 1);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
