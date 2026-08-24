import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late TripRepository tripRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    syncService = SyncService(storage);
    tripRepo = TripRepository(storage: storage, syncService: syncService);
  });

  group('TripRepository Integration Tests', () {
    final creator = GuestUser(
      id: 'usr_creator',
      displayName: 'Darpan',
      recoveryKey: 'KITH-TEST-1234',
      anonymousToken: 'anon_token',
      createdAt: DateTime.now(),
    );

    test('Creates a trip with creator and initial friends', () async {
      final trip = await tripRepo.createTrip(
        name: 'Goa Escape',
        emoji: '🏖️',
        creator: creator,
        initialFriendNames: ['Rahul', 'Priya'],
      );

      expect(trip.name, 'Goa Escape');
      expect(trip.emoji, '🏖️');
      expect(trip.members.length, 3);
      expect(trip.members.first.displayName, 'Darpan');
      expect(trip.members.first.isCreator, isTrue);
      expect(trip.lifecycleState, TripLifecycle.active);

      final trips = await tripRepo.getTrips();
      expect(trips.length, 1);
      expect(trips.first.id, trip.id);
    });

    test('Allows a new user to join via invite code', () async {
      final trip = await tripRepo.createTrip(
        name: 'Manali Trek',
        creator: creator,
      );

      final friend = GuestUser(
        id: 'usr_friend',
        displayName: 'Aman',
        recoveryKey: 'KITH-TEST-5678',
        anonymousToken: 'anon_token_2',
        createdAt: DateTime.now(),
      );

      final joinedTrip = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: friend,
      );

      expect(joinedTrip, isNotNull);
      expect(joinedTrip!.members.length, 2);
      expect(joinedTrip.members.any((m) => m.userId == 'usr_friend'), isTrue);
    });

    test('Updates trip lifecycle state from active to completed', () async {
      final trip = await tripRepo.createTrip(
        name: 'Weekend Getaway',
        creator: creator,
      );

      final updated = await tripRepo.updateLifecycle(
        tripId: trip.id,
        newLifecycle: TripLifecycle.completed,
      );

      expect(updated.lifecycleState, TripLifecycle.completed);
      expect(updated.lifecycleState.isLocked, isTrue);
    });
  });
}
