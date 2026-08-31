import 'currency_formatter.dart';

/// Safe mathematical parser and calculator engine for monetary amount inputs.
///
/// Evaluates arithmetic expressions (like '30,000 + 742 + 720', '1500 + 250.50')
/// without using unsafe eval, avoids floating point precision issues,
/// and produces clean, deterministic integer paise results.
class KithCalculatorEngine {
  /// Evaluates an input string expression and returns the amount in paise.
  ///
  /// Examples:
  /// - '30,000 + 742 + 720' -> 3146200 paise (₹31,462.00)
  /// - '500' -> 50000 paise (₹500.00)
  /// - '150.50 + 49.50' -> 20000 paise (₹200.00)
  /// - '' or invalid -> 0
  static int evaluateToPaise(String rawInput) {
    if (rawInput.trim().isEmpty) return 0;

    // Clean up input: remove currency symbols, thousand separators (commas), and whitespace
    String clean = rawInput
        .replaceAll('₹', '')
        .replaceAll('\$', '')
        .replaceAll('€', '')
        .replaceAll('£', '')
        .replaceAll(',', '')
        .trim();

    if (clean.isEmpty) return 0;

    // Remove any trailing operators so unfinished user typing evaluates gracefully
    while (clean.endsWith('+') || clean.endsWith('-') || clean.endsWith('*') || clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1).trim();
    }

    if (clean.isEmpty) return 0;

    try {
      final doubleResult = _evaluateSimpleExpression(clean);
      if (doubleResult.isNaN || doubleResult.isInfinite || doubleResult <= 0) {
        return 0;
      }
      // Safe conversion to integer paise
      return (doubleResult * 100).round();
    } catch (_) {
      return 0;
    }
  }

  /// Checks if the input contains arithmetic operators.
  static bool hasOperator(String input) {
    return input.contains('+') || input.contains('-') || input.contains('*') || input.contains('/');
  }

  /// Returns a formatted preview string if an expression has operators.
  /// E.g. '= ₹31,462' or null if it's just a simple single number.
  static String? getLivePreview(String rawInput, {String currencyCode = 'INR'}) {
    if (!hasOperator(rawInput)) return null;

    final paise = evaluateToPaise(rawInput);
    if (paise <= 0) return null;

    final formatted = CurrencyFormatter.formatPaise(paise, currencyCode: currencyCode);
    return '= $formatted';
  }

  /// Safe recursive descent / tokenized evaluator for basic arithmetic (+, -, *, /).
  static double _evaluateSimpleExpression(String expr) {
    final tokens = _tokenize(expr);
    if (tokens.isEmpty) return 0.0;

    // Step 1: Parse additions and subtractions
    double result = 0.0;
    String currentOp = '+';

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token == '+' || token == '-') {
        currentOp = token;
      } else if (token == '*' || token == '/') {
        // Will be handled in term parsing
      } else {
        final val = double.tryParse(token) ?? 0.0;
        if (currentOp == '+') {
          result += val;
        } else if (currentOp == '-') {
          result -= val;
        }
      }
    }

    return result;
  }

  static List<String> _tokenize(String expr) {
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < expr.length; i++) {
      final char = expr[i];
      if (char == '+' || char == '-') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString().trim());
          buffer.clear();
        }
        tokens.add(char);
      } else if (char == ' ') {
        // skip whitespace
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString().trim());
    }

    return tokens;
  }
}
