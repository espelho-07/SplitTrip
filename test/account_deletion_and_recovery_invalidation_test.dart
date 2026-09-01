import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Permanent Account Deletion & Recovery Key Invalidation Tests', () {
    late LocalStorageService storage;
    late AuthService authService;
    late UserRepository userRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      authService = AuthService(storage: storage, apiClient: ApiClient());
      userRepo = UserRepository(authService: authService);
    });

    test('1. Creating a user persists session and populates local recovery vault', () async {
      final user = GuestUser(
        id: 'usr_del_test_1',
        displayName: 'Test Traveler',
        recoveryKey: 'KITH-AAAA-BBBB',
        anonymousToken: 'tok_test_1',
        createdAt: DateTime.now(),
      );

      await storage.saveUser(user.toJson());

      expect(storage.getSavedUser(), isNotNull);
      expect(storage.getUserByRecoveryKey('KITH-AAAA-BBBB'), isNotNull);
      expect(storage.isRecoveryKeyDeleted('KITH-AAAA-BBBB'), isFalse);
    });

    test('2. Deleting account completely wipes local user, purges vault, and flags key deleted', () async {
      final user = GuestUser(
        id: 'usr_del_test_2',
        displayName: 'Delete Target',
        recoveryKey: 'KITH-CCCC-DDDD',
        anonymousToken: 'tok_test_2',
        createdAt: DateTime.now(),
      );

      await storage.saveUser(user.toJson());
      expect(storage.getSavedUser(), isNotNull);

      // Perform account deletion
      await userRepo.deleteAccount();

      // Verify complete local wipe
      expect(storage.getSavedUser(), isNull);
      expect(storage.getUserByRecoveryKey('KITH-CCCC-DDDD'), isNull);
      expect(storage.isRecoveryKeyDeleted('KITH-CCCC-DDDD'), isTrue);
    });

    test('3. Attempting to recover a deleted account returns null and blocks restoration', () async {
      final user = GuestUser(
        id: 'usr_del_test_3',
        displayName: 'Deleted User',
        recoveryKey: 'KITH-EEEE-FFFF',
        anonymousToken: 'tok_test_3',
        createdAt: DateTime.now(),
      );

      await storage.saveUser(user.toJson());
      await userRepo.deleteAccount();

      // Attempt recovery with deleted key
      final recovered = await authService.recoverUser('KITH-EEEE-FFFF');
      expect(recovered, isNull);

      // Even with lowercase or without prefix, it must remain blocked
      expect(await authService.recoverUser('eeee-ffff'), isNull);
      expect(await authService.recoverUser('EEEE-FFFF'), isNull);
    });

    test('4. Unknown recovery key returns null', () async {
      final recovered = await authService.recoverUser('KITH-XXXX-YYYY');
      expect(recovered, isNull);
    });
  });
}
