import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/config/app_config.dart';
import 'package:kith_app/domain/engine/qr_code_parser.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  group('Gate G.4 Claim Flow & Token Propagation Tests', () {
    test('AppConfig.buildClaimLink constructs standard claim URL with memberId and claimToken', () {
      final link = AppConfig.buildClaimLink(
        'KITH99',
        memberId: 'mbr_client_abc',
        claimToken: 'clm_token_xyz',
      );

      expect(link, contains('https://kith.app/join'));
      expect(link, contains('code=KITH99'));
      expect(link, contains('memberId=mbr_client_abc'));
      expect(link, contains('token=clm_token_xyz'));

      final uri = Uri.parse(link);
      expect(uri.queryParameters['code'], equals('KITH99'));
      expect(uri.queryParameters['memberId'], equals('mbr_client_abc'));
      expect(uri.queryParameters['token'], equals('clm_token_xyz'));
    });

    test('AppConfig.buildClaimLink includes p2pTripSecret when provided', () {
      final link = AppConfig.buildClaimLink(
        'KITH88',
        memberId: 'mbr_1',
        claimToken: 'clm_1',
        p2pTripSecret: 'secret_hex_value',
      );

      final uri = Uri.parse(link);
      expect(uri.queryParameters['code'], equals('KITH88'));
      expect(uri.queryParameters['memberId'], equals('mbr_1'));
      expect(uri.queryParameters['token'], equals('clm_1'));
      expect(uri.queryParameters['secret'], equals('secret_hex_value'));
    });

    test('QrCodeParser extracts claimMemberId and claimToken from standard claim URL', () {
      const url = 'https://kith.app/join?code=GOA456&memberId=mbr_target_99&token=clm_secret_token_77';

      final payload = QrCodeParser.parsePayload(url);
      expect(payload, isNotNull);
      expect(payload!.inviteCode, equals('GOA456'));
      expect(payload.claimMemberId, equals('mbr_target_99'));
      expect(payload.claimToken, equals('clm_secret_token_77'));

      expect(QrCodeParser.extractInviteCode(url), equals('GOA456'));
      expect(QrCodeParser.extractClaimMemberId(url), equals('mbr_target_99'));
      expect(QrCodeParser.extractClaimToken(url), equals('clm_secret_token_77'));
    });

    test('QrCodeParser extracts claimMemberId and claimToken from JSON QR payload', () {
      const jsonQr = '{"kith":true,"code":"PUNE22","claimMemberId":"mbr_json_1","claimToken":"clm_json_tok"}';

      final payload = QrCodeParser.parsePayload(jsonQr);
      expect(payload, isNotNull);
      expect(payload!.inviteCode, equals('PUNE22'));
      expect(payload.claimMemberId, equals('mbr_json_1'));
      expect(payload.claimToken, equals('clm_json_tok'));
    });

    test('QrCodeParser falls back gracefully when claim token is absent', () {
      const url = 'https://kith.app/join?code=DELHI1';

      final payload = QrCodeParser.parsePayload(url);
      expect(payload, isNotNull);
      expect(payload!.inviteCode, equals('DELHI1'));
      expect(payload.claimMemberId, isNull);
      expect(payload.claimToken, isNull);

      expect(QrCodeParser.extractClaimMemberId(url), isNull);
      expect(QrCodeParser.extractClaimToken(url), isNull);
    });
  });

  group('Gate G.4 Foreground Repository ID Translation Hooks', () {
    test('mergeWithDetailed provides non-empty translationMap and captures member ID transition', () {
      final now = DateTime.now();
      const claimToken = 'clm_delivery_verified_token';

      final localMember = TripMember(
        id: 'mbr_client_temporary',
        userId: 'unclaimed_local_user',
        displayName: 'Samir',
        claimToken: claimToken,
        joinedAt: now,
        isVirtualMember: true,
        isClaimed: false,
      );

      final localTrip = Trip(
        id: 'trip_foreground_1',
        name: 'Foreground Test Trip',
        creatorId: 'usr_creator',
        inviteCode: 'FG1234',
        members: [localMember],
        createdAt: now,
        updatedAt: now,
      );

      final serverMember = TripMember(
        id: 'mbr_server_canonical',
        userId: 'unclaimed_server_user',
        displayName: 'Samir',
        claimToken: claimToken,
        joinedAt: now,
        isVirtualMember: true,
        isClaimed: false,
      );

      final serverTrip = Trip(
        id: 'trip_foreground_1',
        name: 'Foreground Test Trip',
        creatorId: 'usr_creator',
        inviteCode: 'FG1234',
        members: [serverMember],
        createdAt: now,
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      final mergeResult = localTrip.mergeWithDetailed(serverTrip);

      // Verify that translation map is populated
      expect(mergeResult.memberIdMap.isNotEmpty, isTrue);
      expect(mergeResult.memberIdMap['mbr_client_temporary'], equals('mbr_server_canonical'));

      // Verify that the merged trip contains the canonical server member
      expect(mergeResult.mergedTrip.members.length, equals(1));
      expect(mergeResult.mergedTrip.members.first.id, equals('mbr_server_canonical'));
    });
  });
}
