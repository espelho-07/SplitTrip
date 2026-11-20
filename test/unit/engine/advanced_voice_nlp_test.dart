import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/advanced_voice_expense_parser.dart';
import 'package:kith_app/domain/engine/expense_date_extractor.dart';
import 'package:kith_app/domain/engine/member_resolution_service.dart';
import 'package:kith_app/domain/engine/number_normalization_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  final members = [
    TripMember(
      id: 'mem_darpan',
      userId: 'usr_darpan',
      displayName: 'Darpan',
      role: 'creator',
      joinedAt: DateTime.now(),
    ),
    TripMember(
      id: 'mem_rahul',
      userId: 'usr_rahul',
      displayName: 'Rahul',
      role: 'member',
      joinedAt: DateTime.now(),
    ),
    TripMember(
      id: 'mem_aman',
      userId: 'usr_aman',
      displayName: 'Aman',
      role: 'member',
      joinedAt: DateTime.now(),
    ),
    TripMember(
      id: 'mem_priya',
      userId: 'usr_priya',
      displayName: 'Priya',
      role: 'member',
      joinedAt: DateTime.now(),
    ),
    TripMember(
      id: 'mem_rahul_patel',
      userId: 'usr_rahul_patel',
      displayName: 'Rahul Patel',
      role: 'member',
      joinedAt: DateTime.now(),
    ),
  ];

  group('20 Real-World Indian Speech Scenarios Audit & Verification', () {
    // 1. "Aaj humne 500 rupees ka petrol bharwaya."
    test('Scenario 1: "Aaj humne 500 rupees ka petrol bharwaya."', () {
      final drafts = AdvancedVoiceExpenseParser.parse(
        'Aaj humne 500 rupees ka petrol bharwaya.',
        members: members,
        currentUserId: 'usr_darpan',
      );
      expect(drafts.length, 1);
      final d = drafts.first;
      expect(d.amountInPaise, 50000); // 500 rupees = 50,000 paise
      expect(d.title.toLowerCase(), contains('petrol'));
      expect(d.category, ExpenseCategory.transport);
      expect(d.payerMemberId, 'mem_darpan'); // "humne" resolves to current user
      expect(d.expenseDate, isNotNull);
      final now = DateTime.now();
      expect(d.expenseDate!.day, now.day); // Today
    });

    // 2. "Maine 1200 ka dinner pay kiya."
    test('Scenario 2: "Maine 1200 ka dinner pay kiya."', () {
      final drafts = AdvancedVoiceExpenseParser.parse(
        'Maine 1200 ka dinner pay kiya.',
        members: members,
        currentUserId: 'usr_darpan',
      );
      expect(drafts.length, 1);
      final d = drafts.first;
      expect(d.amountInPaise, 120000); // 1200 rupees = 120,000 paise
      expect(d.title.toLowerCase(), contains('dinner'));
      expect(d.category, ExpenseCategory.food);
      expect(d.payerMemberId, 'mem_darpan');
    });

    // 3. "Kal hotel ke 3000 rupaye diye the."
    test('Scenario 3: "Kal hotel ke 3000 rupaye diye the."', () {
      final drafts = AdvancedVoiceExpenseParser.parse(
        'Kal hotel ke 3000 rupaye diye the.',
        members: members,
        currentUserId: 'usr_darpan',
      );
      expect(drafts.length, 1);
      final d = drafts.first;
      expect(d.amountInPaise, 300000); // 3000 rupees
      expect(d.title.toLowerCase(), contains('hotel'));
      expect(d.category, ExpenseCategory.stay);
      expect(d.expenseDate, isNotNull);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(d.expenseDate!.day, yesterday.day); // Kal = Yesterday
    });

    // 4. "Rahul ne 500 diye aur baaki maine pay kiya."
    test('Scenario 4: "Rahul ne 500 diye aur baaki maine pay kiya."', () {
      final drafts = AdvancedVoiceExpenseParser.parse(
        'Rahul ne 500 diye aur baaki maine pay kiya.',
        members: members,
        currentUserId: 'usr_darpan',
      );
      expect(drafts.isNotEmpty, isTrue);
      final d = drafts.first;
      expect(d.amountInPaise, 50000);
      // Rahul matches both Rahul and Rahul Patel -> ambiguous flag
      expect(d.candidatePayers.isNotEmpty, isTrue);
      final candidateIds = d.candidatePayers.map((m) => m.id).toList();
      expect(candidateIds, contains('mem_rahul'));
      expect(candidateIds, contains('mem_rahul_patel'));
    });

    // 5. "Hum chaar logon mein equally split kar do."
    test('Scenario 5: "Hum chaar logon mein equally split kar do."', () {
      final num = NumberNormalizationService.extractAmountInPaise('Hum chaar logon mein 2000 equally split kar do.');
      expect(num, 200000); // 2000 rupees, should NOT confuse 'chaar logon' with 4 rupees
      final participants = MemberResolutionService.resolveParticipants(
        clauseLower: 'hum chaar logon mein equally split kar do',
        members: members,
        currentUserId: 'usr_darpan',
        payerMemberId: 'mem_darpan',
      );
      expect(participants.length, members.length); // Universal / everyone split
    });

    // 6. "Is expense ko sirf mere aur Rahul ke beech split karo."
    test('Scenario 6: "Is expense ko sirf mere aur Rahul ke beech split karo."', () {
      final participants = MemberResolutionService.resolveParticipants(
        clauseLower: 'is expense ko sirf mere aur rahul ke beech split karo',
        members: members,
        currentUserId: 'usr_darpan',
        payerMemberId: 'mem_darpan',
      );
      expect(participants, isNotNull);
      expect(participants, contains('mem_darpan')); // "mere" -> current user
      expect(participants, contains('mem_rahul')); // "rahul" -> mem_rahul
      expect(participants.length, 2);
    });

    // 7. "Petrol ka expense add kar do, 1500 rupees."
    test('Scenario 7: "Petrol ka expense add kar do, 1500 rupees."', () {
      final drafts = AdvancedVoiceExpenseParser.parse(
        'Petrol ka expense add kar do, 1500 rupees.',
        members: members,
        currentUserId: 'usr_darpan',
      );
      expect(drafts.length, 1);
      final d = drafts.first;
      expect(d.amountInPaise, 150000);
      expect(d.title.toLowerCase(), contains('petrol'));
      expect(d.category, ExpenseCategory.transport);
    });

    // 8. "Aaj lunch pe 800 kharch hue."
    test('Scenario 8: "Aaj lunch pe 800 kharch hue."', () {
      final drafts = AdvancedVoiceExpenseParser.parse(
        'Aaj lunch pe 800 kharch hue.',
        members: members,
        currentUserId: 'usr_darpan',
      );
      expect(drafts.length, 1);
      final d = drafts.first;
      expect(d.amountInPaise, 80000);
      expect(d.title.toLowerCase(), contains('lunch'));
      expect(d.category, ExpenseCategory.food);
      expect(d.expenseDate?.day, DateTime.now().day);
    });

    // 9. "Maine 2000 diye, usme se 500 Aman ke the."
    test('Scenario 9: "Maine 2000 diye, usme se 500 Aman ke the."', () {
      final drafts = AdvancedVoiceExpenseParser.parse(
        'Maine 2000 diye, usme se 500 Aman ke the.',
        members: members,
        currentUserId: 'usr_darpan',
      );
      expect(drafts.isNotEmpty, isTrue);
      expect(drafts[0].amountInPaise, 200000);
      expect(drafts[0].payerMemberId, 'mem_darpan');
    });

    // 10. "Teen sau pachaas ka toll laga."
    test('Scenario 10: "Teen sau pachaas ka toll laga."', () {
      final drafts = AdvancedVoiceExpenseParser.parse(
        'Teen sau pachaas ka toll laga.',
        members: members,
        currentUserId: 'usr_darpan',
      );
      expect(drafts.length, 1);
      final d = drafts.first;
      expect(d.amountInPaise, 35000); // 350 rupees = 35,000 paise
      expect(d.title.toLowerCase(), contains('toll'));
      expect(d.category, ExpenseCategory.transport);
    });

    // 11. "Paanch sau" (500)
    test('Scenario 11: Spoken Hindi numeral "Paanch sau" -> 500', () {
      final paise = NumberNormalizationService.extractAmountInPaise('paanch sau');
      expect(paise, 50000);
      final paise2 = NumberNormalizationService.extractAmountInPaise('panch sau snacks');
      expect(paise2, 50000);
    });

    // 12. "Barah sau" (1200)
    test('Scenario 12: Colloquial Indian hundreds "Barah sau" -> 1200', () {
      final paise = NumberNormalizationService.extractAmountInPaise('barah sau train ticket');
      expect(paise, 120000);
    });

    // 13. "Dedh hazar" (1500) & "Dhai hazar" (2500)
    test('Scenario 13: Spoken fraction numerals "Dedh hazar" (1500) and "Dhai hazar" (2500)', () {
      final dedh = NumberNormalizationService.extractAmountInPaise('dedh hazar resort advance');
      expect(dedh, 150000); // 1500 * 100
      final dhai = NumberNormalizationService.extractAmountInPaise('dhai hazar hotel booking');
      expect(dhai, 250000); // 2500 * 100
    });

    // 14. "Sade teen hazar" (3500)
    test('Scenario 14: Fractional hundreds "Sade teen hazar" -> 3500', () {
      final paise = NumberNormalizationService.extractAmountInPaise('sade teen hazar groceries');
      expect(paise, 350000); // 3500 * 100
    });

    // 15. "One thousand five hundred" (1500)
    test('Scenario 15: English spoken words "One thousand five hundred" -> 1500', () {
      final paise = NumberNormalizationService.extractAmountInPaise('one thousand five hundred for dinner');
      expect(paise, 150000);
    });

    // 16. "Twelve hundred" (1200)
    test('Scenario 16: English hundred notation "Twelve hundred" -> 1200', () {
      final paise = NumberNormalizationService.extractAmountInPaise('twelve hundred for cab');
      expect(paise, 120000);
    });

    // 17. "500 rs" vs "₹500"
    test('Scenario 17: Currency symbol variants "500 rs", "₹500", "500 inr"', () {
      expect(NumberNormalizationService.extractAmountInPaise('500 rs petrol'), 50000);
      expect(NumberNormalizationService.extractAmountInPaise('₹500 petrol'), 50000);
      expect(NumberNormalizationService.extractAmountInPaise('500 inr petrol'), 50000);
      expect(NumberNormalizationService.extractAmountInPaise('500 rupaye petrol'), 50000);
    });

    // 18. Payer ambiguity resolution with candidate chips
    test('Scenario 18: Ambiguity resolution when multiple trip members share a name', () {
      // Both "Rahul" and "Rahul Patel" exist in members list
      final res = MemberResolutionService.resolvePayer(
        clauseLower: 'rahul ne 800 diya',
        members: members,
        currentUserId: 'usr_darpan',
      );
      expect(res.isAmbiguous, isTrue);
      expect(res.candidatePayers.length, 2);
      final ids = res.candidatePayers.map((m) => m.id).toList();
      expect(ids, contains('mem_rahul'));
      expect(ids, contains('mem_rahul_patel'));
    });

    // 19. Relative past dates (yesterday, parso, weekdays)
    test('Scenario 19: Relative past date extraction (yesterday, parso, weekdays)', () {
      final now = DateTime.now();

      // Today
      final today = ExpenseDateExtractor.extractDate('aaj shaam ko dinner 600');
      expect(today?.day, now.day);

      // Yesterday
      final yest = ExpenseDateExtractor.extractDate('kal raat hotel 2000');
      final expectedYest = now.subtract(const Duration(days: 1));
      expect(yest?.day, expectedYest.day);

      // Parso
      final parso = ExpenseDateExtractor.extractDate('parso train tickets 1200');
      final expectedParso = now.subtract(const Duration(days: 2));
      expect(parso?.day, expectedParso.day);
    });

    // 20. Compound multi-expense clauses
    test('Scenario 20: Compound multi-expense sentences split into discrete drafts', () {
      final input = 'Kal maine 4k train ke diye, 2.5k hotel ke diye aur 800 snacks pe kharch hue.';
      final drafts = AdvancedVoiceExpenseParser.parse(
        input,
        members: members,
        currentUserId: 'usr_darpan',
      );
      expect(drafts.length, 3);

      // Draft 1
      expect(drafts[0].amountInPaise, 400000);
      expect(drafts[0].title.toLowerCase(), contains('train'));
      expect(drafts[0].payerMemberId, 'mem_darpan');
      expect(drafts[0].expenseDate?.day, DateTime.now().subtract(const Duration(days: 1)).day);

      // Draft 2
      expect(drafts[1].amountInPaise, 250000);
      expect(drafts[1].title.toLowerCase(), contains('hotel'));
      expect(drafts[1].payerMemberId, 'mem_darpan');

      // Draft 3
      expect(drafts[2].amountInPaise, 80000);
      expect(drafts[2].title.toLowerCase(), contains('snack'));
      expect(drafts[2].category, ExpenseCategory.food);
    });
  });
}
