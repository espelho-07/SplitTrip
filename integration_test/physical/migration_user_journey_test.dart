import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/realtime_client.dart';
import 'package:kith_app/core/services/app_version_service.dart';
import 'package:kith_app/core/services/security_lock_service.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/finance_export_bridge_service.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/locale_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/theme_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/version_viewmodel.dart';
import 'package:kith_app/presentation/views/settings/master_settings_view.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kith_app/core/localization/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('STAGE 5.1 PHYSICAL QA - SplitTrip User Journey (Device: CPH2729, Android 16)', () {
    late LocalDatabaseService dbService;
    late LocalStorageService storage;
    late FinanceExportBridgeService exportService;

    setUp(() async {
      LocalDatabaseService.resetStaticInstance();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      dbService = LocalDatabaseService.inMemory();
      storage = LocalStorageService(prefs, databaseService: dbService);
      exportService = FinanceExportBridgeService(storage: storage);
    });

    tearDown(() {
      dbService.dispose();
      LocalDatabaseService.resetStaticInstance();
    });

    testWidgets('JOURNEY-EXP-01: UI Export Sheet, Stat Counters & Checksum Verification', (tester) async {
      // 1. Seed synthetic records
      await storage.savePersonalExpenses([
        {
          'id': 'exp_j_01',
          'title': 'Coffee with Client',
          'amountInPaise': 35000,
          'currency': 'INR',
          'category': 'food',
          'date': '2026-11-01T09:00:00.000Z',
          'createdAt': '2026-11-01T09:00:00.000Z',
        },
        {
          'id': 'exp_j_02',
          'title': 'Metro Recharge',
          'amountInPaise': 50000,
          'currency': 'INR',
          'category': 'transport',
          'date': '2026-11-01T15:00:00.000Z',
          'createdAt': '2026-11-01T15:00:00.000Z',
        },
        {
          'id': 'exp_j_03',
          'title': 'Wi-Fi Fiber Bill',
          'amountInPaise': 99900,
          'currency': 'INR',
          'category': 'bills',
          'date': '2026-11-02T10:00:00.000Z',
          'createdAt': '2026-11-02T10:00:00.000Z',
        },
        {
          'id': 'exp_j_04',
          'title': 'Doctor Consultation',
          'amountInPaise': 80000,
          'currency': 'INR',
          'category': 'health',
          'date': '2026-11-02T16:00:00.000Z',
          'createdAt': '2026-11-02T16:00:00.000Z',
        },
        {
          'id': 'exp_j_05',
          'title': 'Tech Conference Pass',
          'amountInPaise': 250000,
          'currency': 'INR',
          'category': 'education',
          'date': '2026-11-03T11:00:00.000Z',
          'createdAt': '2026-11-03T11:00:00.000Z',
        },
      ]);

      await storage.savePersonalDebts([
        {
          'id': 'debt_j_01',
          'personName': 'Aman Verma',
          'debtType': 'lent',
          'initialAmountInPaise': 400000,
          'remainingAmountInPaise': 200000,
          'description': 'Office equipment',
          'date': '2026-11-01T11:00:00.000Z',
          'isSettled': false,
          'repayments': [
            {
              'id': 'rep_j_01',
              'debtId': 'debt_j_01',
              'amountInPaise': 200000,
              'date': '2026-11-02T11:00:00.000Z',
              'note': 'Part payment',
            }
          ],
        },
        {
          'id': 'debt_j_02',
          'personName': 'Sneha Rao',
          'debtType': 'borrowed',
          'initialAmountInPaise': 150000,
          'remainingAmountInPaise': 50000,
          'description': 'Team lunch',
          'date': '2026-11-02T13:00:00.000Z',
          'isSettled': false,
          'repayments': [
            {
              'id': 'rep_j_02',
              'debtId': 'debt_j_02',
              'amountInPaise': 100000,
              'date': '2026-11-03T10:00:00.000Z',
              'note': 'Cash',
            }
          ],
        },
      ]);

      await storage.savePersonalBudget('11_2026', {'amount': 45000, 'monthYear': '11_2026'});
      await storage.savePersonalBudget('12_2026', {'amount': 55000, 'monthYear': '12_2026'});
      await storage.saveIpoAccounts([
        {
          'id': 'acc_j_01',
          'investorName': 'Darpan Journey',
          'maskedPan': 'XYZAB1234C',
          'upiId': 'darpan@oksbi',
        }
      ]);
      await storage.setIpoTracked('ipo_zomato_2026', true);

      // Verify Summary extraction
      final summary = exportService.inspectLocalFinancialRecords();
      expect(summary.personalExpensesCount, equals(5));
      expect(summary.personalDebtsCount, equals(2));
      expect(summary.personalBudgetsCount, equals(2));
      expect(summary.ipoAccountsCount, equals(1));
      expect(summary.trackedIposCount, equals(1));
      expect(summary.totalRecords, equals(11));

      // 2. Build and verify Export JSON payload
      final jsonPayload = exportService.exportToJsonString();
      final decoded = jsonDecode(jsonPayload) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], equals('kith_finance_bridge_v1'));
      expect(decoded['sourceApp'], equals('SplitTrip'));

      // Verify SHA-256 Checksum
      final canonicalData = jsonEncode(decoded['data']);
      final computedChecksum = sha256.convert(utf8.encode(canonicalData)).toString();
      expect(decoded['checksum'], equals(computedChecksum));

      // 3. Write file to device /sdcard/Download/ for cross-app testing
      final deviceDownloadFile = File('/sdcard/Download/kith_finances_journey_export.json');
      try {
        await deviceDownloadFile.writeAsString(jsonPayload);
        debugPrint('[JOURNEY-EXP-01] Export written to device: ${deviceDownloadFile.path} (${jsonPayload.length} bytes)');
      } catch (e) {
        debugPrint('[JOURNEY-EXP-01] Notice writing to /sdcard: $e');
      }

      // 4. Pump UI with MasterSettingsView
      final apiClient = ApiClient();
      final realtimeClient = RealtimeClient();
      final syncService = SyncService(storage);
      final authService = AuthService(storage: storage, apiClient: apiClient, realtimeClient: realtimeClient);
      final userRepo = UserRepository(authService: authService);
      final appVersionService = AppVersionService(apiClient: apiClient, storage: storage, syncService: syncService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<LocalStorageService>.value(value: storage),
            Provider<LocalDatabaseService>.value(value: dbService),
            ChangeNotifierProvider(create: (_) => SecurityLockService(storage)),
            ChangeNotifierProvider(create: (_) => ThemeViewModel(storage: storage)),
            ChangeNotifierProvider(create: (_) => LocaleViewModel(storage: storage)),
            ChangeNotifierProvider(create: (_) => AuthViewModel(userRepo: userRepo)),
            ChangeNotifierProvider(create: (_) => VersionViewModel(versionService: appVersionService)),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MasterSettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the "Export Data for Finances App" tile
      final exportTileFinder = find.text('Export Data for Finances App');
      final scrollableFinder = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(exportTileFinder, 200, scrollable: scrollableFinder);
      expect(exportTileFinder, findsOneWidget);

      // Tap to open the Migration Bottom Sheet
      await tester.tap(exportTileFinder);
      await tester.pumpAndSettle();

      // Verify BottomSheet Content
      expect(find.text('Export Data for Finances'), findsOneWidget);
      expect(find.text('kith_finance_bridge_v1 (SHA-256 Verified)'), findsOneWidget);
      expect(find.text('Save via Device Storage (SAF)'), findsOneWidget);
      expect(find.text('Share to Finances App'), findsOneWidget);
      expect(find.text('Copy Migration Code'), findsOneWidget);

      // Verify stat pills in bottomsheet
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Debts'), findsOneWidget);
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('IPO Accounts'), findsOneWidget);

      debugPrint('[JOURNEY-EXP-01] UI Export Bottom Sheet Verified Successfully on Device!');
    });
  });
}
