import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/payment/payment_models.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/settlement_transaction.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  group('Trip Member Management & Member Merge System Suite', () {
    final tJoined = DateTime(2026, 8, 24, 10, 0);

    test('1. TripMember model correctly serializes and deserializes mergedIntoMemberId and isMerged', () {
      final json = {
        'id': 'mbr_source_1',
        'userId': 'unclaimed_abc123',
        'displayName': 'Rahul Old',
        'role': 'member',
        'isClaimed': false,
        'status': 'merged',
        'mergedIntoMemberId': 'mbr_canon_2',
        'joinedAt': tJoined.toIso8601String(),
      };

      final member = TripMember.fromJson(json);
      expect(member.id, equals('mbr_source_1'));
      expect(member.displayName, equals('Rahul Old'));
      expect(member.status, equals('merged'));
      expect(member.isMerged, isTrue);
      expect(member.mergedIntoMemberId, equals('mbr_canon_2'));
      expect(member.isUnclaimed, isTrue);

      final exported = member.toJson();
      expect(exported['mergedIntoMemberId'], equals('mbr_canon_2'));
      expect(exported['status'], equals('merged'));
    });

    test('2. BalanceEngine ledger calculation before and after merge preserves total financial conservation', () {
      final darpanM = TripMember(
        id: 'mbr_darpan',
        userId: 'usr_darpan',
        displayName: 'Darpan',
        role: 'creator',
        joinedAt: tJoined,
      );
      final rahulOldM = TripMember(
        id: 'mbr_rahul_old',
        userId: 'unclaimed_1',
        displayName: 'Rahul',
        status: 'unclaimed',
        isClaimed: false,
        joinedAt: tJoined,
      );
      final rahulPatelM = TripMember(
        id: 'mbr_rahul_patel',
        userId: 'usr_rahul',
        displayName: 'Rahul Patel',
        role: 'member',
        joinedAt: tJoined,
      );
      final hardevM = TripMember(
        id: 'mbr_hardev',
        userId: 'usr_hardev',
        displayName: 'Hardev',
        role: 'member',
        joinedAt: tJoined,
      );

      final membersBefore = [darpanM, rahulOldM, rahulPatelM, hardevM];

      // Expense 1: Paid by Rahul Old (₹1,200 total), split between Rahul Old (₹600) and Hardev (₹600)
      final exp1 = Expense(
        id: 'exp_1',
        tripId: 'trip_1',
        title: 'Breakfast by Rahul Old',
        amountInPaise: 120000,
        paidById: 'mbr_rahul_old',
        category: ExpenseCategory.food,
        splits: [
          const ExpenseSplit(memberId: 'mbr_rahul_old', amountInPaise: 60000),
          const ExpenseSplit(memberId: 'mbr_hardev', amountInPaise: 60000),
        ],
        createdAt: tJoined,
        updatedAt: tJoined,
      );

      // Expense 2: Paid by Hardev (₹2,000 total), split between Darpan (₹1,000) and Rahul Patel (₹1,000)
      final exp2 = Expense(
        id: 'exp_2',
        tripId: 'trip_1',
        title: 'Cab by Hardev',
        amountInPaise: 200000,
        paidById: 'mbr_hardev',
        category: ExpenseCategory.transport,
        splits: [
          const ExpenseSplit(memberId: 'mbr_darpan', amountInPaise: 100000),
          const ExpenseSplit(memberId: 'mbr_rahul_patel', amountInPaise: 100000),
        ],
        createdAt: tJoined,
        updatedAt: tJoined,
      );

      // Settlement: Hardev paid ₹300 to Rahul Old
      final stl1 = SettlementTransaction(
        id: 'stl_1',
        fromMemberId: 'mbr_hardev',
        toMemberId: 'mbr_rahul_old',
        amountInPaise: 30000,
        isSettled: true,
        status: PaymentStatus.confirmed,
      );

      // 1. Calculate Balances Before Merge
      final balanceBefore = BalanceEngine.calculateBalances(
        members: membersBefore,
        expenses: [exp1, exp2],
        settlements: [stl1],
        currentUserId: 'usr_rahul',
      );

      expect(balanceBefore.totalTripSpentInPaise, equals(320000));

      // 2. Perform Migration on Models (Simulate Merge Rahul Old -> Rahul Patel)
      final membersAfter = [
        darpanM,
        rahulPatelM,
        hardevM,
        // rahulOldM is now merged tombstone
        rahulOldM.copyWith(status: 'merged', mergedIntoMemberId: 'mbr_rahul_patel'),
      ].where((m) => !m.isMerged).toList();

      final exp1Migrated = exp1.copyWith(
        paidById: 'mbr_rahul_patel',
        splits: [
          const ExpenseSplit(memberId: 'mbr_rahul_patel', amountInPaise: 60000),
          const ExpenseSplit(memberId: 'mbr_hardev', amountInPaise: 60000),
        ],
      );

      final stl1Migrated = SettlementTransaction(
        id: stl1.id,
        fromMemberId: stl1.fromMemberId,
        toMemberId: 'mbr_rahul_patel',
        amountInPaise: stl1.amountInPaise,
        isSettled: stl1.isSettled,
        status: stl1.status,
      );

      // 3. Calculate Balances After Merge
      final balanceAfter = BalanceEngine.calculateBalances(
        members: membersAfter,
        expenses: [exp1Migrated, exp2],
        settlements: [stl1Migrated],
        currentUserId: 'usr_rahul',
      );

      // Total trip expense is conserved
      expect(balanceAfter.totalTripSpentInPaise, equals(320000));

      // Rahul Patel's net balance after merge:
      // Paid: ₹1,200
      // Share: ₹600 + ₹1,000 = ₹1,600
      // Net without settlement: ₹1,200 - ₹1,600 = -₹400
      // Received settlement of ₹300 -> net balance becomes -₹700
      expect(balanceAfter.currentUserNetBalanceInPaise, equals(-70000));

      // Active members list has exactly 3 participants

      expect(membersAfter.length, equals(3));
      expect(membersAfter.any((m) => m.id == 'mbr_rahul_old'), isFalse);
    });

    test('3. Repointing combines overlapping split shares without remainder loss', () {
      final splits = [
        const ExpenseSplit(memberId: 'mbr_creator', amountInPaise: 100000),
        const ExpenseSplit(memberId: 'mbr_dup_1', amountInPaise: 100000),
        const ExpenseSplit(memberId: 'mbr_dup_2', amountInPaise: 100000),
      ];

      // Merge mbr_dup_2 into mbr_dup_1
      final updatedSplits = <ExpenseSplit>[];
      int? dup1Idx;
      for (int i = 0; i < splits.length; i++) {
        if (splits[i].memberId == 'mbr_dup_1') {
          dup1Idx = updatedSplits.length;
          updatedSplits.add(splits[i]);
        } else if (splits[i].memberId == 'mbr_dup_2') {
          if (dup1Idx != null) {
            final existing = updatedSplits[dup1Idx];
            updatedSplits[dup1Idx] = existing.copyWith(
              amountInPaise: existing.amountInPaise + splits[i].amountInPaise,
            );
          } else {
            updatedSplits.add(splits[i].copyWith(memberId: 'mbr_dup_1'));
          }
        } else {
          updatedSplits.add(splits[i]);
        }
      }

      expect(updatedSplits.length, equals(2));
      final combined = updatedSplits.firstWhere((s) => s.memberId == 'mbr_dup_1');
      expect(combined.amountInPaise, equals(200000));
    });
  });
}
