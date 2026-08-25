import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 26 Production Core Flutter Suite', () {
    late LocalStorageService storage;
    late AuthService authService;
    late UserRepository userRepo;
    late AuthViewModel authVm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      final apiClient = ApiClient();
      authService = AuthService(storage: storage, apiClient: apiClient);
      userRepo = UserRepository(authService: authService);
      authVm = AuthViewModel(userRepo: userRepo);
    });

    test('1. Guest session initialization and recovery key creation', () async {
      final user = await authVm.createGuestSession('Pooja');
      expect(user.displayName, 'Pooja');
      expect(user.recoveryKey.startsWith('KITH-'), true);
      expect(user.isLinkedToAccount, false);
      expect(authVm.isAuthenticated, true);
    });

    test('2. Google Sign-In updates user identity and marks account linked', () async {
      // Start with guest user
      await authVm.createGuestSession('Pooja');

      // Sign in with Google (offline mock simulation)
      final googleUser = await authService.linkToAccount(
        email: 'pooja.sharma@gmail.com',
        provider: 'google',
        displayName: 'Pooja Sharma',
      );

      expect(googleUser.email, 'pooja.sharma@gmail.com');
      expect(googleUser.displayName, 'Pooja Sharma');
      expect(googleUser.isLinkedToAccount, true);

      // Verify cached user in LocalStorageService
      final saved = storage.getSavedUser();
      expect(saved, isNotNull);
      expect(saved!['email'], 'pooja.sharma@gmail.com');
      expect(saved['isLinkedToAccount'], true);
    });

    test('3. Session Logout clears local authentication credentials safely', () async {
      await authVm.createGuestSession('Darpan');
      expect(authVm.isAuthenticated, true);
      expect(storage.getSavedUser(), isNotNull);

      await authVm.logout();
      expect(authVm.isAuthenticated, false);
      expect(authVm.currentUser, isNull);
      expect(storage.getSavedUser(), isNull);
    });
  });
}
