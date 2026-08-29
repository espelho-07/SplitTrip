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
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/create_trip_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/views/trip/create_trip_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late UserRepository userRepo;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late CreateTripViewModel createVm;
  late AuthViewModel authVm;
  late HomeViewModel homeVm;

  final testUser = GuestUser(
    id: 'user_master_test',
    displayName: 'Darpan Master',
    recoveryKey: 'KITH-TEST-1234',
    anonymousToken: 'tok_master_123',
    createdAt: DateTime.now(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    apiClient = ApiClient();
    final authService = AuthService(apiClient: apiClient, storage: storage);
    userRepo = UserRepository(authService: authService);
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
    createVm = CreateTripViewModel(tripRepo: tripRepo);
    homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);

    await storage.saveUser(testUser.toJson());
    await authVm.initSession();
  });

  Widget buildCreateTripTestWidget({Locale locale = const Locale('en')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: createVm),
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: homeVm),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('gu')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const CreateTripView(),
      ),
    );
  }

  group('Master CreateTripView Suite', () {
    testWidgets('1. Renders clean New Trip top bar, experience mode, currency, and create button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('New Trip'), findsOneWidget);
      expect(find.text('EXPERIENCE MODE'), findsOneWidget);
      expect(find.text('BASE CURRENCY'), findsOneWidget);
      expect(find.text('Create Trip'), findsOneWidget);
    });

    testWidgets('2. Entering trip name and picking emoji reactively updates state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget());
      await tester.pumpAndSettle();

      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Goa Villa Retreat');
      await tester.pumpAndSettle();

      expect(createVm.name, 'Goa Villa Retreat');

      // Tap emoji button to expand tray
      final emojiBtn = find.text('✈️').first;
      await tester.tap(emojiBtn);
      await tester.pumpAndSettle();

      final beachEmoji = find.text('🏖️').first;
      await tester.tap(beachEmoji);
      await tester.pumpAndSettle();

      expect(createVm.emoji, '🏖️');
    });

    testWidgets('3. Selecting Experience Mode updates mode selection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget());
      await tester.pumpAndSettle();

      final splitOnly = find.text('Split Only').first;
      await tester.tap(splitOnly);
      await tester.pumpAndSettle();

      expect(createVm.tripMode, 'split_only');
    });

    testWidgets('4. Selecting Currency updates currency code chip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget());
      await tester.pumpAndSettle();

      final usdChip = find.text(r'$ USD');
      await tester.tap(usdChip);
      await tester.pumpAndSettle();

      expect(createVm.currencyCode, 'USD');
    });

    testWidgets('5. Adding and removing friends updates crew list', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Friends can join instantly via QR code or invite code.'), findsOneWidget);

      // Expand manual friends
      await tester.tap(find.text('Add friend manually (non-app user)'));
      await tester.pumpAndSettle();

      final friendField = find.widgetWithText(TextField, 'Enter friend name...');
      await tester.enterText(friendField, 'Ananya');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Ananya'), findsOneWidget);

      final removeIcon = find.byIcon(Icons.close_rounded);
      await tester.tap(removeIcon);
      await tester.pumpAndSettle();

      expect(find.text('Ananya'), findsNothing);
    });
  });
}
