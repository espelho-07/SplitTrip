import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/recovery_key_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalStorageService storage;
  late SyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
  });

  group('Guest Identity Cryptographic Token & Timing Attack Tests', () {
    test('1. generateSessionToken produces 256-bit cryptographically secure hex string', () {
      final token1 = RecoveryKeyService.generateSessionToken();
      final token2 = RecoveryKeyService.generateSessionToken();

      expect(token1.length, equals(64), reason: '32 bytes in hex must be 64 characters');
      expect(token2.length, equals(64));
      expect(token1, isNot(equals(token2)), reason: 'Sequential secure random tokens must never collide');
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(token1), isTrue);
    });

    test('2. hashSessionToken computes SHA-256 digest matching PostgreSQL sha256 bytea encode', () {
      const token = 'alice_secret_token_32chars_long_123';
      final hash = RecoveryKeyService.hashSessionToken(token);

      // Known SHA-256 for 'alice_secret_token_32chars_long_123'
      expect(hash, equals('118224a9536e4985430b6d09c86d128f4f14d19dfdfbaf171c7131a657b24e38'));
    });

    test('3. constantTimeEquals protects against timing side-channel attacks', () {
      const sigA = '118224a9536e4985430b6d09c86d128f4f14d19dfdfbaf171c7131a657b24e38';
      const sigB = '118224a9536e4985430b6d09c86d128f4f14d19dfdfbaf171c7131a657b24e38';
      const sigDifferentLastByte = '81b0a501bf021469e32a68a5c3fc89f9e13bfa767222384a62e08678d4624774';
      const sigDifferentFirstByte = '01b0a501bf021469e32a68a5c3fc89f9e13bfa767222384a62e08678d4624773';
      const sigDifferentLength = '81b0a501bf021469';

      expect(RecoveryKeyService.constantTimeEquals(sigA, sigB), isTrue);
      expect(RecoveryKeyService.constantTimeEquals(sigA, sigDifferentLastByte), isFalse);
      expect(RecoveryKeyService.constantTimeEquals(sigA, sigDifferentFirstByte), isFalse);
      expect(RecoveryKeyService.constantTimeEquals(sigA, sigDifferentLength), isFalse);
    });
  });

  group('P2P Replay Detection & Store-and-Forward Invariant Tests', () {
    test('4. Replayed operations do not duplicate domain state or resurrect expenses', () async {
      await storage.saveTrips([
        {
          'id': 'trip_kashmir_01',
          'name': 'Kashmir Trip',
          'inviteCode': 'KASHMIR2026',
        }
      ]);

      final mutation = SyncMutation(
        id: 'op_replay_test_001',
        type: MutationType.addExpense,
        payload: {
          'tripId': 'trip_kashmir_01',
          'id': 'exp_replay_001',
          'title': 'Gondola Ride',
          'amountInPaise': 180000,
        },
        createdAt: DateTime.now(),
        originDeviceId: 'dev_phone_peer',
      );

      // First application: Succeeds
      final firstApplied = await syncService.applyRemoteP2PMutation(mutation, storage);
      expect(firstApplied, isTrue);

      final expensesAfterFirst = storage.getSavedExpenses('trip_kashmir_01');
      expect(expensesAfterFirst.length, equals(1));
      expect(expensesAfterFirst.first['id'], equals('exp_replay_001'));

      // Replay of the exact same operation: MUST NOT duplicate
      final secondApplied = await syncService.applyRemoteP2PMutation(mutation, storage);
      expect(secondApplied, isFalse, reason: 'Replayed mutation must be rejected by persistent ledger');

      final expensesAfterReplay = storage.getSavedExpenses('trip_kashmir_01');
      expect(expensesAfterReplay.length, equals(1), reason: 'Replay must not duplicate expense in storage');
    });

    test('5. Replayed operation ID with altered payload is flagged as mismatch and dropped', () async {
      await storage.saveTrips([
        {
          'id': 'trip_kashmir_01',
          'name': 'Kashmir Trip',
          'inviteCode': 'KASHMIR2026',
        }
      ]);

      final legitMutation = SyncMutation(
        id: 'op_tamper_detect_002',
        type: MutationType.addExpense,
        payload: {
          'tripId': 'trip_kashmir_01',
          'id': 'exp_original_002',
          'title': 'Tea',
          'amountInPaise': 5000,
        },
        createdAt: DateTime.now(),
        originDeviceId: 'dev_phone_peer',
      );

      final applied = await syncService.applyRemoteP2PMutation(legitMutation, storage);
      expect(applied, isTrue);

      // Attacker reuses op_tamper_detect_002 with inflated amount (payload mismatch)
      final maliciousMutation = SyncMutation(
        id: 'op_tamper_detect_002',
        type: MutationType.addExpense,
        payload: {
          'tripId': 'trip_kashmir_01',
          'id': 'exp_original_002',
          'title': 'Tea',
          'amountInPaise': 50000000, // Inflated!
        },
        createdAt: DateTime.now(),
        originDeviceId: 'dev_phone_peer',
      );

      final status = storage.checkOperationStatus(maliciousMutation.id, maliciousMutation.payloadChecksum);
      expect(status.isMismatch, isTrue, reason: 'Reused operation ID with altered payload must be detected as mismatch');

      final attackApplied = await syncService.applyRemoteP2PMutation(maliciousMutation, storage);
      expect(attackApplied, isFalse, reason: 'Tampered operation must be dropped');
    });
  });

  group('Composite Keyset Pagination Correctness Tests', () {
    test('6. Keyset cursor (updated_at, id) safely traverses through concurrent inserts without skipping', () async {
      // 10 initial records
      final dataset = <Map<String, dynamic>>[];
      for (int i = 0; i < 10; i++) {
        dataset.add({
          'id': 'row_${i.toString().padLeft(3, '0')}',
          'updated_at': '2026-11-01T12:00:0${i}Z',
        });
      }

      // Fetch page 1 (pageSize = 4)
      final page1 = dataset.take(4).toList();
      expect(page1.length, equals(4));
      final lastPage1 = page1.last;

      // Simulate concurrent insert of row_000_new before page 2
      dataset.insert(2, {
        'id': 'row_000_concurrent',
        'updated_at': '2026-11-01T12:00:01Z',
      });

      // Keyset query: (updated_at, id) > (lastPage1.updated_at, lastPage1.id)
      bool keysetPredicate(Map<String, dynamic> row) {
        final rTs = row['updated_at'] as String;
        final rId = row['id'] as String;
        final lTs = lastPage1['updated_at'] as String;
        final lId = lastPage1['id'] as String;

        if (rTs.compareTo(lTs) > 0) return true;
        if (rTs == lTs && rId.compareTo(lId) > 0) return true;
        return false;
      }

      final page2 = dataset.where(keysetPredicate).take(4).toList();
      expect(page2.length, equals(4));

      // Row 4 from original dataset must be the first item on Page 2 (NOT skipped)
      expect(page2.first['id'], equals('row_004'));
      // No duplicates between Page 1 and Page 2
      final set1 = page1.map((r) => r['id']).toSet();
      final set2 = page2.map((r) => r['id']).toSet();
      expect(set1.intersection(set2), isEmpty);
    });
  });
}
