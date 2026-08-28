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
    testWidgets('1. Renders Master TopBar, Hero headline, Stats pill, Live Preview banner, and 4 sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('KITH · NEW TRIP'), findsOneWidget);
      expect(find.text('DRAFTING'), findsOneWidget);
      expect(find.text('Design Your Trip'), findsOneWidget);
      expect(find.textContaining('Paise-Perfect Math'), findsOneWidget);
      expect(find.text('LIVE PREVIEW'), findsOneWidget);
      expect(find.text('Trip Name'), findsWidgets);
      expect(find.text('TRIP IDENTITY'), findsOneWidget);
      expect(find.text('EXPERIENCE MODE'), findsOneWidget);
      expect(find.text('BASE CURRENCY'), findsOneWidget);
      expect(find.text('CREW & CO-TRAVELERS'), findsOneWidget);
      expect(find.text('Enter Trip Name to Continue'), findsOneWidget);
    });

    testWidgets('2. Entering trip name and picking emoji/gradient reactively updates Live Preview card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget());
      await tester.pumpAndSettle();

      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Goa Villa Retreat');
      await tester.pumpAndSettle();

      expect(find.text('Goa Villa Retreat'), findsWidgets);
      expect(find.text('Create Trip Space 🚀'), findsOneWidget);

      final beachEmoji = find.text('🏖️').last;
      await tester.tap(beachEmoji);
      await tester.pumpAndSettle();

      expect(createVm.emoji, '🏖️');
    });

    testWidgets('3. Selecting Experience Mode updates mode selection and feature bullet highlights', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget());
      await tester.pumpAndSettle();

      final journeyOption = find.text('Split + Journey').first;
      await tester.tap(journeyOption);
      await tester.pumpAndSettle();

      expect(createVm.tripMode, 'split_and_journey');
      expect(find.text('RECOMMENDED'), findsOneWidget);
      expect(find.text('Includes all Split ledger features'), findsOneWidget);
      expect(find.text('Auto-attaches expenses to timeline'), findsOneWidget);
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

    testWidgets('5. Adding and removing friends updates crew tags and member counter chip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget());
      await tester.pumpAndSettle();

      final friendField = find.widgetWithText(TextField, "Friend's Name (e.g. Rahul)");

      expect(find.text('1 Crew Members'), findsOneWidget);
      expect(find.text('Organizer (You)'), findsOneWidget);

      await tester.enterText(friendField, 'Ananya');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Ananya'), findsOneWidget);
      expect(find.text('2 Crew Members'), findsOneWidget);

      final removeIcon = find.byIcon(Icons.close_rounded);
      await tester.tap(removeIcon);
      await tester.pumpAndSettle();

      expect(find.text('Ananya'), findsNothing);
      expect(find.text('1 Crew Members'), findsOneWidget);
    });

    testWidgets('6. Renders correctly in Hindi (hi) localization', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget(locale: const Locale('hi')));
      await tester.pumpAndSettle();

      expect(find.text('अपनी यात्रा डिज़ाइन करें'), findsOneWidget);
      expect(find.text('यात्रा की पहचान'), findsOneWidget);
      expect(find.text('अनुभव मोड'), findsOneWidget);
      expect(find.text('मुद्रा'), findsOneWidget);
      expect(find.text('सह-यात्री और दोस्त'), findsOneWidget);
    });

    testWidgets('7. Renders correctly in Gujarati (gu) localization', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateTripTestWidget(locale: const Locale('gu')));
      await tester.pumpAndSettle();

      expect(find.text('તમારી યાત્રા ડિઝાઇન કરો'), findsOneWidget);
      expect(find.text('યાત્રાની ઓળખ'), findsOneWidget);
      expect(find.text('અનુભવ મોડ'), findsOneWidget);
      expect(find.text('ચલણ'), findsOneWidget);
      expect(find.text('સાથી પ્રવાસીઓ અને મિત્રો'), findsOneWidget);
    });
  });
}
