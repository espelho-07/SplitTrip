import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/secure_id_service.dart';
import 'package:kith_app/core/services/supabase_guest_sync.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:shared_preferences/shared_preferences.dart';

// In-memory fake for SecureIdService to test reinstall and recovery flows in unit test harness
class FakeSecureIdService extends SecureIdService {
  String? _guestId;
  String? _recoveryKey;

  @override
  Future<String?> getPersistedGuestId() async => _guestId;

  @override
  Future<String?> getPersistedRecoveryKey() async => _recoveryKey;

  @override
  Future<void> persistGuestIdentity(String guestId, String recoveryKey) async {
    _guestId = guestId;
    _recoveryKey = recoveryKey;
  }

  @override
  Future<void> clearSecureIdentity() async {
    _guestId = null;
    _recoveryKey = null;
  }

  @override
  Future<bool> hasPersistedIdentity() async => _guestId != null && _guestId!.isNotEmpty;
}

// In-memory fake for SupabaseGuestSync to test cloud guest session persistence
class FakeSupabaseGuestSync extends SupabaseGuestSync {
  final Map<String, Map<String, dynamic>> _table = {};

  @override
  Future<void> upsertGuestSession(GuestUser user) async {
    _table[user.id] = {
      "id": user.id,
      "recovery_key": user.recoveryKey,
      "display_name": user.displayName,
      "anonymous_token": user.anonymousToken,
      "created_at": user.createdAt.toIso8601String(),
      "last_seen_at": DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>?> recoverByRecoveryKey(String recoveryKey) async {
    for (final row in _table.values) {
      if (row["recovery_key"] == recoveryKey) return row;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> recoverById(String guestId) async {
    return _table[guestId];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late FakeSecureIdService fakeSecureId;
  late FakeSupabaseGuestSync fakeSupabaseSync;
  late ApiClient apiClient;
  late AuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    fakeSecureId = FakeSecureIdService();
    fakeSupabaseSync = FakeSupabaseGuestSync();
    apiClient = ApiClient();

    authService = AuthService(
      storage: storage,
      apiClient: apiClient,
      secureIdService: fakeSecureId,
      supabaseGuestSync: fakeSupabaseSync,
    );
  });

  group("Guest Account Multi-Layer Persistence & Reinstall Recovery Suite", () {
    test("1. Creating guest user anchors identity in Keystore (Layer 1) & Supabase (Layer 2)", () async {
      final user = await authService.createGuestUser(displayName: "Aarav Sharma");

      expect(user.displayName, equals("Aarav Sharma"));
      expect(user.recoveryKey.startsWith("KITH-"), isTrue);

      // Verify Layer 0: SharedPreferences
      final spUser = storage.getSavedUser();
      expect(spUser, isNotNull);
      expect(spUser!["id"], equals(user.id));

      // Verify Layer 1: Keystore Anchor
      final secureId = await fakeSecureId.getPersistedGuestId();
      final secureKey = await fakeSecureId.getPersistedRecoveryKey();
      expect(secureId, equals(user.id));
      expect(secureKey, equals(user.recoveryKey));

      // Verify Layer 2: Supabase Session Table
      final supaRow = await fakeSupabaseSync.recoverById(user.id);
      expect(supaRow, isNotNull);
      expect(supaRow!["display_name"], equals("Aarav Sharma"));
      expect(supaRow["recovery_key"], equals(user.recoveryKey));
    });

    test("2. Reinstall Scenario: SharedPreferences wiped, Keystore restores identity automatically", () async {
      // Step A: Initial install and user creation
      final originalUser = await authService.createGuestUser(displayName: "Priya Patel");
      final originalId = originalUser.id;
      final originalKey = originalUser.recoveryKey;

      // Step B: Simulate Android app reinstall (SharedPreferences wiped, Keystore preserved)
      await storage.clearUser();
      expect(storage.getSavedUser(), isNull);
      expect(await fakeSecureId.getPersistedGuestId(), equals(originalId));

      // Step C: Cold start after reinstall calls restoreGuestIfNeeded()
      final restoredUser = await authService.restoreGuestIfNeeded();

      expect(restoredUser, isNotNull);
      expect(restoredUser!.id, equals(originalId));
      expect(restoredUser.displayName, equals("Priya Patel"));
      expect(restoredUser.recoveryKey, equals(originalKey));

      // Verify SharedPreferences is re-hydrated
      final rehydrated = storage.getSavedUser();
      expect(rehydrated, isNotNull);
      expect(rehydrated!["id"], equals(originalId));
    });

    test("3. Device Switch Scenario: Recovery key restores account from Supabase", () async {
      // Step A: Create user on Device 1
      final user1 = await authService.createGuestUser(displayName: "Rohan Varma");
      final recoveryKey = user1.recoveryKey;

      // Step B: Device 2 has completely empty storage and Keystore
      final device2Storage = await LocalStorageService.init();
      await device2Storage.clearAllUserData();
      final device2SecureId = FakeSecureIdService();

      final device2Auth = AuthService(
        storage: device2Storage,
        apiClient: apiClient,
        secureIdService: device2SecureId,
        supabaseGuestSync: fakeSupabaseSync, // Shares the Supabase database
      );

      // Step C: User enters recovery key on Device 2
      final recoveredUser = await device2Auth.recoverUser(recoveryKey);

      expect(recoveredUser, isNotNull);
      expect(recoveredUser!.id, equals(user1.id));
      expect(recoveredUser.displayName, equals("Rohan Varma"));
      expect(recoveredUser.recoveryKey, equals(recoveryKey));

      // Keystore on Device 2 is now anchored
      expect(await device2SecureId.getPersistedGuestId(), equals(user1.id));
    });

    test("4. Explicit Logout clears Keystore anchor so fresh install is not auto-restored", () async {
      await authService.createGuestUser(displayName: "Neha Gupta");
      expect(await fakeSecureId.hasPersistedIdentity(), isTrue);

      await authService.logout();

      expect(storage.getSavedUser(), isNull);
      expect(await fakeSecureId.hasPersistedIdentity(), isFalse);

      final postLogoutRestore = await authService.restoreGuestIfNeeded();
      expect(postLogoutRestore, isNull);
    });

    test("5. Empty server response in TripRepository does NOT wipe local cached trips", () async {
      final syncService = SyncService(storage);
      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );

      final testTrip = Trip(
        id: "trip_local_safe_123",
        name: "Goa Weekend",
        currencyCode: "INR",
        creatorId: "usr_creator",
        inviteCode: "GOA2026",
        members: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Seed local cache
      await storage.saveTrips([testTrip.toJson()]);
      expect(tripRepo.getCachedTrips().length, equals(1));

      // Calling getTrips() when offline or when server returns [] preserves local cache
      final trips = await tripRepo.getTrips();
      expect(trips.length, equals(1));
      expect(trips.first.id, equals("trip_local_safe_123"));
      expect(trips.first.name, equals("Goa Weekend"));
    });
  });
}
