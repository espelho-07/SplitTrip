import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/utils/currency_formatter.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KITH Official Trip Sprint — P0 Multi-Device Offline Sync & Convergence', () {
    late LocalStorageService storageA;
    late LocalStorageService storageB;
    late SyncService syncServiceA;
    late SyncService syncServiceB;
    late ApiClient apiClientA;
    late ApiClient apiClientB;
    late ExpenseRepository expenseRepoA;
    late ExpenseRepository expenseRepoB;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefsA = await SharedPreferences.getInstance();
      storageA = LocalStorageService(prefsA);

      SharedPreferences.setMockInitialValues({});
      final prefsB = await SharedPreferences.getInstance();
      storageB = LocalStorageService(prefsB);

      apiClientA = ApiClient();
      apiClientB = ApiClient();

      syncServiceA = SyncService(storageA);
      syncServiceB = SyncService(storageB);

      expenseRepoA = ExpenseRepository(
        storage: storageA,
        syncService: syncServiceA,
        apiClient: apiClientA,
      );
      expenseRepoB = ExpenseRepository(
        storage: storageB,
        syncService: syncServiceB,
        apiClient: apiClientB,
      );
    });

    test('1. Bidirectional Offline P2P Sync: Phone A adds Hotel (₹30,000) & Phone B adds Dinner (₹7,500) -> Both converge to ₹37,500', () async {
      const tripId = 'trip_goa_2026';
      final now = DateTime.now();

      // Device A offline: Adds Hotel ₹30,000 (3,000,000 paise)
      final hotelExpense = Expense(
        id: 'exp_hotel_phone_a',
        tripId: tripId,
        title: 'Taj Hotel Stay',
        amountInPaise: 3000000,
        category: ExpenseCategory.stay,
        location: 'Taj Fort Aguada',
        paidById: 'member_user_a',
        splits: const [
          ExpenseSplit(memberId: 'member_user_a', amountInPaise: 1500000),
          ExpenseSplit(memberId: 'member_user_b', amountInPaise: 1500000),
        ],
        splitType: SplitType.equal,
        createdAt: now,
        updatedAt: now,
      );
      await expenseRepoA.addExpense(hotelExpense);

      // Device B offline: Adds Dinner ₹7,500 (750,000 paise)
      final dinnerExpense = Expense(
        id: 'exp_dinner_phone_b',
        tripId: tripId,
        title: 'Fisherman Wharf Dinner',
        amountInPaise: 750000,
        category: ExpenseCategory.food,
        location: 'Fisherman Wharf',
        paidById: 'member_user_b',
        splits: const [
          ExpenseSplit(memberId: 'member_user_a', amountInPaise: 375000),
          ExpenseSplit(memberId: 'member_user_b', amountInPaise: 375000),
        ],
        splitType: SplitType.equal,
        createdAt: now.add(const Duration(minutes: 5)),
        updatedAt: now.add(const Duration(minutes: 5)),
      );
      await expenseRepoB.addExpense(dinnerExpense);

      // Verify isolated offline states before P2P exchange
      final initialA = expenseRepoA.getCachedExpenses(tripId);
      final initialB = expenseRepoB.getCachedExpenses(tripId);
      expect(initialA.length, equals(1));
      expect(initialB.length, equals(1));
      expect(initialA.first.amountInPaise, equals(3000000));
      expect(initialB.first.amountInPaise, equals(750000));

      // Simulate P2P Sync exchange: Phone A mutations -> Phone B
      final mutationsA = syncServiceA.getPendingMutationsForTrip(tripId);
      for (final m in mutationsA) {
        await syncServiceB.applyRemoteP2PMutation(m, storageB);
      }

      // Simulate P2P Sync exchange: Phone B mutations -> Phone A
      final mutationsB = syncServiceB.getPendingMutationsForTrip(tripId);
      for (final m in mutationsB) {
        await syncServiceA.applyRemoteP2PMutation(m, storageA);
      }

      // Verify final converged state on BOTH devices without internet
      final finalA = expenseRepoA.getCachedExpenses(tripId);
      final finalB = expenseRepoB.getCachedExpenses(tripId);

      expect(finalA.length, equals(2));
      expect(finalB.length, equals(2));

      final totalA = finalA.fold<num>(0, (sum, e) => sum + e.amountInPaise).toInt();
      final totalB = finalB.fold<num>(0, (sum, e) => sum + e.amountInPaise).toInt();

      expect(totalA, equals(3750000)); // ₹37,500
      expect(totalB, equals(3750000)); // ₹37,500
      expect(totalA, equals(totalB));
    });

    test('2. Duplicate Protection & Idempotency: Re-receiving identical sync packet does NOT duplicate expenses', () async {
      const tripId = 'trip_goa_2026';
      final now = DateTime.now();

      final dinnerExpense = Expense(
        id: 'exp_unique_dinner_5000',
        tripId: tripId,
        title: 'Dinner at Dominos',
        amountInPaise: 500000,
        category: ExpenseCategory.food,
        paidById: 'member_user_a',
        splits: const [
          ExpenseSplit(memberId: 'member_user_a', amountInPaise: 250000),
          ExpenseSplit(memberId: 'member_user_b', amountInPaise: 250000),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await expenseRepoA.addExpense(dinnerExpense);
      final mutation = syncServiceA.getPendingMutationsForTrip(tripId).first;

      // Deliver packet 1st time
      final appliedFirst = await syncServiceB.applyRemoteP2PMutation(mutation, storageB);
      expect(appliedFirst, isTrue);
      expect(expenseRepoB.getCachedExpenses(tripId).length, equals(1));

      // Deliver identical packet 2nd time (retransmission / replay)
      final appliedSecond = await syncServiceB.applyRemoteP2PMutation(mutation, storageB);
      expect(appliedSecond, isFalse); // Idempotently ignored
      expect(expenseRepoB.getCachedExpenses(tripId).length, equals(1)); // Still exactly ONE expense!

      // Deliver identical packet 3rd time
      final appliedThird = await syncServiceB.applyRemoteP2PMutation(mutation, storageB);
      expect(appliedThird, isFalse);
      expect(expenseRepoB.getCachedExpenses(tripId).length, equals(1));
    });

    test('3. Deterministic Conflict Resolution on Edits: Strictly newer timestamp survives', () async {
      const tripId = 'trip_goa_2026';
      final t1 = DateTime(2026, 9, 1, 10, 0);
      final t2 = DateTime(2026, 9, 1, 10, 15); // Newer edit

      final originalExpense = Expense(
        id: 'exp_fuel_edit',
        tripId: tripId,
        title: 'Fuel',
        amountInPaise: 200000, // ₹2,000
        category: ExpenseCategory.transport,
        paidById: 'member_a',
        splits: const [ExpenseSplit(memberId: 'member_a', amountInPaise: 200000)],
        createdAt: t1,
        updatedAt: t1,
      );
      await expenseRepoA.addExpense(originalExpense);

      // Edit on Phone A at t2: Updated to ₹2,500
      final editedExpense = originalExpense.copyWith(
        amountInPaise: 250000,
        splits: const [ExpenseSplit(memberId: 'member_a', amountInPaise: 250000)],
        updatedAt: t2,
      );
      await expenseRepoA.updateExpense(editedExpense);

      final mutations = syncServiceA.getPendingMutationsForTrip(tripId);
      for (final m in mutations) {
        await syncServiceB.applyRemoteP2PMutation(m, storageB);
      }

      final resultOnB = expenseRepoB.getCachedExpenses(tripId);
      expect(resultOnB.length, equals(1));
      expect(resultOnB.first.amountInPaise, equals(250000)); // ₹2,500
    });
  });

  group('KITH Official Trip Sprint — P2 Large Values & Indian Formatting', () {
    test('1. CurrencyFormatter handles large financial amounts in Indian formatting accurately', () {
      expect(CurrencyFormatter.formatPaise(500000, currencyCode: 'INR'), equals('₹5,000'));
      expect(CurrencyFormatter.formatPaise(5000000, currencyCode: 'INR'), equals('₹50,000'));
      expect(CurrencyFormatter.formatPaise(50000000, currencyCode: 'INR'), equals('₹5,00,000'));
      expect(CurrencyFormatter.formatPaise(500000000, currencyCode: 'INR'), equals('₹50,00,000'));
      expect(CurrencyFormatter.formatPaise(1000000000, currencyCode: 'INR'), equals('₹1,00,00,000'));
      expect(CurrencyFormatter.formatPaise(9999999900, currencyCode: 'INR'), equals('₹9,99,99,999'));
    });

    test('2. Large values arithmetic & split equality', () {
      const largeTotalPaise = 9999999900; // ₹9,99,99,999
      final splits = [
        const ExpenseSplit(memberId: 'm1', amountInPaise: 3333333300),
        const ExpenseSplit(memberId: 'm2', amountInPaise: 3333333300),
        const ExpenseSplit(memberId: 'm3', amountInPaise: 3333333300),
      ];

      final sum = splits.fold<num>(0, (acc, s) => acc + s.amountInPaise).toInt();
      expect(sum, equals(largeTotalPaise));
    });
  });

  group('KITH Official Trip Sprint — P3 Smart Category Prediction', () {
    test('1. Predicts Food category from dining and food keywords', () {
      expect(ExpenseCategory.predictFromTitle("Dinner at Domino's"), equals(ExpenseCategory.food));
      expect(ExpenseCategory.predictFromTitle('Lunch Biryani with friends'), equals(ExpenseCategory.food));
      expect(ExpenseCategory.predictFromTitle('Burger and Fries'), equals(ExpenseCategory.food));
      expect(ExpenseCategory.predictFromTitle('Swiggy order'), equals(ExpenseCategory.food));
      expect(ExpenseCategory.predictFromTitle('McDonalds breakfast'), equals(ExpenseCategory.food));
    });

    test('2. Predicts Transport / Fuel from travel keywords', () {
      expect(ExpenseCategory.predictFromTitle('Petrol at Shell'), equals(ExpenseCategory.transport));
      expect(ExpenseCategory.predictFromTitle('Uber to Airport'), equals(ExpenseCategory.transport));
      expect(ExpenseCategory.predictFromTitle('Indigo flight ticket'), equals(ExpenseCategory.transport));
      expect(ExpenseCategory.predictFromTitle('Highway Toll Fastag'), equals(ExpenseCategory.transport));
      expect(ExpenseCategory.predictFromTitle('Auto rickshaw fare'), equals(ExpenseCategory.transport));
    });

    test('3. Predicts Stay from accommodation keywords', () {
      expect(ExpenseCategory.predictFromTitle('Hotel Taj Goa'), equals(ExpenseCategory.stay));
      expect(ExpenseCategory.predictFromTitle('Airbnb villa in Manali'), equals(ExpenseCategory.stay));
      expect(ExpenseCategory.predictFromTitle('Hostel room booking'), equals(ExpenseCategory.stay));
      expect(ExpenseCategory.predictFromTitle('Resort stay'), equals(ExpenseCategory.stay));
    });

    test('4. Predicts Drinks from beverage & cafe keywords', () {
      expect(ExpenseCategory.predictFromTitle('Starbucks Coffee'), equals(ExpenseCategory.drinks));
      expect(ExpenseCategory.predictFromTitle('Beer and Cocktails at Pub'), equals(ExpenseCategory.drinks));
      expect(ExpenseCategory.predictFromTitle('Chai and snacks'), equals(ExpenseCategory.drinks));
      expect(ExpenseCategory.predictFromTitle('Evening drinks'), equals(ExpenseCategory.drinks));
    });

    test('5. Predicts Activities, Groceries, and Shopping accurately', () {
      expect(ExpenseCategory.predictFromTitle('Movie tickets IMAX'), equals(ExpenseCategory.activities));
      expect(ExpenseCategory.predictFromTitle('Scuba diving pass'), equals(ExpenseCategory.activities));
      expect(ExpenseCategory.predictFromTitle('Blinkit grocery order'), equals(ExpenseCategory.groceries));
      expect(ExpenseCategory.predictFromTitle('Zara shopping in mall'), equals(ExpenseCategory.shopping));
    });

    test('6. Returns null on unrecognized or ambiguous titles (does not make bad guess)', () {
      expect(ExpenseCategory.predictFromTitle('Miscellaneous stuff'), isNull);
      expect(ExpenseCategory.predictFromTitle('Payment to Rahul'), isNull);
      expect(ExpenseCategory.predictFromTitle(''), isNull);
      expect(ExpenseCategory.predictFromTitle(null), isNull);
    });
  });

  group('KITH Official Trip Sprint — P4 & P5 Local-First Persistence & Entity Durability', () {
    test('1. Expense model preserves location and serializes cleanly', () {
      final now = DateTime.now();
      final exp = Expense(
        id: 'exp_starbucks_1',
        tripId: 'trip_1',
        title: 'Starbucks Coffee',
        amountInPaise: 45000,
        category: ExpenseCategory.drinks,
        location: 'Starbucks Ahmedabad Airport',
        paidById: 'usr_me',
        splits: const [
          ExpenseSplit(memberId: 'usr_me', amountInPaise: 45000),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final json = exp.toJson();
      expect(json['location'], equals('Starbucks Ahmedabad Airport'));
      expect(json['category'], equals('drinks'));

      final restored = Expense.fromJson(json);
      expect(restored.location, equals('Starbucks Ahmedabad Airport'));
      expect(restored.category, equals(ExpenseCategory.drinks));
      expect(restored.amountInPaise, equals(45000));
    });
  });
}
