import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/receipt_parser_service.dart';
import 'package:kith_app/domain/models/receipt_data.dart';

void main() {
  late ReceiptParserService parser;

  setUp(() {
    parser = ReceiptParserService();
  });

  group('Receipt Spatial Reconstruction & Advanced Indian Intelligence Tests', () {
    test('reconstructs two-column receipt where OCR read items and prices in disjoint columns', () {
      // In this realistic scenario, ML Kit extracted the left text block first, then the right price column
      final structuredLines = [
        // Header
        const OcrLine(
          text: 'SHARMA DHABA & CAFE',
          boundingBox: OcrBoundingBox(left: 40, top: 20, right: 300, bottom: 45),
        ),
        const OcrLine(
          text: 'Date: 18/11/2024',
          boundingBox: OcrBoundingBox(left: 40, top: 50, right: 180, bottom: 70),
        ),
        // Left column: item names
        const OcrLine(
          text: 'Paneer Butter Masala',
          boundingBox: OcrBoundingBox(left: 40, top: 100, right: 220, bottom: 125),
        ),
        const OcrLine(
          text: 'Butter Naan',
          boundingBox: OcrBoundingBox(left: 40, top: 135, right: 150, bottom: 160),
        ),
        const OcrLine(
          text: 'Jeera Rice',
          boundingBox: OcrBoundingBox(left: 40, top: 170, right: 140, bottom: 195),
        ),
        // Right column: prices (horizontally aligned with items, big gap > 20px)
        const OcrLine(
          text: '280.00',
          boundingBox: OcrBoundingBox(left: 380, top: 102, right: 460, bottom: 124),
        ),
        const OcrLine(
          text: '80.00',
          boundingBox: OcrBoundingBox(left: 380, top: 136, right: 450, bottom: 158),
        ),
        const OcrLine(
          text: '140.00',
          boundingBox: OcrBoundingBox(left: 380, top: 171, right: 460, bottom: 194),
        ),
        // Footer: Total line
        const OcrLine(
          text: 'Total: 500.00',
          boundingBox: OcrBoundingBox(left: 40, top: 220, right: 460, bottom: 250),
        ),
      ];

      final receipt = parser.parse(
        rawText: 'SHARMA DHABA & CAFE\nDate: 18/11/2024\nPaneer Butter Masala\nButter Naan\nJeera Rice\n280.00\n80.00\n140.00\nTotal: 500.00',
        structuredLines: structuredLines,
        imagePath: '/tmp/two_column.jpg',
      );

      expect(receipt.ocr.isTwoColumnDetected, isTrue);
      expect(receipt.merchant.name, 'SHARMA DHABA & CAFE');
      expect(receipt.items.length, 3);
      expect(receipt.items[0].name, 'Paneer Butter Masala');
      expect(receipt.items[0].totalPriceInPaise, 28000);
      expect(receipt.items[1].name, 'Butter Naan');
      expect(receipt.items[1].totalPriceInPaise, 8000);
      expect(receipt.items[2].name, 'Jeera Rice');
      expect(receipt.items[2].totalPriceInPaise, 14000);
      expect(receipt.summary.totalInPaise, 50000);
      expect(receipt.isCalculationConsistent, isTrue);
    });

    test('filters Indian HSN/SAC codes without treating them as prices or quantities', () {
      const sampleText = '''
SPICE GARDEN RESTAURANT
GSTIN: 27AABCS1429B1Z1
Date: 20/11/2024
Bill: 8841

HSN: 996331 Dal Makhani 1 250.00
996331 Tandoori Roti 4 25.00 100.00

Sub Total: 350.00
CGST 2.5%: 8.75
SGST 2.5%: 8.75
Round Off: -0.50
Grand Total: 367.00
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/hsn_bill.jpg',
      );

      expect(receipt.merchant.name, 'SPICE GARDEN RESTAURANT');
      expect(receipt.merchant.gstin, '27AABCS1429B1Z1');
      expect(receipt.items.length, 2);
      expect(receipt.items[0].name, 'Dal Makhani');
      expect(receipt.items[0].totalPriceInPaise, 25000);
      expect(receipt.items[1].name, 'Tandoori Roti');
      expect(receipt.items[1].quantity, 4.0);
      expect(receipt.items[1].totalPriceInPaise, 10000);

      expect(receipt.summary.subtotalInPaise, 35000);
      expect(receipt.summary.taxes.length, 2);
      expect(receipt.summary.roundOffInPaise, -50);
      expect(receipt.summary.totalInPaise, 36700);
      expect(receipt.isCalculationConsistent, isTrue);
    });

    test('parses multi-tax receipt with food (5% GST) and beverages (18% GST)', () {
      const sampleText = '''
THE BREWHOUSE BISTRO
Date: 19/11/2024
Order No: 4921

Classic Burger 1 250.00
Craft Beverage 2 300.00 600.00

Subtotal: 850.00
CGST 2.5%: 6.25
SGST 2.5%: 6.25
CGST 9%: 54.00
SGST 9%: 54.00
Grand Total: 970.50
Payment: UPI
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/multi_tax.jpg',
      );

      expect(receipt.merchant.name, 'THE BREWHOUSE BISTRO');
      expect(receipt.items.length, 2);
      expect(receipt.summary.subtotalInPaise, 85000);
      // All 4 taxes must be captured
      expect(receipt.summary.taxes.length, 4);
      expect(receipt.summary.totalTaxesInPaise, 12050);
      expect(receipt.summary.totalInPaise, 97050);
      expect(receipt.isCalculationConsistent, isTrue);
      expect(receipt.payment.method, 'UPI');
    });

    test('ignores Total Qty, Cash Tendered, and Change Due when extracting Grand Total', () {
      const sampleText = '''
SMART SUPERMARKET
Tax Invoice
Date: 14/11/2024

Milk 1L 2 60.00 120.00
Wheat Bread 1 50.00
Eggs 12pk 1 90.00

Total Qty: 4
Total Items: 3
Subtotal: 260.00
Grand Total: 260.00
Cash Tendered: 2000.00
Change Due: 1740.00
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/supermarket.jpg',
      );

      expect(receipt.merchant.name, 'SMART SUPERMARKET');
      expect(receipt.summary.totalInPaise, 26000);
      expect(receipt.items.length, 3);
      expect(receipt.isCalculationConsistent, isTrue);
    });

    test('infers missing Grand Total from itemized subtotal and taxes with inferred status', () {
      const sampleText = '''
CORNER CAFE
Date: 10/11/2024

Hot Chocolate 1 180.00
Apple Pie 1 120.00
CGST 2.5%: 7.50
SGST 2.5%: 7.50
[RECEIPT BOTTOM TORN OFF]
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/torn_receipt.jpg',
      );

      // Total should be inferred: 180 + 120 + 7.50 + 7.50 = 315.00
      expect(receipt.summary.totalInPaise, 31500);
      expect(receipt.ocr.fieldConfidence.total, FieldVerificationStatus.inferred);
      expect(
        receipt.ocr.warnings.any((w) => w.contains('inferred from item breakdown')),
        isTrue,
      );
      expect(receipt.items.length, 2);
    });

    test('handles multi-line item description where item name is wrapped on line 1 and price on line 2', () {
      const sampleText = '''
ROYAL HERITAGE THALI
Date: 15/11/2024

MAHARAJA DELUXE SPECIAL THALI WITH DESSERT
1 x 450.00 450.00
FRESH SWEET LIME SODA
1 x 70.00 70.00

Sub Total: 520.00
Grand Total: 520.00
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/multiline_item.jpg',
      );

      expect(receipt.merchant.name, 'ROYAL HERITAGE THALI');
      expect(receipt.items.length, 2);
      expect(receipt.summary.totalInPaise, 52000);
      expect(receipt.isCalculationConsistent, isTrue);
    });

    test('assigns granular field-level verification statuses with informative warnings', () {
      // Missing merchant and missing date
      const sampleText = '''
Cold Coffee 1 120.00
Brownie 1 80.00
Total: 200.00
''';

      final receipt = parser.parse(
        rawText: sampleText,
        imagePath: '/tmp/no_merchant.jpg',
      );

      expect(receipt.ocr.fieldConfidence.merchant, FieldVerificationStatus.needsReview);
      expect(receipt.ocr.fieldConfidence.date, FieldVerificationStatus.needsReview);
      expect(receipt.ocr.fieldConfidence.total, FieldVerificationStatus.verified);
      expect(receipt.ocr.fieldConfidence.items, FieldVerificationStatus.verified);
      expect(
        receipt.ocr.fieldConfidence.fieldWarnings.any((w) => w.contains('Merchant name could not be identified')),
        isTrue,
      );
    });
  });
}
