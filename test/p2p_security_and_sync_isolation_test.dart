import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/p2p_sync_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late SharedPreferences prefs;
  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;

  final creatorUser = GuestUser(
    id: 'usr_creator_darpan',
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
  );

  final intruderUser = GuestUser(
    id: 'usr_intruder_mallory',
    displayName: 'Mallory Intruder',
    avatarUrl: null,
    recoveryKey: 'rec_key_mallory',
    anonymousToken: 'tok_mallory',
    createdAt: DateTime.now(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
    apiClient = ApiClient();
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

  group('Phase A & Phase D: P2P Authentication & Security Verification Suite', () {
    late P2PSyncService p2pReceiverService;
    late HttpClient httpClient;
    const testTripId = 'trip_himalaya_2026';
    const testInviteCode = 'HIMA01';
    const testP2PSecret = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

    setUp(() async {
      // Save receiver user
      await storage.saveUser({
        'id': 'usr_receiver_bob',
        'displayName': 'Bob Receiver',
      });

      // Save authorized trip with creator and Alice as registered claimed members, and Charlie as virtual
      await storage.saveTrips([
        {
          'id': testTripId,
          'name': 'Himalayan Expedition',
          'inviteCode': testInviteCode,
          'p2pTripSecret': testP2PSecret,
          'creatorId': 'usr_creator_darpan',
          'members': [
            {
              'id': 'mbr_creator',
              'userId': 'usr_creator_darpan',
              'displayName': 'Darpan Owner',
              'role': 'creator',
              'status': 'claimed',
              'isClaimed': true,
              'isVirtual': false,
            },
            {
              'id': 'mbr_receiver',
              'userId': 'usr_receiver_bob',
              'displayName': 'Bob Receiver',
              'role': 'member',
              'status': 'claimed',
              'isClaimed': true,
              'isVirtual': false,
            },
            {
              'id': 'mbr_alice',
              'userId': 'usr_friend_alice',
              'displayName': 'Alice Real',
              'role': 'member',
              'status': 'claimed',
              'isClaimed': true,
              'isVirtual': false,
            },
            {
              'id': 'mbr_charlie_virtual',
              'userId': 'unclaimed_charlie123',
              'displayName': 'Charlie Placeholder',
              'role': 'virtual',
              'status': 'unclaimed',
              'isClaimed': false,
              'isVirtual': true,
              'claimToken': 'clm_charlie_secret',
            },
          ],
        }
      ]);

      p2pReceiverService = P2PSyncService(
        storage,
        syncService,
        deviceId: 'dev_receiver_bob_phone',
      );
      await p2pReceiverService.start();
      httpClient = HttpClient();
    });

    tearDown(() async {
      httpClient.close();
      await p2pReceiverService.stop();
    });

    test('1. Spoofed userId in UDP beacon fails authentication during HTTP session handshake', () async {
      final port = p2pReceiverService.serverPort;
      expect(port, isNotNull);

      // Mallory broadcasts a beacon pretending to be Alice (u: usr_friend_alice), but signs with Mallory key
      final wrongAuthKey = P2PSyncService.deriveTripAuthKey(
        testTripId,
        testInviteCode,
        p2pTripSecret: 'mallory_bogus_secret_0000000000',
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final spoofedSessionToken = P2PSyncService.computeP2PSessionToken(
        authKey: wrongAuthKey,
        protocolVersion: P2PSyncService.protocolTag,
        tripId: testTripId,
        senderDeviceId: 'dev_mallory_laptop',
        senderUserId: 'usr_friend_alice', // Spoofed Alice userId!
        timestampMs: nowMs,
      );

      final uri = Uri.parse('http://127.0.0.1:$port/kith-p2p/operations');
      final req = await httpClient.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'protocol': P2PSyncService.protocolTag,
        'deviceId': 'dev_mallory_laptop',
        'userId': 'usr_friend_alice',
        'timestamp': nowMs,
        'sessionToken': spoofedSessionToken,
        'tripId': testTripId,
        'operations': [],
        'knownLocalOperations': [],
      }));

      final res = await req.close();
      // Server must reject with 401 Unauthorized because Mallory does not possess the genuine authKey
      expect(res.statusCode, equals(HttpStatus.unauthorized));
    });

    test('2. Invalid session / auth signature rejection: rejects tampered or garbage session tokens', () async {
      final port = p2pReceiverService.serverPort;
      expect(port, isNotNull);
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final uri = Uri.parse('http://127.0.0.1:$port/kith-p2p/operations');
      final req = await httpClient.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'protocol': P2PSyncService.protocolTag,
        'deviceId': 'dev_some_device',
        'userId': 'usr_friend_alice',
        'timestamp': nowMs,
        'sessionToken': 'garbage_tampered_signature_hex_1234567890',
        'tripId': testTripId,
        'operations': [],
        'knownLocalOperations': [],
      }));

      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.unauthorized));
    });

    test('3. Expired / replayed session signature (> 120s drift rejected)', () async {
      final port = p2pReceiverService.serverPort;
      expect(port, isNotNull);
      final authKey = P2PSyncService.deriveTripAuthKey(
        testTripId,
        testInviteCode,
        p2pTripSecret: testP2PSecret,
      );

      final now = DateTime.now();
      // Replay attack: session token generated 130 seconds ago (> 120s max drift)
      final expiredMs = now.subtract(const Duration(seconds: 130)).millisecondsSinceEpoch;

      final replayedSessionToken = P2PSyncService.computeP2PSessionToken(
        authKey: authKey,
        protocolVersion: P2PSyncService.protocolTag,
        tripId: testTripId,
        senderDeviceId: 'dev_alice_device',
        senderUserId: 'usr_friend_alice',
        timestampMs: expiredMs,
      );

      final uri = Uri.parse('http://127.0.0.1:$port/kith-p2p/operations');
      final req = await httpClient.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'protocol': P2PSyncService.protocolTag,
        'deviceId': 'dev_alice_device',
        'userId': 'usr_friend_alice',
        'timestamp': expiredMs,
        'sessionToken': replayedSessionToken,
        'tripId': testTripId,
        'operations': [],
        'knownLocalOperations': [],
      }));

      final res = await req.close();
      // Drift > 120s must be strictly rejected
      expect(res.statusCode, equals(HttpStatus.unauthorized));

      // Also test future drift (> 120s into the future)
      final futureMs = now.add(const Duration(seconds: 130)).millisecondsSinceEpoch;
      final futureToken = P2PSyncService.computeP2PSessionToken(
        authKey: authKey,
        protocolVersion: P2PSyncService.protocolTag,
        tripId: testTripId,
        senderDeviceId: 'dev_alice_device',
        senderUserId: 'usr_friend_alice',
        timestampMs: futureMs,
      );

      final futureReq = await httpClient.postUrl(uri);
      futureReq.headers.contentType = ContentType.json;
      futureReq.write(jsonEncode({
        'protocol': P2PSyncService.protocolTag,
        'deviceId': 'dev_alice_device',
        'userId': 'usr_friend_alice',
        'timestamp': futureMs,
        'sessionToken': futureToken,
        'tripId': testTripId,
        'operations': [],
        'knownLocalOperations': [],
      }));

      final futureRes = await futureReq.close();
      expect(futureRes.statusCode, equals(HttpStatus.unauthorized));
    });

    test('4. Unauthorized trip membership attempt (device not in trip members rejected)', () async {
      final port = p2pReceiverService.serverPort;
      expect(port, isNotNull);
      final authKey = P2PSyncService.deriveTripAuthKey(
        testTripId,
        testInviteCode,
        p2pTripSecret: testP2PSecret,
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Mallory somehow has the authKey, but is NOT a member of the trip!
      final mallorySessionToken = P2PSyncService.computeP2PSessionToken(
        authKey: authKey,
        protocolVersion: P2PSyncService.protocolTag,
        tripId: testTripId,
        senderDeviceId: 'dev_mallory_device',
        senderUserId: 'usr_intruder_mallory', // Not in trip members!
        timestampMs: nowMs,
      );

      final uri = Uri.parse('http://127.0.0.1:$port/kith-p2p/operations');
      final req = await httpClient.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'protocol': P2PSyncService.protocolTag,
        'deviceId': 'dev_mallory_device',
        'userId': 'usr_intruder_mallory',
        'timestamp': nowMs,
        'sessionToken': mallorySessionToken,
        'tripId': testTripId,
        'operations': [],
        'knownLocalOperations': [],
      }));

      final res = await req.close();
      // Server must reject with 403 Forbidden because Mallory is not a claimed member
      expect(res.statusCode, equals(HttpStatus.forbidden));
    });

    test('5. Virtual participant attempting P2P sync is strictly rejected', () async {
      final port = p2pReceiverService.serverPort;
      expect(port, isNotNull);
      final authKey = P2PSyncService.deriveTripAuthKey(
        testTripId,
        testInviteCode,
        p2pTripSecret: testP2PSecret,
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Attacker attempts to use Charlie (who is a virtual unclaimed placeholder) as peer identity
      final virtualSessionToken = P2PSyncService.computeP2PSessionToken(
        authKey: authKey,
        protocolVersion: P2PSyncService.protocolTag,
        tripId: testTripId,
        senderDeviceId: 'dev_fake_charlie',
        senderUserId: 'unclaimed_charlie123', // Virtual member!
        timestampMs: nowMs,
      );

      final uri = Uri.parse('http://127.0.0.1:$port/kith-p2p/operations');
      final req = await httpClient.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'protocol': P2PSyncService.protocolTag,
        'deviceId': 'dev_fake_charlie',
        'userId': 'unclaimed_charlie123',
        'timestamp': nowMs,
        'sessionToken': virtualSessionToken,
        'tripId': testTripId,
        'operations': [],
        'knownLocalOperations': [],
      }));

      final res = await req.close();
      // Virtual participants must be strictly rejected with 403 Forbidden
      expect(res.statusCode, equals(HttpStatus.forbidden));
    });

    test('6. Revoked membership (rotated p2pTripSecret invalidates previous sync authorization)', () async {
      final port = p2pReceiverService.serverPort;
      expect(port, isNotNull);

      // Initially old secret was testP2PSecret
      // Now trip secret rotates on the receiver node to secret_v2_rotated
      const rotatedSecret = 'b2c3d4e5f60718293a4b5c6d7e8f90a1';
      final currentTrips = storage.getSavedTrips();
      final updatedTrips = currentTrips.map((t) {
        if (t['id'] == testTripId) {
          return {...t, 'p2pTripSecret': rotatedSecret};
        }
        return t;
      }).toList();
      await storage.saveTrips(updatedTrips);

      // Alice device still attempts to sync using the old, pre-rotation auth key
      final oldAuthKey = P2PSyncService.deriveTripAuthKey(
        testTripId,
        testInviteCode,
        p2pTripSecret: testP2PSecret, // Old revoked secret!
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final staleSessionToken = P2PSyncService.computeP2PSessionToken(
        authKey: oldAuthKey,
        protocolVersion: P2PSyncService.protocolTag,
        tripId: testTripId,
        senderDeviceId: 'dev_alice_device',
        senderUserId: 'usr_friend_alice',
        timestampMs: nowMs,
      );

      final uri = Uri.parse('http://127.0.0.1:$port/kith-p2p/operations');
      final req = await httpClient.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'protocol': P2PSyncService.protocolTag,
        'deviceId': 'dev_alice_device',
        'userId': 'usr_friend_alice',
        'timestamp': nowMs,
        'sessionToken': staleSessionToken,
        'tripId': testTripId,
        'operations': [],
        'knownLocalOperations': [],
      }));

      final res = await req.close();
      // Receiver checks against rotated secret; old token fails verification -> 401 Unauthorized
      expect(res.statusCode, equals(HttpStatus.unauthorized));
    });
  });

  group('Phase B & Phase D: Participant Claiming & Integrity Suite', () {
    test('7. Concurrent claim attempts: second claim fails with ConflictException', () async {
      final trip = await tripRepo.createTrip(
        name: 'Goa Concurrency Test',
        creator: creatorUser,
        initialFriendNames: ['Rohan'],
      );
      final placeholderRohan = trip.members.firstWhere((m) => m.displayName == 'Rohan');
      expect(placeholderRohan.isUnclaimed, isTrue);

      // First claim succeeds
      final claimedTrip = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: realFriendUser,
        claimMemberId: placeholderRohan.id,
        claimToken: placeholderRohan.claimToken,
      );
      final rohanClaimed = claimedTrip.members.firstWhere((m) => m.id == placeholderRohan.id);
      expect(rohanClaimed.isClaimed, isTrue);
      expect(rohanClaimed.isVirtual, isFalse);
      expect(rohanClaimed.userId, equals(realFriendUser.id));

      // Second concurrent claim attempt by another user on the same placeholder MUST fail with ConflictException
      expect(
        () => tripRepo.joinTrip(
          inviteCodeOrId: trip.inviteCode,
          user: intruderUser,
          claimMemberId: placeholderRohan.id,
          claimToken: placeholderRohan.claimToken,
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test('8. Offline claim followed by online sync preserves data integrity and balances', () async {
      // 1. Create trip offline with virtual member Rahul
      final trip = await tripRepo.createTrip(
        name: 'Kashmir Shikara Trip',
        creator: creatorUser,
        initialFriendNames: ['Rahul'],
      );
      final virtualRahul = trip.members.firstWhere((m) => m.displayName == 'Rahul');
      final creatorMember = trip.members.firstWhere((m) => m.isCreator);

      // 2. Add an expense split with virtual Rahul (total 10,000 paise; 5,000 each)
      final expense = Expense(
        id: 'exp_shikara_001',
        tripId: trip.id,
        title: 'Shikara Boat Ride',
        category: ExpenseCategory.activities,
        amountInPaise: 10000,
        paidById: creatorMember.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        splits: [
          ExpenseSplit(
            memberId: creatorMember.id,
            amountInPaise: 5000,
          ),
          ExpenseSplit(
            memberId: virtualRahul.id,
            amountInPaise: 5000,
          ),
        ],
      );
      await expenseRepo.addExpense(expense);

      // Verify initial balance: Rahul owes 5000 paise
      final expensesBefore = expenseRepo.getCachedExpenses(trip.id);
      final balancesBefore = BalanceEngine.calculateBalances(
        members: trip.members,
        expenses: expensesBefore,
        settlements: const [],
        currentUserId: creatorUser.id,
      );
      expect(balancesBefore.memberNetBalances[virtualRahul.id], equals(-5000));

      // 3. Rahul comes in and legitimately claims his profile offline
      final claimedTrip = await tripRepo.joinTrip(
        inviteCodeOrId: trip.inviteCode,
        user: realFriendUser,
        claimMemberId: virtualRahul.id,
        claimToken: virtualRahul.claimToken,
      );

      final claimedRahul = claimedTrip.members.firstWhere((m) => m.id == virtualRahul.id);
      expect(claimedRahul.id, equals(virtualRahul.id), reason: 'Participant ID must be preserved');
      expect(claimedRahul.isClaimed, isTrue);
      expect(claimedRahul.isVirtual, isFalse);
      expect(claimedRahul.status, equals('claimed'));
      expect(claimedRahul.role, equals('member'));
      expect(claimedRahul.userId, equals(realFriendUser.id));

      // 4. Balances recomputed after claim: Rahul still owes exactly 5000 paise
      final balancesAfterClaim = BalanceEngine.calculateBalances(
        members: claimedTrip.members,
        expenses: expensesBefore,
        settlements: const [],
        currentUserId: creatorUser.id,
      );
      expect(balancesAfterClaim.memberNetBalances[claimedRahul.id], equals(-5000));

      // 5. Online sync simulation: server sends back older snapshot where Rahul was still unclaimed
      final serverSnapshot = trip; // older snapshot with virtual Rahul
      final mergedTrip = claimedTrip.mergeWith(serverSnapshot);

      final finalRahul = mergedTrip.members.firstWhere((m) => m.id == virtualRahul.id);
      expect(finalRahul.isClaimed, isTrue, reason: 'Claimed status must not revert to false');
      expect(finalRahul.isVirtual, isFalse, reason: 'Must not revert to virtual');
      expect(finalRahul.status, equals('claimed'));
      expect(finalRahul.userId, equals(realFriendUser.id), reason: 'Real userId must be preserved');

      // Balances after merge: 100% preserved
      final balancesAfterMerge = BalanceEngine.calculateBalances(
        members: mergedTrip.members,
        expenses: expensesBefore,
        settlements: const [],
        currentUserId: creatorUser.id,
      );
      expect(balancesAfterMerge.memberNetBalances[finalRahul.id], equals(-5000));
    });
  });
}
