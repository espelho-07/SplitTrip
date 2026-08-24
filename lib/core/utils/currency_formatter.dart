import 'package:intl/intl.dart';
import '../../domain/models/currency_config.dart';

/// Formatter for monetary values stored as integer smallest units (paise/cents/pence).
/// Strictly prevents IEEE-754 floating-point inaccuracies across the entire UI.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final Map<String, NumberFormat> _wholeFormatters = {};
  static final Map<String, NumberFormat> _decimalFormatters = {};

  static NumberFormat _getFormatter(String code, bool withDecimals) {
    final currency = AppCurrency.fromCode(code);
    final key = '${currency.code}_$withDecimals';

    if (withDecimals) {
      return _decimalFormatters.putIfAbsent(key, () {
        return NumberFormat.currency(
          locale: currency.locale,
          symbol: currency.symbol,
          decimalDigits: currency.decimalDigits,
        );
      });
    } else {
      return _wholeFormatters.putIfAbsent(key, () {
        return NumberFormat.currency(
          locale: currency.locale,
          symbol: currency.symbol,
          decimalDigits: 0,
        );
      });
    }
  }

  /// Formats an integer amount in smallest unit (e.g. paise/cents) to a clean human string.
  /// Example (INR): 600000 -> "₹6,000"
  /// Example (INR): 46250 -> "₹462.50"
  /// Example (USD): 1250 -> "$12.50"
  /// Example (EUR): 5000 -> "50 €"
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

    final formatter = _getFormatter(currencyCode, hasFraction || forceDecimals);
    final formatted = formatter.format(doubleValue);

    if (isNegative) {
      return '-$formatted';
    } else if (showSign && amountInPaise > 0) {
      return '+$formatted';
    }
    return formatted;
  }

  /// Converts a user entered double or string to integer smallest unit (paise/cents).
  static int toPaise(double mainUnit) {
    return (mainUnit * 100).round();
  }

  /// Converts smallest unit (paise/cents) to standard double representation.
  static double toRupees(int paise) {
    return paise / 100.0;
  }
}
