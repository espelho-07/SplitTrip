import 'package:flutter_test/flutter_test.dart';

import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  final now = DateTime.now();

  group('Gate G.2: Fix 1 — Display-Name Matching Elimination & Duplicate Name Preservation', () {
    test('1. Reconciles single unclaimed virtual placeholder when display name matches', () {
      final localK = TripMember(
        id: 'mbr_local_k_untokened',
        userId: 'unclaimed_local_k',
        displayName: 'K',
        role: 'member',
        isVirtualMember: true,
        isClaimed: false,
        joinedAt: now,
      );

      final localTrip = Trip(
        id: 'trip_g2_01',
        name: 'Birthday Bash',
        creatorId: 'usr_dj',
        members: [localK],
        inviteCode: 'BBASH1',
        createdAt: now,
        updatedAt: now,
      );

      final serverK = TripMember(
        id: 'mbr_server_k_new_id',
        userId: 'unclaimed_server_k',
        displayName: 'K',
        role: 'member',
        isVirtualMember: true,
        isClaimed: false,
        joinedAt: now,
      );

      final serverTrip = Trip(
        id: 'trip_g2_01',
        name: 'Birthday Bash',
        creatorId: 'usr_dj',
        members: [serverK],
        inviteCode: 'BBASH1',
        revision: 2,
        createdAt: now,
        updatedAt: now,
      );

      final result = localTrip.mergeWithDetailed(serverTrip);

      // Reconciles single unclaimed virtual member to prevent duplicate member bug
      expect(result.memberIdMap['mbr_local_k_untokened'], equals('mbr_server_k_new_id'));
      expect(result.mergedTrip.members.length, equals(1));
      expect(result.mergedTrip.members.first.id, equals('mbr_server_k_new_id'));
      expect(result.unresolvedMemberIds, isEmpty);
    });

    test('2. Preserves multiple distinct members with identical display names (never dropped)', () {
      final alex1 = TripMember(
        id: 'mbr_alex_1',
        userId: 'unclaimed_alex_1',
        displayName: 'Alex',
        claimToken: 'tok_alex_1',
        role: 'member',
        isVirtualMember: true,
        isClaimed: false,
        joinedAt: now,
      );

      final alex2 = TripMember(
        id: 'mbr_alex_2',
        userId: 'unclaimed_alex_2',
        displayName: 'Alex',
        claimToken: 'tok_alex_2',
        role: 'member',
        isVirtualMember: true,
        isClaimed: false,
        joinedAt: now,
      );

      final localTrip = Trip(
        id: 'trip_g2_02',
        name: 'Alex Party',
        creatorId: 'usr_dj',
        members: [alex1, alex2],
        inviteCode: 'ALEX01',
        createdAt: now,
        updatedAt: now,
      );

      final serverAlex1 = TripMember(
        id: 'mbr_server_alex_1',
        userId: 'unclaimed_alex_1',
        displayName: 'Alex',
        claimToken: 'tok_alex_1',
        role: 'member',
        isVirtualMember: true,
        isClaimed: false,
        joinedAt: now,
      );

      final serverAlex2 = TripMember(
        id: 'mbr_server_alex_2',
        userId: 'unclaimed_alex_2',
        displayName: 'Alex',
        claimToken: 'tok_alex_2',
        role: 'member',
        isVirtualMember: true,
        isClaimed: false,
        joinedAt: now,
      );

      final serverTrip = Trip(
        id: 'trip_g2_02',
        name: 'Alex Party',
        creatorId: 'usr_dj',
        members: [serverAlex1, serverAlex2],
        inviteCode: 'ALEX01',
        revision: 2,
        createdAt: now,
        updatedAt: now,
      );

      final result = localTrip.mergeWithDetailed(serverTrip);

      // Deterministically maps based on claimToken:
      expect(result.memberIdMap['mbr_alex_1'], equals('mbr_server_alex_1'));
      expect(result.memberIdMap['mbr_alex_2'], equals('mbr_server_alex_2'));

      // Both Alexes are preserved!
      expect(result.mergedTrip.members.length, equals(2));
      expect(result.mergedTrip.members.map((m) => m.id).toSet(), equals({'mbr_server_alex_1', 'mbr_server_alex_2'}));
      expect(result.unresolvedMemberIds, isEmpty);
    });

    test('3. Preserves unresolved members and their expense references', () {
      final unmappedLocalMember = TripMember(
        id: 'mbr_unmapped_k',
        userId: 'unclaimed_k',
        displayName: 'K',
        role: 'member',
        isVirtualMember: true,
        isClaimed: false,
        joinedAt: now,
      );

      final localTrip = Trip(
        id: 'trip_g2_03',
        name: 'Goa',
        creatorId: 'usr_dj',
        members: [unmappedLocalMember],
        inviteCode: 'GOA001',
        createdAt: now,
        updatedAt: now,
      );

      final remoteMember = TripMember(
        id: 'mbr_server_unrelated',
        userId: 'unclaimed_other',
        displayName: 'Different Person',
        role: 'member',
        isVirtualMember: true,
        isClaimed: false,
        joinedAt: now,
      );

      final serverTrip = Trip(
        id: 'trip_g2_03',
        name: 'Goa',
        creatorId: 'usr_dj',
        members: [remoteMember],
        inviteCode: 'GOA001',
        revision: 2,
        createdAt: now,
        updatedAt: now,
      );

      final result = localTrip.mergeWithDetailed(serverTrip);

      // Local member is preserved with original ID
      expect(result.mergedTrip.members.any((m) => m.id == 'mbr_unmapped_k'), isTrue);

      // An expense paid by mbr_unmapped_k remains fully resolvable
      final expense = Expense(
        id: 'exp_001',
        tripId: 'trip_g2_03',
        title: 'Snacks',
        amountInPaise: 50000,
        paidById: 'mbr_unmapped_k',
        category: ExpenseCategory.food,
        splits: [
          const ExpenseSplit(memberId: 'mbr_unmapped_k', amountInPaise: 25000),
          const ExpenseSplit(memberId: 'mbr_server_unrelated', amountInPaise: 25000),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final balanceSummary = BalanceEngine.calculateBalances(
        expenses: [expense],
        members: result.mergedTrip.members,
        currentUserId: 'unclaimed_k',
      );

      expect(balanceSummary.memberNetBalances['mbr_unmapped_k'], equals(25000));
      expect(balanceSummary.memberNetBalances['mbr_server_unrelated'], equals(-25000));
    });
  });

  group('Gate G.2: Fix 2 — Strict Claim Token Validation on Client-Side Claim Logic', () {
    test('4. Participant claiming requires matching claimToken when participant has one', () {
      final virtualMember = TripMember(
        id: 'mbr_target_01',
        userId: 'unclaimed_v1',
        displayName: 'Alice',
        claimToken: 'clm_alice_secret_token_999',
        role: 'member',
        isVirtualMember: true,
        isClaimed: false,
        joinedAt: now,
      );

      final trip = Trip(
        id: 'trip_test_claim',
        name: 'Claim Test',
        creatorId: 'usr_dj',
        members: [virtualMember],
        inviteCode: 'CLM001',
        createdAt: now,
        updatedAt: now,
      );

      final claimingUser = GuestUser(
        id: 'usr_alice_real',
        displayName: 'Alice Real',
        avatarUrl: null,
        recoveryKey: 'key_123',
        anonymousToken: 'tok_anon_123',
        createdAt: now,
      );

      // A. Missing claimToken must throw UnauthorizedException
      expect(
        () => TripRepository.processLocalParticipantClaim(
          trip,
          claimingUser,
          claimMemberId: 'mbr_target_01',
          claimToken: null,
        ),
        throwsA(isA<UnauthorizedException>()),
      );

      // B. Incorrect claimToken must throw UnauthorizedException
      expect(
        () => TripRepository.processLocalParticipantClaim(
          trip,
          claimingUser,
          claimMemberId: 'mbr_target_01',
          claimToken: 'wrong_token',
        ),
        throwsA(isA<UnauthorizedException>()),
      );

      // C. Correct claimToken must succeed
      final claimedTrip = TripRepository.processLocalParticipantClaim(
        trip,
        claimingUser,
        claimMemberId: 'mbr_target_01',
        claimToken: 'clm_alice_secret_token_999',
      );

      final claimedMember = claimedTrip.members.firstWhere((m) => m.id == 'mbr_target_01');
      expect(claimedMember.userId, equals('usr_alice_real'));
      expect(claimedMember.isClaimed, isTrue);
      expect(claimedMember.isVirtual, isFalse);

      // D. Attempting to claim already-claimed participant throws ConflictException
      expect(
        () => TripRepository.processLocalParticipantClaim(
          claimedTrip,
          GuestUser(id: 'usr_eve', displayName: 'Eve', recoveryKey: 'key_eve',
          anonymousToken: 'tok_eve_123', createdAt: now),
          claimMemberId: 'mbr_target_01',
          claimToken: 'clm_alice_secret_token_999',
        ),
        throwsA(isA<ConflictException>()),
      );
    });
  });
}
