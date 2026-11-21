import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline-First Architecture & Causal Dependency Tests', () {
    late LocalDatabaseService dbService;
    late LocalStorageService storage;
    late SyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalDatabaseService.resetStaticInstance();
      dbService = LocalDatabaseService.inMemory();
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs, databaseService: dbService);
      syncService = SyncService(storage);
    });

    test('Automatic causal dependency resolution orders mutations correctly', () async {
      const tripId = 'trip_offline_100';
      const expenseId = 'exp_offline_200';

      // 1. Create trip offline
      final tripMutation = await syncService.enqueueMutation(
        MutationType.createTrip,
        {'id': tripId, 'name': 'Himalayan Expedition', 'creatorId': 'u_creator'},
        idempotencyKey: tripId,
      );
      expect(tripMutation.dependsOn, isEmpty);

      // 2. Add member offline (depends on trip creation)
      final memberMutation = await syncService.enqueueMutation(
        MutationType.addMember,
        {'tripId': tripId, 'displayName': 'Rahul', 'id': 'm_rahul'},
        idempotencyKey: 'add_mbr_m_rahul',
      );
      expect(memberMutation.dependsOn, contains(tripMutation.id));

      // 3. Add expense offline (depends on trip creation AND member addition)
      final addExpenseMutation = await syncService.enqueueMutation(
        MutationType.addExpense,
        {
          'id': expenseId,
          'tripId': tripId,
          'title': 'Rafting Gear',
          'amountInPaise': 450000,
          'paidById': 'u_creator',
          'splits': [
            {'memberId': 'u_creator', 'amountInPaise': 225000},
            {'memberId': 'm_rahul', 'amountInPaise': 225000},
          ],
        },
        idempotencyKey: expenseId,
      );
      expect(addExpenseMutation.dependsOn, contains(tripMutation.id));
      expect(addExpenseMutation.dependsOn, contains(memberMutation.id));

      // 4. Update expense offline (depends on addExpense mutation)
      final updateExpenseMutation = await syncService.enqueueMutation(
        MutationType.updateExpense,
        {
          'id': expenseId,
          'tripId': tripId,
          'title': 'Rafting Gear & Helmets',
          'amountInPaise': 500000,
        },
        idempotencyKey: expenseId,
      );
      expect(updateExpenseMutation.dependsOn, contains(addExpenseMutation.id));

      // 5. Complete trip offline (depends on ALL preceding mutations for this trip)
      final completeTripMutation = await syncService.enqueueMutation(
        MutationType.updateTripLifecycle,
        {'tripId': tripId, 'lifecycleState': 'completed'},
        idempotencyKey: 'complete_$tripId',
      );
      expect(completeTripMutation.dependsOn, contains(tripMutation.id));
      expect(completeTripMutation.dependsOn, contains(memberMutation.id));
      expect(completeTripMutation.dependsOn, contains(addExpenseMutation.id));
      expect(completeTripMutation.dependsOn, contains(updateExpenseMutation.id));
    });

    test('Queue persistence and retry state transitions survive query cycles', () async {
      final mut = await syncService.enqueueMutation(
        MutationType.createPersonalExpense,
        {'title': 'Coffee', 'amount': 150.0},
      );
      expect(mut.syncState, SyncState.localPending);
      expect(syncService.pendingMutationCount, 1);

      // Mark P2P shared
      await syncService.markMutationP2PShared(mut.id);
      final updated = syncService.getAllMutations().firstWhere((m) => m.id == mut.id);
      expect(updated.syncState, SyncState.p2pShared);

      // Retry quarantined mutations resets back to localPending
      await syncService.retryQuarantinedMutations(ApiClient());
      final reset = syncService.getAllMutations().firstWhere((m) => m.id == mut.id);
      expect(reset.syncState, SyncState.p2pShared); // Not quarantined, untouched
    });
  });
}
