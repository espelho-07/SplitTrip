import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/expense_merge.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';

void main() {
  group('Expense Field-Level 3-Way Merge Test Suite', () {
    final baseCreatedAt = DateTime(2026, 11, 20, 10, 0, 0);
    final baseUpdatedAt = DateTime(2026, 11, 20, 10, 0, 0);

    final baseExpense = Expense(
      id: 'exp_dinner_101',
      tripId: 'trip_goa_001',
      title: 'Dinner',
      amountInPaise: 150000, // Rs 1500.00
      category: ExpenseCategory.general,
      paidById: 'mbr_creator',
      splitType: SplitType.equal,
      splits: [
        const ExpenseSplit(memberId: 'mbr_creator', amountInPaise: 75000),
        const ExpenseSplit(memberId: 'mbr_rahul', amountInPaise: 75000),
      ],
      createdAt: baseCreatedAt,
      updatedAt: baseUpdatedAt,
    );

    test('1. Member A changes title, Member B changes category -> Both non-conflicting edits merged', () {
      final tA = DateTime(2026, 11, 20, 10, 5, 0);
      final tB = DateTime(2026, 11, 20, 10, 6, 0);

      // Member A changes title from 'Dinner' to 'Beach BBQ Feast'
      final memberAExpense = baseExpense.copyWith(
        title: 'Beach BBQ Feast',
        updatedAt: tA,
      );

      // Member B concurrently changes category from 'general' to 'food'
      final memberBExpense = baseExpense.copyWith(
        category: ExpenseCategory.food,
        updatedAt: tB,
      );

      final merged = ExpenseMergeEngine.merge3Way(
        local: memberAExpense,
        remote: memberBExpense,
        base: baseExpense,
      );

      // Both non-conflicting edits are preserved!
      expect(merged.title, equals('Beach BBQ Feast'));
      expect(merged.category, equals(ExpenseCategory.food));
      expect(merged.amountInPaise, equals(150000));
      expect(merged.splits.length, equals(2));
      expect(merged.splits[0].amountInPaise, equals(75000));
      expect(merged.splits[1].amountInPaise, equals(75000));
      // Timestamp advanced to reflect authoritative synthesized merge
      expect(merged.updatedAt.isAfter(tB), isTrue);
    });

    test('2. Member A changes category, Member B changes amount + splits -> Preserves category and new financial math', () {
      final tA = DateTime(2026, 11, 20, 11, 0, 0);
      final tB = DateTime(2026, 11, 20, 11, 2, 0);

      // Member A updates category to transport
      final memberAExpense = baseExpense.copyWith(
        category: ExpenseCategory.transport,
        updatedAt: tA,
      );

      // Member B updates amount to Rs 2000 and adjusts splits
      final memberBExpense = baseExpense.copyWith(
        amountInPaise: 200000,
        splits: [
          const ExpenseSplit(memberId: 'mbr_creator', amountInPaise: 100000),
          const ExpenseSplit(memberId: 'mbr_rahul', amountInPaise: 100000),
        ],
        updatedAt: tB,
      );

      final merged = ExpenseMergeEngine.merge3Way(
        local: memberAExpense,
        remote: memberBExpense,
        base: baseExpense,
      );

      expect(merged.category, equals(ExpenseCategory.transport));
      expect(merged.amountInPaise, equals(200000));
      expect(merged.splits[0].amountInPaise, equals(100000));
      expect(merged.splits[1].amountInPaise, equals(100000));
      // Split math is preserved exactly
      expect(merged.splits.fold<int>(0, (sum, s) => sum + s.amountInPaise), equals(200000));
    });

    test('3. Member A attaches receipt, Member B edits title -> Retains receipt and updated title', () {
      final tA = DateTime(2026, 11, 20, 12, 0, 0);
      final tB = DateTime(2026, 11, 20, 12, 1, 0);

      // Member A scans & attaches receipt
      final memberAExpense = baseExpense.copyWith(
        receiptUrl: '/data/user/0/com.nirniq.kith/receipts/rec_123.jpg',
        updatedAt: tA,
      );

      // Member B updates title to 'Dinner with Drinks'
      final memberBExpense = baseExpense.copyWith(
        title: 'Dinner with Drinks',
        updatedAt: tB,
      );

      final merged = ExpenseMergeEngine.merge3Way(
        local: memberAExpense,
        remote: memberBExpense,
        base: baseExpense,
      );

      expect(merged.receiptUrl, equals('/data/user/0/com.nirniq.kith/receipts/rec_123.jpg'));
      expect(merged.title, equals('Dinner with Drinks'));
    });

    test('4. Member A attaches voiceTranscript, Member B updates location -> Retains both', () {
      final tA = DateTime(2026, 11, 20, 13, 0, 0);
      final tB = DateTime(2026, 11, 20, 13, 2, 0);

      final memberAExpense = baseExpense.copyWith(
        voiceTranscript: 'Paid 1500 for dinner at seaside restaurant',
        updatedAt: tA,
      );

      final memberBExpense = baseExpense.copyWith(
        location: 'Curlies Beach Shack, Anjuna',
        updatedAt: tB,
      );

      final merged = ExpenseMergeEngine.merge3Way(
        local: memberAExpense,
        remote: memberBExpense,
        base: baseExpense,
      );

      expect(merged.voiceTranscript, equals('Paid 1500 for dinner at seaside restaurant'));
      expect(merged.location, equals('Curlies Beach Shack, Anjuna'));
    });

    test('5. True conflict on title: both edit title to different strings -> Resolves by newer updatedAt', () {
      final tEarlier = DateTime(2026, 11, 20, 14, 0, 0);
      final tLater = DateTime(2026, 11, 20, 14, 1, 0);

      final memberAExpense = baseExpense.copyWith(
        title: 'Seafood Buffet',
        updatedAt: tEarlier,
      );

      final memberBExpense = baseExpense.copyWith(
        title: 'Italian Fine Dining',
        updatedAt: tLater,
      );

      final merged = ExpenseMergeEngine.merge3Way(
        local: memberAExpense,
        remote: memberBExpense,
        base: baseExpense,
      );

      // Member B was strictly newer on title -> Member B's title wins
      expect(merged.title, equals('Italian Fine Dining'));
    });

    test('6. Tombstone invariant: deleted expense is never resurrected by concurrent edits', () {
      final tA = DateTime(2026, 11, 20, 15, 0, 0);
      final tB = DateTime(2026, 11, 20, 15, 5, 0);

      // Member A deletes expense
      final memberAExpense = baseExpense.copyWith(
        isDeleted: true,
        updatedAt: tA,
      );

      // Member B concurrently modified title
      final memberBExpense = baseExpense.copyWith(
        title: 'Dinner and Dessert',
        updatedAt: tB,
      );

      final merged = ExpenseMergeEngine.merge3Way(
        local: memberAExpense,
        remote: memberBExpense,
        base: baseExpense,
      );

      // Deletion is strictly preserved!
      expect(merged.isDeleted, isTrue);
    });

    test('7. mergeAuthoritativeExpenses reconciles concurrent non-conflicting edits between local outbox and server', () {
      final localPending = baseExpense.copyWith(
        title: 'Sunset Beach Dinner',
        updatedAt: DateTime(2026, 11, 20, 16, 0, 0),
      );

      final serverVersion = baseExpense.copyWith(
        category: ExpenseCategory.food,
        updatedAt: DateTime(2026, 11, 20, 16, 2, 0),
      );

      final outcome = mergeAuthoritativeExpenses(
        localExpenses: [baseExpense],
        serverExpenses: [serverVersion],
        pendingDeletedIds: {},
        pendingUpserts: {baseExpense.id: localPending},
        tombstonedIds: {},
      );

      expect(outcome.expenses.length, equals(1));
      final merged = outcome.expenses.first;
      // 3-way merge synthesized title from pending and category from server!
      expect(merged.title, equals('Sunset Beach Dinner'));
      expect(merged.category, equals(ExpenseCategory.food));
      // Local synthesized newer edit is queued to be pushed to server
      expect(outcome.localNewerIds.contains(baseExpense.id), isTrue);
    });
  });
}
