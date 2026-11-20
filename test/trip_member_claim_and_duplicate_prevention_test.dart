import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late TripRepository tripRepo;
  late SyncService syncService;
  late ApiClient apiClient;

  final creatorUser = GuestUser(
    id: 'usr_creator',
    displayName: 'Darpan',
    avatarUrl: null,
    recoveryKey: 'rec_creator',
    anonymousToken: 'tok_creator',
    createdAt: DateTime.now(),
    upiId: 'darpan@upi',
  );

  final rahulUser = GuestUser(
    id: 'usr_rahul',
    displayName: 'Rahul Sharma',
    avatarUrl: 'https://avatar.com/rahul.png',
    recoveryKey: 'rec_rahul',
    anonymousToken: 'tok_rahul',
    createdAt: DateTime.now(),
    upiId: 'rahul@upi',
  );

  final amanUser = GuestUser(
    id: 'usr_aman',
    displayName: 'Aman Verma',
    avatarUrl: null,
    recoveryKey: 'rec_aman',
    anonymousToken: 'tok_aman',
    createdAt: DateTime.now(),
    upiId: 'aman@upi',
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
  });

  group('Trip Member Claim & Duplicate Prevention Suite', () {
    test('1. Trip creation tags manually added friends as unclaimed placeholders', () async {
      final trip = await tripRepo.createTrip(
        name: 'Goa Trip',
        creator: creatorUser,
        initialFriendNames: ['Rahul', 'Pooja'],
      );

      expect(trip.members.length, 3);
      final creatorMbr = trip.members.firstWhere((m) => m.role == 'creator');
      final rahulMbr = trip.members.firstWhere((m) => m.displayName == 'Rahul');
      final poojaMbr = trip.members.firstWhere((m) => m.displayName == 'Pooja');

      expect(creatorMbr.isClaimed, isTrue);
      expect(creatorMbr.isUnclaimed, isFalse);
      expect(creatorMbr.userId, equals('usr_creator'));

      expect(rahulMbr.isClaimed, isFalse);
      expect(rahulMbr.isUnclaimed, isTrue);
      expect(rahulMbr.userId.startsWith('unclaimed_'), isTrue);
      expect(rahulMbr.claimToken?.startsWith('clm_'), isTrue);

      expect(poojaMbr.isClaimed, isFalse);
      expect(poojaMbr.isUnclaimed, isTrue);

      // Verify preview includes unclaimed members
      final preview = await tripRepo.getTripPreview(trip.inviteCode);
      expect(preview, isNotNull);
      expect(preview!.unclaimedMembers.length, equals(2));
      expect(preview.unclaimedMembers.any((m) => m.displayName == 'Rahul'), isTrue);
    });

    test('2. Real user claims existing unclaimed member in local cache -> No duplicate member created', () async {
      final trip = await tripRepo.createTrip(
        name: 'Goa Trip',
        creator: creatorUser,
        initialFriendNames: ['Rahul'],
      );
      final placeholderRahul = trip.members.firstWhere((m) => m.displayName == 'Rahul');

      // Rahul joins and explicitly claims his placeholder
      final updatedTrip = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: rahulUser,
        claimMemberId: placeholderRahul.id,
        claimToken: placeholderRahul.claimToken,
      );

      // Total members remains exactly 2 (No duplicate!)
      expect(updatedTrip.members.length, equals(2));

      final claimedMember = updatedTrip.members.firstWhere((m) => m.id == placeholderRahul.id);
      expect(claimedMember.userId, equals(rahulUser.id));
      expect(claimedMember.isClaimed, isTrue);
      expect(claimedMember.isUnclaimed, isFalse);
      expect(claimedMember.avatarUrl, equals(rahulUser.avatarUrl));
    });

    test('3. Idempotent Join: Scanning QR code repeatedly never creates duplicates', () async {
      final trip = await tripRepo.createTrip(
        name: 'Goa Trip',
        creator: creatorUser,
        initialFriendNames: ['Rahul'],
      );
      final placeholderRahul = trip.members.firstWhere((m) => m.displayName == 'Rahul');

      // First join
      final firstJoin = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: rahulUser,
        claimMemberId: placeholderRahul.id,
        claimToken: placeholderRahul.claimToken,
      );
      expect(firstJoin.members.length, equals(2));

      // Second join (same user scans QR again)
      final secondJoin = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: rahulUser,
      );
      expect(secondJoin.members.length, equals(2));
      expect(secondJoin.members.where((m) => m.userId == rahulUser.id).length, equals(1));
    });

    test('4. User joining as a new member does NOT touch or claim existing unclaimed members', () async {
      final trip = await tripRepo.createTrip(
        name: 'Goa Trip',
        creator: creatorUser,
        initialFriendNames: ['Rahul'],
      );
      final placeholderRahul = trip.members.firstWhere((m) => m.displayName == 'Rahul');

      // Aman joins as new member without claiming Rahul
      final updatedTrip = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: amanUser,
        claimMemberId: null,
      );

      // Total members is now 3 (Creator, unclaimed Rahul, claimed Aman)
      expect(updatedTrip.members.length, equals(3));
      final rahulStillUnclaimed = updatedTrip.members.firstWhere((m) => m.id == placeholderRahul.id);
      final amanMember = updatedTrip.members.firstWhere((m) => m.userId == amanUser.id);

      expect(rahulStillUnclaimed.isClaimed, isFalse);
      expect(rahulStillUnclaimed.isUnclaimed, isTrue);
      expect(amanMember.isClaimed, isTrue);
    });

    test('5. reconcileDuplicateMembers safely cleans up any historical duplicate entries', () {
      final duplicateMembers = [
        TripMember(
          id: 'mbr_1',
          userId: 'usr_rahul',
          displayName: 'Rahul Primary',
          joinedAt: DateTime.now().subtract(const Duration(hours: 2)),
          isClaimed: true,
        ),
        TripMember(
          id: 'mbr_2',
          userId: 'usr_rahul', // Duplicate userId
          displayName: 'Rahul Duplicate',
          joinedAt: DateTime.now(),
          isClaimed: true,
        ),
        TripMember(
          id: 'mbr_3',
          userId: 'unclaimed_xyz',
          displayName: 'Unclaimed Friend',
          joinedAt: DateTime.now(),
          isClaimed: false,
        ),
      ];

      final corruptedTrip = Trip(
        id: 'trip_dup_test',
        inviteCode: 'TEST01',
        name: 'Duplicate Test Trip',
        creatorId: 'usr_creator',
        members: duplicateMembers,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cleanTrip = tripRepo.reconcileDuplicateMembers(corruptedTrip);

      expect(cleanTrip.members.length, equals(2));
      expect(cleanTrip.members.where((m) => m.userId == 'usr_rahul').length, equals(1));
      expect(cleanTrip.members.first.id, equals('mbr_1'));
      expect(cleanTrip.members.any((m) => m.isUnclaimed), isTrue);
    });

    test('6. User joins via QR / invite code and claims unclaimed spot WITHOUT claimToken -> succeeds', () async {
      final trip = await tripRepo.createTrip(
        name: 'Manali Expedition',
        creator: creatorUser,
        initialFriendNames: ['Pooja'],
      );
      final placeholderPooja = trip.members.firstWhere((m) => m.displayName == 'Pooja');
      expect(placeholderPooja.isClaimed, isFalse);

      // Pooja scans QR, has only trip.inviteCode, does NOT have a secret claimToken
      final updatedTrip = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: rahulUser, // Rahul claims Pooja's spot
        claimMemberId: placeholderPooja.id,
        claimToken: null, // No claimToken provided!
      );

      expect(updatedTrip.members.length, equals(2));
      final claimedSpot = updatedTrip.members.firstWhere((m) => m.id == placeholderPooja.id);
      expect(claimedSpot.userId, equals(rahulUser.id));
      expect(claimedSpot.isClaimed, isTrue);
      expect(claimedSpot.isUnclaimed, isFalse);
    });

    test('7. Preview returns non-null claimToken for unclaimed member placeholders', () async {
      final trip = await tripRepo.createTrip(
        name: 'Kasol Trip',
        creator: creatorUser,
        initialFriendNames: ['Rohit'],
      );
      final placeholderRohit = trip.members.firstWhere((m) => m.displayName == 'Rohit');

      final preview = await tripRepo.getTripPreview(trip.inviteCode);
      expect(preview, isNotNull);
      final rohitPreview = preview!.unclaimedMembers.firstWhere((m) => m.displayName == 'Rohit');
      expect(rohitPreview.claimToken, equals(placeholderRohit.claimToken));
      expect(rohitPreview.claimToken, isNotNull);
      expect(rohitPreview.claimToken!.isNotEmpty, isTrue);
    });

    test('8. Attempting to claim an already claimed member throws ConflictException', () async {
      final trip = await tripRepo.createTrip(
        name: 'Shimla Trip',
        creator: creatorUser,
        initialFriendNames: ['Simran'],
      );
      final placeholderSimran = trip.members.firstWhere((m) => m.displayName == 'Simran');

      // First user claims Simran
      await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: rahulUser,
        claimMemberId: placeholderSimran.id,
      );

      // Second user tries to claim Simran again
      expect(
        () => tripRepo.joinTrip(
          inviteCodeOrId: trip.inviteCode,
          user: amanUser,
          claimMemberId: placeholderSimran.id,
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test('9. Supplying a mismatched/invalid claimToken throws UnauthorizedException', () async {
      final trip = await tripRepo.createTrip(
        name: 'Ooty Trip',
        creator: creatorUser,
        initialFriendNames: ['Karan'],
      );
      final placeholderKaran = trip.members.firstWhere((m) => m.displayName == 'Karan');

      expect(
        () => tripRepo.joinTrip(
          inviteCodeOrId: trip.inviteCode,
          user: rahulUser,
          claimMemberId: placeholderKaran.id,
          claimToken: 'wrong_secret_token_12345',
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}
