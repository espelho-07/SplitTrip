import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense_split.dart';

void main() {
  group('Guest-First Multi-Trip & Local Persistence Tests', () {
    late LocalStorageService storage;
    late SyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      syncService = SyncService(storage);
    });

    test('1. Guest session persists locally across app restarts', () async {
      final guest = GuestUser(
        id: 'usr_abc123456789',
        displayName: 'Darpan',
        recoveryKey: 'KITH-WXYZ-7890',
        anonymousToken: 'kith_sess_999999',
        createdAt: DateTime.now(),
      );

      await storage.saveUser(guest.toJson());

      // Simulate app cold restart
      final restoredJson = storage.getSavedUser();
      expect(restoredJson, isNotNull);
      final restoredGuest = GuestUser.fromJson(restoredJson!);
      expect(restoredGuest.id, 'usr_abc123456789');
      expect(restoredGuest.displayName, 'Darpan');
      expect(restoredGuest.recoveryKey, 'KITH-WXYZ-7890');
    });

    test('2. Multiple trips can be saved and retrieved without artificial limits', () async {
      final trips = List.generate(
        12,
        (i) => Trip(
          id: 'trip_$i',
          name: 'Trip Number $i',
          emoji: '🏖️',
          coverGradientIndex: i % 4,
          currencyCode: 'INR',
          creatorId: 'usr_abc123456789',
          inviteCode: 'CODE$i',
          members: [
            TripMember(
              id: 'mbr_$i',
              userId: 'usr_abc123456789',
              displayName: 'Darpan',
              role: 'creator',
              joinedAt: DateTime.now(),
            ),
          ],
          lifecycleState: TripLifecycle.active,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await storage.saveTrips(trips.map((t) => t.toJson()).toList());

      final loaded = storage.getSavedTrips();
      expect(loaded.length, 12);
      expect(loaded[0]['id'], 'trip_0');
      expect(loaded[11]['id'], 'trip_11');
    });

    test('3. Expenses for Trip A are isolated from Trip B in local persistence', () async {
      final expenseA = Expense(
        id: 'exp_a1',
        tripId: 'trip_A',
        title: 'Train to Goa',
        amountInPaise: 600000,
        paidById: 'mbr_1',
        category: ExpenseCategory.transport,
        splitType: SplitType.equal,
        splits: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final expenseB = Expense(
        id: 'exp_b1',
        tripId: 'trip_B',
        title: 'Dinner in Manali',
        amountInPaise: 120000,
        paidById: 'mbr_2',
        category: ExpenseCategory.food,
        splitType: SplitType.equal,
        splits: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.saveExpenses('trip_A', [expenseA.toJson()]);
      await storage.saveExpenses('trip_B', [expenseB.toJson()]);

      final tripAExpenses = storage.getSavedExpenses('trip_A');
      final tripBExpenses = storage.getSavedExpenses('trip_B');

      expect(tripAExpenses.length, 1);
      expect(tripAExpenses[0]['title'], 'Train to Goa');

      expect(tripBExpenses.length, 1);
      expect(tripBExpenses[0]['title'], 'Dinner in Manali');

      // Verify no cross-talk
      expect(storage.getSavedExpenses('trip_C').isEmpty, isTrue);
    });

    test('4. Offline mutation queue tracks mutations with exact trip scoping', () async {
      await syncService.enqueueMutation(MutationType.addExpense, {
        'tripId': 'trip_A',
        'title': 'Coffee',
        'amountInPaise': 30000,
      });

      await syncService.enqueueMutation(MutationType.addExpense, {
        'tripId': 'trip_B',
        'title': 'Taxi',
        'amountInPaise': 50000,
      });

      final queue = syncService.getPendingMutations();
      expect(queue.length, 2);
      expect(queue[0].payload['tripId'], 'trip_A');
      expect(queue[1].payload['tripId'], 'trip_B');
    });

    test('5. AppExperienceMode persists correctly and defaults to all modules', () async {
      expect(storage.getSavedAppExperienceMode(), isNull);

      await storage.saveAppExperienceMode('trips_only');
      expect(storage.getSavedAppExperienceMode(), 'trips_only');

      await storage.saveAppExperienceMode('all');
      expect(storage.getSavedAppExperienceMode(), 'all');
    });

    test('6. Member total spend consumption isolates individual split shares from payer amount', () {
      // Expense 1: Rahul paid ₹300, split ₹100 each across all 3
      final exp1 = Expense(
        id: 'exp_1',
        tripId: 'trip_1',
        title: 'Snacks',
        amountInPaise: 30000,
        paidById: 'mbr_1',
        category: ExpenseCategory.food,
        splits: [
          const ExpenseSplit(memberId: 'mbr_1', amountInPaise: 10000),
          const ExpenseSplit(memberId: 'mbr_2', amountInPaise: 10000),
          const ExpenseSplit(memberId: 'mbr_3', amountInPaise: 10000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Expense 2: Priya paid ₹200, but only Rahul and Priya were in it (₹100 each)
      final exp2 = Expense(
        id: 'exp_2',
        tripId: 'trip_1',
        title: 'Taxi',
        amountInPaise: 20000,
        paidById: 'mbr_2',
        category: ExpenseCategory.transport,
        splits: [
          const ExpenseSplit(memberId: 'mbr_1', amountInPaise: 10000),
          const ExpenseSplit(memberId: 'mbr_2', amountInPaise: 10000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final expenses = [exp1, exp2];

      // Calculate consumed spend for Rahul (mbr_1): ₹100 + ₹100 = ₹200 (even though Rahul paid ₹300 out of pocket)
      int rahulConsumed = 0;
      for (final e in expenses) {
        final s = e.splits.where((sp) => sp.memberId == 'mbr_1').firstOrNull;
        if (s != null) rahulConsumed += s.amountInPaise;
      }
      expect(rahulConsumed, 20000); // ₹200

      // Calculate consumed spend for Darpan (mbr_3): ₹100 (only part of exp1)
      int darpanConsumed = 0;
      for (final e in expenses) {
        final s = e.splits.where((sp) => sp.memberId == 'mbr_3').firstOrNull;
        if (s != null) darpanConsumed += s.amountInPaise;
      }
      expect(darpanConsumed, 10000); // ₹100
    });
  });
}
