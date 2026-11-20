import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/trip_completion_models.dart';
import 'package:kith_app/domain/models/trip_sync_status.dart';

void main() {
  group('Smart Trip Completion & Member Consent Domain & Repository Tests', () {
    test('1. TripCompletionRequest JSON serialization and status mapping', () {
      final now = DateTime.now();
      final expires = now.add(const Duration(hours: 24));
      final json = {
        'id': 'tcr_test123',
        'tripId': 'trip_goa_001',
        'memberId': 'mbr_alice',
        'userId': 'usr_alice',
        'requestedBy': 'usr_owner',
        'status': 'CONFIRMED_AVAILABLE',
        'response': 'YES',
        'responseNote': 'Ready to finalize',
        'createdAt': now.toIso8601String(),
        'expiresAt': expires.toIso8601String(),
        'respondedAt': now.toIso8601String(),
        'version': 2,
      };

      final req = TripCompletionRequest.fromJson(json);
      expect(req.id, 'tcr_test123');
      expect(req.tripId, 'trip_goa_001');
      expect(req.status, MemberConsentStatus.confirmedAvailable);
      expect(req.isConfirmed, isTrue);
      expect(req.isPending, isFalse);
      expect(req.isUnavailable, isFalse);
      expect(req.response, 'YES');
      expect(req.responseNote, 'Ready to finalize');
      expect(req.version, 2);

      final outJson = req.toJson();
      expect(outJson['status'], 'confirmedAvailable');
      expect(outJson['response'], 'YES');
    });

    test('2. TripReopeningRequest JSON serialization and status evaluation', () {
      final now = DateTime.now();
      final json = {
        'id': 'trr_reopen999',
        'tripId': 'trip_goa_001',
        'requestedBy': 'usr_bob',
        'reasonCategory': 'MISSING_EXPENSE',
        'note': 'Forgot return bus ticket',
        'status': 'PENDING',
        'createdAt': now.toIso8601String(),
      };

      final req = TripReopeningRequest.fromJson(json);
      expect(req.id, 'trr_reopen999');
      expect(req.isPending, isTrue);
      expect(req.isApproved, isFalse);
      expect(req.isRejected, isFalse);
      expect(req.reasonCategory, 'MISSING_EXPENSE');
      expect(req.note, 'Forgot return bus ticket');
    });

    test('3. TripLifecycleHistoryEntry parsing', () {
      final now = DateTime.now();
      final json = {
        'id': 'tlh_hist123',
        'tripId': 'trip_goa_001',
        'previousStatus': 'active',
        'newStatus': 'completing',
        'changedBy': 'usr_owner',
        'reason': 'Owner initiated completion verification',
        'relatedRequestId': 'tcr_test123',
        'createdAt': now.toIso8601String(),
      };

      final entry = TripLifecycleHistoryEntry.fromJson(json);
      expect(entry.id, 'tlh_hist123');
      expect(entry.previousStatus, 'active');
      expect(entry.newStatus, 'completing');
      expect(entry.relatedRequestId, 'tcr_test123');
    });

    test('4. ParticipantSyncInfo authoritative presence and consent badge evaluation', () {
      final json = {
        'memberId': 'mbr_charlie',
        'userId': 'usr_charlie',
        'displayName': 'Charlie',
        'isCreator': false,
        'isCurrentUser': false,
        'isVirtual': false,
        'isOnline': false,
        'syncStatus': 'offline',
        'presenceStatus': 'OFFLINE',
        'consentStatus': 'CONFIRMED_AVAILABLE',
        'lastSyncFormatted': '2h ago',
      };

      final p = ParticipantSyncInfo.fromJson(json);
      expect(p.presenceStatus, 'OFFLINE');
      expect(p.consentStatus, 'CONFIRMED_AVAILABLE');
      expect(p.isConsentConfirmed, isTrue);
      expect(p.isConsentRejected, isFalse);
      expect(p.isConsentPending, isFalse);
    });

    test('5. TripSyncStatus evaluates blocked status when member rejects completion', () {
      final json = {
        'tripId': 'trip_goa_001',
        'tripName': 'Goa Beach Trip',
        'currentRevision': 3,
        'lifecycleState': 'active',
        'isFullySynced': true,
        'canCompleteNormally': false,
        'isCompletionBlocked': true,
        'blockReason': 'Completion blocked by Charlie',
        'totalParticipants': 2,
        'syncedParticipantsCount': 2,
        'unsyncedParticipantsCount': 0,
        'participants': [
          {
            'memberId': 'mbr_owner',
            'userId': 'usr_owner',
            'displayName': 'Darpan',
            'isCreator': true,
            'isCurrentUser': true,
            'isVirtual': false,
            'isOnline': true,
            'syncStatus': 'synced',
            'presenceStatus': 'ONLINE',
            'consentStatus': 'NONE',
          },
          {
            'memberId': 'mbr_charlie',
            'userId': 'usr_charlie',
            'displayName': 'Charlie',
            'isCreator': false,
            'isCurrentUser': false,
            'isVirtual': false,
            'isOnline': false,
            'syncStatus': 'synced',
            'presenceStatus': 'OFFLINE',
            'consentStatus': 'UNAVAILABLE',
            'consentResponseNote': 'Pending dinner bill',
          },
        ],
      };

      final status = TripSyncStatus.fromJson(json);
      expect(status.isFullySynced, isTrue);
      expect(status.canCompleteNormally, isFalse);
      expect(status.isCompletionBlocked, isTrue);
      expect(status.blockReason, 'Completion blocked by Charlie');
      expect(status.participants.length, 2);
      expect(status.participants[1].isConsentRejected, isTrue);
    });

    test('6. TripRepository completeTrip strictly rejects when owner is offline', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dbService = LocalDatabaseService.inMemory();
      final storage = LocalStorageService(prefs, databaseService: dbService);
      final syncService = SyncService(storage);
      final apiClient = ApiClient();
      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );

      // Attempting completion with isOwnerOnline = false must throw NetworkException
      expect(
        () => tripRepo.completeTrip(
          tripId: 'trip_fake_123',
          completionMode: 'NORMAL',
          isOwnerOnline: false,
        ),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains("You're currently offline. Connect to the internet before completing this trip."),
          ),
        ),
      );
    });
  });
}
