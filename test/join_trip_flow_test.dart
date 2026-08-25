import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/presentation/viewmodels/join_trip_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;

  final testUserA = GuestUser(
    id: 'usr_alice_123',
    displayName: 'Alice Creator',
    recoveryKey: 'KITH-AAAA-BBBB',
    anonymousToken: 'kith_sess_alice_token',
    createdAt: DateTime.now(),
    isLinkedToAccount: true,
  );

  final testUserB = GuestUser(
    id: 'usr_bob_456',
    displayName: 'Bob Joiner',
    recoveryKey: 'KITH-CCCC-DDDD',
    anonymousToken: 'kith_sess_bob_token',
    createdAt: DateTime.now(),
    isLinkedToAccount: true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
  });

  group('TripRepository & JoinTripViewModel Cross-Account Flow Tests', () {
    test('1. createTrip preserves deterministic ID and inviteCode in payload and cache', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/trips' && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['id'], startsWith('trip_'));
          expect(body['inviteCode'], isNotEmpty);
          expect(body['name'], 'Manali Trip');

          return http.Response(
            jsonEncode({
              'data': {
                'id': body['id'],
                'name': body['name'],
                'creatorId': testUserA.id,
                'inviteCode': body['inviteCode'],
                'emoji': '🏔️',
                'coverGradientIndex': 0,
                'currencyCode': 'INR',
                'tripMode': 'split_only',
                'lifecycleState': 'active',
                'members': [
                  {
                    'id': 'mbr_alice',
                    'userId': testUserA.id,
                    'displayName': testUserA.displayName,
                    'role': 'creator',
                    'joinedAt': DateTime.now().toIso8601String(),
                  }
                ],
                'createdAt': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              }
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final tripRepo = TripRepository(
        storage: storage,
        apiClient: apiClient,
        syncService: syncService,
      );

      final trip = await tripRepo.createTrip(
        name: 'Manali Trip',
        emoji: '🏔️',
        creator: testUserA,
      );

      expect(trip.name, 'Manali Trip');
      expect(trip.creatorId, testUserA.id);
      expect(trip.inviteCode.length, 6);

      // Verify cached trip
      final cached = tripRepo.getCachedTrips();
      expect(cached.length, 1);
      expect(cached.first.id, trip.id);
      expect(cached.first.inviteCode, trip.inviteCode);
    });

    test('2. joinTrip successfully joins trip with normalized invite code', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/trips/join' && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['inviteCode'], 'GOA123');
          expect(request.headers['Authorization'], 'Bearer kith_sess_bob_token');

          return http.Response(
            jsonEncode({
              'data': {
                'id': 'trip_goa_999',
                'name': 'Goa Beach',
                'creatorId': testUserA.id,
                'inviteCode': 'GOA123',
                'emoji': '🏖️',
                'coverGradientIndex': 1,
                'currencyCode': 'INR',
                'tripMode': 'split_only',
                'lifecycleState': 'active',
                'members': [
                  {
                    'id': 'mbr_alice',
                    'userId': testUserA.id,
                    'displayName': testUserA.displayName,
                    'role': 'creator',
                    'joinedAt': DateTime.now().toIso8601String(),
                  },
                  {
                    'id': 'mbr_bob',
                    'userId': testUserB.id,
                    'displayName': testUserB.displayName,
                    'role': 'member',
                    'joinedAt': DateTime.now().toIso8601String(),
                  },
                ],
                'createdAt': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final tripRepo = TripRepository(
        storage: storage,
        apiClient: apiClient,
        syncService: syncService,
      );

      final joinVm = JoinTripViewModel(tripRepo: tripRepo);
      joinVm.setCode('  goa-123  ');

      final joined = await joinVm.joinTrip(testUserB);

      expect(joined, isNotNull);
      expect(joined!.id, 'trip_goa_999');
      expect(joined.members.length, 2);
      expect(joined.members.any((m) => m.userId == testUserB.id), isTrue);
      expect(joinVm.errorMessage, isNull);
    });

    test('3. joinTrip surfaces clear error when invite code does not exist', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'NOT_FOUND',
              'message': 'No trip found for invite code "XYZ999". Check the code and try again.',
            }
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final tripRepo = TripRepository(
        storage: storage,
        apiClient: apiClient,
        syncService: syncService,
      );

      final joinVm = JoinTripViewModel(tripRepo: tripRepo);
      joinVm.setCode('XYZ999');

      final joined = await joinVm.joinTrip(testUserB);

      expect(joined, isNull);
      expect(joinVm.errorMessage, contains('No trip found for invite code "XYZ999"'));
    });

    test('4. joinTrip locks re-entrancy to prevent rapid double-tap bugs', () async {
      int apiCallCount = 0;
      final mockClient = MockClient((request) async {
        apiCallCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'trip_race_01',
              'name': 'Race Trip',
              'creatorId': testUserA.id,
              'inviteCode': 'RACE01',
              'emoji': '🏎️',
              'coverGradientIndex': 0,
              'currencyCode': 'INR',
              'tripMode': 'split_only',
              'lifecycleState': 'active',
              'members': [],
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final tripRepo = TripRepository(
        storage: storage,
        apiClient: apiClient,
        syncService: syncService,
      );

      final joinVm = JoinTripViewModel(tripRepo: tripRepo);
      joinVm.setCode('RACE01');

      // Fire two join requests simultaneously
      final future1 = joinVm.joinTrip(testUserB);
      final future2 = joinVm.joinTrip(testUserB);

      final results = await Future.wait<Trip?>([future1, future2]);

      // Exactly one should execute the network call and return the trip; the second is locked
      expect(apiCallCount, 1);
      expect(results.where((r) => r != null).length, 1);
    });
  });
}
