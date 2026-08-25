import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/domain/engine/receipt_parser_engine.dart';
import 'package:kith_app/domain/engine/voice_parser.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 27 Core Intelligence & Journey Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. VoiceIntentParser: English & Hindi phrase parsing precision', () {
      final members = [
        TripMember(id: 'mbr_1', userId: 'usr_1', displayName: 'Darpan', role: 'creator', joinedAt: DateTime.now()),
        TripMember(id: 'mbr_2', userId: 'usr_2', displayName: 'Rahul', role: 'member', joinedAt: DateTime.now()),
        TripMember(id: 'mbr_3', userId: 'usr_3', displayName: 'Priya', role: 'member', joinedAt: DateTime.now()),
      ];

      // English: Spent 500 on lunch
      final draft1 = VoiceIntentParser.parseToDraft('Spent 500 on lunch', members, 'usr_1');
      expect(draft1.amountInPaise, 50000);
      expect(draft1.category, ExpenseCategory.food);
      expect(draft1.title, 'Lunch');
      expect(draft1.payerMemberId, 'mbr_1');

      // 500 rupees lunch
      final draft2 = VoiceIntentParser.parseToDraft('500 rupees lunch', members, 'usr_1');
      expect(draft2.amountInPaise, 50000);
      expect(draft2.category, ExpenseCategory.food);

      // Hinglish: Maine lunch pe 500 kharch kiye
      final draft3 = VoiceIntentParser.parseToDraft('Maine lunch pe 500 kharch kiye', members, 'usr_1');
      expect(draft3.amountInPaise, 50000);
      expect(draft3.category, ExpenseCategory.food);

      // Lending: Rahul ko 500 udhar diye
      final personalLend = VoiceIntentParser.parsePersonalDraft('Rahul ko 500 udhar diye');
      expect(personalLend.type, PersonalVoiceIntentType.lend);
      expect(personalLend.personName, 'Rahul');
      expect(personalLend.amountInPaise, 50000);

      // Borrowing: Priya se 300 udhar liye
      final personalBorrow = VoiceIntentParser.parsePersonalDraft('Priya se 300 udhar liye');
      expect(personalBorrow.type, PersonalVoiceIntentType.borrow);
      expect(personalBorrow.personName, 'Priya');
      expect(personalBorrow.amountInPaise, 30000);

      // Repayment: Rahul returned 300
      final personalRepay = VoiceIntentParser.parsePersonalDraft('Rahul returned 300');
      expect(personalRepay.type, PersonalVoiceIntentType.repayment);
      expect(personalRepay.personName, 'Rahul');
      expect(personalRepay.amountInPaise, 30000);
    });

    test('2. Receipt OCR Parsing & Confidence Scoring', () {
      final members = [
        TripMember(id: 'mbr_1', userId: 'usr_1', displayName: 'Darpan', role: 'creator', joinedAt: DateTime.now()),
      ];

      const sampleBill = '''
CAFE COFFEE DAY
MG Road, Bangalore
TAX INVOICE
1x Cappuccino ₹220
1x Croissant ₹180
1x Cold Coffee ₹250
Subtotal: ₹650
CGST 2.5%: ₹16.25
SGST 2.5%: ₹16.25
TOTAL AMOUNT: ₹850.00
Thank you visit again!
''';

      final draft = ReceiptParserEngine.parseToDraft(sampleBill, members, 'usr_1');
      expect(draft.title, 'CAFE COFFEE DAY');
      expect(draft.amountInPaise, 85000);
      expect(draft.category, ExpenseCategory.drinks);
      expect(draft.confidence, greaterThanOrEqualTo(0.85));
      expect(draft.unresolvedFields.isEmpty, true);

      // Blurry / missing total receipt
      const missingTotalBill = '''
BLURRY RECEIPT
Items ordered: Tea, Samosa
No total visible
''';
      final draftMissing = ReceiptParserEngine.parseToDraft(missingTotalBill, members, 'usr_1');
      expect(draftMissing.amountInPaise, 0);
      expect(draftMissing.unresolvedFields.contains('amount'), true);
      expect(draftMissing.ambiguityMessage != null, true);
    });

    test('3. Trip Modes & Journey Capabilities', () {
      final splitTrip = Trip(
        id: 'trip_1',
        name: 'Apartment Expenses',
        creatorId: 'usr_1',
        members: const [],
        inviteCode: 'FLAT01',
        tripMode: 'split_only',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(splitTrip.isJourneyEnabled, false);

      final journeyTrip = Trip(
        id: 'trip_2',
        name: 'Manali Trek',
        creatorId: 'usr_1',
        members: const [],
        inviteCode: 'TREK02',
        tripMode: 'split_and_journey',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(journeyTrip.isJourneyEnabled, true);
    });
  });
}
