import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data Storage & Local Database Integrity Suite', () {
    late LocalDatabaseService dbService;
    late SharedPreferences prefs;
    late LocalStorageService storage;
    const tripId = 'trip_integrity_100';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      dbService = LocalDatabaseService.inMemory();
      storage = LocalStorageService(prefs, databaseService: dbService);
    });

    test('1. Granular SQLite Upsert: Adding an expense preserves existing expenses for the trip', () {
      final exp1 = {
        'id': 'exp_001',
        'tripId': tripId,
        'title': 'Train tickets',
        'amount': 5000.0,
        'category': 'transport',
        'paidById': 'mbr_alice',
        'splitType': 'equal',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // 1. Commit first expense
      dbService.commitAtomicMutationBatch(
        updatedExpensesByTrip: {
          tripId: [exp1],
        },
      );

      var saved = dbService.getSavedExpenses(tripId);
      expect(saved.length, equals(1));
      expect(saved.first['id'], equals('exp_001'));

      // 2. Commit second expense in a separate batch
      final exp2 = {
        'id': 'exp_002',
        'tripId': tripId,
        'title': 'Dinner',
        'amount': 2500.0,
        'category': 'food',
        'paidById': 'mbr_bob',
        'splitType': 'equal',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      dbService.commitAtomicMutationBatch(
        updatedExpensesByTrip: {
          tripId: [exp1, exp2],
        },
      );

      saved = dbService.getSavedExpenses(tripId);
      expect(saved.length, equals(2));
      expect(saved.any((e) => e['id'] == 'exp_001'), isTrue);
      expect(saved.any((e) => e['id'] == 'exp_002'), isTrue);
    });

    test('2. Outbox Protection: Expenses pending in mutation outbox are never purged by sync updates', () {
      // 1. Put an un-synced expense in outbox
      final pendingOutbox = [
        {
          'id': 'mut_offline_999',
          'type': 'addExpense',
          'tripId': tripId,
          'payload': {
            'id': 'exp_offline_pending',
            'tripId': tripId,
            'title': 'Local offline purchase',
            'amount': 1200.0,
          },
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
        }
      ];

      final existingExpense = {
        'id': 'exp_offline_pending',
        'tripId': tripId,
        'title': 'Local offline purchase',
        'amount': 1200.0,
        'category': 'general',
        'paidById': 'mbr_alice',
        'splitType': 'equal',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      dbService.commitAtomicMutationBatch(
        updatedExpensesByTrip: {
          tripId: [existingExpense],
        },
        updatedOutbox: pendingOutbox,
      );

      // 2. Now a partial server sync update arrives containing only a different expense (exp_server_001)
      final serverExpense = {
        'id': 'exp_server_001',
        'tripId': tripId,
        'title': 'Cloud Expense',
        'amount': 3000.0,
        'category': 'food',
        'paidById': 'mbr_bob',
        'splitType': 'equal',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      dbService.commitAtomicMutationBatch(
        updatedExpensesByTrip: {
          tripId: [serverExpense],
        },
      );

      // The un-synced outbox expense must STILL exist in the SQLite database! Zero silent data loss!
      final saved = dbService.getSavedExpenses(tripId);
      expect(saved.length, equals(2));
      expect(saved.any((e) => e['id'] == 'exp_offline_pending'), isTrue);
      expect(saved.any((e) => e['id'] == 'exp_server_001'), isTrue);
    });

    test('3. Explicit Tombstone: tombstoneToAdd deletes target expense from SQLite and records tombstone', () {
      final exp = {
        'id': 'exp_to_delete',
        'tripId': tripId,
        'title': 'Cancelled cab',
        'amount': 450.0,
        'category': 'transport',
        'paidById': 'mbr_alice',
        'splitType': 'equal',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      dbService.commitAtomicMutationBatch(
        updatedExpensesByTrip: {
          tripId: [exp],
        },
      );
      expect(dbService.getSavedExpenses(tripId).length, equals(1));

      // Execute atomic deletion with tombstone
      dbService.commitAtomicMutationBatch(
        tombstoneToAdd: {'tripId': tripId, 'expenseId': 'exp_to_delete'},
      );

      // Must be deleted from expenses table
      expect(dbService.getSavedExpenses(tripId), isEmpty);

      // Must be recorded in expense_tombstones table
      final tombstones = dbService.getDeletedExpenseTombstones(tripId);
      expect(tombstones.containsKey('exp_to_delete'), isTrue);
    });

    test('4. Security & Secret Hygiene: saveUserToRecoveryVault sanitizes tokens from SharedPreferences', () async {
      final userWithTokens = {
        'id': 'usr_alice_001',
        'displayName': 'Alice Traveler',
        'recoveryKey': 'KITH-SAFE-KEY1',
        'anonymousToken': 'kith_sess_super_secret_token_123456',
        'token': 'bearer_secret_xyz',
        'sessionToken': 'sensitive_jwt_token',
      };

      await storage.saveUserToRecoveryVault(userWithTokens);

      final rawVault = prefs.getString('kith_recovery_vault');
      expect(rawVault, isNotNull);

      final vaultMap = jsonDecode(rawVault!) as Map<String, dynamic>;
      final storedUser = vaultMap['KITH-SAFE-KEY1'] as Map<String, dynamic>;

      // Verified: Tokens are strictly stripped before writing to SharedPreferences!
      expect(storedUser.containsKey('anonymousToken'), isFalse);
      expect(storedUser.containsKey('token'), isFalse);
      expect(storedUser.containsKey('sessionToken'), isFalse);
      expect(storedUser['id'], equals('usr_alice_001'));
      expect(storedUser['displayName'], equals('Alice Traveler'));
    });
  });
}
