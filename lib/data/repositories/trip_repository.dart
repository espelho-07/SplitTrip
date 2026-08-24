import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../domain/enums/trip_lifecycle.dart';
import '../../domain/models/guest_user.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_member.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

class TripRepository {
  final LocalStorageService storage;
  final SyncService syncService;
  final Uuid _uuid = const Uuid();

  TripRepository({
    required this.storage,
    required this.syncService,
  });

  /// Returns all cached trips.
  Future<List<Trip>> getTrips() async {
    final raw = storage.getSavedTrips();
    return raw.map((json) => Trip.fromJson(json)).toList();
  }

  /// Returns a specific trip by its ID.
  Future<Trip?> getTripById(String tripId) async {
    final trips = await getTrips();
    return trips.where((t) => t.id == tripId).firstOrNull;
  }

  /// Creates a new trip with the current user as creator and optional initial friend members.
  Future<Trip> createTrip({
    required String name,
    String? description,
    String emoji = '✈️',
    int coverGradientIndex = 0,
    String currencyCode = 'INR',
    required GuestUser creator,
    List<String> initialFriendNames = const [],
  }) async {
    final tripId = _uuid.v4();
    final inviteCode = _generateInviteCode();

    final members = <TripMember>[
      TripMember(
        id: _uuid.v4(),
        userId: creator.id,
        displayName: creator.displayName,
        avatarUrl: creator.avatarUrl,
        role: 'creator',
        joinedAt: DateTime.now(),
      ),
    ];

    // Add initial friends if provided
    for (final friendName in initialFriendNames) {
      if (friendName.trim().isNotEmpty) {
        members.add(TripMember(
          id: _uuid.v4(),
          userId: 'guest_${_uuid.v4().substring(0, 8)}',
          displayName: friendName.trim(),
          role: 'member',
          joinedAt: DateTime.now(),
        ));
      }
    }

    final newTrip = Trip(
      id: tripId,
      name: name.trim(),
      description: description?.trim(),
      emoji: emoji,
      coverGradientIndex: coverGradientIndex,
      currencyCode: currencyCode,
      creatorId: creator.id,
      members: members,
      lifecycleState: TripLifecycle.active,
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final currentTrips = await getTrips();
    currentTrips.insert(0, newTrip);
    await storage.saveTrips(currentTrips.map((t) => t.toJson()).toList());

    // Enqueue sync mutation
    await syncService.enqueueMutation(
      MutationType.createTrip,
      newTrip.toJson(),
    );

    return newTrip;
  }

  /// Joins an existing trip using an invite code or trip ID.
  Future<Trip?> joinTrip({
    required String inviteCodeOrId,
    required GuestUser user,
  }) async {
    final trips = await getTrips();
    final cleanCode = inviteCodeOrId.trim().toUpperCase();

    final matchIndex = trips.indexWhere(
      (t) => t.inviteCode.toUpperCase() == cleanCode || t.id == inviteCodeOrId.trim(),
    );

    if (matchIndex == -1) return null;

    final targetTrip = trips[matchIndex];
    final alreadyMember = targetTrip.members.any((m) => m.userId == user.id);

    if (alreadyMember) {
      return targetTrip;
    }

    final updatedMembers = List<TripMember>.from(targetTrip.members);
    final newMember = TripMember(
      id: _uuid.v4(),
      userId: user.id,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      role: 'member',
      joinedAt: DateTime.now(),
    );
    updatedMembers.add(newMember);

    final updatedTrip = targetTrip.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    trips[matchIndex] = updatedTrip;
    await storage.saveTrips(trips.map((t) => t.toJson()).toList());

    await syncService.enqueueMutation(
      MutationType.joinTrip,
      {'tripId': targetTrip.id, 'member': newMember.toJson()},
    );

    return updatedTrip;
  }

  /// Updates the lifecycle of a trip (e.g. active -> completed).
  Future<Trip> updateLifecycle({
    required String tripId,
    required TripLifecycle newLifecycle,
  }) async {
    final trips = await getTrips();
    final index = trips.indexWhere((t) => t.id == tripId);
    if (index == -1) {
      throw StateError('Trip not found');
    }

    final updatedTrip = trips[index].copyWith(
      lifecycleState: newLifecycle,
      updatedAt: DateTime.now(),
    );

    trips[index] = updatedTrip;
    await storage.saveTrips(trips.map((t) => t.toJson()).toList());

    await syncService.enqueueMutation(
      MutationType.updateTripLifecycle,
      {'tripId': tripId, 'lifecycle': newLifecycle.name},
    );

    return updatedTrip;
  }

  /// Adds an additional member to a trip.
  Future<Trip> addMember({
    required String tripId,
    required String displayName,
  }) async {
    final trips = await getTrips();
    final index = trips.indexWhere((t) => t.id == tripId);
    if (index == -1) throw StateError('Trip not found');

    final updatedMembers = List<TripMember>.from(trips[index].members);
    final newMember = TripMember(
      id: _uuid.v4(),
      userId: 'guest_${_uuid.v4().substring(0, 8)}',
      displayName: displayName.trim(),
      role: 'member',
      joinedAt: DateTime.now(),
    );
    updatedMembers.add(newMember);

    final updatedTrip = trips[index].copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    trips[index] = updatedTrip;
    await storage.saveTrips(trips.map((t) => t.toJson()).toList());

    return updatedTrip;
  }

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
