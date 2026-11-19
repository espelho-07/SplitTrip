import 'currency_formatter.dart';

/// Status of an expression evaluation.
enum CalculatorEvaluationStatus {
  empty,
  valid,
  incomplete,
  error,
}

/// Rich result returned by [KithCalculatorEngine.evaluateExpression].
class CalculatorEvaluationResult {
  final CalculatorEvaluationStatus status;
  final int amountInPaise;
  final double rawValue;
  final String? previewText;
  final String? errorMessage;
  final bool hasOperators;

  const CalculatorEvaluationResult({
    required this.status,
    required this.amountInPaise,
    required this.rawValue,
    this.previewText,
    this.errorMessage,
    required this.hasOperators,
  });

  bool get isValid => status == CalculatorEvaluationStatus.valid;
  bool get isIncomplete => status == CalculatorEvaluationStatus.incomplete;
  bool get isError => status == CalculatorEvaluationStatus.error;
}

/// Custom exception thrown by the internal AST / recursive descent parser.
class CalculationException implements Exception {
  final String message;
  CalculationException(this.message);

  @override
  String toString() => message;
}

/// Safe, high-precision mathematical parser and calculator engine for monetary inputs.
///
/// Supports:
/// - Addition (+), Subtraction (-)
/// - Multiplication (*, ×, x), Division (/, ÷)
/// - Parentheses ()
/// - Standard operator precedence (BODMAS / PEMDAS)
/// - Decimal values (e.g. 12.50 * 2 = 25.00)
/// - Comma-separated thousands (e.g. 30,000 + 500)
/// - Division-by-zero validation
/// - Incomplete typing resilience
/// - Conversion to canonical integer paise without floating-point inaccuracies
class KithCalculatorEngine {
  /// Evaluates an input string expression and returns the canonical amount in paise.
  ///
  /// Examples:
  /// - '100+23' -> 12300 paise (₹123.00)
  /// - '23*5' -> 11500 paise (₹115.00)
  /// - '500/2' -> 25000 paise (₹250.00)
  /// - '100+23*2' -> 14600 paise (₹146.00)
  /// - '(100+23)*2' -> 24600 paise (₹246.00)
  /// - '12.50*2' -> 2500 paise (₹25.00)
  /// - '100+' -> 10000 paise (while typing)
  /// - '10/0' or invalid -> 0 paise
  static int evaluateToPaise(String rawInput) {
    final res = evaluateExpression(rawInput);
    if (res.status == CalculatorEvaluationStatus.error) {
      return 0;
    }
    return res.amountInPaise;
  }

  /// Checks if the input contains arithmetic operators or parentheses.
  static bool hasOperator(String input) {
    return input.contains('+') ||
        input.contains('-') ||
        input.contains('*') ||
        input.contains('×') ||
        input.contains('x') ||
        input.contains('X') ||
        input.contains('/') ||
        input.contains('÷') ||
        input.contains('(') ||
        input.contains(')');
  }

  /// Returns a formatted preview string if an expression has operators (e.g. '= ₹123.00'),
  /// or null if it's just a simple single number.
  static String? getLivePreview(String rawInput, {String currencyCode = 'INR'}) {
    final res = evaluateExpression(rawInput, currencyCode: currencyCode);
    if (!res.hasOperators) return null;
    return res.previewText;
  }

  /// Complete parser and evaluator returning structured validation state and amounts.
  static CalculatorEvaluationResult evaluateExpression(
    String rawInput, {
    String currencyCode = 'INR',
  }) {
    if (rawInput.trim().isEmpty) {
      return const CalculatorEvaluationResult(
        status: CalculatorEvaluationStatus.empty,
        amountInPaise: 0,
        rawValue: 0.0,
        hasOperators: false,
      );
    }

    final hasOps = hasOperator(rawInput);

    // Normalize operators and strip currency symbols
    String clean = _sanitizeInput(rawInput);
    if (clean.isEmpty) {
      return const CalculatorEvaluationResult(
        status: CalculatorEvaluationStatus.empty,
        amountInPaise: 0,
        rawValue: 0.0,
        hasOperators: false,
      );
    }

    // Check if the user is currently mid-keystroke (ends with operator)
    bool isIncomplete = false;
    String evalTarget = clean;

    // If expression ends with an operator, strip trailing operators to preview current value
    if (evalTarget.endsWith('+') ||
        evalTarget.endsWith('-') ||
        evalTarget.endsWith('*') ||
        evalTarget.endsWith('/') ||
        evalTarget.endsWith('(')) {
      isIncomplete = true;
      while (evalTarget.endsWith('+') ||
          evalTarget.endsWith('-') ||
          evalTarget.endsWith('*') ||
          evalTarget.endsWith('/') ||
          evalTarget.endsWith('(')) {
        evalTarget = evalTarget.substring(0, evalTarget.length - 1).trim();
      }
    }

    // Automatically close any unclosed opening parentheses for live typing preview
    int openParens = 0;
    for (int i = 0; i < evalTarget.length; i++) {
      if (evalTarget[i] == '(') openParens++;
      if (evalTarget[i] == ')') openParens--;
    }
    if (openParens > 0) {
      isIncomplete = true;
      evalTarget += ')' * openParens;
    } else if (openParens < 0) {
      return CalculatorEvaluationResult(
        status: CalculatorEvaluationStatus.error,
        amountInPaise: 0,
        rawValue: 0.0,
        errorMessage: 'Unmatched closing parenthesis',
        hasOperators: hasOps,
      );
    }

    if (evalTarget.isEmpty) {
      return CalculatorEvaluationResult(
        status: CalculatorEvaluationStatus.incomplete,
        amountInPaise: 0,
        rawValue: 0.0,
        hasOperators: hasOps,
      );
    }

    try {
      final tokens = _tokenize(evalTarget);
      if (tokens.isEmpty) {
        return const CalculatorEvaluationResult(
          status: CalculatorEvaluationStatus.empty,
          amountInPaise: 0,
          rawValue: 0.0,
          hasOperators: false,
        );
      }

      final parser = _RecursiveDescentParser(tokens);
      final doubleResult = parser.parse();

      if (doubleResult.isNaN || doubleResult.isInfinite) {
        return CalculatorEvaluationResult(
          status: CalculatorEvaluationStatus.error,
          amountInPaise: 0,
          rawValue: 0.0,
          errorMessage: 'Cannot divide by zero',
          hasOperators: hasOps,
        );
      }

      if (doubleResult < 0) {
        return CalculatorEvaluationResult(
          status: CalculatorEvaluationStatus.error,
          amountInPaise: 0,
          rawValue: doubleResult,
          errorMessage: 'Amount cannot be negative',
          hasOperators: hasOps,
        );
      }

      if (doubleResult > 1000000000) {
        return CalculatorEvaluationResult(
          status: CalculatorEvaluationStatus.error,
          amountInPaise: 0,
          rawValue: doubleResult,
          errorMessage: 'Amount exceeds maximum limit',
          hasOperators: hasOps,
        );
      }

      final paise = (doubleResult * 100.0).round();
      final formatted = CurrencyFormatter.formatPaise(paise, currencyCode: currencyCode);

      return CalculatorEvaluationResult(
        status: isIncomplete
            ? CalculatorEvaluationStatus.incomplete
            : CalculatorEvaluationStatus.valid,
        amountInPaise: paise,
        rawValue: doubleResult,
        previewText: '= $formatted',
        hasOperators: hasOps,
      );
    } on CalculationException catch (e) {
      return CalculatorEvaluationResult(
        status: CalculatorEvaluationStatus.error,
        amountInPaise: 0,
        rawValue: 0.0,
        errorMessage: e.message,
        hasOperators: hasOps,
      );
    } catch (_) {
      return CalculatorEvaluationResult(
        status: CalculatorEvaluationStatus.error,
        amountInPaise: 0,
        rawValue: 0.0,
        errorMessage: 'Invalid expression',
        hasOperators: hasOps,
      );
    }
  }

  /// Sanitizes raw input string by stripping currency symbols and normalizing operators.
  static String _sanitizeInput(String raw) {
    var s = raw
        .replaceAll('₹', '')
        .replaceAll('\$', '')
        .replaceAll('€', '')
        .replaceAll('£', '')
        .replaceAll(',', '')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .trim();

    // Convert letter 'x' or 'X' to multiplication only if flanked by numbers, parens or whitespace
    s = s.replaceAllMapped(
      RegExp(r'(\d|\))\s*[xX]\s*(\d|\()'),
      (m) => '${m.group(1)}*${m.group(2)}',
    );

    return s;
  }

  /// Breaks string into arithmetic tokens (numbers, operators, parentheses).
  static List<String> _tokenize(String expr) {
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < expr.length; i++) {
      final char = expr[i];

      if (char == '+' ||
          char == '-' ||
          char == '*' ||
          char == '/' ||
          char == '(' ||
          char == ')') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString().trim());
          buffer.clear();
        }
        tokens.add(char);
      } else if (char == ' ') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString().trim());
          buffer.clear();
        }
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

/// Deterministic, safe Recursive Descent Parser for arithmetic expressions.
/// Enforces standard operator precedence (BODMAS / PEMDAS) and strict validation.
class _RecursiveDescentParser {
  final List<String> _tokens;
  int _pos = 0;

  _RecursiveDescentParser(this._tokens);

  String? _peek() => _pos < _tokens.length ? _tokens[_pos] : null;

  String _next() {
    if (_pos >= _tokens.length) {
      throw CalculationException('Unexpected end of expression');
    }
    return _tokens[_pos++];
  }

  double parse() {
    final result = _parseExpression();
    if (_pos < _tokens.length) {
      throw CalculationException('Unexpected symbol: ${_tokens[_pos]}');
    }
    return result;
  }

  /// Expression: Term (('+' | '-') Term)*
  double _parseExpression() {
    double result = _parseTerm();

    while (_peek() == '+' || _peek() == '-') {
      final op = _next();
      final right = _parseTerm();
      if (op == '+') {
        result += right;
      } else {
        result -= right;
      }
    }

    return result;
  }

  /// Term: Factor (('*' | '/') Factor)*
  double _parseTerm() {
    double result = _parseFactor();

    while (_peek() == '*' || _peek() == '/') {
      final op = _next();
      final right = _parseFactor();
      if (op == '*') {
        result *= right;
      } else {
        if (right == 0.0) {
          throw CalculationException('Cannot divide by zero');
        }
        result /= right;
      }
    }

    return result;
  }

  /// Factor: Unary? (Number | '(' Expression ')')
  double _parseFactor() {
    final token = _peek();
    if (token == null) {
      throw CalculationException('Incomplete expression');
    }

    // Unary plus
    if (token == '+') {
      _next();
      return _parseFactor();
    }

    // Unary minus
    if (token == '-') {
      _next();
      return -_parseFactor();
    }

    // Parenthesized sub-expression
    if (token == '(') {
      _next(); // consume '('
      final inner = _parseExpression();
      if (_peek() != ')') {
        throw CalculationException('Unmatched parentheses');
      }
      _next(); // consume ')'
      return inner;
    }

    // Number
    final numToken = _next();
    final val = double.tryParse(numToken);
    if (val == null) {
      throw CalculationException('Invalid number: $numToken');
    }
    return val;
  }
}
