import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/receipt_data.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/presentation/views/add_expense/receipt_review_view.dart';

void main() {
  const sampleReceipt = ReceiptData(
    id: 'rcpt-widget-test',
    imagePath: '/tmp/sample_receipt.jpg',
    merchant: ReceiptMerchant(
      name: 'Haldiram Sweets',
      address: '123 Market Road, Delhi',
      phone: '9876543210',
      gstin: '07AAAAA0000A1Z5',
    ),
    receipt: ReceiptMetadata(
      receiptNumber: 'INV-8899',
      currency: 'INR',
    ),
    items: [
      ReceiptItem(
        id: 'item-1',
        name: 'Chole Bhature',
        quantity: 2,
        unitPriceInPaise: 12000,
        totalPriceInPaise: 24000,
      ),
      ReceiptItem(
        id: 'item-2',
        name: 'Gulab Jamun',
        quantity: 2,
        unitPriceInPaise: 4000,
        totalPriceInPaise: 8000,
      ),
    ],
    summary: ReceiptSummary(
      subtotalInPaise: 32000,
      taxes: [
        ReceiptTaxItem(name: 'CGST', rate: 2.5, amountInPaise: 800),
        ReceiptTaxItem(name: 'SGST', rate: 2.5, amountInPaise: 800),
      ],
      totalInPaise: 33600,
    ),
    predictedCategory: ExpenseCategory.food,
  );

  Widget createReviewWidget({
    ReceiptData? receipt,
    List<Expense> existingExpenses = const [],
    required ValueChanged<ReceiptData> onConfirmed,
  }) {
    return MaterialApp(
      home: ReceiptReviewView(
        initialReceipt: receipt ?? sampleReceipt,
        existingTripExpenses: existingExpenses,
        onConfirmed: onConfirmed,
      ),
    );
  }

  group('ReceiptReviewView Widget Tests', () {
    testWidgets('renders merchant, items, breakdown, and grand total', (tester) async {
      await tester.pumpWidget(
        createReviewWidget(onConfirmed: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review Receipt 🧾'), findsOneWidget);
      expect(find.text('Haldiram Sweets'), findsOneWidget);
      expect(find.text('Chole Bhature'), findsOneWidget);
      expect(find.text('Gulab Jamun'), findsOneWidget);
      expect(find.textContaining('336'), findsWidgets);
      expect(find.textContaining('Continue to Add Expense'), findsOneWidget);
    });

    testWidgets('calls onConfirmed with updated data on clicking continue button', (tester) async {
      ReceiptData? confirmedData;
      await tester.pumpWidget(
        createReviewWidget(
          onConfirmed: (data) {
            confirmedData = data;
          },
        ),
      );
      await tester.pumpAndSettle();

      final continueButton = find.textContaining('Continue to Add Expense');
      expect(continueButton, findsOneWidget);

      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(confirmedData, isNotNull);
      expect(confirmedData!.merchant.name, 'Haldiram Sweets');
      expect(confirmedData!.summary.totalInPaise, 33600);
    });

    testWidgets('renders duplicate warning when matching existing expense is provided', (tester) async {
      final existingExpense = Expense(
        id: 'dup-1',
        tripId: 'trip-1',
        title: 'Haldiram Sweets',
        amountInPaise: 33600,
        category: ExpenseCategory.food,
        paidById: 'user-1',
        splits: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createReviewWidget(
          existingExpenses: [existingExpense],
          onConfirmed: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Potential Duplicate Receipt'), findsOneWidget);
      expect(find.textContaining('Haldiram Sweets'), findsWidgets);
    });

    testWidgets('opens Add Item sheet and adds a new item', (tester) async {
      await tester.pumpWidget(
        createReviewWidget(onConfirmed: (_) {}),
      );
      await tester.pumpAndSettle();

      final addItemBtn = find.text('Add Item');
      expect(addItemBtn, findsOneWidget);

      await tester.ensureVisible(addItemBtn);
      await tester.pumpAndSettle();
      await tester.tap(addItemBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Receipt Item'), findsOneWidget);

      // Enter item name and price
      final nameField = find.widgetWithText(TextField, 'Item Name');
      final priceField = find.widgetWithText(TextField, 'Unit Price (₹)');

      await tester.enterText(nameField, 'Lassi');
      await tester.enterText(priceField, '60');
      await tester.pumpAndSettle();

      final confirmAddBtn = find.widgetWithText(ElevatedButton, 'Add to Receipt');
      if (confirmAddBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmAddBtn);
      } else {
        await tester.tap(find.text('Add to Receipt'));
      }
      await tester.pumpAndSettle();

      expect(find.text('Lassi'), findsOneWidget);
    });

    testWidgets('displays inconsistency warning banner and syncs total', (tester) async {
      const inconsistentReceipt = ReceiptData(
        id: 'inconsistent-test',
        imagePath: '/tmp/test.jpg',
        merchant: ReceiptMerchant(name: 'Quick Snacks'),
        items: [
          ReceiptItem(
            id: 'item-1',
            name: 'Samosa',
            quantity: 2,
            unitPriceInPaise: 2000,
            totalPriceInPaise: 4000,
          ),
        ],
        summary: ReceiptSummary(
          subtotalInPaise: 4000,
          totalInPaise: 1000, // Inconsistent: 40.00 vs 10.00
        ),
      );

      await tester.pumpWidget(
        createReviewWidget(
          receipt: inconsistentReceipt,
          onConfirmed: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      final syncBtn = find.text('⚡ Sync Total to Items Sum');
      expect(syncBtn, findsOneWidget);

      await tester.tap(syncBtn);
      await tester.pumpAndSettle();

      expect(find.text('⚡ Sync Total to Items Sum'), findsNothing);
    });

    testWidgets('allows manual editing of Grand Total to unblock confirmation when OCR missed total', (tester) async {
      const zeroTotalReceipt = ReceiptData(
        id: 'zero-total-test',
        imagePath: '/tmp/test.jpg',
        merchant: ReceiptMerchant(name: 'Corner Tea Stall'),
        items: [],
        summary: ReceiptSummary(
          totalInPaise: 0,
        ),
      );

      ReceiptData? confirmedData;
      await tester.pumpWidget(
        createReviewWidget(
          receipt: zeroTotalReceipt,
          onConfirmed: (data) => confirmedData = data,
        ),
      );
      await tester.pumpAndSettle();

      // Should show 'Tap to enter total'
      final tapToEnter = find.text('Tap to enter total');
      expect(tapToEnter, findsOneWidget);

      // Ensure visible in scrollable before tapping
      await tester.ensureVisible(tapToEnter);
      await tester.pumpAndSettle();

      // Tap on Grand Total row to open edit sheet
      await tester.tap(tapToEnter);
      await tester.pumpAndSettle();

      expect(find.text('Edit Grand Total'), findsOneWidget);

      // Enter 125.50
      final totalField = find.widgetWithText(TextField, 'Total Amount (₹)');
      await tester.enterText(totalField, '125.50');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Save Total'));
      await tester.pumpAndSettle();

      // Now total should be formatted
      expect(find.textContaining('125.50'), findsWidgets);

      // Continue to Add Expense
      final continueBtn = find.textContaining('Continue to Add Expense');
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(confirmedData, isNotNull);
      expect(confirmedData!.summary.totalInPaise, 12550);
    });
  });
}
