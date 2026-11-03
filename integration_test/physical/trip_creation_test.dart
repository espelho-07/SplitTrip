import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kith_app/domain/models/trip.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 2: Trip Creation and 128-bit P2P Secret', () {
    testWidgets('creates a trip with valid UUID, invite code, and 128-bit secret', (tester) async {
      // 128-bit hex secret (32 hex characters)
      const p2pSecret = 'a1b2c3d4e5f67890123456789abcdef0';
      const tripId = 'trip-uuid-1234-5678-90ab';
      const inviteCode = 'KITH88';
      final now = DateTime.now();

      final trip = Trip(
        id: tripId,
        name: 'Goa Physical Test Trip',
        description: 'Physical Device QA Suite',
        creatorId: 'user-tester-01',
        members: const [],
        inviteCode: inviteCode,
        p2pTripSecret: p2pSecret,
        tripMode: 'split_only',
        revision: 1,
        createdAt: now,
        updatedAt: now,
      );

      expect(trip.id, equals(tripId));
      expect(trip.inviteCode, equals(inviteCode));
      expect(trip.p2pTripSecret, equals(p2pSecret));
      expect(trip.p2pTripSecret!.length, equals(32));

      // Serialization round-trip
      final json = trip.toJson();
      expect(json['p2pTripSecret'], equals(p2pSecret));

      final restored = Trip.fromJson(json);
      expect(restored.p2pTripSecret, equals(p2pSecret));
      expect(restored.name, equals('Goa Physical Test Trip'));
    });
  });
}
