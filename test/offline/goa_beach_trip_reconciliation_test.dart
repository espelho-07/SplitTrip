import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';

void main() {
  group('Goa Beach Trip Critical Production Bug Regression Suite', () {
    const creatorUserId = 'usr_darpan_123';
    const neelUserId = 'usr_neel_456';
    const virtualNeelMemberId = 'mem_virt_neel_999';
    const realNeelMemberId = 'mem_real_neel_001';
    final now = DateTime.now();

    test('1. Deduplication collapses unclaimed virtual member into real claimed member with same name', () {
      final tripWithDuplicate = Trip(
        id: 'trip_goa_001',
        name: 'Goa Beach Trip',
        creatorId: creatorUserId,
        inviteCode: 'GOA123',
        createdAt: now,
        updatedAt: now,
        lifecycleState: TripLifecycle.active,
        members: [
          TripMember(
            id: 'mem_darpan_1',
            userId: creatorUserId,
            displayName: 'Darpan',
            role: 'creator',
            isClaimed: true,
            isVirtualMember: false,
            joinedAt: now,
          ),
          TripMember(
            id: realNeelMemberId,
            userId: neelUserId,
            displayName: 'Neel',
            role: 'member',
            isClaimed: true,
            isVirtualMember: false,
            joinedAt: now,
          ),
          TripMember(
            id: virtualNeelMemberId,
            userId: 'unclaimed_$virtualNeelMemberId',
            displayName: 'Neel',
            role: 'member',
            isClaimed: false,
            isVirtualMember: true,
            joinedAt: now,
          ),
        ],
      );

      final dedupResult = tripWithDuplicate.deduplicateMembers();
      final deduped = dedupResult.mergedTrip.members;

      expect(deduped.length, equals(2));
      expect(deduped.any((m) => m.id == realNeelMemberId), isTrue);
      expect(deduped.any((m) => m.id == virtualNeelMemberId), isFalse);
      expect(dedupResult.memberIdMap[virtualNeelMemberId], equals(realNeelMemberId));
    });

    test('2. mergeWithDetailed reconciles virtual member when real claimed member joins with same display name', () {
      // Local state before join (contains virtual Neel placeholder)
      final localTrip = Trip(
        id: 'trip_goa_001',
        name: 'Goa Beach Trip',
        creatorId: creatorUserId,
        inviteCode: 'GOA123',
        createdAt: now,
        updatedAt: now,
        lifecycleState: TripLifecycle.active,
        members: [
          TripMember(
            id: 'mem_darpan_1',
            userId: creatorUserId,
            displayName: 'Darpan',
            role: 'creator',
            isClaimed: true,
            isVirtualMember: false,
            joinedAt: now,
          ),
          TripMember(
            id: virtualNeelMemberId,
            userId: 'unclaimed_$virtualNeelMemberId',
            displayName: 'Neel',
            role: 'member',
            isClaimed: false,
            isVirtualMember: true,
            joinedAt: now,
          ),
        ],
      );

      // Incoming remote snapshot after Neel joined via code
      final incomingSnapshot = Trip(
        id: 'trip_goa_001',
        name: 'Goa Beach Trip',
        creatorId: creatorUserId,
        inviteCode: 'GOA123',
        createdAt: now,
        updatedAt: now,
        lifecycleState: TripLifecycle.active,
        members: [
          TripMember(
            id: 'mem_darpan_1',
            userId: creatorUserId,
            displayName: 'Darpan',
            role: 'creator',
            isClaimed: true,
            isVirtualMember: false,
            joinedAt: now,
          ),
          TripMember(
            id: realNeelMemberId,
            userId: neelUserId,
            displayName: 'Neel',
            role: 'member',
            isClaimed: true,
            isVirtualMember: false,
            joinedAt: now,
          ),
        ],
      );

      final result = localTrip.mergeWithDetailed(incomingSnapshot);
      final mergedTrip = result.mergedTrip;

      expect(mergedTrip.members.length, equals(2));
      expect(mergedTrip.members.any((m) => m.id == realNeelMemberId), isTrue);
      expect(mergedTrip.members.any((m) => m.id == virtualNeelMemberId), isFalse);
      expect(result.memberIdMap[virtualNeelMemberId], equals(realNeelMemberId));
    });

    test('3. Lifecycle merge protects active state against unauthorized non-creator completion', () {
      final authoritativeActiveTrip = Trip(
        id: 'trip_goa_001',
        name: 'Goa Beach Trip',
        creatorId: creatorUserId,
        inviteCode: 'GOA123',
        createdAt: now,
        updatedAt: now,
        lifecycleState: TripLifecycle.active,
        revision: 1,
        members: [],
      );

      final unauthorizedSettledTrip = Trip(
        id: 'trip_goa_001',
        name: 'Goa Beach Trip',
        creatorId: creatorUserId,
        inviteCode: 'GOA123',
        createdAt: now,
        updatedAt: now,
        lifecycleState: TripLifecycle.settled,
        revision: 1,
        completedBy: neelUserId, // Non-creator
        members: [],
      );

      final result = authoritativeActiveTrip.mergeWithDetailed(unauthorizedSettledTrip);
      // Because candidate was completedBy a non-creator, the authoritative active state is preserved
      expect(result.mergedTrip.lifecycleState, equals(TripLifecycle.active));
    });

    test('4. Trip.isCreator accurately checks trip creator identity', () {
      final trip = Trip(
        id: 'trip_goa_001',
        name: 'Goa Beach Trip',
        creatorId: creatorUserId,
        inviteCode: 'GOA123',
        createdAt: now,
        updatedAt: now,
        lifecycleState: TripLifecycle.active,
        members: [
          TripMember(
            id: 'mem_darpan_1',
            userId: creatorUserId,
            displayName: 'Darpan',
            role: 'creator',
            isClaimed: true,
            isVirtualMember: false,
            joinedAt: now,
          ),
          TripMember(
            id: realNeelMemberId,
            userId: neelUserId,
            displayName: 'Neel',
            role: 'member',
            isClaimed: true,
            isVirtualMember: false,
            joinedAt: now,
          ),
        ],
      );

      expect(trip.isCreator(creatorUserId), isTrue);
      expect(trip.isCreator('mem_darpan_1'), isTrue);
      expect(trip.isCreator(neelUserId), isFalse);
      expect(trip.isCreator(null), isFalse);
      expect(trip.isCreator(''), isFalse);
    });

    test('5. Expense and ExpenseSplit JSON deserialization parses snake_case and memberId fallbacks', () {
      final expenseJson = {
        'id': 'exp_train_101',
        'trip_id': 'trip_goa_001',
        'title': 'Train Ticket Return and going both',
        'amountInPaise': 181600,
        'category': 'transport',
        'paid_by_member_id': realNeelMemberId,
        'currency': 'INR',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'splits': [
          {
            'member_id': realNeelMemberId,
            'amountInPaise': 181600,
          }
        ]
      };

      final expense = Expense.fromJson(expenseJson);
      expect(expense.paidById, equals(realNeelMemberId));
      expect(expense.splits.first.memberId, equals(realNeelMemberId));
    });
  });
}
