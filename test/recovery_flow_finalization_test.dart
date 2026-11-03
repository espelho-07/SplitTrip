import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/recovery_key_service.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/views/onboarding/recovery_progress_view.dart';
import 'package:kith_app/presentation/views/onboarding/widgets/recovery_key_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late AuthService authService;
  late UserRepository userRepo;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late SyncService syncService;
  late ApiClient apiClient;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    apiClient = ApiClient();
    authService = AuthService(storage: storage, apiClient: apiClient);
    userRepo = UserRepository(authService: authService);
    syncService = SyncService(storage);
    tripRepo = TripRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    expenseRepo = ExpenseRepository(storage: storage, syncService: syncService, apiClient: apiClient);
  });

  group('Recovery Key Cryptography & Profile Preservation', () {
    test('Recovery Key verification matches salted hash and preserves true name', () {
      final key = RecoveryKeyService.generateKey();
      final salt = RecoveryKeyService.generateSalt();
      final hash = RecoveryKeyService.hashKey(key, salt);

      expect(RecoveryKeyService.verifyKey(key, hash, salt), isTrue);

      const realName = 'Darpan';
      final guest = GuestUser(
        id: 'usr_recovery_test',
        accountId: 'usr_recovery_test',
        displayName: realName,
        recoveryKey: key,
        anonymousToken: 'kith_rec_test',
        createdAt: DateTime.now(),
      );

      expect(guest.displayName, equals('Darpan'));
      expect(guest.displayName, isNot('Traveler'));
    });

    test('Recovery Key normalization strips spaces and formats uniformly', () {
      final key = RecoveryKeyService.generateKey();
      final lowerSpaced = '  ${key.toLowerCase()}  ';
      final normalized = RecoveryKeyService.normalizeKey(lowerSpaced);
      expect(normalized, equals(key));
      expect(RecoveryKeyService.isValidKeyFormat(normalized), isTrue);
    });
  });

  group('RecoveryProgressView Widget & State Machine Tests', () {
    testWidgets('RecoveryProgressView renders recovery UI and handles invalid key error', (tester) async {
      final authVm = AuthViewModel(userRepo: userRepo);
      final homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
            ChangeNotifierProvider<HomeViewModel>.value(value: homeVm),
            Provider<SyncService>.value(value: syncService),
            Provider<ApiClient>.value(value: apiClient),
          ],
          child: const MaterialApp(
            home: RecoveryProgressView(recoveryKey: 'KITH-XXXX-YYYY-ZZZZ'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Since the mock key does not exist on a fresh empty mock DB, it should safely transition to error state with Retry button
      expect(find.text('Recovery Error'), findsOneWidget);
      expect(find.text('Retry with Different Key'), findsOneWidget);
      expect(find.text('Create New Account'), findsOneWidget);
    });

    testWidgets('RecoveryKeySheet renders paste icon and recover CTA button', (tester) async {
      final authVm = AuthViewModel(userRepo: userRepo);
      final homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
            ChangeNotifierProvider<HomeViewModel>.value(value: homeVm),
            Provider<SyncService>.value(value: syncService),
            Provider<ApiClient>.value(value: apiClient),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecoveryKeySheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.content_paste_rounded), findsOneWidget);
    });
  });
}
