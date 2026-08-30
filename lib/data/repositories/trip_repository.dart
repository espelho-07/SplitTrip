import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/network/realtime_client.dart';
import '../../domain/enums/trip_lifecycle.dart';
import '../../domain/models/activity_log.dart';
import '../../domain/models/guest_user.dart';
import '../../domain/models/journey_moment.dart';
import '../../domain/models/journey_stop.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_member.dart';
import '../../domain/models/trip_memory.dart';
import '../../domain/models/trip_preview.dart';
import '../../domain/models/trip_sync_status.dart';
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

  /// Synchronously returns cached trips from local storage without network latency.
  List<Trip> getCachedTrips() {
    final raw = storage.getSavedTrips();
    return raw.map((json) => Trip.fromJson(json)).toList();
  }

  /// Synchronously returns a cached trip by ID from local storage.
  Trip? getCachedTripById(String tripId) {
    return getCachedTrips().where((t) => t.id == tripId).firstOrNull;
  }

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

    return getCachedTrips();
  }

  /// Returns a specific trip by its ID.
  Future<Trip?> getTripById(String tripId) async {
    try {
      final res = await apiClient.get('/trips/$tripId');
      if (res is Map<String, dynamic>) {
        final trip = Trip.fromJson(res);
        final currentTrips = getCachedTrips();
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

    return getCachedTripById(tripId);
  }

  /// Fetches a non-sensitive preview of a trip by invite code before joining.
  Future<TripPreview?> getTripPreview(String inviteCode) async {
    final cleanCode = inviteCode.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (cleanCode.isEmpty) return null;

    // Check if trip is already cached locally
    final cached = getCachedTrips().where(
      (t) => t.inviteCode.toUpperCase() == cleanCode || t.id.toUpperCase() == cleanCode,
    ).firstOrNull;

    if (cached != null) {
      final unclaimed = cached.members
          .where((m) => m.isUnclaimed)
          .map((m) => UnclaimedMemberPreview(
                id: m.id,
                displayName: m.displayName,
                avatarUrl: m.avatarUrl,
                claimToken: m.claimToken,
              ))
          .toList();

      return TripPreview(
        tripId: cached.id,
        name: cached.name,
        emoji: cached.emoji,
        coverGradientIndex: cached.coverGradientIndex,
        currencyCode: cached.currencyCode,
        creatorName: cached.members.where((m) => m.role == 'creator').firstOrNull?.displayName ?? 'A Kith user',
        memberCount: cached.members.length,
        lifecycleState: cached.lifecycleState.name,
        inviteCode: cached.inviteCode,
        unclaimedMembers: unclaimed,
      );
    }

    try {
      final res = await apiClient.get('/trips/preview', queryParams: {'code': cleanCode});
      if (res is Map<String, dynamic>) {
        return TripPreview.fromJson(res);
      }
    } catch (_) {
      // Return null on preview failure
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
    String tripMode = 'split_only',
  }) async {
    final tripId = 'trip_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final inviteCode = _generateInviteCode();

    final payload = {
      'id': tripId,
      'inviteCode': inviteCode,
      'name': name.trim(),
      'description': description?.trim(),
      'emoji': emoji,
      'coverGradientIndex': coverGradientIndex,
      'currencyCode': currencyCode,
      'initialFriendNames': initialFriendNames,
      'tripMode': tripMode,
    };

    final members = <TripMember>[
      TripMember(
        id: 'mbr_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
        userId: creator.id,
        displayName: creator.displayName,
        avatarUrl: creator.avatarUrl,
        role: 'creator',
        status: 'claimed',
        isClaimed: true,
        joinedAt: DateTime.now(),
        upiId: creator.upiId,
      ),
    ];

    for (final friendName in initialFriendNames) {
      if (friendName.trim().isNotEmpty) {
        members.add(TripMember(
          id: 'mbr_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
          userId: 'unclaimed_${_uuid.v4().replaceAll('-', '').substring(0, 8)}',
          displayName: friendName.trim(),
          role: 'member',
          isClaimed: false,
          claimToken: 'clm_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
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
      tripMode: tripMode,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 1. FAST LOCAL HYDRATION: Save to persistent local cache (< 5ms)
    final currentTrips = getCachedTrips();
    currentTrips.removeWhere((t) => t.id == newTrip.id);
    currentTrips.insert(0, newTrip);
    await storage.saveTrips(currentTrips.map((t) => t.toJson()).toList());

    // 2. Ensure auth credentials are active on API client
    if (creator.anonymousToken.isNotEmpty) {
      apiClient.setAuthToken(creator.anonymousToken);
      realtimeClient?.setAuthToken(creator.anonymousToken);
    }

    // 3. Attempt direct synchronous creation on server when online
    try {
      final res = await apiClient.post('/trips', body: payload);
      if (res is Map<String, dynamic>) {
        final serverTrip = Trip.fromJson(res);
        final trips = getCachedTrips();
        final idx = trips.indexWhere((t) => t.id == serverTrip.id);
        if (idx != -1) {
          trips[idx] = serverTrip;
        } else {
          trips.insert(0, serverTrip);
        }
        await storage.saveTrips(trips.map((t) => t.toJson()).toList());
        return serverTrip;
      }
    } catch (_) {
      // 4. Offline / network failure: enqueue mutation with non-blocking background flush
      await syncService.enqueueMutation(
        MutationType.createTrip,
        payload,
        idempotencyKey: tripId,
        backgroundApiClient: apiClient,
      );
    }

    return newTrip;
  }


  /// Joins a trip via 6-digit alphanumeric invite code, with optional explicit participant claiming.
  Future<Trip> joinTrip({
    required String inviteCodeOrId,
    required GuestUser user,
    String? claimMemberId,
    String? claimToken,
  }) async {
    final cleanCode = inviteCodeOrId.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (cleanCode.isEmpty) {
      throw const ValidationException(message: 'Please enter a valid 6-digit invite code.');
    }

    // Ensure authorization header is set with current session token
    if (user.anonymousToken.isNotEmpty) {
      apiClient.setAuthToken(user.anonymousToken);
      realtimeClient?.setAuthToken(user.anonymousToken);
    }

    final payload = <String, dynamic>{
      'inviteCode': cleanCode,
      if (claimMemberId != null && claimMemberId.isNotEmpty) 'claimMemberId': claimMemberId,
      if (claimToken != null && claimToken.isNotEmpty) 'claimToken': claimToken,
    };

    try {
      final res = await apiClient.post('/trips/join', body: payload);
      if (res is Map<String, dynamic>) {
        final trip = Trip.fromJson(res);
        final currentTrips = getCachedTrips();
        final idx = currentTrips.indexWhere((t) => t.id == trip.id);
        if (idx != -1) {
          currentTrips[idx] = trip;
        } else {
          currentTrips.insert(0, trip);
        }
        await storage.saveTrips(currentTrips.map((t) => t.toJson()).toList());
        return trip;
      }
    } on NotFoundException {
      // Check if trip is in local cache (e.g. newly created on this device / offline)
      final trips = getCachedTrips();
      final match = trips.where(
        (t) => t.inviteCode.toUpperCase() == cleanCode || t.id.toUpperCase() == cleanCode,
      ).firstOrNull;
      if (match != null) {
        final updatedTrip = _processLocalJoin(match, user, claimMemberId: claimMemberId);
        final idx = trips.indexWhere((t) => t.id == match.id);
        if (idx != -1) {
          trips[idx] = updatedTrip;
        } else {
          trips.insert(0, updatedTrip);
        }
        await storage.saveTrips(trips.map((t) => t.toJson()).toList());
        await syncService.enqueueMutation(MutationType.joinTrip, payload);
        return updatedTrip;
      }
      throw NotFoundException(message: 'No trip found for invite code "$cleanCode". Check the code and try again.');
    } on NetworkException {
      // Check if trip was previously cached on this device
      final trips = getCachedTrips();
      final match = trips.where(
        (t) => t.inviteCode.toUpperCase() == cleanCode || t.id.toUpperCase() == cleanCode,
      ).firstOrNull;
      if (match != null) {
        final updatedTrip = _processLocalJoin(match, user, claimMemberId: claimMemberId);
        final idx = trips.indexWhere((t) => t.id == match.id);
        if (idx != -1) {
          trips[idx] = updatedTrip;
        } else {
          trips.add(updatedTrip);
        }
        await storage.saveTrips(trips.map((t) => t.toJson()).toList());
        await syncService.enqueueMutation(MutationType.joinTrip, payload);
        return updatedTrip;
      }
      throw const NetworkException(message: "You're offline. Reconnect to join this trip.");
    } on ApiException catch (e) {
      // If server returned a trip in conflict/already-joined scenario
      if (e.details is Map<String, dynamic> && e.details.containsKey('trip')) {
        final trip = Trip.fromJson(e.details['trip'] as Map<String, dynamic>);
        return trip;
      }
      // If local cache has the trip (e.g. offline or local test session), update local cache
      final trips = getCachedTrips();
      final match = trips.where(
        (t) => t.inviteCode.toUpperCase() == cleanCode || t.id.toUpperCase() == cleanCode,
      ).firstOrNull;
      if (match != null) {
        final updatedTrip = _processLocalJoin(match, user, claimMemberId: claimMemberId);
        final idx = trips.indexWhere((t) => t.id == match.id);
        if (idx != -1) {
          trips[idx] = updatedTrip;
        } else {
          trips.add(updatedTrip);
        }
        await storage.saveTrips(trips.map((t) => t.toJson()).toList());
        await syncService.enqueueMutation(MutationType.joinTrip, payload);
        return updatedTrip;
      }
      rethrow;
    } catch (e) {
      // Offline fallback: check local cache
      final trips = getCachedTrips();
      final match = trips.where(
        (t) => t.inviteCode.toUpperCase() == cleanCode || t.id.toUpperCase() == cleanCode,
      ).firstOrNull;
      if (match != null) {
        final updatedTrip = _processLocalJoin(match, user, claimMemberId: claimMemberId);
        final idx = trips.indexWhere((t) => t.id == match.id);
        if (idx != -1) {
          trips[idx] = updatedTrip;
        } else {
          trips.add(updatedTrip);
        }
        await storage.saveTrips(trips.map((t) => t.toJson()).toList());
        await syncService.enqueueMutation(MutationType.joinTrip, payload);
        return updatedTrip;
      }
      throw NetworkException(message: "Could not join trip: $e");
    }

    throw const NotFoundException(message: 'Could not resolve trip for this invite code.');
  }

  Trip _processLocalJoin(Trip match, GuestUser user, {String? claimMemberId}) {
    // 1. Idempotency Check: already a member
    if (match.members.any((m) => m.userId == user.id)) {
      return match;
    }

    final updatedMembers = List<TripMember>.from(match.members);

    // 2. Claim existing unclaimed member
    if (claimMemberId != null && claimMemberId.isNotEmpty) {
      final idx = updatedMembers.indexWhere((m) => m.id == claimMemberId && m.isUnclaimed);
      if (idx != -1) {
        updatedMembers[idx] = updatedMembers[idx].copyWith(
          userId: user.id,
          avatarUrl: user.avatarUrl ?? updatedMembers[idx].avatarUrl,
          isClaimed: true,
          status: 'claimed',
          joinedAt: DateTime.now(),
          upiId: user.upiId ?? updatedMembers[idx].upiId,
        );
        return match.copyWith(
          members: updatedMembers,
          updatedAt: DateTime.now(),
        );
      }
    }

    // 3. New member join
    final newMember = TripMember(
      id: 'mbr_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
      userId: user.id,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      role: 'member',
      status: 'claimed',
      isClaimed: true,
      joinedAt: DateTime.now(),
      upiId: user.upiId,
    );
    updatedMembers.add(newMember);

    return match.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );
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

    // Determine target local lifecycle:
    // If completing a trip and pending un-synced operations exist for this trip,
    // transition locally to `completing` ("Finishing sync") rather than jumping to `completed`.
    final pendingMutations = syncService.getPendingMutationsForTrip(tripId);
    TripLifecycle targetLocalState = newLifecycle;
    if (newLifecycle == TripLifecycle.completed && pendingMutations.isNotEmpty) {
      targetLocalState = TripLifecycle.completing;
    }

    final updatedTrip = trips[index].copyWith(
      lifecycleState: targetLocalState,
      updatedAt: DateTime.now(),
    );

    trips[index] = updatedTrip;
    await storage.saveTrips(trips.map((t) => t.toJson()).toList());

    // Record local activity
    final log = ActivityLog(
      id: 'act_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
      tripId: tripId,
      type: 'lifecycle_updated',
      actorId: trips[index].creatorId,
      actorName: 'Creator',
      description: targetLocalState == TripLifecycle.completing
          ? 'Finishing sync for trip completion'
          : 'Changed trip state to ${newLifecycle.displayName.toUpperCase()}',
      createdAt: DateTime.now(),
      metadata: {'lifecycleState': targetLocalState.name, 'targetLifecycle': newLifecycle.name},
    );
    await addLocalActivityLog(tripId, log);

    // Enqueue mutation with dependency list of all pending mutations for this trip
    final dependencyIds = pendingMutations.map((m) => m.id).toList();
    await syncService.enqueueMutation(
      MutationType.updateTripLifecycle,
      {'tripId': tripId, 'lifecycleState': newLifecycle.name},
      idempotencyKey: 'life_${tripId}_${newLifecycle.name}',
      dependsOn: dependencyIds,
      backgroundApiClient: apiClient,
    );

    return updatedTrip;
  }

  /// Fetches authoritative multi-participant synchronization status for a trip.
  Future<TripSyncStatus> getTripSyncStatus(String tripId) async {
    final res = await apiClient.get('/trips/$tripId/sync-status');
    if (res is Map<String, dynamic>) {
      return TripSyncStatus.fromJson(res);
    }
    throw const NetworkException(message: 'Invalid response from sync status endpoint');
  }

  /// Broadcasts a real-time sync request to all online participants in the trip.
  Future<void> requestTripSync(String tripId) async {
    try {
      await apiClient.post('/trips/$tripId/request-sync');
    } catch (_) {
      // Best-effort realtime trigger
    }
  }

  /// Reports current device synchronization acknowledgment up to [revision].
  Future<void> acknowledgeSync(String tripId, {required int revision, int pendingCount = 0}) async {
    try {
      await apiClient.post('/trips/$tripId/ack-sync', body: {
        'revision': revision,
        'pendingCount': pendingCount,
      });
    } catch (_) {
      // Best-effort acknowledgment
    }
  }

  /// Atomically completes a trip with server-side sync verification and concurrency protection.
  Future<Trip> completeTrip({
    required String tripId,
    required String completionMode, // 'NORMAL' or 'FORCED_WITH_PENDING_SYNC'
    int? expectedRevision,
  }) async {
    debugPrint('[TripRepository] TRIP COMPLETION REQUEST: tripId=$tripId, mode=$completionMode');
    final res = await apiClient.post('/trips/$tripId/complete', body: {
      'completionMode': completionMode,
      'expectedRevision': expectedRevision,
    });

    if (res is Map<String, dynamic>) {
      final completedTrip = Trip.fromJson(res);
      debugPrint('[TripRepository] SERVER COMPLETION RESULT: tripId=${completedTrip.id}, status=${completedTrip.lifecycleState.name}');

      // 1. Immediately update local storage cache with completed trip
      final cached = getCachedTrips();
      final idx = cached.indexWhere((t) => t.id == tripId);
      if (idx != -1) {
        cached[idx] = completedTrip;
      } else {
        cached.insert(0, completedTrip);
      }
      await storage.saveTrips(cached.map((t) => t.toJson()).toList());

      // 2. Fetch authoritative full remote list in background without dropping completed trip
      try {
        final remoteTrips = await getTrips();
        final rIdx = remoteTrips.indexWhere((t) => t.id == tripId);
        if (rIdx != -1) {
          remoteTrips[rIdx] = completedTrip;
          await storage.saveTrips(remoteTrips.map((t) => t.toJson()).toList());
        }
      } catch (_) {}

      return completedTrip;
    }

    throw const NetworkException(message: 'Failed to complete trip on server');
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
      userId: 'unclaimed_${_uuid.v4().replaceAll('-', '').substring(0, 8)}',
      displayName: displayName.trim(),
      role: 'member',
      status: 'unclaimed',
      isClaimed: false,
      claimToken: 'clm_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
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

  /// Renames an unclaimed member in a trip.
  Future<Trip> renameMember({
    required String tripId,
    required String memberId,
    required String newDisplayName,
  }) async {
    try {
      final res = await apiClient.patch('/trips/$tripId/members/$memberId', body: {
        'displayName': newDisplayName.trim(),
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

    final updatedMembers = trips[index].members.map((m) {
      if (m.id == memberId) {
        return m.copyWith(displayName: newDisplayName.trim());
      }
      return m;
    }).toList();

    final updatedTrip = trips[index].copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    trips[index] = updatedTrip;
    await storage.saveTrips(trips.map((t) => t.toJson()).toList());
    return updatedTrip;
  }

  /// Removes an eligible member from a trip (blocked if financial activity exists).
  Future<Trip> removeMember({
    required String tripId,
    required String memberId,
  }) async {
    try {
      final res = await apiClient.delete('/trips/$tripId/members/$memberId');
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
    } on NetworkException {
      rethrow;
    } catch (_) {
      // Offline fallback
    }

    final trips = await getTrips();
    final index = trips.indexWhere((t) => t.id == tripId);
    if (index == -1) throw StateError('Trip not found');

    final updatedMembers = trips[index].members.where((m) => m.id != memberId).toList();
    final updatedTrip = trips[index].copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    trips[index] = updatedTrip;
    await storage.saveTrips(trips.map((t) => t.toJson()).toList());
    return updatedTrip;
  }

  /// Merges two duplicate members into a single canonical participant, migrating all expenses, splits, and settlements atomically.
  Future<Trip> mergeMembers({
    required String tripId,
    required String sourceMemberId,
    required String canonicalMemberId,
    String? operationId,
  }) async {
    debugPrint('[TripRepository] MERGE REQUEST: tripId=$tripId, source=$sourceMemberId, canonical=$canonicalMemberId');
    try {
      final res = await apiClient.post('/trips/$tripId/members/merge', body: {
        'sourceMemberId': sourceMemberId,
        'canonicalMemberId': canonicalMemberId,
        'operationId': operationId,
      });

      if (res is Map<String, dynamic>) {
        final updatedTrip = Trip.fromJson(res);

        // 1. Update local expenses to reflect migrated ownership
        final cachedExpenses = storage.getSavedExpenses(tripId);
        for (final expJson in cachedExpenses) {
          if (expJson['paidById'] == sourceMemberId) {
            expJson['paidById'] = canonicalMemberId;
          }
          final splits = (expJson['splits'] as List<dynamic>?) ?? [];
          final sourceIdx = splits.indexWhere((s) => s['memberId'] == sourceMemberId);
          final canonIdx = splits.indexWhere((s) => s['memberId'] == canonicalMemberId);

          if (sourceIdx != -1) {
            if (canonIdx != -1) {
              final sSplit = splits[sourceIdx];
              final cSplit = splits[canonIdx];
              cSplit['amountInPaise'] = ((cSplit['amountInPaise'] as int?) ?? 0) + ((sSplit['amountInPaise'] as int?) ?? 0);
              splits.removeAt(sourceIdx);
            } else {
              splits[sourceIdx]['memberId'] = canonicalMemberId;
            }
          }
        }
        await storage.saveExpenses(tripId, cachedExpenses);

        // 2. Update local settlements
        final cachedSettlements = storage.getSavedTripSettlements(tripId);
        for (final sJson in cachedSettlements) {
          if (sJson['fromMemberId'] == sourceMemberId) {
            sJson['fromMemberId'] = canonicalMemberId;
          }
          if (sJson['toMemberId'] == sourceMemberId) {
            sJson['toMemberId'] = canonicalMemberId;
          }
        }
        await storage.saveTripSettlements(tripId, cachedSettlements);

        // 3. Update local trips cache
        final trips = await getTrips();
        final idx = trips.indexWhere((t) => t.id == tripId);
        if (idx != -1) {
          trips[idx] = updatedTrip;
          await storage.saveTrips(trips.map((t) => t.toJson()).toList());
        }

        return updatedTrip;
      }
    } on NetworkException {
      rethrow;
    } catch (_) {
      // Offline fallback
    }

    // Offline Local Migration Fallback
    final cachedExpenses = storage.getSavedExpenses(tripId);
    for (final expJson in cachedExpenses) {
      if (expJson['paidById'] == sourceMemberId) {
        expJson['paidById'] = canonicalMemberId;
      }
      final splits = (expJson['splits'] as List<dynamic>?) ?? [];
      final sourceIdx = splits.indexWhere((s) => s['memberId'] == sourceMemberId);
      final canonIdx = splits.indexWhere((s) => s['memberId'] == canonicalMemberId);

      if (sourceIdx != -1) {
        if (canonIdx != -1) {
          final sSplit = splits[sourceIdx];
          final cSplit = splits[canonIdx];
          cSplit['amountInPaise'] = ((cSplit['amountInPaise'] as int?) ?? 0) + ((sSplit['amountInPaise'] as int?) ?? 0);
          splits.removeAt(sourceIdx);
        } else {
          splits[sourceIdx]['memberId'] = canonicalMemberId;
        }
      }
    }
    await storage.saveExpenses(tripId, cachedExpenses);

    final cachedSettlements = storage.getSavedTripSettlements(tripId);
    for (final sJson in cachedSettlements) {
      if (sJson['fromMemberId'] == sourceMemberId) {
        sJson['fromMemberId'] = canonicalMemberId;
      }
      if (sJson['toMemberId'] == sourceMemberId) {
        sJson['toMemberId'] = canonicalMemberId;
      }
    }
    await storage.saveTripSettlements(tripId, cachedSettlements);


    final trips = await getTrips();
    final index = trips.indexWhere((t) => t.id == tripId);
    if (index == -1) throw StateError('Trip not found');

    final updatedMembers = trips[index].members.where((m) => m.id != sourceMemberId).toList();
    final updatedTrip = trips[index].copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    trips[index] = updatedTrip;
    await storage.saveTrips(trips.map((t) => t.toJson()).toList());
    return updatedTrip;
  }

  /// Reconciles duplicate members sharing the same user ID safely.
  Trip reconcileDuplicateMembers(Trip trip) {
    final byUserId = <String, List<TripMember>>{};
    for (final m in trip.members) {

      if (m.userId.isEmpty || m.isUnclaimed) continue;
      byUserId.putIfAbsent(m.userId, () => []).add(m);
    }

    var hasDuplicates = false;
    for (final list in byUserId.values) {
      if (list.length > 1) {
        hasDuplicates = true;
        break;
      }
    }
    if (!hasDuplicates) return trip;

    final deduplicated = <TripMember>[];
    final seenUserIds = <String>{};

    for (final m in trip.members) {
      if (m.isUnclaimed || m.userId.isEmpty) {
        deduplicated.add(m);
      } else if (!seenUserIds.contains(m.userId)) {
        seenUserIds.add(m.userId);
        deduplicated.add(m);
      }
    }

    return trip.copyWith(members: deduplicated, updatedAt: DateTime.now());
  }

  /// Synchronously returns cached activity logs or synthesizes from trip and expenses if empty.
  List<ActivityLog> getCachedActivityLogs(String tripId) {
    final raw = storage.getSavedActivityLogs(tripId);
    if (raw.isNotEmpty) {
      final logs = raw.map((j) => ActivityLog.fromJson(j)).toList();
      logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return logs;
    }

    // Synthesize logs from local trip & expenses so activity feed is never blank
    final trip = getCachedTripById(tripId);
    if (trip == null) return [];

    final synthesized = <ActivityLog>[];

    // Trip creation event
    final creator = trip.members.where((m) => m.role == 'creator').firstOrNull ?? trip.members.firstOrNull;
    synthesized.add(
      ActivityLog(
        id: 'act_init_${trip.id}',
        tripId: trip.id,
        type: 'trip_created',
        actorId: creator?.userId ?? '',
        actorName: creator?.displayName ?? 'Trip Creator',
        description: '${creator?.displayName ?? "Creator"} created the trip "${trip.name}"',
        metadata: {'tripId': trip.id, 'emoji': trip.emoji},
        createdAt: trip.createdAt,
      ),
    );

    // Member joins
    for (final member in trip.members) {
      if (member.role != 'creator') {
        synthesized.add(
          ActivityLog(
            id: 'act_mbr_${member.id}',
            tripId: trip.id,
            type: 'member_joined',
            actorId: member.userId,
            actorName: member.displayName,
            description: '${member.displayName} joined the trip',
            metadata: {'memberId': member.id},
            createdAt: member.joinedAt,
          ),
        );
      }
    }

    // Expenses
    final expenses = storage.getSavedExpenses(tripId);
    for (final expJson in expenses) {
      final title = expJson['title'] as String? ?? 'Expense';
      final amountInPaise = expJson['amountInPaise'] as int? ?? 0;
      final paidById = expJson['paidById'] as String? ?? '';
      final payer = trip.members.where((m) => m.id == paidById || m.userId == paidById).firstOrNull;
      final expDate = expJson['createdAt'] != null
          ? DateTime.tryParse(expJson['createdAt'] as String) ?? DateTime.now()
          : DateTime.now();

      synthesized.add(
        ActivityLog(
          id: 'act_exp_${expJson['id'] ?? expDate.millisecondsSinceEpoch}',
          tripId: trip.id,
          type: 'expense_added',
          actorId: payer?.userId ?? '',
          actorName: payer?.displayName ?? 'Member',
          description: '${payer?.displayName ?? "Member"} added "$title" for ₹${(amountInPaise / 100).toStringAsFixed(2)}',
          metadata: {'expenseId': expJson['id'], 'amountInPaise': amountInPaise},
          createdAt: expDate,
        ),
      );
    }

    synthesized.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    storage.saveActivityLogs(tripId, synthesized.map((l) => l.toJson()).toList());
    return synthesized;
  }

  /// Appends a new activity log locally to persistent cache.
  Future<void> addLocalActivityLog(String tripId, ActivityLog log) async {
    final logs = getCachedActivityLogs(tripId);
    logs.removeWhere((l) => l.id == log.id);
    logs.insert(0, log);
    await storage.saveActivityLogs(tripId, logs.map((l) => l.toJson()).toList());
  }

  /// Fetches chronological audit activity logs for the trip with local fallback and merge.
  Future<List<ActivityLog>> getActivityLogs(String tripId) async {
    try {
      final res = await apiClient.get('/trips/$tripId/activity');
      List<dynamic>? rawList;
      if (res is List) {
        rawList = res;
      } else if (res is Map<String, dynamic> && res['data'] is List) {
        rawList = res['data'] as List<dynamic>;
      }

      if (rawList != null && rawList.isNotEmpty) {
        final serverLogs = rawList
            .map((item) => ActivityLog.fromJson(item as Map<String, dynamic>))
            .toList();
        await storage.saveActivityLogs(tripId, serverLogs.map((l) => l.toJson()).toList());
        return serverLogs;
      }
    } catch (_) {
      // Offline fallback
    }

    return getCachedActivityLogs(tripId);
  }

  /// Synchronously returns cached journey stops for a trip.
  List<JourneyStop> getCachedJourneyStops(String tripId) {
    final raw = storage.getSavedJourneyStops(tripId);
    final stops = raw.map((json) => JourneyStop.fromJson(json)).toList();
    stops.sort((a, b) {
      final dayComp = a.dayNumber.compareTo(b.dayNumber);
      if (dayComp != 0) return dayComp;
      return a.createdAt.compareTo(b.createdAt);
    });
    return stops;
  }

  /// Persists journey stops for a trip locally.
  Future<void> saveJourneyStops(String tripId, List<JourneyStop> stops) async {
    await storage.saveJourneyStops(tripId, stops.map((s) => s.toJson()).toList());
  }

  /// Appends or updates a single journey stop.
  Future<void> addOrUpdateJourneyStop(String tripId, JourneyStop stop) async {
    final list = getCachedJourneyStops(tripId);
    list.removeWhere((s) => s.id == stop.id);
    list.add(stop);
    await saveJourneyStops(tripId, list);
  }

  /// Deletes a journey stop.
  Future<void> deleteJourneyStop(String tripId, String stopId) async {
    final list = getCachedJourneyStops(tripId);
    list.removeWhere((s) => s.id == stopId);
    await saveJourneyStops(tripId, list);
  }

  /// Synchronously returns cached memories for a trip.
  List<TripMemory> getCachedTripMemories(String tripId) {
    final raw = storage.getSavedTripMemories(tripId);
    final memories = raw.map((json) => TripMemory.fromJson(json)).toList();
    memories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return memories;
  }

  /// Persists memories for a trip locally.
  Future<void> saveTripMemories(String tripId, List<TripMemory> memories) async {
    await storage.saveTripMemories(tripId, memories.map((m) => m.toJson()).toList());
  }

  /// Appends or updates a single memory.
  Future<void> addOrUpdateTripMemory(String tripId, TripMemory memory) async {
    final list = getCachedTripMemories(tripId);
    list.removeWhere((m) => m.id == memory.id);
    list.insert(0, memory);
    await saveTripMemories(tripId, list);
  }

  /// Deletes a memory.
  Future<void> deleteTripMemory(String tripId, String memoryId) async {
    final list = getCachedTripMemories(tripId);
    list.removeWhere((m) => m.id == memoryId);
    await saveTripMemories(tripId, list);
  }

  /// Synchronously returns cached journey moments for a trip.
  List<JourneyMoment> getCachedJourneyMoments(String tripId) {
    final raw = storage.getSavedJourneyMoments(tripId);
    final moments = raw.map((json) => JourneyMoment.fromJson(json)).toList();
    moments.sort((a, b) {
      final dayComp = a.dayIndex.compareTo(b.dayIndex);
      if (dayComp != 0) return dayComp;
      return a.occurredAt.compareTo(b.occurredAt);
    });
    return moments;
  }

  /// Persists journey moments for a trip locally.
  Future<void> saveJourneyMoments(String tripId, List<JourneyMoment> moments) async {
    await storage.saveJourneyMoments(tripId, moments.map((m) => m.toJson()).toList());
  }

  /// Fetches journey moments from the backend with local fallback.
  Future<List<JourneyMoment>> getJourneyMoments(String tripId) async {
    try {
      final res = await apiClient.get('/trips/$tripId/moments');
      if (res is List) {
        final moments = res.map((m) => JourneyMoment.fromJson(m as Map<String, dynamic>)).toList();
        await saveJourneyMoments(tripId, moments);
        return moments;
      }
    } catch (_) {
      // Offline fallback
    }
    return getCachedJourneyMoments(tripId);
  }

  /// Appends or updates a single journey moment with offline queueing.
  Future<void> addOrUpdateJourneyMoment(String tripId, JourneyMoment moment) async {
    final list = getCachedJourneyMoments(tripId);
    list.removeWhere((m) => m.id == moment.id);
    list.add(moment);
    await saveJourneyMoments(tripId, list);

    await syncService.enqueueMutation(
      MutationType.createJourneyMoment,
      {'tripId': tripId, 'moment': moment.toJson()},
      idempotencyKey: moment.id,
      backgroundApiClient: apiClient,
    );
  }

  /// Deletes a journey moment with offline queueing.
  Future<void> deleteJourneyMoment(String tripId, String momentId) async {
    final list = getCachedJourneyMoments(tripId);
    list.removeWhere((m) => m.id == momentId);
    await saveJourneyMoments(tripId, list);

    await syncService.enqueueMutation(
      MutationType.deleteJourneyMoment,
      {'tripId': tripId, 'momentId': momentId},
      idempotencyKey: 'del_mom_$momentId',
      backgroundApiClient: apiClient,
    );
  }


  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
