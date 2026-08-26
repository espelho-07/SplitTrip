import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth State Machine & Sign-Out Tests', () {
    late LocalStorageService storage;
    late UserRepository userRepo;
    late AuthViewModel authVm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      final apiClient = ApiClient();
      final authService = AuthService(apiClient: apiClient, storage: storage);

      userRepo = UserRepository(
        authService: authService,
      );

      authVm = AuthViewModel(userRepo: userRepo);
    });

    test('Initializes with signedOut state when no user exists in storage', () async {
      expect(authVm.authState, equals(AuthState.uninitialized));
      await authVm.initSession();
      expect(authVm.authState, equals(AuthState.signedOut));
      expect(authVm.isAuthenticated, isFalse);
      expect(authVm.currentUser, isNull);
    });

    test('Transitions to authenticated upon guest session creation', () async {
      await authVm.initSession();
      final user = await authVm.createGuestSession('Darpan');

      expect(user.displayName, equals('Darpan'));
      expect(authVm.authState, equals(AuthState.authenticated));
      expect(authVm.isAuthenticated, isTrue);
      expect(authVm.currentUser, isNotNull);
      expect(storage.getSavedUser(), isNotNull);
    });

    test('Signing out immediately purges auth state, user, and cached data', () async {
      await authVm.initSession();
      await authVm.createGuestSession('Darpan');
      expect(authVm.isAuthenticated, isTrue);

      // Perform logout
      await authVm.logout();
      await storage.clearAllUserData();

      expect(authVm.authState, equals(AuthState.signedOut));
      expect(authVm.isAuthenticated, isFalse);
      expect(authVm.currentUser, isNull);
      expect(storage.getSavedUser(), isNull);
    });

    test('Account A logout followed by Account B creates isolated session', () async {
      await authVm.initSession();

      // User A logs in
      final userA = await authVm.createGuestSession('User A');
      expect(authVm.currentUser?.displayName, equals('User A'));

      // User A logs out
      await authVm.logout();
      await storage.clearAllUserData();
      expect(authVm.currentUser, isNull);

      // User B logs in
      final userB = await authVm.createGuestSession('User B');
      expect(authVm.currentUser?.displayName, equals('User B'));
      expect(userB.id, isNot(equals(userA.id)));
    });
  });
}
