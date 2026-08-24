import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/qr_code_parser.dart';
import 'package:kith_app/domain/engine/money_engine.dart';
import 'package:kith_app/domain/engine/voice_parser.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/models/guest_user.dart';

void main() {
  group('Alpha Readiness & User Safety Tests', () {
    test('QR Parser rejects non-Kith links and malicious URLs safely', () {
      expect(QrCodeParser.extractInviteCode('https://malicious-site.com/join?code=XYZ123'), isNull);
      expect(QrCodeParser.extractInviteCode('http://insecure.site/code=ABC'), isNull);
      expect(QrCodeParser.extractInviteCode('javascript:alert(1)'), isNull);
      expect(QrCodeParser.extractInviteCode(''), isNull);
      expect(QrCodeParser.extractInviteCode('   '), isNull);
      expect(QrCodeParser.extractInviteCode('random non invite string text'), isNull);
    });

    test('QR Parser extracts valid 6-char alphanumeric invite codes', () {
      expect(QrCodeParser.extractInviteCode('https://kith.app/join?code=GOA123'), 'GOA123');
      expect(QrCodeParser.extractInviteCode('kith://join?code=GOA123'), 'GOA123');
      expect(QrCodeParser.extractInviteCode('GOA123'), 'GOA123');
      expect(QrCodeParser.extractInviteCode('goa123'), 'GOA123');
    });

    test('GuestUser model creates clean serialization with all required fields', () {
      final user = GuestUser(
        id: 'usr_test123',
        displayName: 'Darpan',
        recoveryKey: 'KITH-ABCD-EFGH',
        anonymousToken: 'kith_sess_secret_token_123',
        createdAt: DateTime.now(),
      );

      final json = user.toJson();
      expect(json['id'], 'usr_test123');
      expect(json['displayName'], 'Darpan');
      expect(json['recoveryKey'], 'KITH-ABCD-EFGH');
    });

    test('Voice parser flags ambiguous member when multiple friends share spoken name', () {
      final members = [
        TripMember(id: 'm1', userId: 'u1', displayName: 'Rahul Sharma', role: 'member', joinedAt: DateTime.now()),
        TripMember(id: 'm2', userId: 'u2', displayName: 'Rahul Verma', role: 'member', joinedAt: DateTime.now()),
        TripMember(id: 'm3', userId: 'u3', displayName: 'Darpan', role: 'creator', joinedAt: DateTime.now()),
      ];

      final draft = VoiceIntentParser.parseToDraft(
        'Rahul paid 1500 for dinner for everyone',
        members,
        'u3',
      );

      expect(draft.candidatePayers.length, 2);
      expect(draft.unresolvedFields.contains('payer_ambiguity'), isTrue);
      expect(draft.ambiguityMessage, isNotNull);
    });

    test('Voice parser flags missing amount when user mentions expense without price', () {
      final members = [
        TripMember(id: 'm1', userId: 'u1', displayName: 'Darpan', role: 'creator', joinedAt: DateTime.now()),
        TripMember(id: 'm2', userId: 'u2', displayName: 'Alex', role: 'member', joinedAt: DateTime.now()),
      ];

      final draft = VoiceIntentParser.parseToDraft(
        'Maine train tickets book kiye sabke liye',
        members,
        'u1',
      );

      expect(draft.amountInPaise, 0);
      expect(draft.unresolvedFields.contains('amount'), isTrue);
    });

    test('MoneyEngine guarantees zero penny leakage across large group splits', () {
      // ₹10,000 split across 3 members (3333.33 -> 333334, 333333, 333333 paise)
      final splits = MoneyEngine.calculateEqualSplits(
        totalPaise: 1000000,
        participantMemberIds: ['m1', 'm2', 'm3'],
      );

      final totalSplitSum = splits.fold<int>(0, (sum, s) => sum + s.amountInPaise);
      expect(totalSplitSum, 1000000);
      expect(splits[0].amountInPaise + splits[1].amountInPaise + splits[2].amountInPaise, 1000000);
    });
  });
}
