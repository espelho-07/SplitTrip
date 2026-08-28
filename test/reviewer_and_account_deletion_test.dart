import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late ApiClient apiClient;
  late AuthService authService;
  late UserRepository userRepo;
  late AuthViewModel authVm;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    apiClient = ApiClient();
    authService = AuthService(storage: storage, apiClient: apiClient);
    userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);
  });

  group('Google Play Compliance: Reviewer Login & Account Deletion Tests', () {
    test('1. Reviewer Demo Access signs into review.nirniq@gmail.com with active session', () async {
      final user = await authVm.signInAsReviewer(email: 'review.nirniq@gmail.com');

      expect(user, isNotNull);
      expect(user!.email, equals('review.nirniq@gmail.com'));
      expect(authVm.currentUser?.email, equals('review.nirniq@gmail.com'));
      expect(authVm.isAuthenticated, isTrue);
      expect(authVm.currentUser?.isGuest, isFalse);
    });

    test('2. Entering review.nirniq email in recoverSession intercepts and signs into reviewer account', () async {
      final user = await authVm.recoverSession('review.nirniq@gmail.com');

      expect(user, isNotNull);
      expect(user!.email, equals('review.nirniq@gmail.com'));
      expect(authVm.isAuthenticated, isTrue);
    });

    test('3. In-App deleteAccount purges auth state and local user session', () async {
      // 1. Sign in as reviewer
      await authVm.signInAsReviewer(email: 'review.nirniq@gmail.com');
      expect(authVm.isAuthenticated, isTrue);

      // 2. Delete account
      final success = await authVm.deleteAccount();
      expect(success, isTrue);
      expect(authVm.currentUser, isNull);
      expect(authVm.isAuthenticated, isFalse);
      expect(storage.getSavedUser(), isNull);
    });
  });
}
