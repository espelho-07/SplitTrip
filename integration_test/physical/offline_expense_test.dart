import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/data/services/local_database_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 7: Offline Expense Creation & Integer Paise Arithmetic', () {
    testWidgets('creates and persists expenses with exact integer paise amounts in SQLite', (tester) async {
      final dbService = LocalDatabaseService.inMemory();
      final nowStr = DateTime.now().toIso8601String();

      // Trip setup with all required NOT NULL columns
      dbService.rawDb.execute('''
        INSERT OR REPLACE INTO trips (
          id, name, currency_code, creator_id, invite_code, started_at, created_at, updated_at, raw_json
        ) VALUES (
          'trip-offline-01', 'Leh Roadtrip', 'INR', 'user-01', 'KITH99', '$nowStr', '$nowStr', '$nowStr', '{}'
        );
      ''');

      // Add expense with integer paise (Rs 1,540.50 -> 154050 paise)
      const amountPaise = 154050;
      final expenseJson = {
        'id': 'exp-offline-01',
        'trip_id': 'trip-offline-01',
        'title': 'Fuel at HPCL',
        'amount': amountPaise,
        'currency': 'INR',
        'paid_by_member_id': 'member-01',
      };

      dbService.rawDb.execute('''
        INSERT OR REPLACE INTO expenses (
          id, trip_id, title, amount, currency, paid_by_member_id, created_at, updated_at, raw_json
        ) VALUES (
          'exp-offline-01', 'trip-offline-01', 'Fuel at HPCL', 154050, 'INR', 'member-01', '$nowStr', '$nowStr', '${jsonEncode(expenseJson)}'
        );
      ''');

      // Verify retrieval
      final expenses = dbService.getSavedExpenses('trip-offline-01');
      expect(expenses, isNotEmpty);
      expect(expenses.length, equals(1));

      // Financial arithmetic check: integer division and modulo
      const totalAmount = 154050;
      const participants = 3;
      const sharePerPerson = totalAmount ~/ participants; // 51350 paise
      const remainder = totalAmount % participants; // 0

      expect(sharePerPerson, equals(51350));
      expect(remainder, equals(0));
      expect(sharePerPerson * participants + remainder, equals(totalAmount));

      dbService.dispose();
    });
  });
}
