import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/receipt_parser_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  group('ReceiptParserEngine OCR Extraction Tests', () {
    final members = [
      TripMember(
        id: 'mbr_1',
        userId: 'usr_1',
        displayName: 'Darpan',
        role: 'creator',
        joinedAt: DateTime.now(),
      ),
      TripMember(
        id: 'mbr_2',
        userId: 'usr_2',
        displayName: 'Rahul',
        role: 'member',
        joinedAt: DateTime.now(),
      ),
    ];

    test('Extracts merchant, total amount and category from restaurant tax invoice', () {
      const ocrText = '''
CAFE COFFEE DAY
MG Road, Bangalore
TAX INVOICE
1x Cappuccino ₹220.00
1x Croissant ₹180.00
1x Cold Coffee ₹250.00
Subtotal: ₹650.00
CGST: ₹16.25
SGST: ₹16.25
TOTAL AMOUNT: ₹850.00
Thank you visit again!
''';

      final draft = ReceiptParserEngine.parseToDraft(ocrText, members, 'usr_1');

      expect(draft.title, 'CAFE COFFEE DAY');
      expect(draft.amountInPaise, 85000);
      expect(draft.category, ExpenseCategory.drinks);
      expect(draft.payerMemberId, 'mbr_1');
      expect(draft.unresolvedFields.isEmpty, true);
      expect(draft.isReadyForConfirmation, true);
    });

    test('Extracts grand total from hotel resort bill', () {
      const ocrText = '''
TAJ GATEWAY RESORT
Calangute Beach, Goa
ROOM BILL
Room Charges: ₹5,000.00
Dining: ₹1,500.00
Service Charge: ₹500.00
GRAND TOTAL: ₹7,000.00
Paid via Credit Card
''';

      final draft = ReceiptParserEngine.parseToDraft(ocrText, members, 'usr_1');

      expect(draft.title, 'TAJ GATEWAY RESORT');
      expect(draft.amountInPaise, 700000);
      expect(draft.category, ExpenseCategory.stay);
    });

    test('Flags missing amount when total cannot be found in blurry or partial receipt', () {
      const blurryOcr = '''
TAX INVOICE
Items purchased
Item A
Item B
''';

      final draft = ReceiptParserEngine.parseToDraft(blurryOcr, members, 'usr_1');

      expect(draft.amountInPaise, 0);
      expect(draft.unresolvedFields.contains('amount'), true);
      expect(draft.isReadyForConfirmation, false);
    });
  });
}
