import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/kith_app_mode.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KITH Critical Data Integrity Audit - Bug A & Bug B Unit Tests', () {
    test('TripMember properly differentiates between registered users and virtual participants', () {
      final now = DateTime.now();

      // Type 1: Registered User
      final registeredMember = TripMember(
        id: 'mbr_user_b_01',
        userId: 'usr_real_b_99',
        displayName: 'User B',
        role: 'member',
        status: 'claimed',
        isClaimed: true,
        isVirtualMember: false,
        joinedAt: now,
      );

      // Type 2: Virtual Trip Participant
      final virtualMember = TripMember(
        id: 'mbr_virt_v1_02',
        userId: 'unclaimed_v1_88',
        displayName: 'Ramesh (Guide)',
        role: 'member',
        status: 'unclaimed',
        isClaimed: false,
        isVirtualMember: true,
        claimToken: 'clm_token_123',
        joinedAt: now,
      );

      expect(registeredMember.isRegistered, isTrue);
      expect(registeredMember.isVirtual, isFalse);
      expect(virtualMember.isRegistered, isFalse);
      expect(virtualMember.isVirtual, isTrue);

      // Verify JSON round-trip preserves virtual flag
      final vJson = virtualMember.toJson();
      expect(vJson['isVirtual'], isTrue);

      final deserializedVirtual = TripMember.fromJson(vJson);
      expect(deserializedVirtual.isVirtual, isTrue);
      expect(deserializedVirtual.displayName, equals('Ramesh (Guide)'));
      expect(deserializedVirtual.id, equals('mbr_virt_v1_02'));
    });

    test('TripMember.fromJson never overwrites valid names with generic "Member"', () {
      final jsonWithValidName = {
        'id': 'mbr_123',
        'userId': 'usr_456',
        'displayName': 'Aditi Rao',
        'role': 'member',
        'status': 'claimed',
        'isClaimed': true,
        'joinedAt': DateTime.now().toIso8601String(),
      };

      final member = TripMember.fromJson(jsonWithValidName);
      expect(member.displayName, equals('Aditi Rao'));
      expect(member.displayName, isNot(equals('Member')));
    });

    test('Trip.mergeWith prevents Bug A (App users disappearing) & Bug B (Virtual members disappearing)', () {
      final now = DateTime.now();

      // Local state has:
      // 1. Creator (User A)
      // 2. User B (Registered user joined via QR code)
      // 3. Ramesh (Virtual participant created manually by User A)
      // 4. Pooja (Virtual participant created manually by User A)
      final localMembers = [
        TripMember(
          id: 'mbr_creator',
          userId: 'usr_creator_a',
          displayName: 'User A (Creator)',
          role: 'creator',
          status: 'claimed',
          isClaimed: true,
          isVirtualMember: false,
          joinedAt: now,
        ),
        TripMember(
          id: 'mbr_user_b',
          userId: 'usr_registered_b',
          displayName: 'User B (Joined)',
          role: 'member',
          status: 'claimed',
          isClaimed: true,
          isVirtualMember: false,
          joinedAt: now,
        ),
        TripMember(
          id: 'mbr_virt_ramesh',
          userId: 'unclaimed_ramesh',
          displayName: 'Ramesh',
          role: 'member',
          status: 'unclaimed',
          isClaimed: false,
          isVirtualMember: true,
          claimToken: 'clm_ramesh',
          joinedAt: now,
        ),
        TripMember(
          id: 'mbr_virt_pooja',
          userId: 'unclaimed_pooja',
          displayName: 'Pooja',
          role: 'member',
          status: 'unclaimed',
          isClaimed: false,
          isVirtualMember: true,
          claimToken: 'clm_pooja',
          joinedAt: now,
        ),
      ];

      final localTrip = Trip(
        id: 'trip_ladakh_2026',
        name: 'Ladakh Roadtrip',
        creatorId: 'usr_creator_a',
        inviteCode: 'LADAKH',
        members: localMembers,
        lifecycleState: TripLifecycle.active,
        revision: 3,
        createdAt: now,
        updatedAt: now,
      );

      // Remote server snapshot (e.g. after Render backend idle restart or partial sync)
      // only has creator and User B, or missing virtual members
      final remoteMembers = [
        TripMember(
          id: 'mbr_creator',
          userId: 'usr_creator_a',
          displayName: 'User A (Creator)',
          role: 'creator',
          status: 'claimed',
          isClaimed: true,
          isVirtualMember: false,
          joinedAt: now,
        ),
        TripMember(
          id: 'mbr_user_b',
          userId: 'usr_registered_b',
          displayName: 'User B (Joined)',
          role: 'member',
          status: 'claimed',
          isClaimed: true,
          isVirtualMember: false,
          joinedAt: now,
        ),
      ];

      final remoteTrip = Trip(
        id: 'trip_ladakh_2026',
        name: 'Ladakh Roadtrip',
        creatorId: 'usr_creator_a',
        inviteCode: 'LADAKH',
        members: remoteMembers,
        lifecycleState: TripLifecycle.active,
        revision: 4,
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 1)),
      );

      // Execute non-destructive merge
      final mergedTrip = localTrip.mergeWith(remoteTrip);

      // ASSERTIONS:
      // 1. All 4 members must be preserved!
      expect(mergedTrip.members.length, equals(4));

      // 2. User B must NOT have disappeared
      final userBMember = mergedTrip.members.firstWhere((m) => m.userId == 'usr_registered_b');
      expect(userBMember.displayName, equals('User B (Joined)'));
      expect(userBMember.isRegistered, isTrue);

      // 3. Virtual participants Ramesh & Pooja must NOT have disappeared
      final rameshMember = mergedTrip.members.firstWhere((m) => m.id == 'mbr_virt_ramesh');
      expect(rameshMember.displayName, equals('Ramesh'));
      expect(rameshMember.isVirtual, isTrue);

      final poojaMember = mergedTrip.members.firstWhere((m) => m.id == 'mbr_virt_pooja');
      expect(poojaMember.displayName, equals('Pooja'));
      expect(poojaMember.isVirtual, isTrue);

      // 4. No generic placeholder names ("Member 1", "Member 2")
      for (final m in mergedTrip.members) {
        expect(m.displayName, isNot(equals('Member')));
        expect(m.displayName, isNot(equals('Member 1')));
        expect(m.displayName, isNot(equals('Member 2')));
      }
    });

    test('Simulated 1-2 hour delay, application restart, and cache restoration preserves members', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final now = DateTime.now();
      final initialTrip = Trip(
        id: 'trip_manali_456',
        name: 'Manali Trek',
        creatorId: 'usr_creator_1',
        inviteCode: 'MANALI',
        members: [
          TripMember(
            id: 'mbr_creator',
            userId: 'usr_creator_1',
            displayName: 'Aarav',
            role: 'creator',
            status: 'claimed',
            isClaimed: true,
            isVirtualMember: false,
            joinedAt: now,
          ),
          TripMember(
            id: 'mbr_joined_b',
            userId: 'usr_joined_b',
            displayName: 'Bhavna',
            role: 'member',
            status: 'claimed',
            isClaimed: true,
            isVirtualMember: false,
            joinedAt: now,
          ),
          TripMember(
            id: 'mbr_virtual_c',
            userId: 'unclaimed_chirag',
            displayName: 'Chirag (Manual)',
            role: 'member',
            status: 'unclaimed',
            isClaimed: false,
            isVirtualMember: true,
            claimToken: 'clm_chirag',
            joinedAt: now,
          ),
        ],
        lifecycleState: TripLifecycle.active,
        createdAt: now,
        updatedAt: now,
      );

      // Save to local persistent storage
      await storage.saveTrips([initialTrip.toJson()]);

      // --- SIMULATE 2-HOUR DELAY & APP RESTART ---
      final restoredRawTrips = storage.getSavedTrips();
      expect(restoredRawTrips.length, equals(1));

      final restoredTrip = Trip.fromJson(restoredRawTrips.first);
      expect(restoredTrip.members.length, equals(3));
      expect(restoredTrip.members.any((m) => m.displayName == 'Bhavna'), isTrue);
      expect(restoredTrip.members.any((m) => m.displayName == 'Chirag (Manual)' && m.isVirtual), isTrue);

      // Simulate partial remote fetch from server that only has Creator
      final partialServerTrip = Trip(
        id: 'trip_manali_456',
        name: 'Manali Trek',
        creatorId: 'usr_creator_1',
        inviteCode: 'MANALI',
        members: [
          TripMember(
            id: 'mbr_creator',
            userId: 'usr_creator_1',
            displayName: 'Aarav',
            role: 'creator',
            status: 'claimed',
            isClaimed: true,
            isVirtualMember: false,
            joinedAt: now,
          ),
        ],
        lifecycleState: TripLifecycle.active,
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 2)),
      );

      // Non-destructive reconciliation
      final reconciled = restoredTrip.mergeWith(partialServerTrip);
      await storage.saveTrips([reconciled.toJson()]);

      // Verify that after sync reconciliation, all 3 members survive!
      final finalTrips = storage.getSavedTrips().map((j) => Trip.fromJson(j)).toList();
      expect(finalTrips.first.members.length, equals(3));
      expect(finalTrips.first.members.where((m) => m.isVirtual).length, equals(1));
      expect(finalTrips.first.members.firstWhere((m) => m.isVirtual).displayName, equals('Chirag (Manual)'));
    });

    test('Expenses remain bound to virtual and registered members without showing zero', () {
      final now = DateTime.now();
      const tripId = 'trip_goa_789';
      const creatorMemberId = 'mbr_creator_goa';
      const virtualMemberId = 'mbr_virt_driver';

      final expense = Expense(
        id: 'exp_petrol_001',
        tripId: tripId,
        title: 'Jeep Fuel',
        amountInPaise: 300000, // ₹3,000.00
        category: ExpenseCategory.transport,
        paidById: creatorMemberId,
        splits: [
          const ExpenseSplit(memberId: creatorMemberId, amountInPaise: 150000),
          const ExpenseSplit(memberId: virtualMemberId, amountInPaise: 150000),
        ],
        createdAt: now,
        updatedAt: now,
      );

      // Verify expense values
      expect(expense.amountInPaise, equals(300000));
      expect(expense.splits.length, equals(2));
      expect(expense.splits.any((s) => s.memberId == virtualMemberId), isTrue);

      final totalSplit = expense.splits.fold<int>(0, (sum, s) => sum + s.amountInPaise);
      expect(totalSplit, equals(expense.amountInPaise));
      expect(totalSplit, isNonZero);
    });
  });

  group('KITH Dual Mode Architecture Suite', () {
    test('KithAppMode enum definitions and key conversions', () {
      expect(KithAppMode.trip.key, equals('trip'));
      expect(KithAppMode.trip.isTrip, isTrue);
      expect(KithAppMode.trip.isFinancial, isFalse);

      expect(KithAppMode.financial.key, equals('financial'));
      expect(KithAppMode.financial.isFinancial, isTrue);
      expect(KithAppMode.financial.isTrip, isFalse);

      expect(KithAppMode.fromKey('financial'), equals(KithAppMode.financial));
      expect(KithAppMode.fromKey('trip'), equals(KithAppMode.trip));
      expect(KithAppMode.fromKey(null), equals(KithAppMode.trip));
      expect(KithAppMode.fromKey('unknown'), equals(KithAppMode.trip));
    });

    test('LocalStorageService persists and retrieves primary app mode across sessions', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      // Default before saving
      expect(storage.getSavedPrimaryAppMode(), isNull);

      // Save Financial Mode
      await storage.savePrimaryAppMode(KithAppMode.financial.key);
      expect(storage.getSavedPrimaryAppMode(), equals('financial'));

      // Save Trip Mode
      await storage.savePrimaryAppMode(KithAppMode.trip.key);
      expect(storage.getSavedPrimaryAppMode(), equals('trip'));
    });
  });
}
