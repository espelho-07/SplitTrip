import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/models/payment_verification_request.dart';
import 'package:kith_app/presentation/router/app_router.dart';

void main() {
  group('Fix 1 — Deep-Link Sensitive Data Redaction Tests', () {
    test('Redacts standard token and claimToken parameters while preserving non-sensitive data', () {
      const uri = 'https://kith.app/join?code=GOA2026&token=clm_secret_token_123&memberId=mbr_456';
      final redacted = AppRouter.redactDeepLink(uri);
      expect(redacted, contains('code=GOA2026'));
      expect(redacted, contains('memberId=mbr_456'));
      expect(redacted, contains('token=[REDACTED]'));
      expect(redacted, isNot(contains('clm_secret_token_123')));
    });

    test('Redacts claimToken parameter in custom scheme URI', () {
      const uri = 'kith://join?code=XYZ999&claimToken=tok_98765';
      final redacted = AppRouter.redactDeepLink(uri);
      expect(redacted, contains('code=XYZ999'));
      expect(redacted, contains('claimToken=[REDACTED]'));
      expect(redacted, isNot(contains('tok_98765')));
    });

    test('Redacts secret, p2p_secret, and key parameters', () {
      const uri = 'https://kith.app/join?code=MANALI&secret=p2p_secret_high_entropy&key=enc_key_val';
      final redacted = AppRouter.redactDeepLink(uri);
      expect(redacted, contains('code=MANALI'));
      expect(redacted, contains('secret=[REDACTED]'));
      expect(redacted, contains('key=[REDACTED]'));
      expect(redacted, isNot(contains('p2p_secret_high_entropy')));
      expect(redacted, isNot(contains('enc_key_val')));
    });

    test('Handles case variations (TOKEN, ClaimToken, SECRET, s, Key)', () {
      const uri1 = 'https://kith.app/join?code=TEST1&TOKEN=upper_token_val';
      final redacted1 = AppRouter.redactDeepLink(uri1);
      expect(redacted1, contains('TOKEN=[REDACTED]'));
      expect(redacted1, isNot(contains('upper_token_val')));

      const uri2 = 'https://kith.app/join?code=TEST2&ClaimToken=mixed_claim_val';
      final redacted2 = AppRouter.redactDeepLink(uri2);
      expect(redacted2, contains('ClaimToken=[REDACTED]'));
      expect(redacted2, isNot(contains('mixed_claim_val')));

      const uri3 = 'https://kith.app/join?code=TEST3&SECRET=upper_secret&s=short_sec';
      final redacted3 = AppRouter.redactDeepLink(uri3);
      expect(redacted3, contains('SECRET=[REDACTED]'));
      expect(redacted3, contains('s=[REDACTED]'));
      expect(redacted3, isNot(contains('upper_secret')));
      expect(redacted3, isNot(contains('short_sec')));
    });

    test('Handles URL-encoded query parameter values and keys safely', () {
      const uri = 'https://kith.app/join?code=GOA%20TRIP&token=sec%20val%2Bplus';
      final redacted = AppRouter.redactDeepLink(uri);
      expect(redacted, contains('code=GOA+TRIP'));
      expect(redacted, contains('token=[REDACTED]'));
      expect(redacted, isNot(contains('sec%20val%2Bplus')));
      expect(redacted, isNot(contains('sec val')));
    });

    test('Preserves URLs without query strings or with non-sensitive parameters only', () {
      const uriNoQuery = 'https://kith.app/trip/trip_123/members';
      expect(AppRouter.redactDeepLink(uriNoQuery), uriNoQuery);

      const uriSafeQuery = '/trip/trip_123?expenseId=exp_456&settlementId=stl_789';
      final redactedSafe = AppRouter.redactDeepLink(uriSafeQuery);
      expect(redactedSafe, contains('expenseId=exp_456'));
      expect(redactedSafe, contains('settlementId=stl_789'));
      expect(redactedSafe, isNot(contains('[REDACTED]')));
    });

    test('Handles null, empty, and whitespace strings gracefully', () {
      expect(AppRouter.redactDeepLink(null), '');
      expect(AppRouter.redactDeepLink(''), '');
      expect(AppRouter.redactDeepLink('   '), '');
    });
  });

  group('Fix 2 — Settlement Trip Scoping Logic Tests', () {
    final sampleVerifications = [
      {
        'id': 'pvr_stl_trip1',
        'settlementId': 'stl_trip1',
        'tripId': 'trip_001',
        'tripName': 'Goa Vacation',
        'payerMemberId': 'mbr_1',
        'payerName': 'Aman',
        'receiverMemberId': 'mbr_2',
        'receiverName': 'Hardev',
        'amountInPaise': 50000,
        'status': 'pending_verification',
      },
      {
        'id': 'pvr_stl_trip2',
        'settlementId': 'stl_trip2',
        'tripId': 'trip_002',
        'tripName': 'Manali Trek',
        'payerMemberId': 'mbr_3',
        'payerName': 'Rohan',
        'receiverMemberId': 'mbr_4',
        'receiverName': 'Hardev',
        'amountInPaise': 75000,
        'status': 'pending_verification',
      },
      {
        'id': 'pvr_stl_legacy_null',
        'settlementId': 'stl_legacy_null',
        'tripId': null, // Legacy record without tripId
        'tripName': 'Legacy Trip',
        'payerMemberId': 'mbr_5',
        'payerName': 'Vikram',
        'receiverMemberId': 'mbr_6',
        'receiverName': 'Hardev',
        'amountInPaise': 30000,
        'status': 'pending_verification',
      },
    ];

    Map<String, dynamic> resolveSettlementMatch({
      required List<Map<String, dynamic>> pendingList,
      required String requestedSettlementId,
      required String currentTripId,
    }) {
      return pendingList.firstWhere(
        (p) =>
            (p['settlementId'] == requestedSettlementId || p['id'] == requestedSettlementId) &&
            (p['tripId'] == null || p['tripId'] == currentTripId),
        orElse: () => <String, dynamic>{},
      );
    }

    test('1. Correct settlement in current trip resolves successfully', () {
      final match = resolveSettlementMatch(
        pendingList: sampleVerifications,
        requestedSettlementId: 'stl_trip1',
        currentTripId: 'trip_001',
      );

      expect(match.isNotEmpty, isTrue);
      expect(match['settlementId'], 'stl_trip1');
      expect(match['tripId'], 'trip_001');

      final req = PaymentVerificationRequest.fromJson(match);
      final effectiveReq = (req.tripId.isEmpty && 'trip_001'.isNotEmpty)
          ? req.copyWith(tripId: 'trip_001')
          : req;
      expect(effectiveReq.tripId, 'trip_001');
    });

    test('2. Settlement belonging to another trip is strictly rejected', () {
      // Attacker attempts to open Manali settlement (trip_002) while inside Goa trip (trip_001)
      final match = resolveSettlementMatch(
        pendingList: sampleVerifications,
        requestedSettlementId: 'stl_trip2',
        currentTripId: 'trip_001', // Cross-trip target
      );

      expect(match.isEmpty, isTrue, reason: 'Settlement from another trip must not match');
    });

    test('3. Legacy record with null tripId follows safe backward-compatible resolution', () {
      final match = resolveSettlementMatch(
        pendingList: sampleVerifications,
        requestedSettlementId: 'stl_legacy_null',
        currentTripId: 'trip_001',
      );

      expect(match.isNotEmpty, isTrue);
      expect(match['tripId'], isNull);

      final req = PaymentVerificationRequest.fromJson(match);
      expect(req.tripId, isEmpty);

      // Backfills with current tripId to maintain authorization integrity
      final effectiveReq = (req.tripId.isEmpty && 'trip_001'.isNotEmpty)
          ? req.copyWith(tripId: 'trip_001', tripName: 'Goa Vacation')
          : req;

      expect(effectiveReq.tripId, 'trip_001');
      expect(effectiveReq.tripName, 'Goa Vacation');
      expect(effectiveReq.amountInPaise, 30000);
    });

    test('4. Invalid settlementId returns empty and avoids opening any sheet', () {
      final match = resolveSettlementMatch(
        pendingList: sampleVerifications,
        requestedSettlementId: 'stl_non_existent',
        currentTripId: 'trip_001',
      );

      expect(match.isEmpty, isTrue);
    });

    test('5. Multi-trip isolation: Different trips isolate their respective settlements', () {
      final matchTrip1 = resolveSettlementMatch(
        pendingList: sampleVerifications,
        requestedSettlementId: 'stl_trip1',
        currentTripId: 'trip_001',
      );
      final matchTrip2 = resolveSettlementMatch(
        pendingList: sampleVerifications,
        requestedSettlementId: 'stl_trip2',
        currentTripId: 'trip_002',
      );

      expect(matchTrip1['settlementId'], 'stl_trip1');
      expect(matchTrip1['tripId'], 'trip_001');

      expect(matchTrip2['settlementId'], 'stl_trip2');
      expect(matchTrip2['tripId'], 'trip_002');

      // Cross-checks
      final crossCheck1 = resolveSettlementMatch(
        pendingList: sampleVerifications,
        requestedSettlementId: 'stl_trip1',
        currentTripId: 'trip_002',
      );
      final crossCheck2 = resolveSettlementMatch(
        pendingList: sampleVerifications,
        requestedSettlementId: 'stl_trip2',
        currentTripId: 'trip_001',
      );

      expect(crossCheck1.isEmpty, isTrue);
      expect(crossCheck2.isEmpty, isTrue);
    });
  });
}
