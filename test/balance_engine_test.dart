import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  group('BalanceEngine Tests', () {
    final memberA = TripMember(id: 'mA', userId: 'uA', displayName: 'Alex', joinedAt: DateTime.now());
    final memberB = TripMember(id: 'mB', userId: 'uB', displayName: 'Bob', joinedAt: DateTime.now());
    final memberC = TripMember(id: 'mC', userId: 'uC', displayName: 'Charlie', joinedAt: DateTime.now());
    final members = [memberA, memberB, memberC];

    test('Computes net balances correctly across multiple expenses', () {
      // Expense 1: Alex pays ₹3,000 (300,000 paise) split equally (₹1,000 each)
      final expense1 = Expense(
        id: 'e1',
        tripId: 't1',
        title: 'Train Tickets',
        amountInPaise: 300000,
        category: ExpenseCategory.transport,
        paidById: 'mA',
        splits: [
          const ExpenseSplit(memberId: 'mA', amountInPaise: 100000),
          const ExpenseSplit(memberId: 'mB', amountInPaise: 100000),
          const ExpenseSplit(memberId: 'mC', amountInPaise: 100000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Expense 2: Bob pays ₹600 (60,000 paise) split equally (₹200 each)
      final expense2 = Expense(
        id: 'e2',
        tripId: 't1',
        title: 'Dinner',
        amountInPaise: 60000,
        category: ExpenseCategory.food,
        paidById: 'mB',
        splits: [
          const ExpenseSplit(memberId: 'mA', amountInPaise: 20000),
          const ExpenseSplit(memberId: 'mB', amountInPaise: 20000),
          const ExpenseSplit(memberId: 'mC', amountInPaise: 20000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final summary = BalanceEngine.calculateBalances(
        members: members,
        expenses: [expense1, expense2],
        currentUserId: 'uA',
      );

      // Total spent = ₹3,000 + ₹600 = ₹3,600 (360,000 paise)
      expect(summary.totalTripSpentInPaise, 360000);

      // Net balances:
      // Alex: Paid ₹3,000, Share ₹1,200 => Net +₹1,800 (+180,000 paise)
      // Bob: Paid ₹600, Share ₹1,200 => Net -₹600 (-60,000 paise)
      // Charlie: Paid ₹0, Share ₹1,200 => Net -₹1,200 (-120,000 paise)
      expect(summary.memberNetBalances['mA'], 180000);
      expect(summary.memberNetBalances['mB'], -60000);
      expect(summary.memberNetBalances['mC'], -120000);

      // Current user Alex is owed ₹1,800
      expect(summary.currentUserNetBalanceInPaise, 180000);
      expect(summary.isCurrentUserOwed, isTrue);
    });

    test('Excludes soft-deleted expenses from calculations', () {
      final expense1 = Expense(
        id: 'e1',
        tripId: 't1',
        title: 'Deleted expense',
        amountInPaise: 50000,
        category: ExpenseCategory.general,
        paidById: 'mA',
        splits: [
          const ExpenseSplit(memberId: 'mA', amountInPaise: 25000),
          const ExpenseSplit(memberId: 'mB', amountInPaise: 25000),
        ],
        isDeleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final summary = BalanceEngine.calculateBalances(
        members: [memberA, memberB],
        expenses: [expense1],
        currentUserId: 'uA',
      );

      expect(summary.totalTripSpentInPaise, 0);
      expect(summary.currentUserNetBalanceInPaise, 0);
    });
  });
}
