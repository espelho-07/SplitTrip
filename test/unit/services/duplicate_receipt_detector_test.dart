import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/duplicate_receipt_detector.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/receipt_data.dart';

void main() {
  group('DuplicateReceiptDetector', () {
    final baseExpense = Expense(
      id: 'exp-1',
      tripId: 'trip-1',
      title: 'Punjabi Dhaba',
      amountInPaise: 60900,
      category: ExpenseCategory.food,
      paidById: 'user-1',
      splits: [],
      voiceTranscript: 'Bill No: INV-4582',
      createdAt: DateTime(2024, 11, 15, 20, 30),
      updatedAt: DateTime(2024, 11, 15, 20, 30),
    );

    test('detects definite duplicate by receipt number in notes/transcript', () {
      const receipt = ReceiptData(
        id: 'rcpt-1',
        imagePath: '/tmp/receipt.jpg',
        merchant: ReceiptMerchant(name: 'Other Name'),
        receipt: ReceiptMetadata(receiptNumber: 'INV-4582'),
        summary: ReceiptSummary(totalInPaise: 60900),
      );

      final match = DuplicateReceiptDetector.detectDuplicate(
        receipt: receipt,
        existingExpenses: [baseExpense],
      );

      expect(match, isNotNull);
      expect(match!.isDefiniteMatch, isTrue);
      expect(match.matchingExpense.id, 'exp-1');
    });

    test('detects probable duplicate by merchant, amount and close date', () {
      final receipt = ReceiptData(
        id: 'rcpt-2',
        imagePath: '/tmp/receipt.jpg',
        merchant: const ReceiptMerchant(name: 'Punjabi Dhaba'),
        receipt: ReceiptMetadata(
          receiptNumber: 'DIFF-999',
          date: DateTime(2024, 11, 15, 21, 00),
        ),
        summary: const ReceiptSummary(totalInPaise: 60900),
      );

      final match = DuplicateReceiptDetector.detectDuplicate(
        receipt: receipt,
        existingExpenses: [baseExpense],
      );

      expect(match, isNotNull);
      expect(match!.isDefiniteMatch, isFalse);
      expect(match.matchingExpense.id, 'exp-1');
    });

    test('returns null when receipt is distinct', () {
      final receipt = ReceiptData(
        id: 'rcpt-3',
        imagePath: '/tmp/receipt.jpg',
        merchant: const ReceiptMerchant(name: 'Cafe Coffee Day'),
        receipt: ReceiptMetadata(
          receiptNumber: 'CCD-101',
          date: DateTime(2024, 11, 15),
        ),
        summary: const ReceiptSummary(totalInPaise: 25000),
      );

      final match = DuplicateReceiptDetector.detectDuplicate(
        receipt: receipt,
        existingExpenses: [baseExpense],
      );

      expect(match, isNull);
    });
  });
}
