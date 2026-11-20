import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Permanent Account Deletion & Multi-Device Invalidation Tests', () {
    late LocalStorageService storage;
    late AuthService authService;
    late UserRepository userRepo;
    late ApiClient apiClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      apiClient = ApiClient();
      authService = AuthService(storage: storage, apiClient: apiClient);
      userRepo = UserRepository(authService: authService);
    });

    tearDown(() {
      authService.dispose();
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

    test('3. Attempting to recover a deleted account throws AccountDeletedException and blocks restoration', () async {
      final user = GuestUser(
        id: 'usr_del_test_3',
        displayName: 'Deleted User',
        recoveryKey: 'KITH-EEEE-FFFF',
        anonymousToken: 'tok_test_3',
        createdAt: DateTime.now(),
      );

      await storage.saveUser(user.toJson());
      await userRepo.deleteAccount();

      // Attempt recovery with deleted key -> throws AccountDeletedException
      await expectLater(
        authService.recoverUser('KITH-EEEE-FFFF'),
        throwsA(isA<AccountDeletedException>()),
      );

      // Even with lowercase or without prefix, it must remain blocked
      await expectLater(
        authService.recoverUser('eeee-ffff'),
        throwsA(isA<AccountDeletedException>()),
      );
      await expectLater(
        authService.recoverUser('EEEE-FFFF'),
        throwsA(isA<AccountDeletedException>()),
      );
    });

    test('4. Cross-Device Deletion Enforcement: When Phone A has user in local vault but server returns 403 ACCOUNT_DELETED, Phone A marks key deleted and throws AccountDeletedException (NEVER resurrects user)', () async {
      const recoveryKey = 'KITH-CROSS-DEV1';
      final staleUser = GuestUser(
        id: 'usr_cross_device_phone_a',
        displayName: 'Phone A Stale User',
        recoveryKey: recoveryKey,
        anonymousToken: 'tok_cross_dev_stale',
        createdAt: DateTime.now(),
      );

      // Phone A had logged in previously, so local recovery vault still has the user
      await storage.saveUserToRecoveryVault(staleUser.toJson());
      expect(storage.getUserByRecoveryKey(recoveryKey), isNotNull);
      expect(storage.isRecoveryKeyDeleted(recoveryKey), isFalse);

      // Mock client that returns 403 ACCOUNT_DELETED from Render backend /auth/recover
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/recover')) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'ACCOUNT_DELETED',
                'message': 'This account has been permanently deleted.',
              }
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final testApiClient = ApiClient(httpClient: mockClient);
      final testAuthService = AuthService(storage: storage, apiClient: testApiClient);

      // Attempting to recover must NOT fall through to the local vault!
      await expectLater(
        testAuthService.recoverUser(recoveryKey),
        throwsA(isA<AccountDeletedException>()),
      );

      // Verify that Phone A has now marked the key as deleted locally and purged the vault!
      expect(storage.isRecoveryKeyDeleted(recoveryKey), isTrue);
      expect(storage.getUserByRecoveryKey(recoveryKey), isNull);

      testAuthService.dispose();
    });

    test('5. Global Notification: apiClient.onAccountDeleted immediately wipes user session and emits event', () async {
      final user = GuestUser(
        id: 'usr_active_session_phone_a',
        displayName: 'Active Phone A',
        recoveryKey: 'KITH-ACTV-SESS',
        anonymousToken: 'tok_active_phone_a',
        createdAt: DateTime.now(),
      );

      await storage.saveUser(user.toJson());
      await storage.saveUserToRecoveryVault(user.toJson());
      expect(storage.getSavedUser(), isNotNull);

      String? receivedEvent;
      final sub = authService.accountDeletedEvents.listen((reason) {
        receivedEvent = reason;
      });

      // Simulate backend returning 403 ACCOUNT_DELETED during an API request
      apiClient.onAccountDeleted?.call('This account has been deleted on another device.');

      await Future.delayed(const Duration(milliseconds: 50));

      expect(storage.getSavedUser(), isNull);
      expect(storage.getUserByRecoveryKey('KITH-ACTV-SESS'), isNull);
      expect(storage.isRecoveryKeyDeleted('KITH-ACTV-SESS'), isTrue);
      expect(receivedEvent, contains('deleted on another device'));

      await sub.cancel();
    });
  });
}
