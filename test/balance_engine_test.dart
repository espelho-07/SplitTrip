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

    test('Properly attributes expenses and resolves canonical member IDs for merged members', () {
      // Scenario matching production bug:
      // Darpan (m_darpan, u_darpan) and Neel (m_neel, u_neel).
      // An old virtual placeholder for Neel existed: m_neel_virtual, mergedIntoMemberId = 'm_neel'.
      final darpan = TripMember(id: 'm_darpan', userId: 'u_darpan', displayName: 'Darpan Parmar', joinedAt: DateTime.now());
      final neelClaimed = TripMember(id: 'm_neel', userId: 'u_neel', displayName: 'Neel Vyas', role: 'member', joinedAt: DateTime.now());
      final neelVirtualPlaceholder = TripMember(
        id: 'm_neel_virtual',
        userId: '',
        displayName: 'Neel Vyas',
        role: 'virtual',
        mergedIntoMemberId: 'm_neel',
        joinedAt: DateTime.now(),
      );

      final membersList = [darpan, neelClaimed, neelVirtualPlaceholder];

      // Expense 1: General ₹500 (50,000 paise). Paid by Neel's user ID or old virtual member ID. Split ₹250 each.
      final exp1 = Expense(
        id: 'e1',
        tripId: 't_manali',
        title: 'General',
        amountInPaise: 50000,
        category: ExpenseCategory.general,
        paidById: 'm_neel_virtual', // Created before claim using virtual ID
        splits: [
          const ExpenseSplit(memberId: 'm_darpan', amountInPaise: 25000),
          const ExpenseSplit(memberId: 'm_neel_virtual', amountInPaise: 25000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Expense 2: Stay ₹2,500 (250,000 paise). Paid by Darpan. Split ₹1,250 each.
      final exp2 = Expense(
        id: 'e2',
        tripId: 't_manali',
        title: 'Stay',
        amountInPaise: 250000,
        category: ExpenseCategory.general,
        paidById: 'm_darpan',
        splits: [
          const ExpenseSplit(memberId: 'm_darpan', amountInPaise: 125000),
          const ExpenseSplit(memberId: 'u_neel', amountInPaise: 125000), // Referenced by raw userId
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Calculate from Darpan's perspective
      final darpanSummary = BalanceEngine.calculateBalances(
        members: membersList,
        expenses: [exp1, exp2],
        currentUserId: 'u_darpan',
      );

      // Total spent = ₹3,000 (300,000 paise)
      expect(darpanSummary.totalTripSpentInPaise, 300000);

      // Darpan: Paid ₹2,500, share = ₹250 + ₹1,250 = ₹1,500 => Net +₹1,000 (+100,000 paise)
      // Neel: Paid ₹500, share = ₹250 + ₹1,250 = ₹1,500 => Net -₹1,000 (-100,000 paise)
      expect(darpanSummary.memberNetBalances['m_darpan'], 100000);
      expect(darpanSummary.memberNetBalances['m_neel'], -100000);

      // Darpan is owed ₹1,000
      expect(darpanSummary.currentUserNetBalanceInPaise, 100000);
      expect(darpanSummary.isCurrentUserOwed, isTrue);

      // Calculate from Neel's perspective
      final neelSummary = BalanceEngine.calculateBalances(
        members: membersList,
        expenses: [exp1, exp2],
        currentUserId: 'u_neel',
      );
      expect(neelSummary.currentUserNetBalanceInPaise, -100000);
      expect(neelSummary.isCurrentUserInDebt, isTrue);
    });
  });
}
