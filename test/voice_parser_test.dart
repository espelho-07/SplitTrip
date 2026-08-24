import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/voice_parser.dart';
import 'package:kith_app/domain/enums/expense_category.dart';

void main() {
  group('VoiceIntentParser Tests', () {
    test('Parses Hindi / Hinglish train phrase correctly', () {
      final intent = VoiceIntentParser.parse('Maine 6 hazar train ke diye sabke liye');

      expect(intent.amountInPaise, 600000); // 6000 INR
      expect(intent.category, ExpenseCategory.transport);
      expect(intent.paidBySelf, isTrue);
      expect(intent.forAllParticipants, isTrue);
      expect(intent.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Parses digits and participants in English phrase', () {
      final intent = VoiceIntentParser.parse('I paid 850 for dinner for me and Rahul');

      expect(intent.amountInPaise, 85000); // 850 INR
      expect(intent.category, ExpenseCategory.food);
      expect(intent.paidBySelf, isTrue);
      expect(intent.forAllParticipants, isFalse);
      expect(intent.specifiedParticipantNames, contains('Rahul'));
    });

    test('Parses third-party payer in Hinglish phrase', () {
      final intent = VoiceIntentParser.parse('Rahul ne hotel ke 3000 diye aur sabke liye tha');

      expect(intent.amountInPaise, 300000); // 3000 INR
      expect(intent.category, ExpenseCategory.stay);
      expect(intent.paidBySelf, isFalse);
      expect(intent.specifiedPayerName?.toLowerCase(), 'rahul');
    });

    test('Parses short coffee and taxi phrases', () {
      final intent1 = VoiceIntentParser.parse('500 coffee');
      expect(intent1.amountInPaise, 50000);
      expect(intent1.category, ExpenseCategory.drinks);

      final intent2 = VoiceIntentParser.parse('1200 taxi cab');
      expect(intent2.amountInPaise, 120000);
      expect(intent2.category, ExpenseCategory.transport);
    });
  });
}
