import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/core/services/platform_migration_channel.dart';
import 'package:kith_app/data/services/finance_export_bridge_service.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('STAGE 5 PHYSICAL QA - SplitTrip Financial Export Suite (Device: CPH2729, Android 16)', () {
    late LocalStorageService storage;
    late FinanceExportBridgeService exportService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = LocalDatabaseService.inMemory();
      storage = LocalStorageService(prefs, databaseService: db);
      exportService = FinanceExportBridgeService(storage: storage);
    });

    testWidgets('QA-EXP-01: Create synthetic financial dataset and verify strict trip isolation', (tester) async {
      // 1. Synthetic Personal Expenses (5 records)
      final syntheticExpenses = [
        {
          'id': 'exp_qa_01',
          'title': 'Organic Groceries',
          'amountInPaise': 145000,
          'currency': 'INR',
          'category': 'food',
          'date': '2026-11-01T10:00:00.000Z',
          'createdAt': '2026-11-01T10:00:00.000Z',
        },
        {
          'id': 'exp_qa_02',
          'title': 'Electricity Bill',
          'amountInPaise': 220000,
          'currency': 'INR',
          'category': 'bills',
          'date': '2026-11-01T14:30:00.000Z',
          'createdAt': '2026-11-01T14:30:00.000Z',
        },
        {
          'id': 'exp_qa_03',
          'title': 'Medical Prescription',
          'amountInPaise': 65000,
          'currency': 'INR',
          'category': 'health',
          'date': '2026-11-02T09:15:00.000Z',
          'createdAt': '2026-11-02T09:15:00.000Z',
        },
        {
          'id': 'exp_qa_04',
          'title': 'Petrol Pump',
          'amountInPaise': 120000,
          'currency': 'INR',
          'category': 'transport',
          'date': '2026-11-02T18:00:00.000Z',
          'createdAt': '2026-11-02T18:00:00.000Z',
        },
        {
          'id': 'exp_qa_05',
          'title': 'Flutter Architecture Books',
          'amountInPaise': 89000,
          'currency': 'INR',
          'category': 'education',
          'date': '2026-11-03T11:45:00.000Z',
          'createdAt': '2026-11-03T11:45:00.000Z',
        },
      ];
      await storage.savePersonalExpenses(syntheticExpenses);

      // 2. Synthetic Personal Debts with Repayments (2 debts, 2 repayments)
      final syntheticDebts = [
        {
          'id': 'debt_qa_01',
          'personName': 'Rahul Sharma',
          'debtType': 'lent',
          'initialAmountInPaise': 500000,
          'remainingAmountInPaise': 300000,
          'description': 'Concert Tickets',
          'date': '2026-11-01T16:00:00.000Z',
          'isSettled': false,
          'repayments': [
            {
              'id': 'rep_qa_01',
              'debtId': 'debt_qa_01',
              'amountInPaise': 200000,
              'date': '2026-11-02T12:00:00.000Z',
              'note': 'GPay transfer',
            }
          ],
        },
        {
          'id': 'debt_qa_02',
          'personName': 'Priya Patel',
          'debtType': 'borrowed',
          'initialAmountInPaise': 300000,
          'remainingAmountInPaise': 200000,
          'description': 'Dinner contribution',
          'date': '2026-11-02T21:00:00.000Z',
          'isSettled': false,
          'repayments': [
            {
              'id': 'rep_qa_02',
              'debtId': 'debt_qa_02',
              'amountInPaise': 100000,
              'date': '2026-11-03T09:30:00.000Z',
              'note': 'Cash return',
            }
          ],
        },
      ];
      await storage.savePersonalDebts(syntheticDebts);

      // 3. Synthetic Monthly Budgets (2 months)
      await storage.savePersonalBudget('11_2026', {
        'monthYear': '11_2026',
        'hasBudget': true,
        'amount': 40000,
      });
      await storage.setAutoBudgetingEnabled('11_2026', true);

      await storage.savePersonalBudget('12_2026', {
        'monthYear': '12_2026',
        'hasBudget': true,
        'amount': 50000,
      });
      await storage.setAutoBudgetingEnabled('12_2026', false);

      // 4. Synthetic IPO Records
      await storage.saveIpoAccounts([
        {
          'id': 'acc_qa_01',
          'investorName': 'Darpan Primary',
          'maskedPan': 'ABCDE1234F',
          'upiId': 'darpan@okhdfcbank',
        }
      ]);
      await storage.setIpoTracked('ipo_swiggy_2026', true);

      // 5. Trip Records (MUST BE STRICTLY EXCLUDED)
      await storage.saveExpenses('trip_leh_ladakh', [
        {
          'id': 'exp_trip_bound_01',
          'tripId': 'trip_leh_ladakh',
          'title': 'Leh Hotel Stay',
          'amount': 1500000,
        }
      ]);

      // Execute Export
      final payload = exportService.buildExportPayload();

      // Invariant 1: Schema Version
      expect(payload['schemaVersion'], equals('kith_finance_bridge_v1'));
      expect(payload['sourceApp'], equals('SplitTrip'));

      // Invariant 2: Checksum Verification
      final data = payload['data'] as Map<String, dynamic>;
      final computedChecksum = FinanceExportBridgeService.computeChecksum(data);
      expect(payload['checksum'], equals(computedChecksum));

      // Invariant 3: Record Counts
      final stats = payload['stats'] as Map<String, dynamic>;
      expect(stats['personalExpenses'], equals(5));
      expect(stats['personalDebts'], equals(2));
      expect(stats['personalBudgets'], equals(2));
      expect(stats['ipoAccounts'], equals(1));
      expect(stats['trackedIpos'], equals(1));
      expect(stats['totalRecords'], equals(11));

      // Invariant 4: Zero Trip Records Exported
      final exportedExpenses = (data['personalExpenses'] as List).cast<Map<String, dynamic>>();
      for (final exp in exportedExpenses) {
        expect(exp.containsKey('tripId'), isFalse);
        expect(exp.containsKey('trip_id'), isFalse);
        expect(exp['id'], isNot(equals('exp_trip_bound_01')));
      }

      // Invariant 5: Repayments Intact
      final exportedDebts = (data['personalDebts'] as List).cast<Map<String, dynamic>>();
      final debt1 = exportedDebts.firstWhere((d) => d['id'] == 'debt_qa_01');
      expect(debt1['repayments'], isNotEmpty);
      expect((debt1['repayments'] as List).length, equals(1));
      expect(debt1['repayments'][0]['id'], equals('rep_qa_01'));

      final debt2 = exportedDebts.firstWhere((d) => d['id'] == 'debt_qa_02');
      expect(debt2['repayments'], isNotEmpty);
      expect((debt2['repayments'] as List).length, equals(1));
      expect(debt2['repayments'][0]['id'], equals('rep_qa_02'));
    });

    testWidgets('QA-EXP-02: Native Platform Channel Verification on Physical Android 16 Hardware', (tester) async {
      final isSupported = await PlatformMigrationChannel.isPlatformChannelSupported();
      // On real Android physical hardware, the platform channel responds true!
      expect(isSupported, isTrue);
    });
  });
}
