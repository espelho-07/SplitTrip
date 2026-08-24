import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/create_trip_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;

  final testUser = GuestUser(
    id: 'usr_test_alpha',
    displayName: 'Aarav Tester',
    recoveryKey: 'KITH-TEST-1234',
    anonymousToken: 'tok_alpha_123',
    createdAt: DateTime.now(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    apiClient = ApiClient();
    syncService = SyncService(storage);
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
  });

  group('Async Lifecycle & Mutation Guard Tests', () {
    test('1. TripRepository returns cached trips synchronously without network delay', () async {
      final trip = Trip(
        id: 'trip_cache_001',
        name: 'Goa Weekend',
        emoji: '🏖️',
        coverGradientIndex: 1,
        currencyCode: 'INR',
        creatorId: testUser.id,
        inviteCode: 'GOA123',
        members: [
          TripMember(
            id: 'mbr_01',
            userId: testUser.id,
            displayName: testUser.displayName,
            role: 'creator',
            joinedAt: DateTime.now(),
          ),
        ],
        lifecycleState: TripLifecycle.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.saveTrips([trip.toJson()]);

      // Synchronous retrieval must return cached trip instantly
      final cached = tripRepo.getCachedTrips();
      expect(cached.length, 1);
      expect(cached.first.id, 'trip_cache_001');
      expect(cached.first.name, 'Goa Weekend');

      final cachedById = tripRepo.getCachedTripById('trip_cache_001');
      expect(cachedById, isNotNull);
      expect(cachedById!.inviteCode, 'GOA123');
    });

    test('2. CreateTripViewModel blocks duplicate concurrent creation calls', () async {
      final createVm = CreateTripViewModel(tripRepo: tripRepo);
      createVm.setName('Manali Expedition');
      createVm.addFriendName('Rohan');

      expect(createVm.isValid, true);
      expect(createVm.isCreating, false);

      // Start creation
      final future1 = createVm.createTrip(testUser);
      expect(createVm.isCreating, true);

      // Attempt second concurrent creation while isCreating is active
      final future2 = createVm.createTrip(testUser);
      expect(await future2, isNull); // Must immediately reject duplicate call!

      final createdTrip = await future1;
      expect(createdTrip, isNotNull);
      expect(createVm.isCreating, false);
      expect(createVm.name, ''); // Form must be reset on success
    });

    test('3. HomeViewModel.addTripLocally updates in-memory trips and balances instantly', () async {
      final homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
      expect(homeVm.trips, isEmpty);

      final newTrip = Trip(
        id: 'trip_instant_001',
        name: 'Leh Ladakh',
        emoji: '🏔️',
        coverGradientIndex: 2,
        currencyCode: 'INR',
        creatorId: testUser.id,
        inviteCode: 'LEH789',
        members: [
          TripMember(
            id: 'mbr_01',
            userId: testUser.id,
            displayName: testUser.displayName,
            role: 'creator',
            joinedAt: DateTime.now(),
          ),
        ],
        lifecycleState: TripLifecycle.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      homeVm.addTripLocally(newTrip, testUser.id);

      expect(homeVm.trips.length, 1);
      expect(homeVm.trips.first.id, 'trip_instant_001');
      expect(homeVm.tripBalances.containsKey('trip_instant_001'), true);
      expect(homeVm.isLoading, false);
    });

    test('4. HomeViewModel.loadTrips renders cached trips instantly on cold start', () async {
      final trip = Trip(
        id: 'trip_cold_001',
        name: 'Cached Paris Trip',
        emoji: '🗼',
        coverGradientIndex: 3,
        currencyCode: 'EUR',
        creatorId: testUser.id,
        inviteCode: 'PARIS1',
        members: [
          TripMember(
            id: 'mbr_01',
            userId: testUser.id,
            displayName: testUser.displayName,
            role: 'creator',
            joinedAt: DateTime.now(),
          ),
        ],
        lifecycleState: TripLifecycle.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.saveTrips([trip.toJson()]);

      final homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
      await homeVm.loadTrips(testUser.id);

      expect(homeVm.trips.length, 1);
      expect(homeVm.trips.first.name, 'Cached Paris Trip');
      expect(homeVm.isLoading, false);
    });
  });
}
