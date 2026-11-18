import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/payment/payment_service.dart';
import 'package:kith_app/core/theme/app_theme.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/balance_summary.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/payment_verification_request.dart';
import 'package:kith_app/domain/models/settlement_transaction.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/models/trip_preview.dart';
import 'package:kith_app/domain/services/notification_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/trip_detail_viewmodel.dart';
import 'package:kith_app/presentation/views/onboarding/widgets/recovery_key_created_sheet.dart';
import 'package:kith_app/presentation/views/payment/payment_verification_dialog.dart';
import 'package:kith_app/presentation/views/payment/upi_payment_dialog.dart';
import 'package:kith_app/presentation/views/trip/widgets/join_preview_sheet.dart';
import 'package:kith_app/presentation/views/trip/widgets/settlement_sheet.dart';
import 'package:kith_app/presentation/views/trip/widgets/trip_completion_verification_sheet.dart';
import 'package:kith_app/presentation/widgets/progress/kith_stage_progress.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late SyncService syncService;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late NotificationService notifService;
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
    notifService = NotificationService();
    homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
    tripDetailVm = TripDetailViewModel(
      tripRepo: tripRepo,
      expenseRepo: expenseRepo,
      storage: storage,
    );

    testUser = GuestUser(
      id: 'usr_landscape_test',
      displayName: 'Landscape Tester',
      recoveryKey: 'KITH-LAND-TEST-1234',
      anonymousToken: 'tok_land_123',
      createdAt: DateTime.now(),
    );

    await storage.saveUser(testUser.toJson());
    await authVm.initSession();

    sampleTrip = Trip(
      id: 'trip_landscape_01',
      name: 'Goa Weekend Trip',
      creatorId: testUser.id,
      inviteCode: 'GOA999',
      currencyCode: 'INR',
      lifecycleState: TripLifecycle.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      members: [
        TripMember(
          id: testUser.id,
          userId: testUser.id,
          displayName: 'Landscape Tester',
          role: 'creator',
          joinedAt: DateTime.now(),
        ),
        TripMember(
          id: 'usr_bob',
          userId: 'usr_bob',
          displayName: 'Bob Walker',
          role: 'member',
          joinedAt: DateTime.now(),
        ),
        TripMember(
          id: 'usr_alice',
          userId: 'usr_alice',
          displayName: 'Alice Springs',
          role: 'member',
          joinedAt: DateTime.now(),
        ),
      ],
    );
  });

  Widget wrapInApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: homeVm),
        ChangeNotifierProvider.value(value: tripDetailVm),
        Provider.value(value: storage),
        Provider.value(value: tripRepo),
        Provider.value(value: expenseRepo),
        Provider.value(value: notifService),
        Provider.value(value: apiClient),
        Provider.value(value: syncService),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: const Locale('en'),
        supportedLocales: const [Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );
  }

  group('Landscape / Orientation RenderFlex Overflow Elimination Suite', () {
    testWidgets('1. KithStageProgress renders in compact landscape (640x320) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final stages = [
        const ProgressStage(label: 'Checking Connectivity', description: 'Testing server heartbeat'),
        const ProgressStage(label: 'Flushing Mutations', description: 'Sending 3 pending records'),
        const ProgressStage(label: 'Syncing Member Ledger', description: 'Validating balances across peers'),
        const ProgressStage(label: 'Finalizing Completion', description: 'Locking trip on cloud'),
      ];

      await tester.pumpWidget(
        wrapInApp(
          Center(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              padding: const EdgeInsets.all(16),
              child: KithStageProgress(
                title: 'Verifying Trip Sync',
                stages: stages,
                currentStageIndex: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Verifying Trip Sync'), findsOneWidget);
      expect(find.text('Checking Connectivity'), findsOneWidget);
    });

    testWidgets('2. RecoveryKeyCreatedSheet renders in compact landscape (640x320) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapInApp(
          RecoveryKeyCreatedSheet(
            recoveryKey: 'KITH-VAULT-2026-X99Z',
            onDismissed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Your Recovery Key'), findsOneWidget);
      expect(find.text('KITH-VAULT-2026-X99Z'), findsOneWidget);
    });

    testWidgets('3. PaymentVerificationSheet & PaymentDisputeAlertSheet render in landscape (800x360) without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final request = PaymentVerificationRequest(
        id: 'verif_01',
        settlementId: 'settle_01',
        tripId: sampleTrip.id,
        tripName: sampleTrip.name,
        payerMemberId: 'usr_bob',
        payerName: 'Bob Walker',
        receiverMemberId: testUser.id,
        receiverName: testUser.displayName,
        amountInPaise: 45000,
        status: 'pending_verification',
        markedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        wrapInApp(PaymentVerificationSheet(request: request)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Payment Verification'), findsOneWidget);
      expect(find.text('Yes, Received ✓'), findsOneWidget);

      await tester.pumpWidget(
        wrapInApp(PaymentDisputeAlertSheet(request: request)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Payment Not Received'), findsOneWidget);
      expect(find.text('Send Payment Proof'), findsOneWidget);
    });

    testWidgets('4. PaymentProofSheet renders in compact landscape (640x320) without overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final request = PaymentVerificationRequest(
        id: 'verif_02',
        settlementId: 'settle_02',
        tripId: sampleTrip.id,
        tripName: sampleTrip.name,
        payerMemberId: testUser.id,
        payerName: testUser.displayName,
        receiverMemberId: 'usr_bob',
        receiverName: 'Bob Walker',
        amountInPaise: 25000,
        status: 'disputed',
        markedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        wrapInApp(PaymentProofSheet(request: request, isPayer: true)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Submit Payment Proof'), findsOneWidget);
      expect(find.text('Transaction Reference / UTR (12 digits)'), findsOneWidget);
    });

    testWidgets('5. UpiPaymentSheet renders in compact landscape (640x320) without overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapInApp(
          UpiPaymentSheet(
            recipientName: 'Alice Springs',
            initialRecipientUpiId: 'alice@okaxis',
            amountInPaise: 35000,
            tripName: sampleTrip.name,
            tripId: sampleTrip.id,
            fromMemberId: testUser.id,
            toMemberId: 'usr_alice',
            paymentService: PaymentService(),
            onConfirmSettlement: ({required paymentReference, required paymentStatus, required recipientUpiId}) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Settle Balance'), findsOneWidget);
      expect(find.text('Alice Springs'), findsOneWidget);
    });

    testWidgets('6. JoinPreviewSheet renders in landscape (800x360) without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const preview = TripPreview(
        tripId: 'trip_land_prev',
        name: 'Himalayan Trek',
        emoji: '🏔️',
        coverGradientIndex: 1,
        currencyCode: 'INR',
        creatorName: 'Sherpa Tenzing',
        memberCount: 5,
        lifecycleState: 'active',
        inviteCode: 'HIM999',
        unclaimedMembers: [
          UnclaimedMemberPreview(id: 'm_guest_1', displayName: 'Rohan (Unclaimed)'),
        ],
      );

      await tester.pumpWidget(
        wrapInApp(
          JoinPreviewSheet(
            preview: preview,
            isJoining: false,
            onConfirmJoin: ({claimMemberId, claimToken}) {},
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Himalayan Trek'), findsOneWidget);
      expect(find.text('HIM999'), findsOneWidget);
    });

    testWidgets('7. SettlementSheet renders in compact landscape (640x320) without overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final balanceSummary = BalanceSummary(
        totalTripSpentInPaise: 100000,
        memberNetBalances: {
          testUser.id: -50000,
          'usr_bob': 50000,
          'usr_alice': 0,
        },
        currentUserNetBalanceInPaise: -50000,
        debtsToPay: [
          DebtTransfer(
            fromMemberId: testUser.id,
            toMemberId: 'usr_bob',
            amountInPaise: 50000,
          ),
        ],
        debtsToReceive: const [],
        simplifiedSettlements: [
          SettlementTransaction(
            id: 'st_01',
            fromMemberId: testUser.id,
            toMemberId: 'usr_bob',
            amountInPaise: 50000,
          ),
        ],
      );

      // Render without overriding tripDetailVm.balanceSummary
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authVm),
            ChangeNotifierProvider.value(value: homeVm),
            Provider.value(value: storage),
            Provider.value(value: tripRepo),
            Provider.value(value: expenseRepo),
            Provider.value(value: notifService),
            Provider.value(value: apiClient),
            Provider.value(value: syncService),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            locale: const Locale('en'),
            supportedLocales: const [Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: SettlementSheet(
                trip: sampleTrip,
                balanceSummary: balanceSummary,
                currentUserId: testUser.id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Settle Up'), findsOneWidget);
      expect(find.text('Total you owe'), findsOneWidget);
    });

    testWidgets('8. TripCompletionVerificationSheet renders in compact landscape (640x320) without overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await storage.saveTrips([sampleTrip.toJson()]);

      await tester.pumpWidget(
        wrapInApp(
          TripCompletionVerificationSheet(
            tripId: sampleTrip.id,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('Multi-Participant Final Sync Verification'), findsOneWidget);

      // Allow 200ms verification timer to finish so no pending timers remain
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
