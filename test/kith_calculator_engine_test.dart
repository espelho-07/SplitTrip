import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/utils/kith_calculator_engine.dart';

void main() {
  group('KithCalculatorEngine Tests', () {
    test('1. Parses simple integer: 500 -> 50000 paise', () {
      expect(KithCalculatorEngine.evaluateToPaise('500'), 50000);
      expect(KithCalculatorEngine.hasOperator('500'), false);
      expect(KithCalculatorEngine.getLivePreview('500'), isNull);
    });

    test('2. Multi-add calculation with thousands commas: 30,000 + 742 + 720 -> 3146200 paise', () {
      const input = '30,000 + 742 + 720';
      final paise = KithCalculatorEngine.evaluateToPaise(input);
      expect(paise, 3146200);
      expect(KithCalculatorEngine.hasOperator(input), true);
      expect(KithCalculatorEngine.getLivePreview(input), contains('31,462'));
    });

    test('3. Handles decimals cleanly: 150.50 + 49.50 -> 20000 paise', () {
      const input = '150.50 + 49.50';
      expect(KithCalculatorEngine.evaluateToPaise(input), 20000);
    });

    test('4. Gracefully handles incomplete input while typing: 30000 + -> 3000000 paise', () {
      expect(KithCalculatorEngine.evaluateToPaise('30000 + '), 3000000);
      final res = KithCalculatorEngine.evaluateExpression('30000 + ');
      expect(res.isIncomplete, isTrue);
      expect(res.amountInPaise, 3000000);
    });

    test('5. Handles subtraction and currency symbols: ₹10,000 - 2,500 -> 750000 paise', () {
      expect(KithCalculatorEngine.evaluateToPaise('₹10,000 - 2,500'), 750000);
    });

    test('6. Addition: 100+23 = 123 (12300 paise)', () {
      expect(KithCalculatorEngine.evaluateToPaise('100+23'), 12300);
      expect(KithCalculatorEngine.getLivePreview('100+23'), contains('123'));
    });

    test('7. Multiplication: 23*5 = 115 (11500 paise)', () {
      expect(KithCalculatorEngine.evaluateToPaise('23*5'), 11500);
      expect(KithCalculatorEngine.getLivePreview('23*5'), contains('115'));
      // Unicode multiplication symbol
      expect(KithCalculatorEngine.evaluateToPaise('23×5'), 11500);
      // Letter x multiplication
      expect(KithCalculatorEngine.evaluateToPaise('23 x 5'), 11500);
    });

    test('8. Division: 500/2 = 250 (25000 paise)', () {
      expect(KithCalculatorEngine.evaluateToPaise('500/2'), 25000);
      expect(KithCalculatorEngine.getLivePreview('500/2'), contains('250'));
      // Unicode division symbol
      expect(KithCalculatorEngine.evaluateToPaise('500÷2'), 25000);
    });

    test('9. Subtraction: 100-20 = 80 (8000 paise)', () {
      expect(KithCalculatorEngine.evaluateToPaise('100-20'), 8000);
      expect(KithCalculatorEngine.getLivePreview('100-20'), contains('80'));
    });

    test('10. Operator Precedence (BODMAS): 100+23*2 = 146 (14600 paise)', () {
      expect(KithCalculatorEngine.evaluateToPaise('100+23*2'), 14600);
      expect(KithCalculatorEngine.getLivePreview('100+23*2'), contains('146'));
    });

    test('11. Parentheses: (100+23)*2 = 246 (24600 paise)', () {
      expect(KithCalculatorEngine.evaluateToPaise('(100+23)*2'), 24600);
      expect(KithCalculatorEngine.getLivePreview('(100+23)*2'), contains('246'));
    });

    test('12. Decimal multiplication: 12.50*2 = 25 (2500 paise)', () {
      expect(KithCalculatorEngine.evaluateToPaise('12.50*2'), 2500);
      expect(KithCalculatorEngine.getLivePreview('12.50*2'), contains('25'));
    });

    test('13. Division by zero validation: 10/0 returns error status and 0 paise', () {
      expect(KithCalculatorEngine.evaluateToPaise('10/0'), 0);
      final res = KithCalculatorEngine.evaluateExpression('10/0');
      expect(res.isError, isTrue);
      expect(res.errorMessage, 'Cannot divide by zero');
    });

    test('14. Incomplete parenthesis during typing evaluates gracefully', () {
      final res = KithCalculatorEngine.evaluateExpression('(100+23');
      expect(res.isIncomplete, isTrue);
      expect(res.amountInPaise, 12300);
      expect(res.previewText, contains('123'));
    });

    test('15. Rejects negative results for expense amount', () {
      expect(KithCalculatorEngine.evaluateToPaise('50 - 100'), 0);
      final res = KithCalculatorEngine.evaluateExpression('50 - 100');
      expect(res.isError, isTrue);
      expect(res.errorMessage, contains('negative'));
    });

    test('16. Handles empty / invalid strings without crashing', () {
      expect(KithCalculatorEngine.evaluateToPaise(''), 0);
      expect(KithCalculatorEngine.evaluateToPaise('   '), 0);
      expect(KithCalculatorEngine.evaluateToPaise('invalid text'), 0);
    });
  });
}
