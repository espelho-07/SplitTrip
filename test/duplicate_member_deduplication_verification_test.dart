import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  group('Trip Member Deduplication & Identity Matching Tests (Gate G.2/G.3 Invariants)', () {
    test('mergeWith reconciles single unclaimed virtual member with same display name when no claimToken or userId matches', () {
      final now = DateTime.now();
      final localMember = TripMember(
        id: 'mbr_client_123',
        userId: 'unclaimed_client_abc',
        displayName: 'xyz',
        joinedAt: now,
        isVirtualMember: true,
        isClaimed: false,
        status: 'unclaimed',
      );

      final creator = TripMember(
        id: 'mbr_creator',
        userId: 'user_creator_id',
        displayName: 'You (Creator)',
        joinedAt: now,
        isVirtualMember: false,
        isClaimed: true,
        role: 'creator',
      );

      final localTrip = Trip(
        id: 'trip_1',
        name: 'Goa',
        creatorId: 'user_creator_id',
        inviteCode: 'GOA123',
        members: [creator, localMember],
        createdAt: now,
        updatedAt: now,
      );

      // Server returns another member with a backend-assigned ID but NO claimToken matching localMember
      final serverMember = TripMember(
        id: 'mbr_server_999',
        userId: 'unclaimed_server_xyz',
        displayName: 'xyz',
        joinedAt: now,
        isVirtualMember: true,
        isClaimed: false,
        status: 'unclaimed',
      );

      final serverTrip = Trip(
        id: 'trip_1',
        name: 'Goa',
        creatorId: 'user_creator_id',
        inviteCode: 'GOA123',
        members: [creator, serverMember],
        createdAt: now,
        updatedAt: now.add(const Duration(seconds: 1)),
        revision: 2,
      );

      final mergedResult = localTrip.mergeWithDetailed(serverTrip);
      final merged = mergedResult.mergedTrip;

      // Invariant: Single unclaimed virtual placeholder with identical display name is reconciled
      // to prevent duplicate member bugs in the UI and allow outbox translations.
      expect(merged.members.length, equals(2));
      final xyzMembers = merged.members.where((m) => m.displayName.toLowerCase() == 'xyz').toList();
      expect(xyzMembers.length, equals(1));
      expect(xyzMembers.first.id, equals('mbr_server_999'));
      // Translation correctly maps client ID to server ID
      expect(mergedResult.memberIdMap['mbr_client_123'], equals('mbr_server_999'));
    });

    test('deduplicateMembers collapses duplicate unclaimed entries sharing same clean name', () {
      final now = DateTime.now();
      final member1 = TripMember(
        id: 'mbr_1',
        userId: 'unclaimed_1',
        displayName: '  rahul  ',
        joinedAt: now,
        isVirtualMember: true,
        isClaimed: false,
      );
      final member2 = TripMember(
        id: 'mbr_2',
        userId: 'unclaimed_2',
        displayName: 'Rahul',
        joinedAt: now.add(const Duration(seconds: 1)),
        isVirtualMember: true,
        isClaimed: false,
      );

      final trip = Trip(
        id: 'trip_1',
        name: 'Manali',
        creatorId: 'c1',
        inviteCode: 'M1',
        members: [member1, member2],
        createdAt: now,
        updatedAt: now,
      );

      final dedupResult = trip.deduplicateMembers();
      expect(dedupResult.mergedTrip.members.length, equals(1));
      expect(dedupResult.mergedTrip.members.first.displayName.trim().toLowerCase(), equals('rahul'));
      expect(dedupResult.memberIdMap['mbr_2'], equals('mbr_1'));
    });

    test('mergeWithDetailed deterministically reconciles virtual member when valid claimToken matches', () {
      final now = DateTime.now();
      const sharedClaimToken = 'clm_verified_secret_123';

      final localMember = TripMember(
        id: 'mbr_client_temp_1',
        userId: 'unclaimed_client_1',
        displayName: 'Aarav',
        claimToken: sharedClaimToken,
        joinedAt: now,
        isVirtualMember: true,
        isClaimed: false,
      );

      final creator = TripMember(
        id: 'mbr_creator',
        userId: 'user_creator_id',
        displayName: 'Creator',
        joinedAt: now,
        isVirtualMember: false,
        isClaimed: true,
        role: 'creator',
      );

      final localTrip = Trip(
        id: 'trip_1',
        name: 'Kerala',
        creatorId: 'user_creator_id',
        inviteCode: 'KER123',
        members: [creator, localMember],
        createdAt: now,
        updatedAt: now,
      );

      // Server assigned persistent server member ID but preserved claimToken
      final serverMember = TripMember(
        id: 'mbr_server_persisted_99',
        userId: 'unclaimed_server_1',
        displayName: 'Aarav',
        claimToken: sharedClaimToken,
        joinedAt: now,
        isVirtualMember: true,
        isClaimed: false,
      );

      final serverTrip = Trip(
        id: 'trip_1',
        name: 'Kerala',
        creatorId: 'user_creator_id',
        inviteCode: 'KER123',
        members: [creator, serverMember],
        createdAt: now,
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      final result = localTrip.mergeWithDetailed(serverTrip);

      // Invariant: Claim token matching accurately reconciles the member
      expect(result.mergedTrip.members.length, equals(2));
      expect(result.memberIdMap['mbr_client_temp_1'], equals('mbr_server_persisted_99'));
      final reconciled = result.mergedTrip.members.firstWhere((m) => m.id == 'mbr_server_persisted_99');
      expect(reconciled.displayName, equals('Aarav'));
      expect(reconciled.claimToken, equals(sharedClaimToken));
    });

    test('mergeWithDetailed deterministically reconciles member when authenticated userId matches', () {
      final now = DateTime.now();
      const authenticatedUserId = 'usr_real_account_456';

      final localMember = TripMember(
        id: 'mbr_local_id',
        userId: authenticatedUserId,
        displayName: 'Diya',
        joinedAt: now,
        isVirtualMember: false,
        isClaimed: true,
      );

      final localTrip = Trip(
        id: 'trip_1',
        name: 'Jaipur',
        creatorId: 'user_creator_id',
        inviteCode: 'JAI123',
        members: [localMember],
        createdAt: now,
        updatedAt: now,
      );

      final serverMember = TripMember(
        id: 'mbr_server_id',
        userId: authenticatedUserId,
        displayName: 'Diya Sharma',
        joinedAt: now,
        isVirtualMember: false,
        isClaimed: true,
      );

      final serverTrip = Trip(
        id: 'trip_1',
        name: 'Jaipur',
        creatorId: 'user_creator_id',
        inviteCode: 'JAI123',
        members: [serverMember],
        createdAt: now,
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      final result = localTrip.mergeWithDetailed(serverTrip);

      expect(result.mergedTrip.members.length, equals(1));
      expect(result.memberIdMap['mbr_local_id'], equals('mbr_server_id'));
      expect(result.mergedTrip.members.first.id, equals('mbr_server_id'));
    });

    test('unresolved members preserve expense references and ledger conservation', () {
      final now = DateTime.now();
      final unresolvedLocalMember = TripMember(
        id: 'mbr_orphan_101',
        userId: 'unclaimed_unknown_1',
        displayName: 'Unknown Guest',
        joinedAt: now,
        isVirtualMember: true,
        isClaimed: false,
      );

      final localTrip = Trip(
        id: 'trip_1',
        name: 'Udaipur',
        creatorId: 'user_creator_id',
        inviteCode: 'UDA123',
        members: [unresolvedLocalMember],
        createdAt: now,
        updatedAt: now,
      );

      final serverTrip = Trip(
        id: 'trip_1',
        name: 'Udaipur',
        creatorId: 'user_creator_id',
        inviteCode: 'UDA123',
        members: [], // Server does not know about this local member yet
        createdAt: now,
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      final result = localTrip.mergeWithDetailed(serverTrip);

      // Invariant: Unresolved members must NEVER be purged from the merged trip
      expect(result.mergedTrip.members.length, equals(1));
      expect(result.mergedTrip.members.first.id, equals('mbr_orphan_101'));
      // No ID reassignment occurs so existing expenses paid by mbr_orphan_101 remain intact
      expect(result.memberIdMap.isEmpty, isTrue);
    });
  });
}
