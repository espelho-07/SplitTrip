import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  group('Virtual Member Reconciliation & Role Preservation Regression Suite', () {
    final now = DateTime.now();

    test('Merging real claimed member into trip with unclaimed virtual placeholder leaves member registered and NOT virtual', () {
      // 1. User A creates trip and adds a virtual placeholder for "Neel Vyas"
      final creator = TripMember(
        id: 'mbr_creator_darpan',
        userId: 'usr_darpan_001',
        displayName: 'Darpan Parmar',
        joinedAt: now,
        isVirtualMember: false,
        isClaimed: true,
        role: 'creator',
        status: 'claimed',
      );

      final virtualNeel = TripMember(
        id: 'mbr_virtual_neel',
        userId: 'unclaimed_neel_tmp',
        displayName: 'Neel Vyas',
        joinedAt: now,
        isVirtualMember: true,
        isClaimed: false,
        role: 'virtual',
        status: 'unclaimed',
      );

      final tripOnDeviceA = Trip(
        id: 'trip_manali_trek',
        name: 'Manali Trek',
        creatorId: 'usr_darpan_001',
        inviteCode: 'MANALI',
        members: [creator, virtualNeel],
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      // 2. User B joins the trip with authenticated account
      final claimedNeel = TripMember(
        id: 'mbr_real_neel',
        userId: 'usr_neel_vyas_auth_999',
        displayName: 'Neel Vyas',
        joinedAt: now.add(const Duration(minutes: 5)),
        isVirtualMember: false,
        isClaimed: true,
        role: 'member',
        status: 'claimed',
      );

      final tripOnDeviceB = Trip(
        id: 'trip_manali_trek',
        name: 'Manali Trek',
        creatorId: 'usr_darpan_001',
        inviteCode: 'MANALI',
        members: [creator, claimedNeel],
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 5)),
        revision: 2,
      );

      // 3. User A receives Device B's trip or syncs with backend
      final mergeResult = tripOnDeviceA.mergeWithDetailed(tripOnDeviceB);
      final mergedTrip = mergeResult.mergedTrip;

      // Assertions:
      expect(mergedTrip.members.length, equals(2), reason: 'Should not create duplicate member for Neel Vyas');

      final resolvedNeel = mergedTrip.members.firstWhere((m) => m.displayName == 'Neel Vyas');
      expect(resolvedNeel.isRegistered, isTrue, reason: 'Claimed user MUST be recognized as registered');
      expect(resolvedNeel.isVirtual, isFalse, reason: 'Claimed user MUST NEVER be marked virtual');
      expect(resolvedNeel.isVirtualMember, isFalse);
      expect(resolvedNeel.isClaimed, isTrue);
      expect(resolvedNeel.role, equals('member'), reason: 'Role must be member, not virtual');
      expect(resolvedNeel.userId, equals('usr_neel_vyas_auth_999'));
    });

    test('TripMember.fromJson normalizes role and prevents real UID from ever being tagged virtual', () {
      final jsonFromStaleBackend = {
        'id': 'mbr_test_123',
        'user_id': 'usr_real_account_777',
        'display_name': 'Neel Vyas',
        'role': 'virtual', // Stale role from DB
        'is_claimed': true,
        'status': 'claimed',
      };

      final member = TripMember.fromJson(jsonFromStaleBackend);
      expect(member.isRegistered, isTrue);
      expect(member.isVirtual, isFalse);
      expect(member.role, equals('member'), reason: 'Stale virtual role must be normalized to member for real UIDs');
      expect(member.userId, equals('usr_real_account_777'));
    });

    test('deduplicateMembers collapses unclaimed placeholder into real claimed member', () {
      final claimedMember = TripMember(
        id: 'mbr_canonical_1',
        userId: 'usr_auth_claimed_111',
        displayName: 'Neel Vyas',
        joinedAt: now,
        isVirtualMember: false,
        isClaimed: true,
        role: 'member',
        status: 'claimed',
      );

      final stalePlaceholder = TripMember(
        id: 'mbr_stale_placeholder_2',
        userId: 'unclaimed_dup_222',
        displayName: 'Neel Vyas',
        joinedAt: now.subtract(const Duration(minutes: 10)),
        isVirtualMember: true,
        isClaimed: false,
        role: 'virtual',
        status: 'unclaimed',
      );

      final trip = Trip(
        id: 'trip_100',
        name: 'Trek',
        creatorId: 'usr_auth_claimed_111',
        inviteCode: 'TREK01',
        members: [claimedMember, stalePlaceholder],
        createdAt: now,
        updatedAt: now,
      );

      final result = trip.deduplicateMembers();
      expect(result.mergedTrip.members.length, equals(1));
      expect(result.mergedTrip.members.first.id, equals('mbr_canonical_1'));
      expect(result.mergedTrip.members.first.isVirtual, isFalse);
      expect(result.mergedTrip.members.first.isRegistered, isTrue);
      expect(result.memberIdMap['mbr_stale_placeholder_2'], equals('mbr_canonical_1'));
    });
  });
}
