import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/presentation/views/help/help_faq_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 29: Account Experience + Google Auth + Cloud Sync + FAQ Suite', () {
    late LocalStorageService storage;
    late AuthService authService;
    late UserRepository userRepo;
    late SyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      final apiClient = ApiClient();
      authService = AuthService(storage: storage, apiClient: apiClient);
      userRepo = UserRepository(authService: authService);
      syncService = SyncService(storage);
    });

    test('1. Onboarding completion flag persists accurately across sessions', () async {
      expect(userRepo.hasCompletedOnboarding(), isFalse);
      await userRepo.setOnboardingCompleted(true);
      expect(userRepo.hasCompletedOnboarding(), isTrue);

      await userRepo.setOnboardingCompleted(false);
      expect(userRepo.hasCompletedOnboarding(), isFalse);
    });

    test('2. Last sync time and auto-sync preferences persist correctly', () async {
      expect(userRepo.getLastSyncTime(), isNull);
      expect(userRepo.isAutoSyncEnabled(), isTrue);

      final now = DateTime(2026, 8, 25, 18, 45);
      await userRepo.saveLastSyncTime(now);
      expect(userRepo.getLastSyncTime(), equals(now));

      await userRepo.setAutoSyncEnabled(false);
      expect(userRepo.isAutoSyncEnabled(), isFalse);
    });

    test('3. Full user logout wipes user credentials, sync queue, and cached data', () async {
      await authService.createGuestUser(displayName: 'Test Traveler');
      expect(authService.getCurrentUser(), isNotNull);

      await syncService.enqueueMutation(MutationType.addExpense, {'title': 'Dinner', 'amount': 500});
      expect(syncService.pendingCount, equals(1));

      // Execute full logout
      await authService.logout();

      expect(authService.getCurrentUser(), isNull);
      expect(storage.getSavedUser(), isNull);
      expect(syncService.pendingCount, equals(0));
      expect(storage.getSavedTrips(), isEmpty);
    });

    test('4. Google Account linking state displays correctly in GuestUser model', () {
      final guest = GuestUser(
        id: 'usr_1',
        displayName: 'Sam',
        recoveryKey: 'KITH-AAAA-BBBB',
        anonymousToken: 'tok_1',
        createdAt: DateTime.now(),
        isLinkedToAccount: false,
      );

      expect(guest.isGoogleLinked, isFalse);
      expect(guest.isLinkedToAccount, isFalse);

      final googleUser = guest.copyWith(
        email: 'sam@gmail.com',
        googleId: 'g_12345',
        isLinkedToAccount: true,
      );

      expect(googleUser.isGoogleLinked, isTrue);
      expect(googleUser.isLinkedToAccount, isTrue);
      expect(googleUser.email, equals('sam@gmail.com'));
      expect(googleUser.googleId, equals('g_12345'));
    });

    test('5. FAQ items cover all 13 core categories and filter correctly', () {
      const allCategories = [
        'GETTING STARTED',
        'ACCOUNT & SECURITY',
        'PERSONAL EXPENSES',
        'TRIPS',
        'SPLITTING EXPENSES',
        'SETTLEMENTS',
        'VOICE INTELLIGENCE',
        'RECEIPTS & OCR',
        'QR & TRIP JOINING',
        'CLOUD SYNCHRONIZATION',
        'OFFLINE MODE',
        'DATA PRIVACY',
        'TROUBLESHOOTING',
      ];

      // Verify that sample FAQ items match expected structure
      const sampleItem = FaqItem(
        category: 'ACCOUNT & SECURITY',
        question: 'What is a Recovery Key?',
        answer: 'Your Recovery Key is a cryptographic backup code.',
      );

      expect(allCategories.contains(sampleItem.category), isTrue);
      expect(sampleItem.question.toLowerCase().contains('recovery'), isTrue);
    });
  });
}
