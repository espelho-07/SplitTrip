import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
import 'package:kith_app/core/theme/app_theme.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip_preview.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/join_trip_viewmodel.dart';
import 'package:kith_app/presentation/views/trip/join_trip_view.dart';
import 'package:kith_app/presentation/views/trip/widgets/join_preview_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late SyncService syncService;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late AuthViewModel authVm;
  late HomeViewModel homeVm;
  late JoinTripViewModel joinVm;
  late KithWidgetService widgetService;
  late GuestUser testUser;

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
    homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
    joinVm = JoinTripViewModel(tripRepo: tripRepo);
    widgetService = KithWidgetService(storage: storage);

    testUser = GuestUser(
      id: 'usr_join_test',
      displayName: 'Darpan Joiner',
      recoveryKey: 'KITH-JOIN-TEST',
      anonymousToken: 'tok_join_123',
      createdAt: DateTime.now(),
    );

    await storage.saveUser(testUser.toJson());
    await authVm.initSession();
  });

  Widget createTestWidget({Locale locale = const Locale('en')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authVm),
        ChangeNotifierProvider.value(value: homeVm),
        ChangeNotifierProvider.value(value: joinVm),
        Provider.value(value: apiClient),
        Provider.value(value: syncService),
        ChangeNotifierProvider.value(value: widgetService),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('gu')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const JoinTripView(),
      ),
    );
  }

  group('Master JoinTripView Suite', () {
    testWidgets('1. Renders Master TopBar, tactile 6-box input deck, paste chip, and QR scanner deck', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('KITH · JOIN TRIP'), findsOneWidget);
      expect(find.text('Join Trip'), findsOneWidget);
      expect(find.text('INVITE CODE'), findsOneWidget);
      expect(find.text('Paste from Clipboard'), findsOneWidget);
      expect(find.text('INSTANT QR SCANNER'), findsOneWidget);
      expect(find.text('Find Trip & Preview'), findsOneWidget);
      expect(find.text('Open Camera & Scan QR'), findsOneWidget);
    });

    testWidgets('2. Entering code updates 6 character cells and uppercase normalization', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'GOA123');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('G'), findsOneWidget);
      expect(find.text('O'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('3. JoinPreviewSheet renders host, members, currency, and confirm button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final preview = const TripPreview(
        tripId: 'trip_preview_123',
        name: 'Kyoto Autumn Walk',
        emoji: '🍁',
        creatorName: 'Rohan Sharma',
        memberCount: 4,
        currencyCode: 'JPY',
        inviteCode: 'KYO123',
        coverGradientIndex: 0,
        lifecycleState: 'active',
      );

      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: JoinPreviewSheet(
              preview: preview,
              isJoining: false,
              onConfirmJoin: () => confirmed = true,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kyoto Autumn Walk'), findsOneWidget);
      expect(find.text('Hosted by Rohan Sharma'), findsOneWidget);
      expect(find.text('🍁'), findsOneWidget);
      expect(find.text('JPY'), findsOneWidget);
      expect(find.text('KYO123'), findsOneWidget);
      expect(find.text('Join Trip Now'), findsOneWidget);

      await tester.tap(find.text('Join Trip Now'));
      await tester.pumpAndSettle();

      expect(confirmed, true);
    });

    testWidgets('4. Renders full Hindi localization for JoinTripView', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(locale: const Locale('hi')));
      await tester.pumpAndSettle();

      expect(find.text('यात्रा से जुड़ें'), findsOneWidget);
      expect(find.text('आमंत्रण कोड'), findsOneWidget);
      expect(find.text('त्वरित QR स्कैनर'), findsOneWidget);
      expect(find.text('क्लिपबोर्ड से पेस्ट करें'), findsOneWidget);
      expect(find.text('ट्रिप खोजें और पूर्वावलोकन करें'), findsOneWidget);
    });

    testWidgets('5. Renders full Gujarati localization for JoinTripView', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(locale: const Locale('gu')));
      await tester.pumpAndSettle();

      expect(find.text('પ્રવાસમાં જોડાઓ'), findsOneWidget);
      expect(find.text('આમંત્રણ કોડ'), findsOneWidget);
      expect(find.text('ત્વરિત QR સ્કેનર'), findsOneWidget);
      expect(find.text('ક્લિપબોર્ડથી પેસ્ટ કરો'), findsOneWidget);
      expect(find.text('ટ્રિપ શોધો અને પ્રીવ્યૂ જુઓ'), findsOneWidget);
    });
  });
}
