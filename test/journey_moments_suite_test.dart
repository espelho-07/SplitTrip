import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/journey_moment.dart';
import 'package:kith_app/presentation/viewmodels/trip_detail_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late TripDetailViewModel viewModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    final syncService = SyncService(storage);
    final apiClient = ApiClient();
    tripRepo = TripRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    expenseRepo = ExpenseRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    viewModel = TripDetailViewModel(
      tripRepo: tripRepo,
      expenseRepo: expenseRepo,
    );
  });

  group('Journey Moments Experience 2.0 Test Suite', () {
    test('1. JourneyMoment serialization and deserialization roundtrip', () {
      final now = DateTime.now();
      final moment = JourneyMoment(
        id: 'moment_01',
        tripId: 'trip_100',
        createdBy: 'user_darpan',
        creatorName: 'Darpan',
        title: 'Sunset at Vagator Beach',
        placeName: 'Vagator Beach, North Goa',
        note: 'Beautiful orange sky and live acoustic music',
        latitude: 15.5986,
        longitude: 73.7389,
        occurredAt: now,
        dayIndex: 1,
        photoUrls: ['https://example.com/p1.jpg', 'https://example.com/p2.jpg'],
        expenseId: 'exp_beach_dinner_01',
        createdAt: now,
        updatedAt: now,
      );

      final json = moment.toJson();
      expect(json['id'], equals('moment_01'));
      expect(json['title'], equals('Sunset at Vagator Beach'));
      expect(json['placeName'], equals('Vagator Beach, North Goa'));
      expect(json['latitude'], equals(15.5986));
      expect(json['longitude'], equals(73.7389));
      expect(json['photoUrls'], isA<List>());
      expect(json['photoUrls'].length, equals(2));
      expect(json['expenseId'], equals('exp_beach_dinner_01'));

      final reconstructed = JourneyMoment.fromJson(json);
      expect(reconstructed.id, equals(moment.id));
      expect(reconstructed.title, equals(moment.title));
      expect(reconstructed.placeName, equals(moment.placeName));
      expect(reconstructed.dayIndex, equals(1));
      expect(reconstructed.photoUrls.length, equals(2));
      expect(reconstructed.expenseId, equals('exp_beach_dinner_01'));

      // Test snake_case backend payload
      final snakeJson = {
        'id': 'moment_02',
        'trip_id': 'trip_100',
        'created_by': 'user_darpan',
        'title': 'Anjuna Flea Market',
        'place_name': 'Anjuna',
        'photo_urls': ['https://example.com/m.jpg'],
        'day_index': 2,
        'expense_id': 'exp_market_01',
      };
      final fromSnake = JourneyMoment.fromJson(snakeJson);
      expect(fromSnake.id, equals('moment_02'));
      expect(fromSnake.tripId, equals('trip_100'));
      expect(fromSnake.placeName, equals('Anjuna'));
      expect(fromSnake.dayIndex, equals(2));
      expect(fromSnake.photoUrls.length, equals(1));
      expect(fromSnake.expenseId, equals('exp_market_01'));
    });

    test('2. TripRepository journey moments caching and CRUD operations', () async {
      const tripId = 'trip_bali_2026';
      final now = DateTime.now();

      final m1 = JourneyMoment(
        id: 'm1',
        tripId: tripId,
        createdBy: 'u1',
        title: 'Landed in Denpasar',
        placeName: 'Ngurah Rai International Airport',
        dayIndex: 1,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final m2 = JourneyMoment(
        id: 'm2',
        tripId: tripId,
        createdBy: 'u1',
        title: 'Uluwatu Temple Cliff Walk',
        placeName: 'Uluwatu',
        dayIndex: 2,
        occurredAt: now.add(const Duration(days: 1)),
        createdAt: now.add(const Duration(days: 1)),
        updatedAt: now.add(const Duration(days: 1)),
      );

      // Add moments
      await tripRepo.addOrUpdateJourneyMoment(tripId, m1);
      await tripRepo.addOrUpdateJourneyMoment(tripId, m2);

      var cached = tripRepo.getCachedJourneyMoments(tripId);
      expect(cached.length, equals(2));
      expect(cached[0].title, equals('Landed in Denpasar'));
      expect(cached[1].title, equals('Uluwatu Temple Cliff Walk'));

      // Update moment
      final updatedM1 = m1.copyWith(note: 'Flight was on time, got local SIM cards');
      await tripRepo.addOrUpdateJourneyMoment(tripId, updatedM1);

      cached = tripRepo.getCachedJourneyMoments(tripId);
      expect(cached.length, equals(2));
      expect(cached[0].note, equals('Flight was on time, got local SIM cards'));

      // Delete moment
      await tripRepo.deleteJourneyMoment(tripId, 'm1');
      cached = tripRepo.getCachedJourneyMoments(tripId);
      expect(cached.length, equals(1));
      expect(cached[0].id, equals('m2'));
    });

    test('3. TripDetailViewModel journey moments state reactivity', () async {
      final creator = GuestUser(
        id: 'u1',
        displayName: 'Darpan',
        recoveryKey: 'KEY-1234',
        anonymousToken: 'anon_token',
        createdAt: DateTime.now(),
      );

      final trip = await tripRepo.createTrip(
        name: 'Leh Ladakh Expedition',
        emoji: '🏔️',
        creator: creator,
      );

      await viewModel.loadTrip(trip.id, 'u1');
      expect(viewModel.journeyMoments, isEmpty);

      final now = DateTime.now();
      final moment1 = JourneyMoment(
        id: 'jm_01',
        tripId: trip.id,
        createdBy: 'u1',
        creatorName: 'Darpan',
        title: 'Crossed Khardung La Pass (17,982 ft)',
        placeName: 'Khardung La, Ladakh',
        note: 'Snowing and freezing wind, had hot chai',
        dayIndex: 3,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await viewModel.addJourneyMoment(moment1);
      expect(viewModel.journeyMoments.length, equals(1));
      expect(viewModel.journeyMoments.first.title, contains('Khardung La'));

      await viewModel.deleteJourneyMoment('jm_01');
      expect(viewModel.journeyMoments, isEmpty);
    });
  });
}
