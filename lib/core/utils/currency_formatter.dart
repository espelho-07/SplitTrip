import 'package:intl/intl.dart';

/// Formatter for monetary values stored as integer smallest units (paise/cents).
/// Prevents IEEE-754 floating-point inaccuracies across the entire UI.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _inrWholeFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _inrDecimalFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _usdWholeFormatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 0,
  );

  static final NumberFormat _usdDecimalFormatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );

  /// Formats an integer amount in paise (1 INR = 100 paise) to a clean human string.
  /// Example: 600000 -> "₹6,000"
  /// Example: 46250 -> "₹462.50"
  static String formatPaise(
    int amountInPaise, {
    String currencyCode = 'INR',
    bool showSign = false,
    bool forceDecimals = false,
  }) {
    final isNegative = amountInPaise < 0;
    final absPaise = amountInPaise.abs();
    final doubleValue = absPaise / 100.0;
    final hasFraction = (absPaise % 100) != 0;

    NumberFormat formatter;
    if (currencyCode.toUpperCase() == 'USD') {
      formatter = (hasFraction || forceDecimals)
          ? _usdDecimalFormatter
          : _usdWholeFormatter;
    } else {
      formatter = (hasFraction || forceDecimals)
          ? _inrDecimalFormatter
          : _inrWholeFormatter;
    }

    final formatted = formatter.format(doubleValue);
    if (isNegative) {
      return '-$formatted';
    } else if (showSign && amountInPaise > 0) {
      return '+$formatted';
    }
    return formatted;
  }

  /// Converts a user entered double or string to integer paise.
  static int toPaise(double rupees) {
    return (rupees * 100).round();
  }

  /// Converts paise to standard double representation.
  static double toRupees(int paise) {
    return paise / 100.0;
  }
}
