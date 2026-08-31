import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';

class MockRestartHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  MockRestartHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final res = await handler(req);
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trip Expense Persistence & App Restart Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('1. Adding 3 expenses persists across app restart and cold reload', () async {
      // --- Session 1: App Open ---
      final storage1 = LocalStorageService(prefs);
      final sync1 = SyncService(storage1);
      final client1 = ApiClient(httpClient: MockRestartHttpClient((req) async => http.Response('[]', 200)));
      final repo1 = ExpenseRepository(storage: storage1, syncService: sync1, apiClient: client1);

      final now = DateTime.now();

      final exp1 = Expense(
        id: 'exp_001',
        tripId: 'trip_goa_99',
        title: 'Fishermans Wharf Dinner',
        amountInPaise: 240000,
        category: ExpenseCategory.food,
        paidById: 'mem_hardev',
        splits: [
          const ExpenseSplit(memberId: 'mem_hardev', amountInPaise: 120000),
          const ExpenseSplit(memberId: 'mem_alice', amountInPaise: 120000),
        ],
        splitType: SplitType.equal,
        createdAt: now.subtract(const Duration(minutes: 10)),
        updatedAt: now.subtract(const Duration(minutes: 10)),
      );

      final exp2 = Expense(
        id: 'exp_002',
        tripId: 'trip_goa_99',
        title: 'Beach Scooters Rental',
        amountInPaise: 150000,
        category: ExpenseCategory.transport,
        paidById: 'mem_hardev',
        splits: [
          const ExpenseSplit(memberId: 'mem_hardev', amountInPaise: 75000),
          const ExpenseSplit(memberId: 'mem_alice', amountInPaise: 75000),
        ],
        splitType: SplitType.equal,
        createdAt: now.subtract(const Duration(minutes: 5)),
        updatedAt: now.subtract(const Duration(minutes: 5)),
      );

      final exp3 = Expense(
        id: 'exp_003',
        tripId: 'trip_goa_99',
        title: 'Late Night Gelato',
        amountInPaise: 45000,
        category: ExpenseCategory.food,
        paidById: 'mem_alice',
        splits: [
          const ExpenseSplit(memberId: 'mem_hardev', amountInPaise: 22500),
          const ExpenseSplit(memberId: 'mem_alice', amountInPaise: 22500),
        ],
        splitType: SplitType.equal,
        createdAt: now,
        updatedAt: now,
      );

      await repo1.addExpense(exp1);
      await repo1.addExpense(exp2);
      await repo1.addExpense(exp3);

      expect(repo1.getCachedExpenses('trip_goa_99').length, 3);

      // --- Session 2: App Killed & Reopened (Cold Start Simulation) ---
      final storage2 = LocalStorageService(prefs);
      final sync2 = SyncService(storage2);
      // Server returns empty list or offline -> local persistence must NOT be clobbered
      final client2 = ApiClient(httpClient: MockRestartHttpClient((req) async => http.Response('[]', 200)));
      final repo2 = ExpenseRepository(storage: storage2, syncService: sync2, apiClient: client2);

      // 1. Synchronous cold cache hydration
      final cachedOnStartup = repo2.getCachedExpenses('trip_goa_99');
      expect(cachedOnStartup.length, 3);
      expect(cachedOnStartup.map((e) => e.id), containsAll(['exp_001', 'exp_002', 'exp_003']));

      // 2. Asynchronous getExpenses call with empty remote response
      final reloaded = await repo2.getExpenses('trip_goa_99');
      expect(reloaded.length, 3);
      expect(reloaded.any((e) => e.title == 'Fishermans Wharf Dinner'), isTrue);
      expect(reloaded.any((e) => e.title == 'Beach Scooters Rental'), isTrue);
      expect(reloaded.any((e) => e.title == 'Late Night Gelato'), isTrue);
    });

    test('2. Editing an expense persists across app restart', () async {
      final storage1 = LocalStorageService(prefs);
      final sync1 = SyncService(storage1);
      final client1 = ApiClient(httpClient: MockRestartHttpClient((req) async => http.Response('[]', 200)));
      final repo1 = ExpenseRepository(storage: storage1, syncService: sync1, apiClient: client1);
      final now = DateTime.now();

      final exp = Expense(
        id: 'exp_edit_test',
        tripId: 'trip_manali_101',
        title: 'Original Title',
        amountInPaise: 100000,
        category: ExpenseCategory.food,
        paidById: 'mem_1',
        splits: [const ExpenseSplit(memberId: 'mem_1', amountInPaise: 100000)],
        splitType: SplitType.equal,
        createdAt: now,
        updatedAt: now,
      );
      await repo1.addExpense(exp);

      // Edit expense
      final updated = exp.copyWith(
        title: 'Edited Special Buffet Dinner',
        amountInPaise: 180000,
        splits: [const ExpenseSplit(memberId: 'mem_1', amountInPaise: 180000)],
      );
      await repo1.updateExpense(updated);

      // Cold Restart
      final storage2 = LocalStorageService(prefs);
      final sync2 = SyncService(storage2);
      final repo2 = ExpenseRepository(storage: storage2, syncService: sync2, apiClient: client1);

      final loaded = await repo2.getExpenses('trip_manali_101');
      expect(loaded.length, 1);
      expect(loaded.first.title, 'Edited Special Buffet Dinner');
      expect(loaded.first.amountInPaise, 180000);
    });

    test('3. Deleting an expense persists deletion across app restart', () async {
      final storage1 = LocalStorageService(prefs);
      final sync1 = SyncService(storage1);
      final client1 = ApiClient(httpClient: MockRestartHttpClient((req) async => http.Response('[]', 200)));
      final repo1 = ExpenseRepository(storage: storage1, syncService: sync1, apiClient: client1);
      final now = DateTime.now();

      final exp1 = Expense(
        id: 'exp_del_1',
        tripId: 'trip_kerala_1',
        title: 'Boat Ride',
        amountInPaise: 50000,
        category: ExpenseCategory.activities,
        paidById: 'mem_1',
        splits: [const ExpenseSplit(memberId: 'mem_1', amountInPaise: 50000)],
        splitType: SplitType.equal,
        createdAt: now,
        updatedAt: now,
      );
      final exp2 = Expense(
        id: 'exp_del_2',
        tripId: 'trip_kerala_1',
        title: 'Tea Estate Visit',
        amountInPaise: 20000,
        category: ExpenseCategory.activities,
        paidById: 'mem_1',
        splits: [const ExpenseSplit(memberId: 'mem_1', amountInPaise: 20000)],
        splitType: SplitType.equal,
        createdAt: now,
        updatedAt: now,
      );
      await repo1.addExpense(exp1);
      await repo1.addExpense(exp2);

      // Delete exp1
      await repo1.deleteExpense(tripId: 'trip_kerala_1', expenseId: 'exp_del_1');

      // Cold Restart
      final storage2 = LocalStorageService(prefs);
      final sync2 = SyncService(storage2);
      final repo2 = ExpenseRepository(storage: storage2, syncService: sync2, apiClient: client1);

      final remaining = await repo2.getExpenses('trip_kerala_1');
      expect(remaining.length, 1);
      expect(remaining.first.id, 'exp_del_2');
    });

    test('4. Multi-trip isolation: Trip A expenses vs Trip B expenses do not cross-contaminate', () async {
      final storage = LocalStorageService(prefs);
      final sync = SyncService(storage);
      final client = ApiClient(httpClient: MockRestartHttpClient((req) async => http.Response('[]', 200)));
      final repo = ExpenseRepository(storage: storage, syncService: sync, apiClient: client);
      final now = DateTime.now();

      final expA1 = Expense(
        id: 'exp_a1',
        tripId: 'trip_a',
        title: 'Trip A Expense 1',
        amountInPaise: 10000,
        category: ExpenseCategory.general,
        paidById: 'm1',
        splits: [const ExpenseSplit(memberId: 'm1', amountInPaise: 10000)],
        splitType: SplitType.equal,
        createdAt: now,
        updatedAt: now,
      );
      final expB1 = Expense(
        id: 'exp_b1',
        tripId: 'trip_b',
        title: 'Trip B Expense 1',
        amountInPaise: 20000,
        category: ExpenseCategory.general,
        paidById: 'm2',
        splits: [const ExpenseSplit(memberId: 'm2', amountInPaise: 20000)],
        splitType: SplitType.equal,
        createdAt: now,
        updatedAt: now,
      );

      await repo.addExpense(expA1);
      await repo.addExpense(expB1);

      // Cold Restart
      final storage2 = LocalStorageService(prefs);
      final sync2 = SyncService(storage2);
      final repo2 = ExpenseRepository(storage: storage2, syncService: sync2, apiClient: client);

      final listA = await repo2.getExpenses('trip_a');
      final listB = await repo2.getExpenses('trip_b');

      expect(listA.map((e) => e.id), ['exp_a1']);
      expect(listB.map((e) => e.id), ['exp_b1']);
    });
  });
}
