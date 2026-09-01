import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('3-Device Offline Convergence & Data Consistency Suite (Rule 54)', () {
    late LocalStorageService storageA;
    late SyncService syncA;

    late LocalStorageService storageB;
    late SyncService syncB;

    late LocalStorageService storageC;
    late SyncService syncC;

    const tripId = 'trip_goa_multi_2026';
    final now = DateTime(2026, 8, 30, 8, 0);
    final memberA = TripMember(id: 'mbr_a', userId: 'usr_a', displayName: 'Alice', joinedAt: now);
    final memberB = TripMember(id: 'mbr_b', userId: 'usr_b', displayName: 'Bob', joinedAt: now);
    final memberC = TripMember(id: 'mbr_c', userId: 'usr_c', displayName: 'Charlie', joinedAt: now);
    final allMembers = [memberA, memberB, memberC];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefsA = await SharedPreferences.getInstance();
      storageA = LocalStorageService(prefsA);
      syncA = SyncService(storageA);

      // Create isolated storage mock instances for Device B and C
      final mapB = <String, Object>{};
      SharedPreferences.setMockInitialValues(mapB);
      final prefsB = await SharedPreferences.getInstance();
      storageB = LocalStorageService(prefsB);
      syncB = SyncService(storageB);

      final mapC = <String, Object>{};
      SharedPreferences.setMockInitialValues(mapC);
      final prefsC = await SharedPreferences.getInstance();
      storageC = LocalStorageService(prefsC);
      syncC = SyncService(storageC);

      // Pre-save shared trip on all 3 devices
      final tripMap = {
        'id': tripId,
        'name': 'Goa Trip 2026',
        'inviteCode': 'GOA2026',
      };
      await storageA.saveTrips([tripMap]);
      await storageB.saveTrips([tripMap]);
      await storageC.saveTrips([tripMap]);
    });

    test('All 3 devices converge to identical 12 expenses and exact same balance totals', () async {
      // ── Step 1: Device A creates 5 expenses offline ─────────────────────────
      final expensesA = <Expense>[];
      for (int i = 1; i <= 5; i++) {
        final exp = Expense(
          id: 'exp_a_$i',
          tripId: tripId,
          title: 'Alice Expense $i',
          amountInPaise: 30000 * i, // ₹300, ₹600, ₹900, ₹1200, ₹1500
          category: ExpenseCategory.food,
          paidById: 'mbr_a',
          splits: [
            ExpenseSplit(memberId: 'mbr_a', amountInPaise: 10000 * i),
            ExpenseSplit(memberId: 'mbr_b', amountInPaise: 10000 * i),
            ExpenseSplit(memberId: 'mbr_c', amountInPaise: 10000 * i),
          ],
          createdAt: DateTime(2026, 8, 30, 10, i),
          updatedAt: DateTime(2026, 8, 30, 10, i),
        );
        expensesA.add(exp);
        await syncA.enqueueMutation(MutationType.addExpense, exp.toJson(), idempotencyKey: exp.id);
        final list = storageA.getSavedExpenses(tripId);
        list.insert(0, exp.toJson());
        await storageA.saveExpenses(tripId, list);
      }

      // ── Step 2: Device B creates 3 expenses offline ─────────────────────────
      final expensesB = <Expense>[];
      for (int i = 1; i <= 3; i++) {
        final exp = Expense(
          id: 'exp_b_$i',
          tripId: tripId,
          title: 'Bob Expense $i',
          amountInPaise: 60000 * i, // ₹600, ₹1200, ₹1800
          category: ExpenseCategory.transport,
          paidById: 'mbr_b',
          splits: [
            ExpenseSplit(memberId: 'mbr_a', amountInPaise: 20000 * i),
            ExpenseSplit(memberId: 'mbr_b', amountInPaise: 20000 * i),
            ExpenseSplit(memberId: 'mbr_c', amountInPaise: 20000 * i),
          ],
          createdAt: DateTime(2026, 8, 30, 11, i),
          updatedAt: DateTime(2026, 8, 30, 11, i),
        );
        expensesB.add(exp);
        await syncB.enqueueMutation(MutationType.addExpense, exp.toJson(), idempotencyKey: exp.id);
        final list = storageB.getSavedExpenses(tripId);
        list.insert(0, exp.toJson());
        await storageB.saveExpenses(tripId, list);
      }

      // ── Step 3: Device C creates 4 expenses offline ─────────────────────────
      final expensesC = <Expense>[];
      for (int i = 1; i <= 4; i++) {
        final exp = Expense(
          id: 'exp_c_$i',
          tripId: tripId,
          title: 'Charlie Expense $i',
          amountInPaise: 90000 * i, // ₹900, ₹1800, ₹2700, ₹3600
          category: ExpenseCategory.activities,
          paidById: 'mbr_c',
          splits: [
            ExpenseSplit(memberId: 'mbr_a', amountInPaise: 30000 * i),
            ExpenseSplit(memberId: 'mbr_b', amountInPaise: 30000 * i),
            ExpenseSplit(memberId: 'mbr_c', amountInPaise: 30000 * i),
          ],
          createdAt: DateTime(2026, 8, 30, 12, i),
          updatedAt: DateTime(2026, 8, 30, 12, i),
        );
        expensesC.add(exp);
        await syncC.enqueueMutation(MutationType.addExpense, exp.toJson(), idempotencyKey: exp.id);
        final list = storageC.getSavedExpenses(tripId);
        list.insert(0, exp.toJson());
        await storageC.saveExpenses(tripId, list);
      }

      // Initial counts before sync: A=5, B=3, C=4
      expect(storageA.getSavedExpenses(tripId).length, equals(5));
      expect(storageB.getSavedExpenses(tripId).length, equals(3));
      expect(storageC.getSavedExpenses(tripId).length, equals(4));

      // ── Step 4: Nearby Sync Exchange Phase 1: Device A ↔ Device B ───────────
      final mutsA = syncA.getPendingMutationsForTrip(tripId);
      for (final m in mutsA) {
        await syncB.applyRemoteP2PMutation(m, storageB);
      }
      final mutsB = syncB.getPendingMutationsForTrip(tripId);
      for (final m in mutsB) {
        await syncA.applyRemoteP2PMutation(m, storageA);
      }

      // After A ↔ B sync: A and B both have 8 expenses (5 from A + 3 from B)
      expect(storageA.getSavedExpenses(tripId).length, equals(8));
      expect(storageB.getSavedExpenses(tripId).length, equals(8));

      // ── Step 5: Nearby Sync Exchange Phase 2: Device B ↔ Device C ───────────
      final mutsB2 = syncB.getPendingMutationsForTrip(tripId);
      for (final m in mutsB2) {
        await syncC.applyRemoteP2PMutation(m, storageC);
      }
      final mutsC = syncC.getPendingMutationsForTrip(tripId);
      for (final m in mutsC) {
        await syncB.applyRemoteP2PMutation(m, storageB);
      }

      // After B ↔ C sync: Device B and Device C both have 12 expenses!
      expect(storageB.getSavedExpenses(tripId).length, equals(12));
      expect(storageC.getSavedExpenses(tripId).length, equals(12));

      // ── Step 6: Final Hop: Device C ↔ Device A ──────────────────────────────
      final mutsC2 = syncC.getPendingMutationsForTrip(tripId);
      for (final m in mutsC2) {
        await syncA.applyRemoteP2PMutation(m, storageA);
      }

      // ── Step 7: RECONCILIATION VERIFICATION ─────────────────────────────────
      final listA = storageA.getSavedExpenses(tripId).map((e) => Expense.fromJson(e)).toList();
      final listB = storageB.getSavedExpenses(tripId).map((e) => Expense.fromJson(e)).toList();
      final listC = storageC.getSavedExpenses(tripId).map((e) => Expense.fromJson(e)).toList();

      expect(listA.length, equals(12), reason: 'Device A must have all 12 expenses');
      expect(listB.length, equals(12), reason: 'Device B must have all 12 expenses');
      expect(listC.length, equals(12), reason: 'Device C must have all 12 expenses');

      final idsA = listA.map((e) => e.id).toSet();
      final idsB = listB.map((e) => e.id).toSet();
      final idsC = listC.map((e) => e.id).toSet();

      expect(idsA, equals(idsB), reason: 'Device A and B expense IDs must be identical');
      expect(idsB, equals(idsC), reason: 'Device B and C expense IDs must be identical');

      // Calculate total spent across all devices
      final totalA = listA.fold<int>(0, (sum, e) => sum + e.amountInPaise);
      final totalB = listB.fold<int>(0, (sum, e) => sum + e.amountInPaise);
      final totalC = listC.fold<int>(0, (sum, e) => sum + e.amountInPaise);

      expect(totalA, equals(totalB));
      expect(totalB, equals(totalC));
      // Total calculation:
      // A: 300 + 600 + 900 + 1200 + 1500 = 450000 (₹4,500)
      // B: 600 + 1200 + 1800 = 360000 (₹3,600)
      // C: 900 + 1800 + 2700 + 3600 = 900000 (₹9,000)
      // Total = 4500 + 3600 + 9000 = ₹17,100 (1710000 paise)
      expect(totalA, equals(1710000));

      // Calculate Person Balances on all 3 devices
      final balA = BalanceEngine.calculateBalances(
        members: allMembers,
        expenses: listA,
        settlements: const [],
        currentUserId: 'usr_a',
      );
      final balB = BalanceEngine.calculateBalances(
        members: allMembers,
        expenses: listB,
        settlements: const [],
        currentUserId: 'usr_b',
      );
      final balC = BalanceEngine.calculateBalances(
        members: allMembers,
        expenses: listC,
        settlements: const [],
        currentUserId: 'usr_c',
      );

      expect(balA.totalTripSpentInPaise, equals(1710000));
      expect(balB.totalTripSpentInPaise, equals(1710000));
      expect(balC.totalTripSpentInPaise, equals(1710000));

      // Re-applying any duplicate operation is completely idempotent
      for (final m in mutsA) {
        final appliedAgain = await syncA.applyRemoteP2PMutation(m, storageA);
        expect(appliedAgain, isFalse);
      }
      expect(storageA.getSavedExpenses(tripId).length, equals(12), reason: 'Duplicate operations must never create duplicate expenses');
    });
  });
}
