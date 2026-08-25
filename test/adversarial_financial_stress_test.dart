import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/money_engine.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/engine/settlement_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  group('Phase 19: Adversarial Financial Precision & Stress Tests', () {
    test('1. Equal Split: 100 participants with 1 paise remainder allocation preserves conservation', () {
      final memberIds = List.generate(100, (i) => 'mbr_$i');
      const totalPaise = 10001; // ₹100.01 split amongst 100 people = 100 paise each + 1 remainder paise

      final splits = MoneyEngine.calculateEqualSplits(
        totalPaise: totalPaise,
        participantMemberIds: memberIds,
        priorityMemberId: 'mbr_0',
      );

      expect(splits.length, 100);

      // Verify exact sum equals totalPaise without any penny leak
      final sum = splits.fold<int>(0, (prev, s) => prev + s.amountInPaise);
      expect(sum, totalPaise);

      // Verify priority member received the extra 1 paise
      final prioritySplit = splits.firstWhere((s) => s.memberId == 'mbr_0');
      expect(prioritySplit.amountInPaise, 101); // 100 + 1

      // Other 99 members receive exactly 100 paise
      for (int i = 1; i < 100; i++) {
        final split = splits.firstWhere((s) => s.memberId == 'mbr_$i');
        expect(split.amountInPaise, 100);
      }
    });

    test('2. Large Scale Shares Split: ₹50,00,000 (500M paise) across 17 participants with uneven shares', () {
      const totalPaise = 500000000; // ₹50 Lakhs
      final memberShares = {
        for (int i = 0; i < 17; i++) 'mbr_$i': (i % 5) + 1, // shares from 1 to 5
      };

      final splits = MoneyEngine.calculateSharesSplits(
        totalPaise: totalPaise,
        shares: memberShares,
      );

      expect(splits.length, 17);
      final sum = splits.fold<int>(0, (prev, s) => prev + s.amountInPaise);
      expect(sum, totalPaise);
    });

    test('3. Zero-Sum Invariant: 500 multi-payer random expenses strictly conserve SUM(netBalances) == 0', () {
      final members = List.generate(
        8,
        (i) => TripMember(
          id: 'mbr_$i',
          userId: 'usr_$i',
          displayName: 'User $i',
          role: i == 0 ? 'creator' : 'member',
          joinedAt: DateTime.now(),
        ),
      );

      final expenses = <Expense>[];
      for (int i = 0; i < 500; i++) {
        final payerIndex = i % 8;
        final amountPaise = (i * 137 + 500) % 50000 + 100; // Deterministic pseudo-random amount
        final numParticipants = (i % 7) + 2; // 2 to 8 participants
        final participantIds = List.generate(numParticipants, (p) => 'mbr_${(payerIndex + p) % 8}');

        final splits = MoneyEngine.calculateEqualSplits(
          totalPaise: amountPaise,
          participantMemberIds: participantIds,
          priorityMemberId: 'mbr_$payerIndex',
        );

        expenses.add(
          Expense(
            id: 'exp_$i',
            tripId: 'trip_stress',
            title: 'Expense #$i',
            amountInPaise: amountPaise,
            paidById: 'mbr_$payerIndex',
            category: ExpenseCategory.food,
            splitType: SplitType.equal,
            splits: splits,
            createdAt: DateTime.now().subtract(Duration(minutes: 500 - i)),
            updatedAt: DateTime.now().subtract(Duration(minutes: 500 - i)),
          ),
        );
      }

      final summary = BalanceEngine.calculateBalances(
        members: members,
        expenses: expenses,
        currentUserId: 'usr_0',
      );

      // Verify Total Spent
      final expectedTotal = expenses.fold<int>(0, (sum, e) => sum + e.amountInPaise);
      expect(summary.totalTripSpentInPaise, expectedTotal);

      // Verify conservation: Sum of net balances must be precisely zero
      final sumNetBalances = summary.memberNetBalances.values.fold<int>(0, (sum, net) => sum + net);
      expect(sumNetBalances, 0);

      // Verify simplified settlement reduction satisfies all debts
      final simplified = SettlementEngine.simplifyDebts(summary.memberNetBalances);
      expect(simplified.isNotEmpty, isTrue);

      // Simulating all simplified settlements should yield a net 0 for all members
      final simulatedBalances = Map<String, int>.from(summary.memberNetBalances);
      for (final s in simplified) {
        simulatedBalances[s.fromMemberId] = (simulatedBalances[s.fromMemberId] ?? 0) + s.amountInPaise;
        simulatedBalances[s.toMemberId] = (simulatedBalances[s.toMemberId] ?? 0) - s.amountInPaise;
      }

      for (final net in simulatedBalances.values) {
        expect(net, 0);
      }
    });

    test('4. Performance Benchmark: 1000 expenses balance calculation completes in under 50ms', () {
      final members = List.generate(
        10,
        (i) => TripMember(
          id: 'mbr_$i',
          userId: 'usr_$i',
          displayName: 'User $i',
          role: i == 0 ? 'creator' : 'member',
          joinedAt: DateTime.now(),
        ),
      );

      final expenses = List.generate(
        1000,
        (i) => Expense(
          id: 'exp_$i',
          tripId: 'trip_1000',
          title: 'Item $i',
          amountInPaise: 25000,
          paidById: 'mbr_${i % 10}',
          category: ExpenseCategory.transport,
          splitType: SplitType.equal,
          splits: [
            for (int m = 0; m < 10; m++)
              ExpenseSplit(memberId: 'mbr_$m', amountInPaise: 2500),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final stopwatch = Stopwatch()..start();
      final summary = BalanceEngine.calculateBalances(
        members: members,
        expenses: expenses,
        currentUserId: 'usr_0',
      );
      stopwatch.stop();

      expect(summary.totalTripSpentInPaise, 25000000); // ₹2,50,000
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
