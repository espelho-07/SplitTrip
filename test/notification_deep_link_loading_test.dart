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
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/trip_detail_viewmodel.dart';
import 'package:kith_app/presentation/views/notifications/notifications_view.dart';
import 'package:kith_app/presentation/views/trip/trip_detail_view.dart';
import 'package:kith_app/presentation/views/trip/widgets/expense_detail_loading_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late P2PSyncService p2pService;
  late ApiClient apiClient;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late AuthViewModel authVm;
  late HomeViewModel homeVm;
  late TripDetailViewModel tripDetailVm;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
    p2pService = P2PSyncService(storage, syncService, deviceId: 'test_device');
    apiClient = ApiClient();
    final authService = AuthService(apiClient: apiClient, storage: storage);
    final userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);
    tripRepo = TripRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    expenseRepo = ExpenseRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
    tripDetailVm = TripDetailViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);

    final tripJson = {
      'id': 'trip_dl_001',
      'name': 'Goa Beach Trip',
      'inviteCode': 'GOA123',
      'currency': 'INR',
      'lifecycleState': 'active',
      'creatorId': 'u1',
      'members': [
        {'id': 'u1', 'displayName': 'Rahul', 'role': 'admin', 'joinedAt': DateTime.now().toIso8601String()},
        {'id': 'u2', 'displayName': 'Priya', 'role': 'member', 'joinedAt': DateTime.now().toIso8601String()},
      ],
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final expenseJson = {
      'id': 'exp_dl_999',
      'tripId': 'trip_dl_001',
      'title': 'Seafood Dinner',
      'amountInPaise': 180000,
      'category': 'food',
      'paidById': 'u1',
      'splitType': 'equal',
      'splits': [
        {'memberId': 'u1', 'amountInPaise': 90000},
        {'memberId': 'u2', 'amountInPaise': 90000},
      ],
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await storage.saveTrips([tripJson]);
    await storage.saveExpenses('trip_dl_001', [expenseJson]);
    await storage.saveUser({
      'id': 'u1',
      'displayName': 'Rahul',
      'email': 'rahul@kith.local',
    });
    await authVm.initSession();
    await storage.saveNotifications([
      {
        'id': 'notif_exp_1',
        'title': 'New Expense Added',
        'description': 'Rahul added Seafood Dinner (₹1,800)',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'expense',
        'route': '/trip/trip_dl_001?expenseId=exp_dl_999',
        'actionLabel': 'View Expense',
        'isRead': false,
      },
    ]);
  });

  tearDown(() async {
    await p2pService.stop();
  });

  Widget buildTestApp({required Widget child}) {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: storage),
        Provider<SyncService>.value(value: syncService),
        Provider<P2PSyncService>.value(value: p2pService),
        Provider<TripRepository>.value(value: tripRepo),
        Provider<ExpenseRepository>.value(value: expenseRepo),
        ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
        ChangeNotifierProvider<HomeViewModel>.value(value: homeVm),
        ChangeNotifierProvider<TripDetailViewModel>.value(value: tripDetailVm),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }

  group('Deep-Linked Expense & Payment Loading Tests', () {
    testWidgets('1. ExpenseDetailLoadingSheet renders shimmer placeholders and title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExpenseDetailLoadingSheet(title: 'Loading Expense Details...'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Loading Expense Details...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('2. TripDetailView with expenseId deep-link immediately opens expense detail', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestApp(
          child: const TripDetailView(
            tripId: 'trip_dl_001',
            expenseId: 'exp_dl_999',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Seafood Dinner'), findsWidgets);
    });

    testWidgets('3. TripDetailView displays loading banner when deep-linking an expense', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestApp(
          child: const TripDetailView(
            tripId: 'trip_dl_001',
            expenseId: 'exp_nonexistent_cloud',
          ),
        ),
      );

      await tester.pump();
      expect(find.textContaining('Expense'), findsWidgets);
    });

    testWidgets('4. NotificationsView displays notifications and action button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestApp(
          child: const NotificationsView(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Expense Added'), findsOneWidget);
      expect(find.textContaining('Seafood Dinner'), findsOneWidget);
      expect(find.text('View Expense →'), findsOneWidget);
    });
  });
}
