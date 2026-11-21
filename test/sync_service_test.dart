import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    syncService = SyncService(storage);
  });

  group('SyncService Tests', () {
    test('Enqueues mutations and persists them to storage', () async {
      await syncService.enqueueMutation(MutationType.addExpense, {
        'tripId': 'trip_100',
        'title': 'Dinner',
        'amountInPaise': 50000,
      });

      final pending = syncService.getPendingMutations();
      expect(pending.length, 1);
      expect(pending.first.type, MutationType.addExpense);
      expect(pending.first.payload['title'], 'Dinner');
    });

    test('Flushes queue against ApiClient and clears completed mutations', () async {
      final processedRequests = <String>[];

      final mockClient = MockClient((request) async {
        processedRequests.add(request.url.path);
        return http.Response(
          jsonEncode({
            'data': {'success': true}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);

      await syncService.enqueueMutation(MutationType.createTrip, {'name': 'Goa'});
      await syncService.enqueueMutation(MutationType.addExpense, {'tripId': 't1', 'title': 'Fuel'});

      expect(syncService.getPendingMutations().length, 2);

      await syncService.flushQueue(apiClient);

      expect(syncService.getPendingMutations().length, 0);
      expect(processedRequests.length, 2);
      expect(processedRequests.any((p) => p.contains('/trips')), isTrue);
    });

    test('Quarantined mutations do not count toward pendingMutationCount and do not cause infinite pending loop', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': {'success': true}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final apiClient = ApiClient(httpClient: mockClient);

      // Enqueue a mutation
      await syncService.enqueueMutation(MutationType.addExpense, {
        'tripId': 'trip_100',
        'title': 'Train',
        'amountInPaise': 181600,
      });

      expect(syncService.pendingMutationCount, 1);
      expect(syncService.quarantinedCount, 0);

      // Quarantining the mutation directly simulates max retries or divergence
      final rawQueue = syncService.getAllMutations();
      rawQueue[0] = rawQueue[0].copyWith(syncState: SyncState.quarantined, retryCount: 5);
      await storage.saveMutationQueue(rawQueue.map((m) => m.toJson()).toList());

      // pendingMutationCount MUST be 0 now!
      expect(syncService.pendingMutationCount, 0);
      expect(syncService.quarantinedCount, 1);

      // Status updates observed during flushQueue
      final emittedStatuses = <SyncStatus>[];
      final sub = syncService.statusStream.listen(emittedStatuses.add);

      // flushQueue should NOT set syncing, and should transition to error with clear explanation
      await syncService.flushQueue(apiClient);

      expect(emittedStatuses.contains(SyncStatus.syncing), isFalse,
          reason: 'flushQueue must not flash SyncStatus.syncing when no actionable mutations exist');
      expect(syncService.currentStatus, SyncStatus.error);
      expect(syncService.lastErrorMessage, contains('could not be synced'));

      // Tapping retry unquarantines and flushes successfully
      await syncService.retryQuarantinedMutations(apiClient);
      expect(syncService.pendingMutationCount, 0);
      expect(syncService.quarantinedCount, 0);
      expect(syncService.currentStatus, SyncStatus.synced);

      await sub.cancel();
    });

    test('flushQueue with empty queue immediately resolves to SyncStatus.synced without flashing syncing', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'data': {}}), 200);
      });
      final apiClient = ApiClient(httpClient: mockClient);

      final emittedStatuses = <SyncStatus>[];
      final sub = syncService.statusStream.listen(emittedStatuses.add);

      await syncService.flushQueue(apiClient);

      expect(emittedStatuses.contains(SyncStatus.syncing), isFalse);
      expect(syncService.currentStatus, SyncStatus.synced);
      await sub.cancel();
    });

    test('clearQuarantinedMutations purges quarantined items and resets status cleanly', () async {
      await syncService.enqueueMutation(MutationType.addExpense, {
        'tripId': 'trip_100',
        'title': 'Stuck Expense',
      });
      final rawQueue = syncService.getAllMutations();
      rawQueue[0] = rawQueue[0].copyWith(syncState: SyncState.quarantined);
      await storage.saveMutationQueue(rawQueue.map((m) => m.toJson()).toList());

      expect(syncService.quarantinedCount, 1);
      expect(syncService.pendingMutationCount, 0);

      await syncService.clearQuarantinedMutations();

      expect(syncService.quarantinedCount, 0);
      expect(syncService.pendingMutationCount, 0);
      expect(syncService.currentStatus, SyncStatus.synced);
    });

    test('flushQueue auto-adopts device mutations from old guest session to active user', () async {
      // 1. Setup an active logged in user
      await storage.saveUser({
        'id': 'usr_active_canonical',
        'accountId': 'usr_active_canonical',
        'displayName': 'Darpan',
        'anonymousToken': 'valid_token_123',
      });

      // 2. Enqueue mutation with old guest ID
      await syncService.enqueueMutation(
        MutationType.addExpense,
        {'tripId': 'trip_manali', 'title': 'Trek Guide'},
        userId: 'usr_old_guest_id',
      );

      final processedRequests = <String>[];
      final mockClient = MockClient((request) async {
        processedRequests.add(request.url.path);
        return http.Response(jsonEncode({'data': {'id': 'exp_123'}}), 200);
      });
      final apiClient = ApiClient(httpClient: mockClient);

      expect(syncService.pendingMutationCount, 1);

      // 3. flushQueue should auto-adopt the mutation and flush it cleanly
      await syncService.flushQueue(apiClient);

      expect(syncService.pendingMutationCount, 0);
      expect(processedRequests.length, 1);
      expect(processedRequests.first, contains('/trips/trip_manali/expenses'));
      expect(syncService.currentStatus, SyncStatus.synced);
    });

    test('flushQueue(force: true) when server fails transitions to SyncStatus.error and does NOT get stuck in pending', () async {
      await storage.saveUser({
        'id': 'usr_active_canonical',
        'displayName': 'Darpan',
        'anonymousToken': 'token_xyz',
      });

      await syncService.enqueueMutation(MutationType.createTrip, {
        'id': 'trip_manali',
        'name': 'Manali Trek',
      });

      // Server returns 400 Bad Request
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': {'message': 'Trip name already exists on remote'}}),
          400,
        );
      });
      final apiClient = ApiClient(httpClient: mockClient);

      // Force flush (like tapping "Sync now")
      await syncService.flushQueue(apiClient, force: true);

      // Status must transition to SyncStatus.error so the user gets actionable Review/Dismiss UI
      expect(syncService.currentStatus, SyncStatus.error);
      expect(syncService.lastErrorMessage, contains('Trip name already exists'));
      expect(syncService.pendingMutationCount, 1);

      // User taps Dismiss to clear stuck mutation
      await syncService.clearAllPendingMutations();
      expect(syncService.pendingMutationCount, 0);
      expect(syncService.currentStatus, SyncStatus.synced);
    });
  });
}
