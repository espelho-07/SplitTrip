import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/engine/money_engine.dart';
import 'package:kith_app/domain/models/journey_moment.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
  });

  group('Phase 23 Production Hardening & RC Flutter Suite', () {
    test('1. Financial Integrity: MoneyEngine conserves uneven splits to exact paise', () {
      final splits = MoneyEngine.calculateEqualSplits(
        totalPaise: 100000, // �1,000.00
        participantMemberIds: ['mbr1', 'mbr2', 'mbr3'],
        priorityMemberId: 'mbr1',
      );

      expect(splits.length, 3);
      final sum = splits.map((s) => s.amountInPaise).reduce((a, b) => a + b);
      expect(sum, equals(100000));
      expect(splits[0].amountInPaise, equals(33334));
      expect(splits[1].amountInPaise, equals(33333));
      expect(splits[2].amountInPaise, equals(33333));
    });

    test('2. Financial Integrity: single paise split does not vanish or inflate', () {
      final splits = MoneyEngine.calculateEqualSplits(
        totalPaise: 1, // π0.01
        participantMemberIds: ['mbr1', 'mbr2', 'mbr3'],
        priorityMemberId: 'mbr1',
      );

      final sum = splits.map((s) => s.amountInPaise).reduce((a, b) => a + b);
      expect(sum, equals(1));
      expect(splits[0].amountInPaise, equals(1));
      expect(splits[1].amountInPaise, equals(0));
      expect(splits[2].amountInPaise, equals(0));
    });

    test('3. Offline Sync Durability: enqueues and reads Journey Moment mutations', () async {
      final syncService = SyncService(storage);

      final moment = JourneyMoment(
        id: 'moment_rc_001',
        tripId: 'trip_rc_001',
        createdBy: 'usr_rc_001',
        title: 'Sunset viewpoint',
        placeName: 'Ago Cliffs',
        occurredAt: DateTime(2026, 8, 25, 18, 30),
        dayIndex: 1,
        createdAt: DateTime(2026, 8, 25, 18, 30),
        updatedAt: DateTime(2026, 8, 25, 18, 30),
      );

      await syncService.enqueueMutation(
        MutationType.createJourneyMoment,
        {'tripId': 'trip_rc_001', 'moment': moment.toJson()},
      );

      final pending = syncService.getPendingMutations();
      expect(pending.length, equals(1));
      expect(pending.first.type, equals(MutationType.createJourneyMoment));
      expect(pending.first.payload['tripId'], equals('trip_rc_001'));
      expect(pending.first.payload['moment']['title'], equals('Sunset viewpoint'));
    });

    test('4. Multi-Trip Isolation: separate trip moments do not leak across keys', () async {
      final momentTripA = JourneyMoment(
        id: 'moment_a',
        tripId: 'trip_a',
        createdBy: 'usr_a',
        title: 'Trip A Moment',
        occurredAt: DateTime(2026, 8, 25),
        dayIndex: 1,
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
      );

      final momentTripB = JourneyMoment(
        id: 'moment_b',
        tripId: 'trip_b',
        createdBy: 'usr_b',
        title: 'Trip B Moment',
        occurredAt: DateTime(2026, 8, 25),
        dayIndex: 1,
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
      );

      await storage.saveJourneyMoments('trip_a', [momentTripA.toJson()]);
      await storage.saveJourneyMoments('trip_b', [momentTripB.toJson()]);

      final readTripA = storage.getSavedJourneyMoments('trip_a');
      final readTripB = storage.getSavedJourneyMoments('trip_b');

      expect(readTripA.length, equals(1));
      expect(readTripA.first['id'], equals('moment_a'));

      expect(readTripB.length, equals(1));
      expect(readTripB.first['id'], equals('moment_b'));
    });
  });
}
