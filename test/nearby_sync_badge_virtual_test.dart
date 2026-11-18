import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/p2p_sync_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/views/trip/widgets/nearby_sync_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late P2PSyncService p2pService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
    p2pService = P2PSyncService(storage, syncService, deviceId: 'test_dev');
  });

  testWidgets('NearbySyncBadge returns SizedBox.shrink() when all members are virtual even with pending mutations', (tester) async {
    final virtualTrip = Trip(
      id: 'trip_virtual_01',
      name: 'Goa Beach Trip',
      creatorId: 'user_creator',
      inviteCode: 'GOA123',
      members: [
        TripMember(
          id: 'm1',
          userId: 'user_creator',
          displayName: 'Darpan',
          role: 'creator',
          joinedAt: DateTime.now(),
        ),
        TripMember(
          id: 'm2',
          userId: 'unclaimed_01',
          displayName: 'Rahul',
          role: 'member',
          isVirtualMember: true,
          isClaimed: false,
          joinedAt: DateTime.now(),
        ),
        TripMember(
          id: 'm3',
          userId: 'unclaimed_02',
          displayName: 'T',
          role: 'member',
          isVirtualMember: true,
          isClaimed: false,
          joinedAt: DateTime.now(),
        ),
      ],
      lifecycleState: TripLifecycle.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Enqueue 2 pending mutations for this trip
    await syncService.enqueueMutation(MutationType.addMember, {'tripId': 'trip_virtual_01', 'id': 'm2'});
    await syncService.enqueueMutation(MutationType.addExpense, {'tripId': 'trip_virtual_01', 'id': 'exp_1'});

    expect(syncService.getPendingMutationsForTrip('trip_virtual_01').length, 2);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NearbySyncBadge(
            p2pService: p2pService,
            syncService: syncService,
            tripId: 'trip_virtual_01',
            trip: virtualTrip,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Since all other members are virtual and peerCount is 0, no "pending offline" badge is shown
    expect(find.textContaining('pending offline'), findsNothing);
  });

  testWidgets('NearbySyncBadge shows pending offline badge when a real registered member is in the trip', (tester) async {
    final realTrip = Trip(
      id: 'trip_real_01',
      name: 'Goa Friends Trip',
      creatorId: 'user_creator',
      inviteCode: 'GOA456',
      members: [
        TripMember(
          id: 'm1',
          userId: 'user_creator',
          displayName: 'Darpan',
          role: 'creator',
          joinedAt: DateTime.now(),
        ),
        TripMember(
          id: 'm2',
          userId: 'user_real_friend',
          displayName: 'Aakash',
          role: 'member',
          isVirtualMember: false,
          isClaimed: true,
          joinedAt: DateTime.now(),
        ),
      ],
      lifecycleState: TripLifecycle.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await syncService.enqueueMutation(MutationType.addExpense, {'tripId': 'trip_real_01', 'id': 'exp_2'});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NearbySyncBadge(
            p2pService: p2pService,
            syncService: syncService,
            tripId: 'trip_real_01',
            trip: realTrip,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 pending offline'), findsOneWidget);
  });
}
