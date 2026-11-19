import '../../domain/models/expense.dart';
import '../../domain/models/receipt_data.dart';

class DuplicateReceiptMatch {
  final Expense matchingExpense;
  final String reason;
  final bool isDefiniteMatch;

  const DuplicateReceiptMatch({
    required this.matchingExpense,
    required this.reason,
    required this.isDefiniteMatch,
  });
}

class DuplicateReceiptDetector {
  /// Analyzes a scanned receipt against existing trip expenses to detect potential duplicates.
  static DuplicateReceiptMatch? detectDuplicate({
    required ReceiptData receipt,
    required List<Expense> existingExpenses,
  }) {
    if (existingExpenses.isEmpty) return null;

    final receiptTotal = receipt.summary.totalInPaise;
    final receiptNum = receipt.receipt.receiptNumber?.trim().toLowerCase();
    final merchantName = receipt.merchant.name?.trim().toLowerCase();
    final receiptDate = receipt.receipt.date;

    // 1. High-confidence check: Matching Receipt Number in notes/title
    if (receiptNum != null && receiptNum.length >= 3) {
      for (final exp in existingExpenses) {
        if (exp.isDeleted) continue;
        final title = exp.title.toLowerCase();
        final transcript = exp.voiceTranscript?.toLowerCase() ?? '';

        if (title.contains(receiptNum) || transcript.contains(receiptNum)) {
          return DuplicateReceiptMatch(
            matchingExpense: exp,
            reason: 'An existing expense contains receipt #$receiptNum.',
            isDefiniteMatch: true,
          );
        }
      }
    }

    // 2. Probable match: Identical Amount in paise AND Similar Merchant Name
    if (receiptTotal != null && receiptTotal > 0 && merchantName != null && merchantName.length >= 3) {
      for (final exp in existingExpenses) {
        if (exp.isDeleted) continue;
        if (exp.amountInPaise == receiptTotal) {
          final expTitle = exp.title.toLowerCase();
          final isSameMerchant = expTitle.contains(merchantName) || merchantName.contains(expTitle);

          if (isSameMerchant) {
            // Check if within 48 hours or dates match
            final isDateClose = receiptDate == null ||
                (exp.createdAt.difference(receiptDate).inHours.abs() <= 48);

            if (isDateClose) {
              return DuplicateReceiptMatch(
                matchingExpense: exp,
                reason: 'An expense of ₹${(receiptTotal / 100.0).toStringAsFixed(2)} for "$expTitle" was already recorded.',
                isDefiniteMatch: false,
              );
            }
          }
        }
      }
    }

    return null;
  }
}
