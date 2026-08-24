import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/money_engine.dart';

void main() {
  group('MoneyEngine Tests', () {
    test('calculateEqualSplits cleanly divides without remainder', () {
      final splits = MoneyEngine.calculateEqualSplits(
        totalPaise: 600000, // ₹6,000.00
        participantMemberIds: ['user1', 'user2', 'user3', 'user4', 'user5'],
      );

      expect(splits.length, 5);
      for (final split in splits) {
        expect(split.amountInPaise, 120000); // ₹1,200.00 each
      }

      expect(MoneyEngine.validateSplits(600000, splits), isTrue);
    });

    test('calculateEqualSplits allocates remainder paise deterministically to avoid penny leaks', () {
      // ₹100.00 split among 3 people = 33.33 each + 1 paise leftover
      final splits = MoneyEngine.calculateEqualSplits(
        totalPaise: 10000, // 10,000 paise
        participantMemberIds: ['userA', 'userB', 'userC'],
        priorityMemberId: 'userA',
      );

      expect(splits.length, 3);
      expect(splits[0].memberId, 'userA');
      expect(splits[0].amountInPaise, 3334); // Priority member gets the remainder 1 paise
      expect(splits[1].amountInPaise, 3333);
      expect(splits[2].amountInPaise, 3333);

      final totalSum = splits.fold(0, (sum, s) => sum + s.amountInPaise);
      expect(totalSum, 10000);
      expect(MoneyEngine.validateSplits(10000, splits), isTrue);
    });

    test('calculateSharesSplits proportionally allocates shares and reconciles remainders', () {
      // 2 shares for A, 1 share for B, 1 share for C across ₹1,000 (100,000 paise)
      final splits = MoneyEngine.calculateSharesSplits(
        totalPaise: 100000,
        shares: {'userA': 2, 'userB': 1, 'userC': 1},
      );

      expect(splits.length, 3);
      expect(splits.firstWhere((s) => s.memberId == 'userA').amountInPaise, 50000);
      expect(splits.firstWhere((s) => s.memberId == 'userB').amountInPaise, 25000);
      expect(splits.firstWhere((s) => s.memberId == 'userC').amountInPaise, 25000);
      expect(MoneyEngine.validateSplits(100000, splits), isTrue);
    });

    test('calculatePercentageSplits allocates exact percentages', () {
      final splits = MoneyEngine.calculatePercentageSplits(
        totalPaise: 50000, // ₹500
        percentages: {'user1': 50.0, 'user2': 30.0, 'user3': 20.0},
      );

      expect(splits.length, 3);
      expect(splits.firstWhere((s) => s.memberId == 'user1').amountInPaise, 25000);
      expect(splits.firstWhere((s) => s.memberId == 'user2').amountInPaise, 15000);
      expect(splits.firstWhere((s) => s.memberId == 'user3').amountInPaise, 10000);
      expect(MoneyEngine.validateSplits(50000, splits), isTrue);
    });
  });
}
