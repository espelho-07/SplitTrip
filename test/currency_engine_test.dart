import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/utils/currency_formatter.dart';
import 'package:kith_app/domain/models/currency_config.dart';

void main() {
  group('Multi-Currency & Formatting Tests', () {
    test('AppCurrency fromCode maps supported currencies correctly', () {
      expect(AppCurrency.fromCode('INR').symbol, '₹');
      expect(AppCurrency.fromCode('usd').symbol, '\$');
      expect(AppCurrency.fromCode('EUR').symbol, '€');
      expect(AppCurrency.fromCode('gbp').symbol, '£');
      expect(AppCurrency.fromCode('xyz').code, 'INR'); // default fallback
    });

    test('Formats INR paise accurately with whole and fraction values', () {
      expect(CurrencyFormatter.formatPaise(600000, currencyCode: 'INR'), '₹6,000');
      expect(CurrencyFormatter.formatPaise(46250, currencyCode: 'INR'), '₹462.50');
      expect(CurrencyFormatter.formatPaise(-125000, currencyCode: 'INR'), '-₹1,250');
      expect(CurrencyFormatter.formatPaise(50000, currencyCode: 'INR', showSign: true), '+₹500');
    });

    test('Formats USD cents accurately', () {
      expect(CurrencyFormatter.formatPaise(10000, currencyCode: 'USD'), '\$100');
      expect(CurrencyFormatter.formatPaise(1250, currencyCode: 'USD'), '\$12.50');
      expect(CurrencyFormatter.formatPaise(-550, currencyCode: 'USD'), '-\$5.50');
    });

    test('Formats EUR and GBP smallest integer units accurately', () {
      final eurFormatted = CurrencyFormatter.formatPaise(2500, currencyCode: 'EUR');
      expect(eurFormatted.contains('25') && eurFormatted.contains('€'), true);

      final gbpFormatted = CurrencyFormatter.formatPaise(7500, currencyCode: 'GBP');
      expect(gbpFormatted.contains('75') && gbpFormatted.contains('£'), true);
    });

    test('Smallest integer conversion preserves exact values without floating point drift', () {
      expect(CurrencyFormatter.toPaise(125.50), 12550);
      expect(CurrencyFormatter.toRupees(12550), 125.50);
      expect(CurrencyFormatter.toPaise(0.01), 1);
      expect(CurrencyFormatter.toRupees(1), 0.01);
    });
  });
}
