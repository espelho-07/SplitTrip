import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/multi_expense_voice_parser.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  final members = [
    TripMember(
      id: 'mbr_self',
      userId: 'usr_self',
      displayName: 'Self User',
      role: 'creator',
      joinedAt: DateTime.now(),
    ),
    TripMember(
      id: 'mbr_rahul_p',
      userId: 'usr_rahul_p',
      displayName: 'Rahul Patel',
      role: 'member',
      joinedAt: DateTime.now(),
    ),
    TripMember(
      id: 'mbr_rahul_s',
      userId: 'usr_rahul_s',
      displayName: 'Rahul Shah',
      role: 'member',
      joinedAt: DateTime.now(),
    ),
    TripMember(
      id: 'mbr_priya',
      userId: 'usr_priya',
      displayName: 'Priya',
      role: 'member',
      joinedAt: DateTime.now(),
    ),
  ];

  group('MultiExpenseVoiceParser Tests', () {
    test('Parses compound Hinglish sentence into 3 separate drafts', () {
      final input = 'Maine 4k train ke diye, 5k club ke diye aur 800 food ke diye.';
      final drafts = MultiExpenseVoiceParser.parse(
        input,
        members: members,
        currentUserId: 'usr_self',
      );

      expect(drafts.length, 3);

      // Draft 1: Train ₹4,000
      expect(drafts[0].amountInPaise, 400000);
      expect(drafts[0].title.toLowerCase(), contains('train'));
      expect(drafts[0].category, ExpenseCategory.transport);
      expect(drafts[0].payerMemberId, 'mbr_self');

      // Draft 2: Club ₹5,000
      expect(drafts[1].amountInPaise, 500000);
      expect(drafts[1].title.toLowerCase(), contains('club'));
      expect(drafts[1].category, ExpenseCategory.drinks);

      // Draft 3: Food ₹800
      expect(drafts[2].amountInPaise, 80000);
      expect(drafts[2].title.toLowerCase(), contains('food'));
      expect(drafts[2].category, ExpenseCategory.food);

      // Total must equal ₹9,800
      final totalPaise = drafts.fold<int>(0, (sum, d) => sum + d.amountInPaise);
      expect(totalPaise, 980000);
    });

    test('Parses comma-separated items without conjunctions', () {
      final input = 'Train 4000, hotel 5000, food 800';
      final drafts = MultiExpenseVoiceParser.parse(input);

      expect(drafts.length, 3);
      expect(drafts[0].amountInPaise, 400000);
      expect(drafts[0].category, ExpenseCategory.transport);

      expect(drafts[1].amountInPaise, 500000);
      expect(drafts[1].category, ExpenseCategory.stay);

      expect(drafts[2].amountInPaise, 80000);
      expect(drafts[2].category, ExpenseCategory.food);
    });

    test('Parses English sentence with multiple expenses and descriptors', () {
      final input = 'Yesterday I paid 2500 for hotel, 1200 for dinner and 450 for taxi';
      final drafts = MultiExpenseVoiceParser.parse(
        input,
        members: members,
        currentUserId: 'usr_self',
      );

      expect(drafts.length, 3);
      expect(drafts[0].amountInPaise, 250000);
      expect(drafts[0].category, ExpenseCategory.stay);
      expect(drafts[0].title.toLowerCase(), contains('hotel'));

      expect(drafts[1].amountInPaise, 120000);
      expect(drafts[1].category, ExpenseCategory.food);
      expect(drafts[1].title.toLowerCase(), contains('dinner'));

      expect(drafts[2].amountInPaise, 45000);
      expect(drafts[2].category, ExpenseCategory.transport);
      expect(drafts[2].title.toLowerCase(), contains('taxi'));
    });

    test('Parses inverted Hinglish pattern: "Train ke 4k, club ke 5k aur hotel ke 3k"', () {
      final input = 'Train ke 4k, club ke 5k aur hotel ke 3k';
      final drafts = MultiExpenseVoiceParser.parse(input);

      expect(drafts.length, 3);
      expect(drafts[0].amountInPaise, 400000);
      expect(drafts[0].title.toLowerCase(), contains('train'));

      expect(drafts[1].amountInPaise, 500000);
      expect(drafts[1].title.toLowerCase(), contains('club'));

      expect(drafts[2].amountInPaise, 300000);
      expect(drafts[2].title.toLowerCase(), contains('hotel'));
    });

    test('Parses Hindi "pe" phrases: "Food pe 500 aur drinks pe 700 kharch kiye"', () {
      final input = 'Food pe 500 aur drinks pe 700 kharch kiye';
      final drafts = MultiExpenseVoiceParser.parse(input);

      expect(drafts.length, 2);
      expect(drafts[0].amountInPaise, 50000);
      expect(drafts[0].title.toLowerCase(), contains('food'));
      expect(drafts[0].category, ExpenseCategory.food);

      expect(drafts[1].amountInPaise, 70000);
      expect(drafts[1].title.toLowerCase(), contains('drinks'));
      expect(drafts[1].category, ExpenseCategory.drinks);
    });

    test('Parses decimal k notation: "2.5k taxi and 700 snacks"', () {
      final input = '2.5k taxi and 700 snacks';
      final drafts = MultiExpenseVoiceParser.parse(input);

      expect(drafts.length, 2);
      expect(drafts[0].amountInPaise, 250000); // 2500 INR
      expect(drafts[0].category, ExpenseCategory.transport);

      expect(drafts[1].amountInPaise, 70000); // 700 INR
      expect(drafts[1].category, ExpenseCategory.food);
    });

    test('Does NOT merge duplicate titles into a single expense', () {
      final input = 'Train 4000, train 5000';
      final drafts = MultiExpenseVoiceParser.parse(input);

      expect(drafts.length, 2);
      expect(drafts[0].amountInPaise, 400000);
      expect(drafts[1].amountInPaise, 500000);
      expect(drafts[0].title.toLowerCase(), contains('train'));
      expect(drafts[1].title.toLowerCase(), contains('train'));
    });

    test('Parses Indian numerals: lakh, thousand, and word numbers', () {
      final input1 = '1.5 lakh resort booking';
      final drafts1 = MultiExpenseVoiceParser.parse(input1);
      expect(drafts1.first.amountInPaise, 15000000); // 1,50,000 INR

      final input2 = '10 thousand flight';
      final drafts2 = MultiExpenseVoiceParser.parse(input2);
      expect(drafts2.first.amountInPaise, 1000000); // 10,000 INR

      final input3 = 'do hazar movie tickets';
      final drafts3 = MultiExpenseVoiceParser.parse(input3);
      expect(drafts3.first.amountInPaise, 200000); // 2,000 INR
    });

    test('Handles single expense fast path seamlessly', () {
      final input = '500 coffee';
      final drafts = MultiExpenseVoiceParser.parse(input);

      expect(drafts.length, 1);
      expect(drafts.first.amountInPaise, 50000);
      expect(drafts.first.category, ExpenseCategory.drinks);
    });

    test('Handles payer ambiguity when multiple members match name', () {
      final input = 'Rahul ne hotel ke 3000 diye';
      final drafts = MultiExpenseVoiceParser.parse(
        input,
        members: members,
        currentUserId: 'usr_self',
      );

      expect(drafts.length, 1);
      expect(drafts.first.unresolvedFields.contains('payer_ambiguity'), isTrue);
      expect(drafts.first.candidatePayers.length, 2);
      expect(drafts.first.isReadyForConfirmation, isFalse);
    });

    test('Flags missing amount if user mentions item without price', () {
      final input = 'hotel booking for everyone';
      final drafts = MultiExpenseVoiceParser.parse(input);

      expect(drafts.length, 1);
      expect(drafts.first.amountInPaise, 0);
      expect(drafts.first.unresolvedFields.contains('amount'), isTrue);
      expect(drafts.first.isReadyForConfirmation, isFalse);
    });
  });
}
