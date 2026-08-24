import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../core/network/realtime_client.dart';
import '../../domain/enums/trip_lifecycle.dart';
import '../../domain/models/activity_log.dart';
import '../../domain/models/guest_user.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_member.dart';
import '../../domain/models/trip_preview.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

class TripRepository {
  final LocalStorageService storage;
  final SyncService syncService;
  final ApiClient apiClient;
  final RealtimeClient? realtimeClient;
  final Uuid _uuid = const Uuid();

  TripRepository({
    required this.storage,
    required this.syncService,
    required this.apiClient,
    this.realtimeClient,
  });

  /// Returns all trips, querying the backend when online and falling back to offline cache.
  Future<List<Trip>> getTrips() async {
    try {
      final res = await apiClient.get('/trips');
      if (res is List) {
        final trips = res.map((j) => Trip.fromJson(j as Map<String, dynamic>)).toList();
        await storage.saveTrips(trips.map((t) => t.toJson()).toList());
        return trips;
      }
    } catch (_) {
      // Offline fallback: load from persistent local cache
    }

    final raw = storage.getSavedTrips();
    return raw.map((json) => Trip.fromJson(json)).toList();
  }

  /// Returns a specific trip by its ID.
  Future<Trip?> getTripById(String tripId) async {
    try {
      final res = await apiClient.get('/trips/$tripId');
      if (res is Map<String, dynamic>) {
        final trip = Trip.fromJson(res);
        final currentTrips = await getTrips();
        final idx = currentTrips.indexWhere((t) => t.id == trip.id);
        if (idx != -1) {
          currentTrips[idx] = trip;
        } else {
          currentTrips.insert(0, trip);
        }
        await storage.saveTrips(currentTrips.map((t) => t.toJson()).toList());
        return trip;
      }
    } catch (_) {
      // Offline fallback
    }

    final trips = await getTrips();
    return trips.where((t) => t.id == tripId).firstOrNull;
  }

  /// Fetches a non-sensitive preview of a trip by invite code before joining.
  Future<TripPreview?> getTripPreview(String inviteCode) async {
    try {
      final res = await apiClient.get('/trips/preview', queryParams: {'code': inviteCode.trim()});
      if (res is Map<String, dynamic>) {
        return TripPreview.fromJson(res);
      }
    } catch (_) {
      // Offline fallback
    }
    return null;
  }

  /// Creates a new trip on the backend with the current user as creator.
  Future<Trip> createTrip({
    required String name,
    String? description,
    String emoji = '✈️',
    int coverGradientIndex = 0,
    String currencyCode = 'INR',
    required GuestUser creator,
    List<String> initialFriendNames = const [],
  }) async {
    final payload = {
      'name': name.trim(),
      'description': description?.trim(),
      'emoji': emoji,
      'coverGradientIndex': coverGradientIndex,
      'currencyCode': currencyCode,
      'initialFriendNames': initialFriendNames,
    };

    try {
      final res = await apiClient.post('/trips', body: payload);
      if (res is Map<String, dynamic>) {
        final trip = Trip.fromJson(res);
        final currentTrips = await getTrips();
        currentTrips.insert(0, trip);
        await storage.saveTrips(currentTrips.map((t) => t.toJson()).toList());
        return trip;
      }
    } catch (_) {
      // Offline fallback
    }

    final tripId = 'trip_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final inviteCode = _generateInviteCode();

    final members = <TripMember>[
      TripMember(
        id: 'mbr_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
        userId: creator.id,
        displayName: creator.displayName,
        avatarUrl: creator.avatarUrl,
        role: 'creator',
        joinedAt: DateTime.now(),
      ),
    ];

    for (final friendName in initialFriendNames) {
      if (friendName.trim().isNotEmpty) {
        members.add(TripMember(
          id: 'mbr_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
          userId: 'guest_${_uuid.v4().replaceAll('-', '').substring(0, 8)}',
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
      inviteCode: inviteCode,
      members: members,
      lifecycleState: TripLifecycle.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final currentTrips = await getTrips();
    currentTrips.insert(0, newTrip);
    await storage.saveTrips(currentTrips.map((t) => t.toJson()).toList());

    await syncService.enqueueMutation(MutationType.createTrip, payload);

    return newTrip;
  }

  /// Joins a trip via 6-digit alphanumeric invite code.
  Future<Trip?> joinTrip({
    required String inviteCodeOrId,
    required GuestUser user,
  }) async {
    final cleanCode = inviteCodeOrId.trim().toUpperCase();

    try {
      final res = await apiClient.post('/trips/join', body: {'inviteCode': cleanCode});
      if (res is Map<String, dynamic>) {
        final trip = Trip.fromJson(res);
        final currentTrips = await getTrips();
        final idx = currentTrips.indexWhere((t) => t.id == trip.id);
        if (idx != -1) {
          currentTrips[idx] = trip;
        } else {
          currentTrips.insert(0, trip);
        }
        await storage.saveTrips(currentTrips.map((t) => t.toJson()).toList());
        return trip;
      }
    } catch (_) {
      // Offline fallback: check local match
    }

    final trips = await getTrips();
    final matchIndex = trips.indexWhere(
      (t) => t.inviteCode.toUpperCase() == cleanCode || t.id == cleanCode,
    );

    if (matchIndex == -1) {
      return null;
    }

    final targetTrip = trips[matchIndex];
    if (targetTrip.members.any((m) => m.userId == user.id)) {
      return targetTrip;
    }

    final updatedMembers = List<TripMember>.from(targetTrip.members);
    final newMember = TripMember(
      id: 'mbr_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
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
      {'inviteCode': cleanCode},
    );

    return updatedTrip;
  }

  /// Updates the lifecycle of a trip (e.g. active -> completed).
  Future<Trip> updateLifecycle({
    required String tripId,
    required TripLifecycle newLifecycle,
  }) async {
    try {
      final res = await apiClient.patch('/trips/$tripId/lifecycle', body: {
        'lifecycleState': newLifecycle.name,
      });
      if (res is Map<String, dynamic>) {
        final updatedTrip = Trip.fromJson(res);
        final trips = await getTrips();
        final idx = trips.indexWhere((t) => t.id == tripId);
        if (idx != -1) {
          trips[idx] = updatedTrip;
          await storage.saveTrips(trips.map((t) => t.toJson()).toList());
        }
        return updatedTrip;
      }
    } catch (_) {
      // Offline fallback
    }

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
      {'tripId': tripId, 'lifecycleState': newLifecycle.name},
    );

    return updatedTrip;
  }

  /// Adds an additional member to a trip.
  Future<Trip> addMember({
    required String tripId,
    required String displayName,
  }) async {
    try {
      final res = await apiClient.post('/trips/$tripId/members', body: {
        'displayName': displayName.trim(),
      });
      if (res is Map<String, dynamic>) {
        final updatedTrip = Trip.fromJson(res);
        final trips = await getTrips();
        final idx = trips.indexWhere((t) => t.id == tripId);
        if (idx != -1) {
          trips[idx] = updatedTrip;
          await storage.saveTrips(trips.map((t) => t.toJson()).toList());
        }
        return updatedTrip;
      }
    } catch (_) {
      // Offline fallback
    }

    final trips = await getTrips();
    final index = trips.indexWhere((t) => t.id == tripId);
    if (index == -1) throw StateError('Trip not found');

    final updatedMembers = List<TripMember>.from(trips[index].members);
    final newMember = TripMember(
      id: 'mbr_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
      userId: 'guest_${_uuid.v4().replaceAll('-', '').substring(0, 8)}',
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

  /// Fetches chronological audit activity logs for the trip.
  Future<List<ActivityLog>> getActivityLogs(String tripId) async {
    try {
      final res = await apiClient.get('/trips/$tripId/activity');
      if (res is List) {
        return res
            .map((item) => ActivityLog.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fallback
    }
    return [];
  }

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
