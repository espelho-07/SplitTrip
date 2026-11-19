import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/receipt_parser_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/receipt_data.dart';

void main() {
  late ReceiptParserService parser;

  setUp(() {
    parser = ReceiptParserService();
  });

  group('ReceiptParserService', () {
    test('parses Indian GST Restaurant Bill with items, taxes and totals', () {
      const sampleText = '''
PUNJABI DHABA & RESTAURANT
12, MG Road, Bengaluru
GSTIN: 29AABCU9603R1ZM
Phone: 9876543210
Date: 15/11/2024  Time: 20:30
Bill No: INV-4582

Paneer Butter Masala 1 280.00
Butter Naan 4 x 40.00 160.00
Jeera Rice 1 140.00

Sub Total: 580.00
CGST 2.5%: 14.50
SGST 2.5%: 14.50
Grand Total: 609.00
Payment: UPI / GPay
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/receipt1.jpg',
      );

      expect(receipt.merchant.name, 'PUNJABI DHABA & RESTAURANT');
      expect(receipt.merchant.gstin, '29AABCU9603R1ZM');
      expect(receipt.merchant.phone, '9876543210');
      expect(receipt.receipt.receiptNumber, 'INV-4582');
      expect(receipt.receipt.date, DateTime(2024, 11, 15));
      expect(receipt.receipt.time, '20:30');

      expect(receipt.items.length, 3);
      expect(receipt.items[0].name, 'Paneer Butter Masala');
      expect(receipt.items[0].totalPriceInPaise, 28000);
      expect(receipt.items[1].name, 'Butter Naan');
      expect(receipt.items[1].quantity, 4.0);
      expect(receipt.items[1].totalPriceInPaise, 16000);

      expect(receipt.summary.subtotalInPaise, 58000);
      expect(receipt.summary.taxes.length, 2);
      expect(receipt.summary.taxes[0].name, 'CGST');
      expect(receipt.summary.taxes[0].amountInPaise, 1450);
      expect(receipt.summary.taxes[1].name, 'SGST');
      expect(receipt.summary.taxes[1].amountInPaise, 1450);
      expect(receipt.summary.totalInPaise, 60900);

      expect(receipt.payment.method, 'UPI');
      expect(receipt.predictedCategory, ExpenseCategory.food);
      expect(receipt.isCalculationConsistent, isTrue);
      expect(receipt.ocr.confidence, OcrConfidenceLevel.high);
    });

    test('parses Retail Bill with Discount and Round Off', () {
      const sampleText = '''
SUPERMART RETAIL
Tax Invoice
Date: 2024-10-05
Invoice Ref: SM-9921

Almonds 500g 1 450.00
Green Tea 1 200.00
Biscuits 2 50.00 100.00

Sub Total: 750.00
Discount: 50.00
Round Off: -0.00
Grand Total: 700.00
Paid via: Credit Card
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/receipt2.jpg',
      );

      expect(receipt.merchant.name, 'SUPERMART RETAIL');
      expect(receipt.receipt.receiptNumber, 'SM-9921');
      expect(receipt.receipt.date, DateTime(2024, 10, 5));
      expect(receipt.items.length, 3);
      expect(receipt.summary.subtotalInPaise, 75000);
      expect(receipt.summary.discountInPaise, 5000);
      expect(receipt.summary.totalInPaise, 70000);
      expect(receipt.payment.method, 'Card');
      expect(receipt.predictedCategory, ExpenseCategory.groceries);
      expect(receipt.isCalculationConsistent, isTrue);
    });

    test('parses Cafe bill with Service Charge and 18% GST (9% CGST + 9% SGST)', () {
      const sampleText = '''
BLUE TOKAI COFFEE ROASTERS
Indiranagar, Bangalore
GSTIN: 29AAGCB1234D1Z8
Date: 12-Nov-2024 16:45
Order No: BT-302

Cappuccino 2 220.00 440.00
Croissant 1 180.00

Subtotal: 620.00
Service Charge: 31.00
CGST 9%: 58.59
SGST 9%: 58.59
Grand Total: 768.18
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/cafe.jpg',
      );

      expect(receipt.merchant.name, 'BLUE TOKAI COFFEE ROASTERS');
      expect(receipt.receipt.date, DateTime(2024, 11, 12));
      expect(receipt.items.length, 2);
      expect(receipt.summary.subtotalInPaise, 62000);
      expect(receipt.summary.additionalChargesInPaise, 3100);
      expect(receipt.summary.totalInPaise, 76818);
      expect(receipt.predictedCategory, ExpenseCategory.food);
      expect(receipt.isCalculationConsistent, isTrue);
    });

    test('parses Fuel / Petrol receipt and maps to Transport category', () {
      const sampleText = '''
INDIAN OIL CORPORATION LTD
COCO BANGALORE
Date: 01/11/2024
Time: 09:15:00
Receipt No: IOC-88291

Petrol 15.50L 102.50 1588.75

Total Amount: 1588.75
Payment Mode: UPI
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/fuel.jpg',
      );

      expect(receipt.merchant.name, 'INDIAN OIL CORPORATION LTD');
      expect(receipt.receipt.receiptNumber, 'IOC-88291');
      expect(receipt.summary.totalInPaise, 158875);
      expect(receipt.predictedCategory, ExpenseCategory.transport);
    });

    test('parses Cinema ticket receipt and maps to Activities category', () {
      const sampleText = '''
PVR INOX CINEMAS
Forum Mall, Koramangala
Date: 25-Oct-2024
Bill No: PVR-4412

Movie Tickets 2 350.00 700.00
Popcorn & Coke Combo 1 450.00

Grand Total: 1150.00
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/cinema.jpg',
      );

      expect(receipt.merchant.name, 'PVR INOX CINEMAS');
      expect(receipt.summary.totalInPaise, 115000);
      expect(receipt.predictedCategory, ExpenseCategory.activities);
    });

    test('flags warning on calculation mismatch', () {
      const sampleText = '''
BISTRO CAFE
Cold Coffee 1 150.00
Sandwich 1 200.00

Subtotal: 350.00
Grand Total: 500.00
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/receipt3.jpg',
      );

      expect(receipt.isCalculationConsistent, isFalse);
      expect(receipt.ocr.confidence, OcrConfidenceLevel.needsVerification);
      expect(
        receipt.ocr.warnings.any((w) => w.contains('Receipt calculation does not strictly match')),
        isTrue,
      );
    });

    test('handles empty or unreadable text gracefully without throwing', () {
      final receipt = parser.parse(
        rawText: '   \n\n   ',
        imagePath: '/tmp/empty.jpg',
      );

      expect(receipt.ocr.status, 'failed');
      expect(receipt.ocr.confidence, OcrConfidenceLevel.low);
      expect(receipt.items, isEmpty);
      expect(receipt.summary.totalInPaise, isNull);
    });

    test('recovers from optical OCR character confusion in amounts and items', () {
      const sampleText = '''
THE COFFEE CLUB
Cappuccino 1 I50.OO
Croissant 1 12O.00
Grand Total: 27O.00
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/ocr_confused.jpg',
      );

      expect(receipt.summary.totalInPaise, 27000);
      expect(receipt.items.length, 2);
      expect(receipt.items[0].totalPriceInPaise, 15000);
      expect(receipt.items[1].totalPriceInPaise, 12000);
      expect(receipt.isCalculationConsistent, isTrue);
    });

    test('correctly parses negative fractional round-off and discounts without sign inversion', () {
      const sampleText = '''
METRO SUPERSTORE
Bread 1 45.00
Butter 1 55.00
Sub Total: 100.00
Round Off: -0.40
Grand Total: 99.60
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/roundoff.jpg',
      );

      expect(receipt.summary.roundOffInPaise, -40);
      expect(receipt.summary.totalInPaise, 9960);
      expect(receipt.summary.subtotalInPaise, 10000);
    });

    test('disambiguates dates by trip currency and rejects invalid calendar dates', () {
      const sampleIndia = '''
MUMBAI CAFE
Date: 05/11/2024
Total: 250.00
''';
      final receiptInr = parser.parse(
        rawText: sampleIndia,
        imagePath: '/tmp/date_inr.jpg',
        tripCurrencyCode: 'INR',
      );
      // In INR, 05/11/2024 is 5th November 2024
      expect(receiptInr.receipt.date, DateTime(2024, 11, 5));

      const sampleUS = '''
NEW YORK DINER
Date: 05/11/2024
Total: 25.00
''';
      final receiptUsd = parser.parse(
        rawText: sampleUS,
        imagePath: '/tmp/date_usd.jpg',
        tripCurrencyCode: 'USD',
      );
      // In USD, 05/11/2024 is May 11, 2024
      expect(receiptUsd.receipt.date, DateTime(2024, 5, 11));

      // Invalid date (Feb 31) should be safely rejected
      const sampleInvalidDate = '''
ANY PLACE
Date: 31/02/2024
Total: 100.00
''';
      final receiptInvalid = parser.parse(
        rawText: sampleInvalidDate,
        imagePath: '/tmp/date_inv.jpg',
      );
      expect(receiptInvalid.receipt.date, isNull);
    });
  });
}
