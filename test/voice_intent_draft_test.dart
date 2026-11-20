import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/voice_parser.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense_draft.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  group('VoiceIntentParser Entity & Draft Resolution Tests', () {
    final members = [
      TripMember(
        id: 'mbr_alice',
        userId: 'usr_alice',
        displayName: 'Alice',
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
        displayName: 'Priya Sharma',
        role: 'member',
        joinedAt: DateTime.now(),
      ),
    ];

    test('Parses Hinglish all-members train expense paid by self', () {
      final draft = VoiceIntentParser.parseToDraft(
        'Maine 6000 train ke diye sabke liye',
        members,
        'usr_alice',
      );

      expect(draft.source, ExpenseDraftSource.voice);
      expect(draft.amountInPaise, 600000);
      expect(draft.title, 'Train');
      expect(draft.category, ExpenseCategory.transport);
      expect(draft.payerMemberId, 'mbr_alice');
      expect(draft.participantMemberIds.length, 4);
      expect(draft.unresolvedFields.isEmpty, true);
      expect(draft.isReadyForConfirmation, true);
    });

    test('Parses English 6k notation with specific member participant', () {
      final draft = VoiceIntentParser.parseToDraft(
        'I paid 6k for hotel for me and Priya',
        members,
        'usr_alice',
      );

      expect(draft.amountInPaise, 600000);
      expect(draft.category, ExpenseCategory.stay);
      expect(draft.payerMemberId, 'mbr_alice');
      expect(draft.participantMemberIds.contains('mbr_alice'), true);
      expect(draft.participantMemberIds.contains('mbr_priya'), true);
      expect(draft.unresolvedFields.isEmpty, true);
    });

    test('Flags payer ambiguity when multiple members share the spoken name', () {
      final draft = VoiceIntentParser.parseToDraft(
        'Rahul ne hotel ke 3000 diye sabke liye',
        members,
        'usr_alice',
      );

      expect(draft.amountInPaise, 300000);
      expect(draft.unresolvedFields.contains('payer_ambiguity'), true);
      expect(draft.candidatePayers.length, 2);
      expect(draft.candidatePayers.map((c) => c.displayName), containsAll(['Rahul Patel', 'Rahul Shah']));
      expect(draft.isReadyForConfirmation, false); // Blocked until user picks the exact Rahul
    });

    test('Flags missing amount when user mentions expense without price', () {
      final draft = VoiceIntentParser.parseToDraft(
        'Maine hotel ke paise diye sabke liye',
        members,
        'usr_alice',
      );

      expect(draft.amountInPaise, 0);
      expect(draft.unresolvedFields.contains('amount'), true);
      expect(draft.isReadyForConfirmation, false);
    });

    test('Normalizes numbers in Hindi words like chhe hazar', () {
      final draft = VoiceIntentParser.parseToDraft(
        'chhe hazar flight tickets',
        members,
        'usr_alice',
      );

      expect(draft.amountInPaise, 600000);
      expect(draft.category, ExpenseCategory.transport);
    });
  });
}
