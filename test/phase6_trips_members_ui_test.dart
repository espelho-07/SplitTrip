import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/p2p_sync_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/trip_detail_viewmodel.dart';
import 'package:kith_app/presentation/views/trip/manage_members_view.dart';
import 'package:kith_app/presentation/views/trip/trip_detail_view.dart';
import 'package:kith_app/presentation/views/trip/trip_members_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late SyncService syncService;
  late P2PSyncService p2pService;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late AuthViewModel authVm;
  late HomeViewModel homeVm;
  late TripDetailViewModel tripDetailVm;
  late GuestUser testUser;
  late Trip sampleTrip;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    apiClient = ApiClient();
    final authService = AuthService(apiClient: apiClient, storage: storage);
    final userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);
    syncService = SyncService(storage);
    p2pService = P2PSyncService(storage, syncService, deviceId: 'test_dev_01');
    tripRepo = TripRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    expenseRepo = ExpenseRepository(
      storage: storage,
      syncService: syncService,
      apiClient: apiClient,
    );
    homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);

    testUser = GuestUser(
      id: 'usr_creator_01',
      displayName: 'Darpan Creator',
      recoveryKey: 'KITH-TEST-1234',
      anonymousToken: 'anon_tok_123',
      createdAt: DateTime.now(),
    );

    await storage.saveUser(testUser.toJson());
    await authVm.initSession();

    sampleTrip = Trip(
      id: 'trip_goa_001',
      name: 'Goa Weekend Trip',
      creatorId: 'usr_creator_01',
      inviteCode: 'GOA123',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now(),
      members: [
        // 1. Creator (KITH Member)
        TripMember(
          id: 'mem_01',
          userId: 'usr_creator_01',
          displayName: 'Darpan Creator',
          role: 'creator',
          joinedAt: DateTime.now(),
          isClaimed: true,
          isVirtualMember: false,
          status: 'claimed',
        ),
        // 2. Verified KITH Member
        TripMember(
          id: 'mem_02',
          userId: 'usr_alice_02',
          displayName: 'Alice Singh',
          role: 'member',
          joinedAt: DateTime.now(),
          isClaimed: true,
          isVirtualMember: false,
          status: 'claimed',
        ),
        // 3. Virtual Participant 1 (Unclaimed)
        TripMember(
          id: 'mem_03',
          userId: 'unclaimed_bob_03',
          displayName: 'Bob Offline',
          role: 'member',
          joinedAt: DateTime.now(),
          isClaimed: false,
          isVirtualMember: true,
          status: 'unclaimed',
        ),
        // 4. Virtual Participant 2 (Unclaimed)
        TripMember(
          id: 'mem_04',
          userId: 'unclaimed_charlie_04',
          displayName: 'Charlie Placeholder',
          role: 'member',
          joinedAt: DateTime.now(),
          isClaimed: false,
          isVirtualMember: true,
          status: 'unclaimed',
        ),
      ],
    );

    await storage.saveTrips([sampleTrip.toJson()]);
    await tripRepo.getTrips();

    tripDetailVm = TripDetailViewModel(
      tripRepo: tripRepo,
      expenseRepo: expenseRepo,
    );
    await tripDetailVm.loadTrip(sampleTrip.id, testUser.id);
  });

  Widget buildTestApp({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
        ChangeNotifierProvider<HomeViewModel>.value(value: homeVm),
        ChangeNotifierProvider<TripDetailViewModel>.value(value: tripDetailVm),
        Provider<TripRepository>.value(value: tripRepo),
        Provider<ExpenseRepository>.value(value: expenseRepo),
        Provider<LocalStorageService>.value(value: storage),
        Provider<SyncService>.value(value: syncService),
        Provider<P2PSyncService>.value(value: p2pService),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: child,
      ),
    );
  }

  group('Phase 6 — Trips Section UI/UX and Participant Experience Tests', () {
    testWidgets('1. TripMembersView renders top summary banner with exact KITH vs Virtual counts', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const TripMembersView(tripId: 'trip_goa_001')));
      await tester.pumpAndSettle();

      // Top title
      expect(find.text('Trip Participants'), findsOneWidget);
      expect(find.text('Goa Weekend Trip'), findsOneWidget);

      // Summary subheader and breakdown chips
      expect(find.text('4 Participants • 2 KITH, 2 Virtual'), findsOneWidget);
      expect(find.text('2 KITH'), findsOneWidget);
      expect(find.text('Verified & Synced'), findsOneWidget);
      expect(find.text('2 Virtual'), findsOneWidget);
      expect(find.text('Offline • Unclaimed'), findsOneWidget);
    });

    testWidgets('2. TripMembersView segmented filter switches between All, KITH, and Virtual views', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const TripMembersView(tripId: 'trip_goa_001')));
      await tester.pumpAndSettle();

      // Filter tabs rendered
      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('KITH (2)'), findsOneWidget);
      expect(find.text('Virtual (2)'), findsOneWidget);

      // By default: 'All (4)' selected, all 4 members visible
      expect(find.text('Darpan Creator'), findsOneWidget);
      expect(find.text('Alice Singh'), findsOneWidget);
      expect(find.text('Bob Offline'), findsOneWidget);
      expect(find.text('Charlie Placeholder'), findsOneWidget);

      // Tap 'KITH (2)' tab
      await tester.tap(find.text('KITH (2)'));
      await tester.pumpAndSettle();

      // KITH members present, virtual members filtered out
      expect(find.text('Darpan Creator'), findsOneWidget);
      expect(find.text('Alice Singh'), findsOneWidget);
      expect(find.text('Bob Offline'), findsNothing);
      expect(find.text('Charlie Placeholder'), findsNothing);

      // Tap 'Virtual (2)' tab
      await tester.tap(find.text('Virtual (2)'));
      await tester.pumpAndSettle();

      // Virtual members present, KITH members filtered out
      expect(find.text('Darpan Creator'), findsNothing);
      expect(find.text('Alice Singh'), findsNothing);
      expect(find.text('Bob Offline'), findsOneWidget);
      expect(find.text('Charlie Placeholder'), findsOneWidget);

      // Tap back to 'All (4)'
      await tester.tap(find.text('All (4)'));
      await tester.pumpAndSettle();
      expect(find.text('Darpan Creator'), findsOneWidget);
      expect(find.text('Bob Offline'), findsOneWidget);
    });

    testWidgets('3. TripMembersView displays distinct KITH Member vs Virtual badges and share actions', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const TripMembersView(tripId: 'trip_goa_001')));
      await tester.pumpAndSettle();

      // Creator badge
      expect(find.text('Creator'), findsOneWidget);

      // KITH Member badge
      expect(find.text('KITH Member'), findsOneWidget);

      // Virtual badges on the 2 virtual members
      expect(find.text('Virtual'), findsNWidgets(2));

      // Virtual members have "Share Invite Code" action chip
      expect(find.text('Share Invite Code'), findsNWidgets(2));

      // Tap "Share Invite Code"
      await tester.tap(find.text('Share Invite Code').first);
      await tester.pumpAndSettle();

      // SnackBar shows copy notification
      expect(find.text('Claim link for Bob Offline copied! Share with them to claim. ✓'), findsOneWidget);
    });

    testWidgets('4. TripMembersView shows empty state when a category has zero members', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create trip with only KITH members (0 virtual)
      final allKithTrip = Trip(
        id: 'trip_kith_only',
        name: 'KITH Only Trip',
        creatorId: 'usr_creator_01',
        inviteCode: 'KITHONLY',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now(),
        members: [
          TripMember(
            id: 'mem_k1',
            userId: 'usr_creator_01',
            displayName: 'Darpan Creator',
            role: 'creator',
            joinedAt: DateTime.now(),
            isClaimed: true,
            isVirtualMember: false,
          ),
        ],
      );
      await storage.saveTrips([allKithTrip.toJson()]);
      tripRepo.invalidateCache();
      await tripRepo.getTrips();

      await tester.pumpWidget(buildTestApp(child: const TripMembersView(tripId: 'trip_kith_only')));
      await tester.pumpAndSettle();

      expect(find.text('Virtual (0)'), findsOneWidget);

      // Switch to Virtual tab
      await tester.tap(find.text('Virtual (0)'));
      await tester.pumpAndSettle();

      expect(
        find.text('No virtual participants in this trip.\nAll participants have joined with active KITH accounts!'),
        findsOneWidget,
      );
    });

    testWidgets('5. ManageMembersView organizes participants into KITH MEMBERS and VIRTUAL PARTICIPANTS sections', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const ManageMembersView(tripId: 'trip_goa_001')));
      await tester.pumpAndSettle();

      // Top title
      expect(find.text('Manage Members'), findsOneWidget);

      // Banner summary
      expect(find.textContaining('2 KITH Members • 2 Virtual Participants'), findsOneWidget);

      // Section 1: KITH MEMBERS
      expect(find.text('KITH MEMBERS (2)'), findsOneWidget);
      expect(find.text('Darpan Creator'), findsOneWidget);
      expect(find.text('Alice Singh'), findsOneWidget);

      // Section 2: VIRTUAL PARTICIPANTS
      expect(find.text('VIRTUAL PARTICIPANTS (2)'), findsOneWidget);
      expect(find.text('Bob Offline'), findsOneWidget);
      expect(find.text('Charlie Placeholder'), findsOneWidget);

      // Virtual participant actions
      expect(find.text('Share'), findsNWidgets(2));
      expect(find.text('Rename'), findsNWidgets(2));
      expect(find.text('Merge'), findsNWidgets(3)); // Alice, Bob, Charlie (non-creators)
      expect(find.text('Remove'), findsNWidgets(3));
    });

    testWidgets('6. ManageMembersView share action copies trip code for the virtual participant', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const ManageMembersView(tripId: 'trip_goa_001')));
      await tester.pumpAndSettle();

      // Tap 'Share' on Bob
      await tester.tap(find.text('Share').first);
      await tester.pumpAndSettle();

      expect(find.text('Claim link for Bob Offline copied! Share with them to claim.'), findsOneWidget);
    });

    testWidgets('7. TripDetailView displays participants count link and VIRTUAL indicators', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const TripDetailView(tripId: 'trip_goa_001')));
      await tester.pumpAndSettle();

      // Trip detail header displays members count link
      expect(find.text('Members (4)'), findsOneWidget);

      // Wrap chips show all 4 members
      expect(find.text('Darpan Creator (You)'), findsWidgets);
      expect(find.text('Alice Singh'), findsWidgets);
      expect(find.text('Bob Offline'), findsWidgets);
      expect(find.text('Charlie Placeholder'), findsWidgets);

      // Virtual chips display 'VIRTUAL' badge
      expect(find.text('VIRTUAL'), findsWidgets);

      // Tapping member count navigates to TripMembersView
      await tester.tap(find.text('Members (4)'));
      await tester.pumpAndSettle();

      // Successfully navigated to TripMembersView
      expect(find.text('Trip Participants'), findsOneWidget);
      expect(find.text('4 Participants • 2 KITH, 2 Virtual'), findsOneWidget);
    });
  });
}
