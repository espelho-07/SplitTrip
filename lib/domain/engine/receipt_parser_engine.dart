import '../enums/expense_category.dart';
import '../enums/split_type.dart';
import '../models/expense_draft.dart';
import '../models/trip_member.dart';

/// Deterministic OCR text extraction engine for receipts and bills.
/// Extracts merchant, total amount in paise, date, and category.
class ReceiptParserEngine {
  ReceiptParserEngine._();

  static ExpenseDraft parseToDraft(
    String ocrText,
    List<TripMember> members,
    String currentUserId,
  ) {
    final cleanText = ocrText.trim();
    final lines = cleanText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final unresolved = <String>[];

    // 1. Identify Merchant
    String merchant = _extractMerchant(lines);

    // 2. Extract Total Amount
    int? amountInPaise = _extractTotalAmount(lines);
    if (amountInPaise == null || amountInPaise <= 0) {
      amountInPaise = 0;
      unresolved.add('amount');
    }

    // 3. Infer Category
    final category = _extractCategory(cleanText, merchant);

    // 4. Resolve Payer (Default to current user)
    final selfMember = members.where((m) => m.userId == currentUserId).firstOrNull ??
        members.firstOrNull;
    final resolvedPayerId = selfMember?.id;
    final resolvedPayerName = selfMember?.displayName;

    // 5. Participants (Default to all members)
    final participantIds = members.map((m) => m.id).toList();

    double confidence = (amountInPaise > 0 && merchant.isNotEmpty) ? 0.90 : 0.40;

    return ExpenseDraft(
      amountInPaise: amountInPaise,
      title: merchant.isNotEmpty ? merchant : 'Receipt Expense',
      category: category,
      payerMemberId: resolvedPayerId,
      payerName: resolvedPayerName,
      participantMemberIds: participantIds,
      splitType: SplitType.equal,
      confidence: confidence,
      rawInput: ocrText,
      source: ExpenseDraftSource.receiptOcr,
      unresolvedFields: unresolved,
      ambiguityMessage: unresolved.contains('amount')
          ? 'Could not confidently detect the receipt total. Please enter the amount manually.'
          : null,
    );
  }

  static String _extractMerchant(List<String> lines) {
    if (lines.isEmpty) return 'Receipt';

    // Typically the first non-generic line is the merchant name
    for (int i = 0; i < lines.length && i < 3; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (!lower.contains('tax invoice') &&
          !lower.contains('receipt') &&
          !lower.contains('bill') &&
          !lower.contains('welcome') &&
          !lower.contains('gst') &&
          line.length > 2) {
        return line;
      }
    }
    return lines.first;
  }

  static int? _extractTotalAmount(List<String> lines) {
    // Search priority 1: Explicit total line keywords (GRAND TOTAL, TOTAL AMOUNT, NET AMOUNT, AMOUNT DUE, TOTAL)
    final totalPatterns = [
      RegExp(r'(?:grand\s+total|total\s+amount|net\s+amount|amount\s+payable|balance\s+due|bill\s+amount)\s*[:=]?\s*(?:₹|rs\.?|inr|\$)?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'\btotal\b\s*[:=]?\s*(?:₹|rs\.?|inr|\$)?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:subtotal|sub\s+total)\s*[:=]?\s*(?:₹|rs\.?|inr|\$)?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)', caseSensitive: false),
    ];

    for (final pattern in totalPatterns) {
      for (final line in lines.reversed) {
        final match = pattern.firstMatch(line);
        if (match != null && match.group(1) != null) {
          final cleaned = match.group(1)!.replaceAll(',', '');
          final val = double.tryParse(cleaned);
          if (val != null && val > 0) {
            return (val * 100).round();
          }
        }
      }
    }

    // Search priority 2: Lines containing currency symbols near bottom
    final currencyPattern = RegExp(r'(?:₹|rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)', caseSensitive: false);
    for (final line in lines.reversed) {
      final match = currencyPattern.firstMatch(line);
      if (match != null && match.group(1) != null) {
        final cleaned = match.group(1)!.replaceAll(',', '');
        final val = double.tryParse(cleaned);
        if (val != null && val > 0) {
          return (val * 100).round();
        }
      }
    }

    return null;
  }

  static ExpenseCategory _extractCategory(String text, String merchant) {
    final lower = '$text $merchant'.toLowerCase();

    if (lower.contains('cafe') ||
        lower.contains('coffee') ||
        lower.contains('bar') ||
        lower.contains('pub') ||
        lower.contains('brewery')) {
      return ExpenseCategory.drinks;
    }
    if (lower.contains('hotel') ||
        lower.contains('resort') ||
        lower.contains('stay') ||
        lower.contains('inn') ||
        lower.contains('suites') ||
        lower.contains('room bill') ||
        lower.contains('room charges') ||
        merchant.toLowerCase().contains('hotel') ||
        merchant.toLowerCase().contains('resort') ||
        merchant.toLowerCase().contains('stay')) {
      return ExpenseCategory.stay;
    }
    if (lower.contains('restaurant') ||
        lower.contains('dining') ||
        lower.contains('food') ||
        lower.contains('kitchen') ||
        lower.contains('pizza') ||
        lower.contains('burger') ||
        lower.contains('dhaba') ||
        lower.contains('sweets') ||
        lower.contains('baker') ||
        lower.contains('bites')) {
      return ExpenseCategory.food;
    }
    if (lower.contains('petrol') ||
        lower.contains('fuel') ||
        lower.contains('diesel') ||
        lower.contains('gas station') ||
        lower.contains('hpcl') ||
        lower.contains('bpcl') ||
        lower.contains('ioc')) {
      return ExpenseCategory.transport;
    }
    if (lower.contains('supermarket') ||
        lower.contains('grocery') ||
        lower.contains('mart') ||
        lower.contains('hyper') ||
        lower.contains('store') ||
        lower.contains('provisions')) {
      return ExpenseCategory.groceries;
    }
    if (lower.contains('transport') ||
        lower.contains('toll') ||
        lower.contains('cab') ||
        lower.contains('taxi') ||
        lower.contains('airline') ||
        lower.contains('rail')) {
      return ExpenseCategory.transport;
    }

    return ExpenseCategory.general;
  }
}
