import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/enums/expense_category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;

  final creatorUser = GuestUser(
    id: 'usr_creator_1',
    displayName: 'Darpan Owner',
    avatarUrl: null,
    recoveryKey: 'rec_key_creator',
    anonymousToken: 'tok_creator',
    createdAt: DateTime.now(),
  );

  final realFriendUser = GuestUser(
    id: 'usr_friend_alice',
    displayName: 'Alice Real',
    avatarUrl: 'https://avatar.com/alice.png',
    recoveryKey: 'rec_key_alice',
    anonymousToken: 'tok_alice',
    createdAt: DateTime.now(),
    upiId: 'alice@upi',
  );

  final otherUser = GuestUser(
    id: 'usr_intruder_bob',
    displayName: 'Bob Intruder',
    avatarUrl: null,
    recoveryKey: 'rec_key_bob',
    anonymousToken: 'tok_bob',
    createdAt: DateTime.now(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    apiClient = ApiClient();
    syncService = SyncService(storage);
    tripRepo = TripRepository(
      storage: storage,
      apiClient: apiClient,
      syncService: syncService,
    );
    expenseRepo = ExpenseRepository(
      storage: storage,
      apiClient: apiClient,
      syncService: syncService,
    );
  });

  group('Phase 4 — Participant Identity & Secure Claiming Suite', () {
    test('1. Virtual participant claiming sets isVirtualMember=false, isClaimed=true, status=claimed, role=member', () async {
      final trip = await tripRepo.createTrip(
        name: 'Goa Adventure',
        creator: creatorUser,
        initialFriendNames: ['Alice'],
      );

      final virtualAlice = trip.members.firstWhere((m) => m.displayName == 'Alice');
      expect(virtualAlice.isVirtual, isTrue);
      expect(virtualAlice.isClaimed, isFalse);
      expect(virtualAlice.isVirtualMember, isTrue);
      expect(virtualAlice.userId.startsWith('unclaimed_'), isTrue);

      // Real Alice claims her participant slot
      final updatedTrip = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: realFriendUser,
        claimMemberId: virtualAlice.id,
        claimToken: virtualAlice.claimToken,
      );

      final claimedAlice = updatedTrip.members.firstWhere((m) => m.id == virtualAlice.id);
      expect(claimedAlice.id, equals(virtualAlice.id), reason: 'Participant ID must be preserved');
      expect(claimedAlice.userId, equals(realFriendUser.id));
      expect(claimedAlice.isVirtualMember, isFalse, reason: 'isVirtualMember must be set to false');
      expect(claimedAlice.isClaimed, isTrue);
      expect(claimedAlice.status, equals('claimed'));
      expect(claimedAlice.role, equals('member'));
      expect(claimedAlice.isVirtual, isFalse, reason: 'isVirtual getter must evaluate to false');
      expect(claimedAlice.isRegistered, isTrue);
      expect(claimedAlice.avatarUrl, equals(realFriendUser.avatarUrl));
      expect(claimedAlice.upiId, equals(realFriendUser.upiId));
    });

    test('2. Claimed participant identity preserves ID and updates profile', () async {
      final trip = await tripRepo.createTrip(
        name: 'Manali Trek',
        creator: creatorUser,
        initialFriendNames: ['Rohan'],
      );

      final virtualRohan = trip.members.firstWhere((m) => m.displayName == 'Rohan');
      final originalId = virtualRohan.id;

      final rohanUser = GuestUser(
        id: 'usr_rohan_99',
        displayName: 'Rohan Sharma',
        avatarUrl: null,
        recoveryKey: 'rec_rohan',
        anonymousToken: 'tok_rohan',
        createdAt: DateTime.now(),
      );

      final joined = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: rohanUser,
        claimMemberId: originalId,
        claimToken: virtualRohan.claimToken,
      );

      final rohan = joined.members.firstWhere((m) => m.id == originalId);
      expect(rohan.id, equals(originalId));
      expect(rohan.displayName, equals('Rohan Sharma'));
      expect(rohan.userId, equals('usr_rohan_99'));
      expect(rohan.isVirtual, isFalse);
    });

    test('3. Duplicate claim rejection: prevents claiming an already claimed participant', () async {
      final trip = await tripRepo.createTrip(
        name: 'Kerala Backwaters',
        creator: creatorUser,
        initialFriendNames: ['Alice'],
      );
      final virtualAlice = trip.members.firstWhere((m) => m.displayName == 'Alice');

      // Alice claims first
      await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: realFriendUser,
        claimMemberId: virtualAlice.id,
        claimToken: virtualAlice.claimToken,
      );

      // Other user attempts to claim the same participant (even with token, fails with ConflictException because already claimed)
      expect(
        () => tripRepo.joinTrip(
          inviteCodeOrId: trip.inviteCode,
          user: otherUser,
          claimMemberId: virtualAlice.id,
          claimToken: virtualAlice.claimToken,
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test('4. Duplicate claim rejection: prevents a user from claiming multiple members in same trip', () async {
      final trip = await tripRepo.createTrip(
        name: 'Ladakh Roadtrip',
        creator: creatorUser,
        initialFriendNames: ['Alice', 'Charlie'],
      );
      final virtualAlice = trip.members.firstWhere((m) => m.displayName == 'Alice');
      final virtualCharlie = trip.members.firstWhere((m) => m.displayName == 'Charlie');

      // User claims Alice
      await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: realFriendUser,
        claimMemberId: virtualAlice.id,
        claimToken: virtualAlice.claimToken,
      );

      // Same user attempts to claim Charlie as well
      expect(
        () => tripRepo.joinTrip(
          inviteCodeOrId: trip.inviteCode,
          user: realFriendUser,
          claimMemberId: virtualCharlie.id,
          claimToken: virtualCharlie.claimToken,
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test('5. Invalid claim token is strictly rejected', () async {
      final trip = await tripRepo.createTrip(
        name: 'Rajasthan Heritage',
        creator: creatorUser,
        initialFriendNames: ['SecretFriend'],
      );
      final virtualFriend = trip.members.firstWhere((m) => m.displayName == 'SecretFriend');
      expect(virtualFriend.claimToken, isNotNull);

      // Attempt to claim with wrong token
      expect(
        () => tripRepo.joinTrip(
          inviteCodeOrId: trip.inviteCode,
          user: realFriendUser,
          claimMemberId: virtualFriend.id,
          claimToken: 'clm_WRONG_TOKEN_123',
        ),
        throwsA(isA<UnauthorizedException>()),
      );

      // Attempt to claim with correct token succeeds
      final joined = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: realFriendUser,
        claimMemberId: virtualFriend.id,
        claimToken: virtualFriend.claimToken,
      );
      final claimed = joined.members.firstWhere((m) => m.id == virtualFriend.id);
      expect(claimed.isClaimed, isTrue);
      expect(claimed.isVirtual, isFalse);
    });

    test('6. Cross-trip claim rejection: cannot claim participant belonging to another trip', () async {
      final tripA = await tripRepo.createTrip(
        name: 'Trip Alpha',
        creator: creatorUser,
        initialFriendNames: ['FriendA'],
      );
      final tripB = await tripRepo.createTrip(
        name: 'Trip Beta',
        creator: creatorUser,
        initialFriendNames: ['FriendB'],
      );

      final memberA = tripA.members.firstWhere((m) => m.displayName == 'FriendA');

      // Attempt to join Trip B using participant ID from Trip A
      expect(
        () => tripRepo.joinTrip(
          inviteCodeOrId: tripB.inviteCode,
          user: realFriendUser,
          claimMemberId: memberA.id,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('7. Same-displayName users: never match or claim participants using displayName alone', () async {
      final trip = await tripRepo.createTrip(
        name: 'Pune Weekend',
        creator: creatorUser,
        initialFriendNames: ['SameNameUser'],
      );
      final virtualSameName = trip.members.firstWhere((m) => m.displayName == 'SameNameUser');

      final userWithSameName = GuestUser(
        id: 'usr_different_account',
        displayName: 'SameNameUser', // Identical display name
        avatarUrl: null,
        recoveryKey: 'rec_diff',
        anonymousToken: 'tok_diff',
        createdAt: DateTime.now(),
      );

      // Join WITHOUT claimMemberId (just entering code)
      final joinedTrip = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: userWithSameName,
      );

      // Must NOT accidentally claim virtualSameName! Must add a distinct member!
      expect(joinedTrip.members.length, equals(3));
      final stillVirtual = joinedTrip.members.firstWhere((m) => m.id == virtualSameName.id);
      expect(stillVirtual.isVirtual, isTrue, reason: 'Virtual member must remain virtual');
      expect(stillVirtual.isClaimed, isFalse);

      final newRealMember = joinedTrip.members.firstWhere((m) => m.userId == userWithSameName.id);
      expect(newRealMember.isClaimed, isTrue);
      expect(newRealMember.isVirtual, isFalse);
    });
  });

  group('Phase 5 — P2P & Cloud Sync Filtering Suite', () {
    test('8. Virtual participant exclusion from P2P eligible sync target list', () async {
      final trip = await tripRepo.createTrip(
        name: 'Goa Mesh',
        creator: creatorUser,
        initialFriendNames: ['Virtual1', 'Virtual2', 'Virtual3', 'Virtual4', 'Virtual5'],
      );

      // 1 Creator (Linked) + 5 Virtual
      expect(trip.members.length, 6);

      // Radar sheet filter: only linked, claimed KITH members
      final eligibleSyncMembers = trip.members.where((m) => !m.isVirtual && m.isClaimed).toList();
      expect(eligibleSyncMembers.length, equals(1));
      expect(eligibleSyncMembers.first.userId, equals(creatorUser.id));

      // 5 Virtual members are completely excluded from sync targets
      final virtualMembers = trip.members.where((m) => m.isVirtual).toList();
      expect(virtualMembers.length, equals(5));
      for (final vm in virtualMembers) {
        expect(eligibleSyncMembers.contains(vm), isFalse);
      }
    });

    test('9. Registered participant becomes eligible for sync upon legitimate claim', () async {
      final trip = await tripRepo.createTrip(
        name: 'Goa Mesh 2',
        creator: creatorUser,
        initialFriendNames: ['AliceVirtual'],
      );

      var eligible = trip.members.where((m) => !m.isVirtual && m.isClaimed).toList();
      expect(eligible.length, 1);

      final placeholderAlice = trip.members.firstWhere((m) => m.displayName == 'AliceVirtual');

      // Alice links her account
      final updatedTrip = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: realFriendUser,
        claimMemberId: placeholderAlice.id,
        claimToken: placeholderAlice.claimToken,
      );

      eligible = updatedTrip.members.where((m) => !m.isVirtual && m.isClaimed).toList();
      expect(eligible.length, 2);
      expect(eligible.any((m) => m.id == placeholderAlice.id && m.userId == realFriendUser.id), isTrue);
    });

    test('10. Expense split and balance preservation: virtual splits seamlessly transition to claimed user', () async {
      final trip = await tripRepo.createTrip(
        name: 'Expense Split Trip',
        creator: creatorUser,
        initialFriendNames: ['VirtualBob'],
      );
      final virtualBob = trip.members.firstWhere((m) => m.displayName == 'VirtualBob');

      // Creator adds expense of ₹100 split 50/50 with VirtualBob
      final expense = Expense(
        id: 'exp_split_1',
        tripId: trip.id,
        title: 'Dinner at Beach',
        category: ExpenseCategory.food,
        amountInPaise: 10000, // ₹100.00
        paidById: trip.members.firstWhere((m) => m.userId == creatorUser.id).id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        splits: [
          ExpenseSplit(
            memberId: trip.members.firstWhere((m) => m.userId == creatorUser.id).id,
            amountInPaise: 5000,
          ),
          ExpenseSplit(
            memberId: virtualBob.id,
            amountInPaise: 5000,
          ),
        ],
      );
      await expenseRepo.addExpense(expense);

      // Verify initial balance: Creator is owed ₹50, VirtualBob owes ₹50
      var balances = BalanceEngine.calculateBalances(
        members: trip.members,
        expenses: expenseRepo.getCachedExpenses(trip.id),
        settlements: const [],
        currentUserId: creatorUser.id,
      );
      expect(balances.currentUserNetBalanceInPaise, equals(5000));
      expect(balances.memberNetBalances[virtualBob.id], equals(-5000));

      // Bob installs KITH and claims his participant record
      final bobUser = GuestUser(
        id: 'usr_real_bob',
        displayName: 'Bob The Real',
        avatarUrl: null,
        recoveryKey: 'rec_bob',
        anonymousToken: 'tok_bob',
        createdAt: DateTime.now(),
      );
      final updatedTrip = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: bobUser,
        claimMemberId: virtualBob.id,
        claimToken: virtualBob.claimToken,
      );

      // Re-evaluate balances with claimed trip members
      final updatedBalances = BalanceEngine.calculateBalances(
        members: updatedTrip.members,
        expenses: expenseRepo.getCachedExpenses(trip.id),
        settlements: const [],
        currentUserId: creatorUser.id,
      );

      // Zero leakage, exact same balances preserved
      expect(updatedBalances.currentUserNetBalanceInPaise, equals(5000));
      expect(updatedBalances.memberNetBalances[virtualBob.id], equals(-5000));
    });

    test('11. Offline claim followed by online mergeWith preserves claimed status', () async {
      final localTrip = await tripRepo.createTrip(
        name: 'Merge Test Trip',
        creator: creatorUser,
        initialFriendNames: ['VirtualAlice'],
      );
      final virtualAlice = localTrip.members.firstWhere((m) => m.displayName == 'VirtualAlice');

      // Claim performed locally
      final claimedLocalTrip = await tripRepo.joinTrip(
        inviteCodeOrId: localTrip.inviteCode,
        user: realFriendUser,
        claimMemberId: virtualAlice.id,
        claimToken: virtualAlice.claimToken,
      );

      final claimedMember = claimedLocalTrip.members.firstWhere((m) => m.id == virtualAlice.id);
      expect(claimedMember.isVirtual, isFalse);
      expect(claimedMember.isClaimed, isTrue);

      // Simulate receiving older trip state from cloud server where Alice was still virtual
      final merged = claimedLocalTrip.mergeWith(localTrip);
      final mergedAlice = merged.members.firstWhere((m) => m.id == virtualAlice.id);

      // Merge must preserve the claimed status and not revert to virtual
      expect(mergedAlice.isClaimed, isTrue);
      expect(mergedAlice.isVirtual, isFalse);
      expect(mergedAlice.userId, equals(realFriendUser.id));
    });
  });
}
