import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/journey_stop.dart';
import 'package:kith_app/domain/models/trip_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late TripRepository tripRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    final syncService = SyncService(storage);
    final apiClient = ApiClient();
    tripRepo = TripRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
  });

  group('Trip Journey Stops & Trip Memories Tests', () {
    test('1. JourneyStop serialization and local storage persistence', () async {
      const tripId = 'trip_goa_01';
      final now = DateTime.now();

      final stop1 = JourneyStop(
        id: 'stop_1',
        tripId: tripId,
        dayNumber: 1,
        time: '11:00 AM',
        locationName: 'Calangute Beach',
        notes: 'Arrived and checked into beach shack',
        createdAt: now,
      );

      final stop2 = JourneyStop(
        id: 'stop_2',
        tripId: tripId,
        dayNumber: 2,
        time: '06:30 PM',
        locationName: 'Chapora Fort',
        notes: 'Sunset view with the crew',
        createdAt: now.add(const Duration(hours: 30)),
      );

      await tripRepo.addOrUpdateJourneyStop(tripId, stop1);
      await tripRepo.addOrUpdateJourneyStop(tripId, stop2);

      final stops = tripRepo.getCachedJourneyStops(tripId);
      expect(stops.length, equals(2));
      expect(stops[0].locationName, equals('Calangute Beach'));
      expect(stops[0].dayNumber, equals(1));
      expect(stops[1].locationName, equals('Chapora Fort'));
      expect(stops[1].dayNumber, equals(2));

      // Delete stop
      await tripRepo.deleteJourneyStop(tripId, 'stop_1');
      final remaining = tripRepo.getCachedJourneyStops(tripId);
      expect(remaining.length, equals(1));
      expect(remaining[0].id, equals('stop_2'));
    });

    test('2. TripMemory serialization and local storage persistence', () async {
      const tripId = 'trip_manali_02';
      final now = DateTime.now();

      final mem1 = TripMemory(
        id: 'mem_1',
        tripId: tripId,
        title: 'Late night bonfire jamming',
        note: 'Acoustic guitar singing under clear starry skies',
        emoji: '🎸',
        dayNumber: 1,
        createdAt: now,
      );

      final mem2 = TripMemory(
        id: 'mem_2',
        tripId: tripId,
        title: 'Solang Valley paragliding',
        note: 'First time flying over the snow peaks',
        emoji: '🪂',
        dayNumber: 2,
        createdAt: now.add(const Duration(hours: 24)),
      );

      await tripRepo.addOrUpdateTripMemory(tripId, mem1);
      await tripRepo.addOrUpdateTripMemory(tripId, mem2);

      final memories = tripRepo.getCachedTripMemories(tripId);
      expect(memories.length, equals(2));
      // Ordered newest first
      expect(memories[0].title, equals('Solang Valley paragliding'));
      expect(memories[0].emoji, equals('🪂'));
      expect(memories[1].title, equals('Late night bonfire jamming'));

      // Delete memory
      await tripRepo.deleteTripMemory(tripId, 'mem_1');
      final remaining = tripRepo.getCachedTripMemories(tripId);
      expect(remaining.length, equals(1));
      expect(remaining[0].id, equals('mem_2'));
    });
  });
}
