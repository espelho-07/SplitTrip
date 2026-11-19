import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/receipt_data.dart';
import 'package:kith_app/presentation/viewmodels/receipt_review_viewmodel.dart';

void main() {
  group('ReceiptReviewViewModel', () {
    const initialReceipt = ReceiptData(
      id: 'rcpt-test',
      imagePath: '/tmp/test.jpg',
      merchant: ReceiptMerchant(name: 'Cafe Good Vibes'),
      receipt: ReceiptMetadata(receiptNumber: 'INV-101'),
      items: [
        ReceiptItem(
          id: 'item-1',
          name: 'Cold Coffee',
          quantity: 2,
          unitPriceInPaise: 15000,
          totalPriceInPaise: 30000,
        ),
      ],
      summary: ReceiptSummary(
        subtotalInPaise: 30000,
        totalInPaise: 30000,
      ),
    );

    test('adds an item and updates items sum and summary', () {
      final vm = ReceiptReviewViewModel(initialReceipt: initialReceipt);

      expect(vm.receipt.items.length, 1);
      expect(vm.receipt.itemsSumInPaise, 30000);

      vm.addItem(
        name: 'Brownie',
        quantity: 1,
        unitPriceInPaise: 10000,
      );

      expect(vm.receipt.items.length, 2);
      expect(vm.receipt.itemsSumInPaise, 40000);
      expect(vm.receipt.summary.subtotalInPaise, 40000);
      expect(vm.receipt.summary.totalInPaise, 40000);
    });

    test('updates item quantity and recalculates line total', () {
      final vm = ReceiptReviewViewModel(initialReceipt: initialReceipt);

      vm.updateItem('item-1', quantity: 3);

      expect(vm.receipt.items.first.quantity, 3);
      expect(vm.receipt.items.first.totalPriceInPaise, 45000);
      expect(vm.receipt.itemsSumInPaise, 45000);
    });

    test('removes item and recalculates summary', () {
      final vm = ReceiptReviewViewModel(initialReceipt: initialReceipt);

      vm.removeItem('item-1');

      expect(vm.receipt.items, isEmpty);
      expect(vm.receipt.itemsSumInPaise, 0);
    });

    test('detects duplicate expense when merchant and total match', () {
      final existingExpense = Expense(
        id: 'exp-existing',
        tripId: 'trip-1',
        title: 'Cafe Good Vibes',
        amountInPaise: 30000,
        category: ExpenseCategory.food,
        paidById: 'user-1',
        splits: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final vm = ReceiptReviewViewModel(
        initialReceipt: initialReceipt,
        existingTripExpenses: [existingExpense],
      );

      expect(vm.duplicateMatch, isNotNull);
      expect(vm.duplicateMatch!.matchingExpense.id, 'exp-existing');
    });

    test('applies calculated total to fix inconsistency', () {
      const inconsistentReceipt = ReceiptData(
        id: 'rcpt-inconsistent',
        imagePath: '/tmp/test.jpg',
        items: [
          ReceiptItem(
            id: 'item-1',
            name: 'Pizza',
            quantity: 1,
            unitPriceInPaise: 40000,
            totalPriceInPaise: 40000,
          ),
        ],
        summary: ReceiptSummary(
          subtotalInPaise: 40000,
          totalInPaise: 10000, // Inconsistent
        ),
      );

      final vm = ReceiptReviewViewModel(initialReceipt: inconsistentReceipt);
      expect(vm.isConsistent, isFalse);
      expect(vm.differenceInPaise, 30000);

      vm.applyCalculatedTotal();
      expect(vm.receipt.summary.totalInPaise, 40000);
      expect(vm.isConsistent, isTrue);
    });
  });
}
