import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
    apiClient = ApiClient();
    tripRepo = TripRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    expenseRepo = ExpenseRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );

    // Seed mock trips & expenses
    final mockTrips = List.generate(
      10,
      (i) => Trip(
        id: 'trip_$i',
        name: 'Goa Trip $i',
        creatorId: 'user_owner',
        inviteCode: 'GOA00$i',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        members: List.generate(
          10,
          (m) => TripMember(
            id: 'mbr_${i}_$m',
            userId: m < 5 ? 'usr_$m' : 'unclaimed_$m',
            displayName: 'Friend $m',
            joinedAt: DateTime.now(),
            isVirtualMember: m >= 5,
            isClaimed: m < 5,
          ),
        ),
      ),
    );
    await storage.saveTrips(mockTrips.map((t) => t.toJson()).toList().cast<Map<String, dynamic>>());

    for (int i = 0; i < 10; i++) {
      final mockExpenses = List.generate(
        20,
        (e) => Expense(
          id: 'exp_${i}_$e',
          tripId: 'trip_$i',
          title: 'Expense $e',
          category: ExpenseCategory.food,
          amountInPaise: (e + 1) * 10000,
          paidById: 'usr_0',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          splits: const [],
        ),
      );
      await storage.saveExpenses(
        'trip_$i',
        mockExpenses.map((e) => e.toJson()).toList().cast<Map<String, dynamic>>(),
      );
    }
  });

  test('Benchmark cached trips & expenses retrieval latency', () {
    // Warm up
    tripRepo.getCachedTrips();
    expenseRepo.getCachedExpenses('trip_0');

    final stopwatchTrips = Stopwatch()..start();
    for (int i = 0; i < 500; i++) {
      final trips = tripRepo.getCachedTrips();
      expect(trips.length, 10);
    }
    stopwatchTrips.stop();
    final tripsTimeMs = stopwatchTrips.elapsedMilliseconds;

    final stopwatchExpenses = Stopwatch()..start();
    for (int i = 0; i < 500; i++) {
      final expenses = expenseRepo.getCachedExpenses('trip_0');
      expect(expenses.length, 20);
    }
    stopwatchExpenses.stop();
    final expensesTimeMs = stopwatchExpenses.elapsedMilliseconds;

    // ignore: avoid_print
    print('BENCHMARK_RESULT: trips_500_iters=${tripsTimeMs}ms, expenses_500_iters=${expensesTimeMs}ms');
  });
}
