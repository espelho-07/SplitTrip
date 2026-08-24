import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/qr_code_parser.dart';

void main() {
  group('QrCodeParser Tests', () {
    test('Extracts invite code from HTTPS deep link URL', () {
      const url = 'https://kith.app/join?code=K7P4XM';
      final code = QrCodeParser.extractInviteCode(url);
      expect(code, 'K7P4XM');
    });

    test('Extracts invite code from custom URI scheme deep link', () {
      const url = 'kith://join?code=MNL123';
      final code = QrCodeParser.extractInviteCode(url);
      expect(code, 'MNL123');
    });

    test('Extracts invite code from path segment deep link', () {
      const url = 'https://kith.app/join/AB45CD';
      final code = QrCodeParser.extractInviteCode(url);
      expect(code, 'AB45CD');
    });

    test('Extracts invite code from direct raw 6-character code with lowercase handling', () {
      const raw = 'goa123';
      final code = QrCodeParser.extractInviteCode(raw);
      expect(code, 'GOA123');
    });

    test('Extracts trip ID format', () {
      const tripId = 'TRIP_1234ABCD5678';
      final code = QrCodeParser.extractInviteCode(tripId);
      expect(code, 'TRIP_1234ABCD5678');
    });

    test('Returns null for malformed or non-invite inputs', () {
      expect(QrCodeParser.extractInviteCode(''), null);
      expect(QrCodeParser.extractInviteCode('   '), null);
      expect(QrCodeParser.extractInviteCode('random text string'), null);
      expect(QrCodeParser.extractInviteCode('https://google.com'), null);
    });
  });
}
