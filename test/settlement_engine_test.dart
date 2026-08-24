import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/settlement_engine.dart';

void main() {
  group('SettlementEngine Tests', () {
    test('Simplifies 5-member mesh of debts to minimal direct payments', () {
      // 5 friends scenario from product vision:
      // Member 1 paid ₹6,000, others spent varying amounts.
      // Net balances:
      // M1: +450,000 paise (+₹4,500)
      // M2: -130,000 paise (-₹1,300)
      // M3: -40,000 paise (-₹400)
      // M4: -120,000 paise (-₹1,200)
      // M5: -160,000 paise (-₹1,600)
      final netBalances = {
        'M1': 450000,
        'M2': -130000,
        'M3': -40000,
        'M4': -120000,
        'M5': -160000,
      };

      final settlements = SettlementEngine.simplifyDebts(netBalances);

      // Total settlements should be <= 4 (N - 1)
      expect(settlements.length, lessThanOrEqualTo(4));

      // Sum of all payments must equal total creditor credit (₹4,500 = 450,000 paise)
      final totalSettled = settlements.fold(0, (sum, s) => sum + s.amountInPaise);
      expect(totalSettled, 450000);

      // Verify that M1 is the recipient for all settlements
      for (final s in settlements) {
        expect(s.toMemberId, 'M1');
        expect(s.amountInPaise, greaterThan(0));
      }
    });

    test('Returns empty settlements when all balances are 0', () {
      final netBalances = {
        'M1': 0,
        'M2': 0,
        'M3': 0,
      };

      final settlements = SettlementEngine.simplifyDebts(netBalances);
      expect(settlements, isEmpty);
    });

    test('Handles multiple creditors and multiple debtors accurately', () {
      final netBalances = {
        'A': 10000,  // +₹100
        'B': 20000,  // +₹200
        'C': -15000, // -₹150
        'D': -15000, // -₹150
      };

      final settlements = SettlementEngine.simplifyDebts(netBalances);

      expect(settlements.length, lessThanOrEqualTo(3));
      final totalSettled = settlements.fold(0, (sum, s) => sum + s.amountInPaise);
      expect(totalSettled, 30000);
    });
  });
}
