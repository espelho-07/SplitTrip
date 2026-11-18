import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/data/services/local_database_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';

void main() {
  final now = DateTime.now();

  group('Gate G: Trip.mergeWithDetailed & Identity Translation Tests', () {
    test('1. Preserves and maps member IDs when matching by claimToken', () {
      final localCreator = TripMember(
        id: 'mbr_client_creator',
        userId: 'usr_creator',
        displayName: 'Dj',
        role: 'creator',
        isClaimed: true,
        joinedAt: now,
      );
      final localFriendK = TripMember(
        id: 'mbr_client_k',
        userId: 'unclaimed_k',
        displayName: 'K',
        claimToken: 'clm_token_k_123',
        role: 'member',
        isClaimed: false,
        isVirtualMember: true,
        joinedAt: now,
      );

      final localTrip = Trip(
        id: 'trip_001',
        name: 'Goa Trip',
        creatorId: 'usr_creator',
        members: [localCreator, localFriendK],
        inviteCode: 'GOA123',
        createdAt: now,
        updatedAt: now,
      );

      final serverFriendK = TripMember(
        id: 'mbr_server_k_999',
        userId: 'unclaimed_k',
        displayName: 'K',
        claimToken: 'clm_token_k_123',
        role: 'member',
        isClaimed: false,
        isVirtualMember: true,
        joinedAt: now,
      );

      final serverTrip = Trip(
        id: 'trip_001',
        name: 'Goa Trip',
        creatorId: 'usr_creator',
        members: [localCreator, serverFriendK],
        inviteCode: 'GOA123',
        revision: 2,
        createdAt: now,
        updatedAt: now,
      );

      final result = localTrip.mergeWithDetailed(serverTrip);

      expect(result.memberIdMap['mbr_client_k'], equals('mbr_server_k_999'));
      expect(result.mergedTrip.members.length, equals(2));
      expect(result.mergedTrip.members.any((m) => m.id == 'mbr_server_k_999'), isTrue);
      expect(result.unresolvedMemberIds, isEmpty);
    });

    test('2. Preserves and maps member IDs when matching by authenticated userId', () {
      final localMember = TripMember(
        id: 'mbr_local_user',
        userId: 'usr_real_alice',
        displayName: 'Alice',
        role: 'member',
        isClaimed: true,
        joinedAt: now,
      );

      final localTrip = Trip(
        id: 'trip_002',
        name: 'Camping',
        creatorId: 'usr_creator',
        members: [localMember],
        inviteCode: 'CAMP01',
        createdAt: now,
        updatedAt: now,
      );

      final serverMember = TripMember(
        id: 'mbr_server_user_888',
        userId: 'usr_real_alice',
        displayName: 'Alice M',
        role: 'member',
        isClaimed: true,
        joinedAt: now,
      );

      final serverTrip = Trip(
        id: 'trip_002',
        name: 'Camping',
        creatorId: 'usr_creator',
        members: [serverMember],
        inviteCode: 'CAMP01',
        revision: 2,
        createdAt: now,
        updatedAt: now,
      );

      final result = localTrip.mergeWithDetailed(serverTrip);

      expect(result.memberIdMap['mbr_local_user'], equals('mbr_server_user_888'));
      expect(result.mergedTrip.members.first.id, equals('mbr_server_user_888'));
      expect(result.mergedTrip.members.first.displayName, equals('Alice M'));
    });

    test('3. Detects ambiguous members with identical names and does NOT guess', () {
      final localK1 = TripMember(
        id: 'mbr_local_k1',
        userId: 'unclaimed_1',
        displayName: 'K',
        role: 'member',
        isVirtualMember: true,
        joinedAt: now,
      );
      final localK2 = TripMember(
        id: 'mbr_local_k2',
        userId: 'unclaimed_2',
        displayName: 'K',
        role: 'member',
        isVirtualMember: true,
        joinedAt: now,
      );

      final localTrip = Trip(
        id: 'trip_003',
        name: 'Ambiguous Trip',
        creatorId: 'usr_creator',
        members: [localK1, localK2],
        inviteCode: 'AMBIG1',
        createdAt: now,
        updatedAt: now,
      );

      final serverK = TripMember(
        id: 'mbr_server_k_single',
        userId: 'unclaimed_srv',
        displayName: 'K',
        role: 'member',
        isVirtualMember: true,
        joinedAt: now,
      );

      final serverTrip = Trip(
        id: 'trip_003',
        name: 'Ambiguous Trip',
        creatorId: 'usr_creator',
        members: [serverK],
        inviteCode: 'AMBIG1',
        revision: 2,
        createdAt: now,
        updatedAt: now,
      );

      final result = localTrip.mergeWithDetailed(serverTrip);

      // Must NOT guess which K maps to mbr_server_k_single!
      expect(result.memberIdMap.containsKey('mbr_local_k1'), isFalse);
      expect(result.memberIdMap.containsKey('mbr_local_k2'), isFalse);
      expect(result.unresolvedMemberIds, containsAll(['mbr_local_k1', 'mbr_local_k2']));
    });

    test('4. Backward compatible mergeWith delegates to mergeWithDetailed', () {
      final localMember = TripMember(
        id: 'mbr_m1',
        userId: 'usr_1',
        displayName: 'Member 1',
        role: 'creator',
        joinedAt: now,
      );
      final trip1 = Trip(
        id: 't_compat',
        name: 'Trip 1',
        creatorId: 'usr_1',
        members: [localMember],
        inviteCode: 'COMP01',
        createdAt: now,
        updatedAt: now,
      );
      final trip2 = Trip(
        id: 't_compat',
        name: 'Trip 1 Updated',
        creatorId: 'usr_1',
        members: [localMember],
        inviteCode: 'COMP01',
        revision: 5,
        createdAt: now,
        updatedAt: now,
      );

      final merged = trip1.mergeWith(trip2);
      expect(merged.name, equals('Trip 1 Updated'));
      expect(merged.revision, equals(5));
    });
  });

  group('Gate G: LocalDatabaseService Transactional Member ID Translation Tests', () {
    late LocalDatabaseService dbService;

    setUp(() {
      dbService = LocalDatabaseService.inMemory();
    });

    tearDown(() {
      dbService.dispose();
    });

    test('5. Atomically translates expenses, settlements, and outbox in SQLite', () {
      final tripId = 'trip_aba271e62650';
      final oldDj = 'mbr_e4d349ab54';
      final oldK = 'mbr_74bef53ce3';
      final oldB = 'mbr_fb6d234191';

      final newDj = 'mbr_d7a0c7104b';
      final newK = 'mbr_4f5ba67530';
      final newB = 'mbr_bcf72c1143';

      final translationMap = {
        oldDj: newDj,
        oldK: newK,
        oldB: newB,
      };

      // 1. Insert mock expense
      final rawExpense = {
        'id': 'exp_birthday_cake',
        'tripId': tripId,
        'title': 'Birthday Cake',
        'amount': 1500.0,
        'amountInPaise': 150000,
        'paidById': oldDj,
        'splits': [
          {'memberId': oldDj, 'amount': 500.0, 'amountInPaise': 50000},
          {'memberId': oldK, 'amount': 500.0, 'amountInPaise': 50000},
          {'memberId': oldB, 'amount': 500.0, 'amountInPaise': 50000},
        ],
      };

      dbService.commitAtomicMutationBatch(
        updatedExpensesByTrip: {
          tripId: [rawExpense],
        },
      );

      // 2. Insert mock settlement
      final rawSettlement = {
        'id': 'stl_001',
        'tripId': tripId,
        'fromMemberId': oldK,
        'toMemberId': oldDj,
        'amount': 500.0,
        'isSettled': false,
      };

      dbService.commitAtomicMutationBatch(
        updatedSettlementsByTrip: {
          tripId: [rawSettlement],
        },
      );

      // 3. Insert mock quarantined outbox mutation
      final rawOutbox = {
        'id': 'mut_create_cake',
        'type': 'createExpense',
        'mutation_type': 'createExpense',
        'tripId': tripId,
        'trip_id': tripId,
        'status': 'quarantined',
        'syncState': 'quarantined',
        'retryCount': 26,
        'retry_count': 26,
        'error': 'Payer member is not part of this trip',
        'lastError': 'Payer member is not part of this trip',
        'payload': {
          'title': 'Birthday Cake',
          'amountInPaise': 150000,
          'paidById': oldDj,
          'splits': [
            {'memberId': oldDj, 'amountInPaise': 50000},
            {'memberId': oldK, 'amountInPaise': 50000},
            {'memberId': oldB, 'amountInPaise': 50000},
          ],
        },
      };

      dbService.commitAtomicMutationBatch(
        updatedOutbox: [rawOutbox],
      );

      // Execute translation
      final modified = dbService.translateMemberIds(
        tripId: tripId,
        translationMap: translationMap,
      );

      expect(modified, isTrue);

      // Verify Expenses
      final expenses = dbService.getSavedExpenses(tripId);
      expect(expenses.length, equals(1));
      final exp = expenses.first;
      expect(exp['paidById'], equals(newDj));
      final splits = exp['splits'] as List<dynamic>;
      expect(splits[0]['memberId'], equals(newDj));
      expect(splits[1]['memberId'], equals(newK));
      expect(splits[2]['memberId'], equals(newB));

      // Verify Settlements
      final settlements = dbService.getSavedSettlements(tripId);
      expect(settlements.length, equals(1));
      final stl = settlements.first;
      expect(stl['fromMemberId'], equals(newK));
      expect(stl['toMemberId'], equals(newDj));

      // Verify Outbox Mutation Recovery
      final outbox = dbService.getOutboxMutations();
      expect(outbox.length, equals(1));
      final mut = outbox.first;
      final payload = mut['payload'] as Map<String, dynamic>;
      expect(payload['paidById'], equals(newDj));
      expect(payload['splits'][0]['memberId'], equals(newDj));
      expect(payload['splits'][1]['memberId'], equals(newK));
      expect(payload['splits'][2]['memberId'], equals(newB));

      // Outbox status must be reset to pending and retryCount reset to 0!
      expect(mut['syncState'], equals('localPending'));
      expect(mut['retryCount'], equals(0));
      expect(mut['lastError'], isNull);
    });
  });

  group('Gate G: LocalStorageService SharedPreferences Cache Translation Tests', () {
    test('6. Synchronizes SharedPreferences caches alongside SQLite', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final tripId = 'trip_sync_prefs_001';
      final oldId = 'mbr_old_111';
      final newId = 'mbr_new_222';

      await storage.saveExpenses(tripId, [
        {
          'id': 'exp_01',
          'tripId': tripId,
          'paidById': oldId,
          'splits': [
            {'memberId': oldId, 'amount': 100.0},
          ],
        }
      ]);

      await storage.saveTripSettlements(tripId, [
        {
          'id': 'stl_01',
          'tripId': tripId,
          'fromMemberId': oldId,
          'toMemberId': 'mbr_other',
        }
      ]);

      await storage.saveMutationQueue([
        {
          'id': 'mut_01',
          'tripId': tripId,
          'status': 'quarantined',
          'syncState': 'quarantined',
          'retryCount': 5,
          'payload': {
            'paidById': oldId,
            'splits': [
              {'memberId': oldId, 'amountInPaise': 10000},
            ],
          },
        }
      ]);

      await storage.translateMemberIds(
        tripId: tripId,
        translationMap: {oldId: newId},
      );

      final expenses = storage.getSavedExpenses(tripId);
      expect(expenses.first['paidById'], equals(newId));
      expect((expenses.first['splits'] as List).first['memberId'], equals(newId));

      final settlements = storage.getSavedTripSettlements(tripId);
      expect(settlements.first['fromMemberId'], equals(newId));

      final queue = storage.getMutationQueue();
      final mut = queue.first;
      expect((mut['payload'] as Map)['paidById'], equals(newId));
      expect(mut['status'], equals('pending'));
      expect(mut['syncState'], equals('localPending'));
      expect(mut['retryCount'], equals(0));
    });
  });

  group('Gate G: Financial Invariants & BalanceEngine Verification', () {
    test('7. Proves zero-balance UI collapse defect is resolved after member ID translation', () {
      final tripId = 'trip_aba271e62650';

      final memberDj = TripMember(
        id: 'mbr_d7a0c7104b',
        userId: 'usr_dj_actual',
        displayName: 'Dj',
        role: 'creator',
        joinedAt: now,
      );
      final memberK = TripMember(
        id: 'mbr_4f5ba67530',
        userId: 'unclaimed_k',
        displayName: 'K',
        role: 'member',
        isVirtualMember: true,
        joinedAt: now,
      );
      final memberB = TripMember(
        id: 'mbr_bcf72c1143',
        userId: 'unclaimed_b',
        displayName: 'B',
        role: 'member',
        isVirtualMember: true,
        joinedAt: now,
      );

      final members = [memberDj, memberK, memberB];

      // Reconstructed 5 Birthday Bash expenses (totaling ₹3,133.00 = 313,300 paise)
      final legacyDj = 'mbr_e4d349ab54';
      final legacyK = 'mbr_74bef53ce3';
      final legacyB = 'mbr_fb6d234191';

      final legacyExpenses = [
        Expense(
          id: 'exp_01',
          tripId: tripId,
          title: 'Petrol',
          amountInPaise: 50000,
          category: ExpenseCategory.transport,
          paidById: legacyDj,
          splits: [
            ExpenseSplit(memberId: legacyDj, amountInPaise: 16667),
            ExpenseSplit(memberId: legacyK, amountInPaise: 16667),
            ExpenseSplit(memberId: legacyB, amountInPaise: 16666),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        Expense(
          id: 'exp_02',
          tripId: tripId,
          title: 'Snacks',
          amountInPaise: 40000,
          category: ExpenseCategory.food,
          paidById: legacyDj,
          splits: [
            ExpenseSplit(memberId: legacyDj, amountInPaise: 13334),
            ExpenseSplit(memberId: legacyK, amountInPaise: 13333),
            ExpenseSplit(memberId: legacyB, amountInPaise: 13333),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        Expense(
          id: 'exp_03',
          tripId: tripId,
          title: 'Dinner',
          amountInPaise: 120000,
          category: ExpenseCategory.food,
          paidById: legacyDj,
          splits: [
            ExpenseSplit(memberId: legacyDj, amountInPaise: 40000),
            ExpenseSplit(memberId: legacyK, amountInPaise: 40000),
            ExpenseSplit(memberId: legacyB, amountInPaise: 40000),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        Expense(
          id: 'exp_04',
          tripId: tripId,
          title: 'Dessert',
          amountInPaise: 33300,
          category: ExpenseCategory.food,
          paidById: legacyDj,
          splits: [
            ExpenseSplit(memberId: legacyDj, amountInPaise: 11100),
            ExpenseSplit(memberId: legacyK, amountInPaise: 11100),
            ExpenseSplit(memberId: legacyB, amountInPaise: 11100),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        Expense(
          id: 'exp_05',
          tripId: tripId,
          title: 'Entry Tickets',
          amountInPaise: 70000,
          category: ExpenseCategory.general,
          paidById: legacyDj,
          splits: [
            ExpenseSplit(memberId: legacyDj, amountInPaise: 23334),
            ExpenseSplit(memberId: legacyK, amountInPaise: 23333),
            ExpenseSplit(memberId: legacyB, amountInPaise: 23333),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // A. DEFECT DEMONSTRATION: With legacy IDs, BalanceEngine collapses all active balances to 0!
      final defectSummary = BalanceEngine.calculateBalances(
        members: members,
        expenses: legacyExpenses,
        currentUserId: 'usr_dj_actual',
      );

      expect(defectSummary.totalTripSpentInPaise, equals(313300)); // ₹3,133.00 is spent
      expect(defectSummary.memberNetBalances[memberDj.id], equals(0)); // Dj = ₹0.00 (COLLAPSE!)
      expect(defectSummary.memberNetBalances[memberK.id], equals(0));  // K = ₹0.00 (COLLAPSE!)
      expect(defectSummary.memberNetBalances[memberB.id], equals(0));  // B = ₹0.00 (COLLAPSE!)
      expect(defectSummary.debtsToReceive, isEmpty);                    // Zero settlements!

      // B. RESOLUTION: After deterministic member ID translation
      final translatedExpenses = legacyExpenses.map((e) {
        return e.copyWith(
          paidById: memberDj.id,
          splits: e.splits.map((s) {
            String targetId = s.memberId;
            if (s.memberId == legacyDj) targetId = memberDj.id;
            if (s.memberId == legacyK) targetId = memberK.id;
            if (s.memberId == legacyB) targetId = memberB.id;
            return ExpenseSplit(
              memberId: targetId,
              amountInPaise: s.amountInPaise,
            );
          }).toList(),
        );
      }).toList();

      final resolvedSummary = BalanceEngine.calculateBalances(
        members: members,
        expenses: translatedExpenses,
        currentUserId: 'usr_dj_actual',
      );

      // FINANCIAL INVARIANTS:
      // 1. Total spent matches exactly
      expect(resolvedSummary.totalTripSpentInPaise, equals(313300));

      // 2. Dj paid ₹3,133.00 and is owed money
      final djNet = resolvedSummary.memberNetBalances[memberDj.id]!;
      final kNet = resolvedSummary.memberNetBalances[memberK.id]!;
      final bNet = resolvedSummary.memberNetBalances[memberB.id]!;

      expect(djNet, isPositive);
      expect(kNet, isNegative);
      expect(bNet, isNegative);

      // 3. Sum of all net balances is strictly zero (zero drift)
      final netSum = djNet + kNet + bNet;
      expect(netSum, equals(0));

      // 4. Simplified debts exist and clear all liabilities
      expect(resolvedSummary.debtsToReceive, isNotEmpty);
      final totalDebtOwedToDj = resolvedSummary.debtsToReceive.fold<int>(
        0,
        (sum, d) => sum + d.amountInPaise,
      );
      expect(totalDebtOwedToDj, equals(djNet));
    });
  });
}
