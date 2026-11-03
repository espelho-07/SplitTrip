import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDatabaseService - SplitTrip Singleton & Column Persistence Tests', () {
    late LocalDatabaseService dbService;

    setUp(() {
      LocalDatabaseService.resetStaticInstance();
      dbService = LocalDatabaseService.inMemory();
    });

    tearDown(() {
      dbService.dispose();
      LocalDatabaseService.resetStaticInstance();
    });

    test('resetStaticInstance and dispose correctly reset static handle state', () {
      expect(dbService.isDisposed, isFalse);
      dbService.dispose();
      expect(dbService.isDisposed, isTrue);

      LocalDatabaseService.resetStaticInstance();
      final newDb = LocalDatabaseService.inMemory();
      expect(newDb.isDisposed, isFalse);
      newDb.dispose();
    });

    test('commitAtomicMutationBatch correctly populates amount and spent_at from amountInPaise and date', () {
      final success = dbService.commitAtomicMutationBatch(
        updatedPersonalExpenses: [
          {
            'id': 'exp_split_01',
            'title': 'Flight Tickets',
            'amountInPaise': 450000, // 4500.00 INR
            'currency': 'INR',
            'category': 'travel',
            'date': '2026-11-01T12:00:00.000Z',
          },
        ],
      );

      expect(success, isTrue);

      final rows = dbService.rawDb.select(
        'SELECT id, title, amount, currency, category, spent_at, raw_json FROM personal_expenses WHERE id = ?',
        ['exp_split_01'],
      );

      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['id'], equals('exp_split_01'));
      expect(row['amount'], equals(4500.00));
      expect(row['spent_at'], equals('2026-11-01T12:00:00.000Z'));
    });

    test('commitAtomicMutationBatch correctly populates debt amount and is_owed_by_me mapping', () {
      final success = dbService.commitAtomicMutationBatch(
        updatedPersonalDebts: [
          {
            'id': 'debt_split_01',
            'personName': 'Priya',
            'debtType': 'borrowed', // Owed by me
            'initialAmountInPaise': 300000, // 3000.00 INR
            'isSettled': false,
          },
          {
            'id': 'debt_split_02',
            'personName': 'Rohan',
            'debtType': 'lent', // Lent by me
            'initialAmountInPaise': 120000, // 1200.00 INR
            'isSettled': true,
          },
        ],
      );

      expect(success, isTrue);

      final borrowedRows = dbService.rawDb.select(
        'SELECT id, person_name, amount, is_owed_by_me, is_settled FROM personal_debts WHERE id = ?',
        ['debt_split_01'],
      );
      expect(borrowedRows.length, equals(1));
      final bRow = borrowedRows.first;
      expect(bRow['amount'], equals(3000.00));
      expect(bRow['is_owed_by_me'], equals(1));
      expect(bRow['is_settled'], equals(0));

      final lentRows = dbService.rawDb.select(
        'SELECT id, person_name, amount, is_owed_by_me, is_settled FROM personal_debts WHERE id = ?',
        ['debt_split_02'],
      );
      expect(lentRows.length, equals(1));
      final lRow = lentRows.first;
      expect(lRow['amount'], equals(1200.00));
      expect(lRow['is_owed_by_me'], equals(0));
      expect(lRow['is_settled'], equals(1));
    });

    test('savePersonalExpensesAndDebts commits both expenses and debts in single atomic batch', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs, databaseService: dbService);

      final committed = await storage.savePersonalExpensesAndDebts(
        expensesJson: [
          {
            'id': 'exp_unified_02',
            'title': 'Dinner Split',
            'amountInPaise': 240000,
            'date': '2026-11-02T21:00:00.000Z',
          }
        ],
        debtsJson: [
          {
            'id': 'debt_unified_02',
            'personName': 'Ananya',
            'debtType': 'lent',
            'initialAmountInPaise': 120000,
            'isSettled': false,
          }
        ],
      );

      expect(committed, isTrue);

      final expRows = dbService.rawDb.select('SELECT id, amount FROM personal_expenses WHERE id = ?', ['exp_unified_02']);
      expect(expRows.length, equals(1));
      expect(expRows.first['amount'], equals(2400.00));

      final debtRows = dbService.rawDb.select('SELECT id, amount, is_owed_by_me FROM personal_debts WHERE id = ?', ['debt_unified_02']);
      expect(debtRows.length, equals(1));
      expect(debtRows.first['amount'], equals(1200.00));
      expect(debtRows.first['is_owed_by_me'], equals(0));
    });
  });
}
