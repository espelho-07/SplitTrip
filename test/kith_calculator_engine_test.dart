import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/utils/kith_calculator_engine.dart';

void main() {
  group('KithCalculatorEngine Tests', () {
    test('1. Parses simple integer: 500 -> 50000 paise', () {
      expect(KithCalculatorEngine.evaluateToPaise('500'), 50000);
      expect(KithCalculatorEngine.hasOperator('500'), false);
      expect(KithCalculatorEngine.getLivePreview('500'), isNull);
    });

    test('2. Parses multi-add calculation with thousands commas: 30,000 + 742 + 720 -> 3146200 paise (₹31,462)', () {
      final input = '30,000 + 742 + 720';
      final paise = KithCalculatorEngine.evaluateToPaise(input);
      expect(paise, 3146200);
      expect(KithCalculatorEngine.hasOperator(input), true);
      expect(KithCalculatorEngine.getLivePreview(input), contains('31,462'));
    });

    test('3. Handles decimals cleanly: 150.50 + 49.50 -> 20000 paise', () {
      final input = '150.50 + 49.50';
      expect(KithCalculatorEngine.evaluateToPaise(input), 20000);
    });

    test('4. Gracefully handles incomplete input while typing: 30000 + -> 3000000 paise', () {
      expect(KithCalculatorEngine.evaluateToPaise('30000 + '), 3000000);
    });

    test('5. Handles subtraction and currency symbols: ₹10,000 - 2,500 -> 750000 paise', () {
      expect(KithCalculatorEngine.evaluateToPaise('₹10,000 - 2,500'), 750000);
    });

    test('6. Handles empty / invalid strings without crashing', () {
      expect(KithCalculatorEngine.evaluateToPaise(''), 0);
      expect(KithCalculatorEngine.evaluateToPaise('   '), 0);
      expect(KithCalculatorEngine.evaluateToPaise('invalid text'), 0);
    });
  });
}
