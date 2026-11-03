import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/core/config/app_config.dart';
import 'package:kith_app/domain/engine/qr_code_parser.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 3: QR Invitation Generation and Parsing', () {
    testWidgets('encodes and parses invitation link with v2 P2P secret', (tester) async {
      const inviteCode = 'KITH77';
      const secret = 'e9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4';

      final link = AppConfig.buildInviteLink(inviteCode, p2pTripSecret: secret);
      expect(link, contains('code=KITH77'));
      expect(link, contains('secret=$secret'));

      final payload = QrCodeParser.parsePayload(link);
      expect(payload, isNotNull);
      expect(payload!.inviteCode, equals(inviteCode));
      expect(payload.p2pTripSecret, equals(secret));
    });

    testWidgets('supports legacy v1 invitation link without secret', (tester) async {
      final link = AppConfig.buildInviteLink('KITH00');
      expect(link, equals('https://kith.app/join?code=KITH00'));

      final payload = QrCodeParser.parsePayload(link);
      expect(payload, isNotNull);
      expect(payload!.inviteCode, equals('KITH00'));
      expect(payload.p2pTripSecret, isNull);
    });
  });
}
