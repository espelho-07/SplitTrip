import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/models/trip_sync_status.dart';

void main() {
  group('Trip & Participant Sync Status Domain Models', () {
    test('1. TripSyncStatus and ParticipantSyncInfo JSON Serialization', () {
      final json = {
        'tripId': 'trip_123',
        'tripName': 'Manali Road Trip',
        'currentRevision': 5,
        'lifecycleState': 'active',
        'isFullySynced': true,
        'canCompleteNormally': true,
        'totalParticipants': 2,
        'syncedParticipantsCount': 2,
        'unsyncedParticipantsCount': 0,
        'participants': [
          {
            'memberId': 'mem_1',
            'userId': 'usr_1',
            'displayName': 'Darpan',
            'isCreator': true,
            'isCurrentUser': true,
            'isOnline': true,
            'syncStatus': 'synced',
            'acknowledgedRevision': 5,
            'pendingCount': 0,
            'lastSeenAt': '2026-08-29T10:00:00.000Z',
            'lastSyncFormatted': 'Just now',
          },
          {
            'memberId': 'mem_2',
            'userId': 'usr_2',
            'displayName': 'Rahul',
            'isCreator': false,
            'isCurrentUser': false,
            'isOnline': true,
            'syncStatus': 'synced',
            'acknowledgedRevision': 5,
            'pendingCount': 0,
            'lastSeenAt': '2026-08-29T10:00:00.000Z',
            'lastSyncFormatted': 'Just now',
          },
        ],
      };

      final status = TripSyncStatus.fromJson(json);
      expect(status.tripId, 'trip_123');
      expect(status.currentRevision, 5);
      expect(status.isFullySynced, true);
      expect(status.canCompleteNormally, true);
      expect(status.totalParticipants, 2);
      expect(status.participants.length, 2);

      final p1 = status.participants.first;
      expect(p1.displayName, 'Darpan');
      expect(p1.isCurrentUser, true);
      expect(p1.isSynced, true);
      expect(p1.syncStatus, ParticipantSyncState.synced);
    });

    test('2. Unsynced / Offline participant flags and completion conditions', () {
      final json = {
        'tripId': 'trip_456',
        'tripName': 'Goa Vacation',
        'currentRevision': 8,
        'lifecycleState': 'active',
        'isFullySynced': false,
        'canCompleteNormally': false,
        'totalParticipants': 3,
        'syncedParticipantsCount': 1,
        'unsyncedParticipantsCount': 2,
        'participants': [
          {
            'memberId': 'mem_1',
            'userId': 'usr_1',
            'displayName': 'Alice',
            'isCurrentUser': true,
            'isOnline': true,
            'syncStatus': 'synced',
            'acknowledgedRevision': 8,
            'pendingCount': 0,
          },
          {
            'memberId': 'mem_2',
            'userId': 'usr_2',
            'displayName': 'Bob',
            'isCurrentUser': false,
            'isOnline': false,
            'syncStatus': 'offline',
            'acknowledgedRevision': 6,
            'pendingCount': 2,
            'lastSyncFormatted': '2 hours ago',
          },
        ],
      };

      final status = TripSyncStatus.fromJson(json);
      expect(status.isFullySynced, false);
      expect(status.canCompleteNormally, false);
      expect(status.unsyncedParticipantsCount, 2);

      final bob = status.participants[1];
      expect(bob.displayName, 'Bob');
      expect(bob.syncStatus, ParticipantSyncState.offline);
      expect(bob.isSynced, false);
      expect(bob.pendingCount, 2);
      expect(bob.lastSyncFormatted, '2 hours ago');
    });

    test('3. TripLifecycle transitions and string conversions', () {
      expect(TripLifecycle.fromString('active'), TripLifecycle.active);
      expect(TripLifecycle.fromString('completed'), TripLifecycle.completed);
      expect(TripLifecycle.fromString('completed_with_pending_changes'), TripLifecycle.completedWithPendingChanges);
      expect(TripLifecycle.fromString('completing'), TripLifecycle.completing);

      expect(TripLifecycle.completed.isCompleted, true);
      expect(TripLifecycle.completedWithPendingChanges.isCompleted, true);
      expect(TripLifecycle.active.isCompleted, false);
      expect(TripLifecycle.active.allowsExpenses, true);
      expect(TripLifecycle.completed.allowsExpenses, false);
    });

    test('4. Trip revision and completionMode roundtrip JSON serialization', () {
      final trip = Trip(
        id: 'trip_rev_1',
        name: 'Kerala Backwaters',
        creatorId: 'usr_1',
        members: [
          TripMember(
            id: 'mem_1',
            userId: 'usr_1',
            displayName: 'Darpan',
            joinedAt: DateTime(2026, 8, 29),
            lastSyncedRevision: 12,
            pendingMutationsCount: 0,
          ),
        ],
        inviteCode: 'KBW123',
        revision: 12,
        completionMode: 'forced_with_pending_sync',
        completedAt: DateTime(2026, 8, 29, 12, 0),
        completedBy: 'usr_1',
        lifecycleState: TripLifecycle.completedWithPendingChanges,
        createdAt: DateTime(2026, 8, 29),
        updatedAt: DateTime(2026, 8, 29),
      );

      final serialized = trip.toJson();
      expect(serialized['revision'], 12);
      expect(serialized['completionMode'], 'forced_with_pending_sync');
      expect(serialized['completedBy'], 'usr_1');

      final deserialized = Trip.fromJson(serialized);
      expect(deserialized.id, 'trip_rev_1');
      expect(deserialized.revision, 12);
      expect(deserialized.completionMode, 'forced_with_pending_sync');
      expect(deserialized.completedBy, 'usr_1');
      expect(deserialized.lifecycleState, TripLifecycle.completedWithPendingChanges);
      expect(deserialized.members.first.lastSyncedRevision, 12);
    });
  });
}
