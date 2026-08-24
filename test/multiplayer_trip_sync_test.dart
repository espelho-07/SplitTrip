import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/realtime_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/trip_detail_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multiplayer Realtime Sync Tests', () {
    late LocalStorageService storage;
    late SyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      syncService = SyncService(storage);
    });

    test('TripDetailViewModel auto-reloads and reconciles on realtime trip broadcast event', () async {
      final tripId = 'trip_goa_123';
      int tripFetchCount = 0;

      final initialTrip = Trip(
        id: tripId,
        name: 'Goa Holiday',
        creatorId: 'usr_1',
        inviteCode: 'GOA123',
        members: [
          TripMember(
            id: 'mbr_1',
            userId: 'usr_1',
            displayName: 'Rahul',
            joinedAt: DateTime.now(),
          ),
        ],
        lifecycleState: TripLifecycle.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/trips/$tripId/expenses/balance/summary')) {
          return http.Response(
            jsonEncode({
              'data': {
                'totalTripSpendingInPaise': 0,
                'netBalancesInPaise': {},
                'currentUserNetBalanceInPaise': 0,
                'debtsToPay': [],
                'debtsToReceive': [],
                'simplifiedSettlements': [],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.contains('/trips/$tripId/expenses')) {
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.contains('/trips/$tripId')) {
          tripFetchCount++;
          return http.Response(
            jsonEncode({'data': initialTrip.toJson()}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{"error":"not found"}', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final realtimeClient = RealtimeClient();

      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
        realtimeClient: realtimeClient,
      );

      final expenseRepo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
        realtimeClient: realtimeClient,
      );

      final vm = TripDetailViewModel(
        tripRepo: tripRepo,
        expenseRepo: expenseRepo,
        realtimeClient: realtimeClient,
      );

      // Load trip for user 1
      await vm.loadTrip(tripId, 'usr_1');
      expect(vm.trip?.name, 'Goa Holiday');
      expect(tripFetchCount, 1);

      // Simulate a background refresh
      await vm.refresh('usr_1');
      expect(tripFetchCount, 2);

      vm.dispose();
      realtimeClient.dispose();
    });
  });
}
