import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/qr_code_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late AuthService authService;
  late UserRepository userRepo;
  late TripRepository tripRepo;

  // In-memory backend simulation tables
  late Map<String, dynamic> dbTrips;
  late Map<String, dynamic> dbUsers;
  late Map<String, dynamic> dbSessions;
  late List<Map<String, dynamic>> dbTripMembers;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);

    dbTrips = {};
    dbUsers = {};
    dbSessions = {};
    dbTripMembers = [];

    // Mock HTTP Handler simulating Kith Backend
    final mockHttp = MockClient((request) async {
      final path = request.url.path;
      final method = request.method;
      final authHeader = request.headers['authorization'] ?? '';
      final token = authHeader.replaceFirst('Bearer ', '').trim();

      // Auth middleware lookup
      final session = dbSessions[token];
      final currentUserId = session?['userId'] as String?;

      if (path == '/api/auth/guest' && method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final userId = 'usr_guest_${dbUsers.length + 1}';
        final sessionToken = 'kith_sess_$userId';
        final user = {
          'id': userId,
          'displayName': body['displayName'] ?? 'Traveler',
          'avatarUrl': body['avatarUrl'],
          'isGuest': true,
          'recoveryKey': 'KITH-TEST-1234',
          'anonymousToken': sessionToken,
          'upiId': null,
          'upiQr': null,
          'createdAt': DateTime.now().toIso8601String(),
        };
        dbUsers[userId] = user;
        dbSessions[sessionToken] = {'token': sessionToken, 'userId': userId};
        return http.Response(jsonEncode({'user': user, 'token': sessionToken}), 201);
      }

      if (path == '/api/auth/sync-guest' && method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final userId = body['id'] as String;
        final sessionToken = body['token'] as String;
        final existingUser = dbUsers[userId];
        final user = {
          'id': userId,
          'displayName': body['displayName'] ?? existingUser?['displayName'] ?? 'Traveler',
          'avatarUrl': body['avatarUrl'] ?? existingUser?['avatarUrl'],
          'isGuest': true,
          'recoveryKey': body['recoveryKey'] ?? existingUser?['recoveryKey'] ?? 'KITH-TEST-1234',
          'anonymousToken': sessionToken,
          'upiId': existingUser?['upiId'],
          'upiQr': existingUser?['upiQr'],
          'createdAt': existingUser?['createdAt'] ?? DateTime.now().toIso8601String(),
        };
        dbUsers[userId] = user;
        dbSessions[sessionToken] = {'token': sessionToken, 'userId': userId};
        return http.Response(jsonEncode({'data': user, 'session': {'token': sessionToken}}), 200);
      }

      if ((path == '/api/auth/payment' || path == '/api/user/payment') && (method == 'PUT' || method == 'POST')) {
        if (currentUserId == null) return http.Response(jsonEncode({'error': 'Unauthorized'}), 401);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final upiId = body['upiId'] as String?;
        if (dbUsers.containsKey(currentUserId)) {
          dbUsers[currentUserId]['upiId'] = upiId?.trim().toLowerCase();
        }
        for (final m in dbTripMembers) {
          if (m['userId'] == currentUserId) {
            m['upiId'] = upiId?.trim().toLowerCase();
          }
        }
        return http.Response(jsonEncode({'data': dbUsers[currentUserId]}), 200);
      }

      if (path.startsWith('/api/auth/users/') && path.endsWith('/upi') && method == 'GET') {
        final segments = request.url.pathSegments;
        final targetUserId = segments[segments.length - 2];
        final user = dbUsers[targetUserId];
        if (user != null) {
          return http.Response(jsonEncode({'upiId': user['upiId'], 'displayName': user['displayName']}), 200);
        }
        return http.Response(jsonEncode({'upiId': null, 'displayName': 'Traveler'}), 200);
      }

      if (path == '/api/trips' && method == 'POST') {
        if (currentUserId == null) return http.Response(jsonEncode({'error': 'Unauthorized'}), 401);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final tripId = body['id'] as String? ?? 'trip_123';
        final inviteCode = body['inviteCode'] as String? ?? 'MAN999';
        final creatorUser = dbUsers[currentUserId];

        final creatorMember = {
          'id': 'mbr_creator',
          'tripId': tripId,
          'userId': currentUserId,
          'displayName': creatorUser?['displayName'] ?? 'Creator',
          'avatarUrl': creatorUser?['avatarUrl'],
          'role': 'creator',
          'joinedAt': DateTime.now().toIso8601String(),
          'upiId': creatorUser?['upiId'],
        };
        dbTripMembers.add(creatorMember);

        final trip = {
          'id': tripId,
          'name': body['name'],
          'description': body['description'],
          'emoji': body['emoji'] ?? '??',
          'coverGradientIndex': body['coverGradientIndex'] ?? 0,
          'currencyCode': body['currencyCode'] ?? 'INR',
          'creatorId': currentUserId,
          'inviteCode': inviteCode,
          'lifecycleState': 'active',
          'tripMode': body['tripMode'] ?? 'split_only',
          'members': [creatorMember],
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };
        dbTrips[tripId] = trip;
        return http.Response(jsonEncode(trip), 201);
      }

      if (path == '/api/trips/preview' && method == 'GET') {
        final code = request.url.queryParameters['code']?.toUpperCase();
        final trip = dbTrips.values.where((t) =>
            (t['inviteCode'] as String).toUpperCase() == code ||
            (t['id'] as String).toUpperCase() == code
        ).firstOrNull;

        if (trip != null) {
          final members = dbTripMembers.where((m) => m['tripId'] == trip['id']).toList();
          return http.Response(jsonEncode({
            'tripId': trip['id'],
            'id': trip['id'],
            'name': trip['name'],
            'emoji': trip['emoji'],
            'coverGradientIndex': trip['coverGradientIndex'],
            'currencyCode': trip['currencyCode'],
            'creatorName': 'Alex',
            'memberCount': members.length,
            'lifecycleState': trip['lifecycleState'],
            'inviteCode': trip['inviteCode'],
          }), 200);
        }
        return http.Response(jsonEncode({'error': 'Not Found'}), 404);
      }

      if (path == '/api/trips/join' && method == 'POST') {
        if (currentUserId == null) return http.Response(jsonEncode({'error': 'Unauthorized'}), 401);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final code = (body['inviteCode'] as String?)?.toUpperCase();

        final trip = dbTrips.values.where((t) =>
            (t['inviteCode'] as String).toUpperCase() == code ||
            (t['id'] as String).toUpperCase() == code
        ).firstOrNull;

        if (trip == null) {
          return http.Response(jsonEncode({'error': 'Trip not found'}), 404);
        }

        final joiningUser = dbUsers[currentUserId];
        final existing = dbTripMembers.where((m) => m['tripId'] == trip['id'] && m['userId'] == currentUserId).firstOrNull;
        if (existing == null) {
          final newMember = {
            'id': 'mbr_${dbTripMembers.length + 1}',
            'tripId': trip['id'],
            'userId': currentUserId,
            'displayName': joiningUser?['displayName'] ?? 'Joiner',
            'avatarUrl': joiningUser?['avatarUrl'],
            'role': 'member',
            'joinedAt': DateTime.now().toIso8601String(),
            'upiId': joiningUser?['upiId'],
          };
          dbTripMembers.add(newMember);
        }

        final members = dbTripMembers.where((m) => m['tripId'] == trip['id']).map((m) {
          final u = dbUsers[m['userId']];
          return {
            ...m,
            'upiId': m['upiId'] ?? u?['upiId'],
          };
        }).toList();

        final enrichedTrip = {
          ...trip,
          'members': members,
        };
        return http.Response(jsonEncode(enrichedTrip), 200);
      }

      return http.Response(jsonEncode({'error': 'Unhandled mock route'}), 404);
    });

    apiClient = ApiClient(httpClient: mockHttp);
    authService = AuthService(apiClient: apiClient, storage: storage);
    userRepo = UserRepository(authService: authService);
    tripRepo = TripRepository(storage: storage, syncService: syncService, apiClient: apiClient);
  });

  group('P0 Critical Bug Fix #1: Guest Trip Creation & Joining', () {
    test('1. Guest User A creates trip -> Trip is synchronously saved on server with invite code', () async {
      final guestA = await userRepo.createGuestUser(displayName: 'Alex (Guest)');
      expect(guestA.id, isNotEmpty);
      expect(guestA.anonymousToken, isNotEmpty);

      final tripA = await tripRepo.createTrip(
        name: 'Goa Weekend 2026',
        emoji: '???',
        creator: guestA,
      );

      expect(tripA.id, isNotEmpty);
      expect(tripA.inviteCode, isNotEmpty);
      expect(tripA.creatorId, equals(guestA.id));
      expect(tripA.members.length, equals(1));
      expect(tripA.members.first.userId, equals(guestA.id));

      // Check trip exists in backend dbTrips
      expect(dbTrips.containsKey(tripA.id), isTrue);
      expect(dbTrips[tripA.id]['inviteCode'], equals(tripA.inviteCode));
    });

    test('2. Guest User B joins Guest User A trip via 6-digit invite code', () async {
      // Creator A
      final guestA = await userRepo.createGuestUser(displayName: 'Alex');
      final tripA = await tripRepo.createTrip(name: 'Manali Expedition', creator: guestA);

      // Joiner B
      final guestB = await userRepo.createGuestUser(displayName: 'Sam');
      final preview = await tripRepo.getTripPreview(tripA.inviteCode);
      expect(preview, isNotNull);
      expect(preview!.name, equals('Manali Expedition'));
      expect(preview.inviteCode, equals(tripA.inviteCode));

      final joinedTrip = await tripRepo.joinTrip(inviteCodeOrId: tripA.inviteCode, user: guestB);
      expect(joinedTrip.id, equals(tripA.id));
      expect(joinedTrip.members.length, equals(2));
      expect(joinedTrip.members.any((m) => m.userId == guestB.id), isTrue);
    });

    test('3. QR Code Parser parses web link, app scheme, and direct code payloads', () {
      const inviteCode = 'GOA999';
      expect(QrCodeParser.extractInviteCode('https://kith.app/join?code=$inviteCode'), equals(inviteCode));
      expect(QrCodeParser.extractInviteCode('kith://join?code=$inviteCode'), equals(inviteCode));
      expect(QrCodeParser.extractInviteCode('kith://trip?code=$inviteCode'), equals(inviteCode));
      expect(QrCodeParser.extractInviteCode('https://kith.app/join/$inviteCode'), equals(inviteCode));
      expect(QrCodeParser.extractInviteCode('https://splittrip.app/join?code=$inviteCode'), equals(inviteCode));
      expect(QrCodeParser.extractInviteCode('https://splittrip-4es6.onrender.com/join?code=$inviteCode'), equals(inviteCode));
      expect(QrCodeParser.extractInviteCode(inviteCode), equals(inviteCode));
      expect(QrCodeParser.extractInviteCode('GOA-999'), equals(inviteCode));
      expect(QrCodeParser.extractInviteCode('trip_abc12345678'), equals('TRIP_ABC12345678'));
      expect(QrCodeParser.extractInviteCode('https://malicious.example.com/fake'), isNull);
    });

    test('4. Authenticated User C joins Guest User A trip via QR code scanned link', () async {
      // Creator A (Guest)
      final guestA = await userRepo.createGuestUser(displayName: 'Guest Host');
      final tripA = await tripRepo.createTrip(name: 'Kerala Backwaters', creator: guestA);

      // Scanned QR code URL
      final qrPayload = 'https://kith.app/join?code=${tripA.inviteCode}';
      final extractedCode = QrCodeParser.extractInviteCode(qrPayload);
      expect(extractedCode, equals(tripA.inviteCode));

      // User C
      final userC = await userRepo.createGuestUser(displayName: 'Dev (Nirniq Auth)');
      final joinedTrip = await tripRepo.joinTrip(inviteCodeOrId: extractedCode!, user: userC);
      expect(joinedTrip.id, equals(tripA.id));
      expect(joinedTrip.members.length, equals(2));
      expect(joinedTrip.members.any((m) => m.displayName == 'Dev (Nirniq Auth)'), isTrue);
    });
  });

  group('P0 Critical Bug Fix #2: UPI Payment Configuration & Recipient Resolution', () {
    test('1. User B configures UPI ID -> Persisted in storage and synced to backend', () async {
      final userB = await userRepo.createGuestUser(displayName: 'Rahul');
      expect(userB.upiId, isNull);

      final updatedB = await userRepo.updatePaymentInfo('rahul@okaxis');
      expect(updatedB, isNotNull);
      expect(updatedB!.upiId, equals('rahul@okaxis'));
      expect(storage.getPrimaryUpiId(), equals('rahul@okaxis'));
      expect(dbUsers[userB.id]['upiId'], equals('rahul@okaxis'));
    });

    test('2. Dynamic Recipient UPI lookup resolves User B configured UPI for User A settlement', () async {
      // User A (Payer)
      final userA = await userRepo.createGuestUser(displayName: 'Alex (Payer)');
      await userRepo.updatePaymentInfo('alex@okhdfc');

      // User B (Recipient)
      final userB = await userRepo.createGuestUser(displayName: 'Rahul (Payee)');
      await userRepo.updatePaymentInfo('rahul@okaxis');

      // Create Trip and join
      final trip = await tripRepo.createTrip(name: 'Dinner Trip', creator: userA);
      final joinedTrip = await tripRepo.joinTrip(inviteCodeOrId: trip.inviteCode, user: userB);

      // User A looks up User B's UPI
      final toMember = joinedTrip.members.firstWhere((m) => m.userId == userB.id);
      String? resolvedUpi = toMember.upiId;

      if (resolvedUpi == null || resolvedUpi.isEmpty) {
        resolvedUpi = await userRepo.getUserUpi(toMember.userId);
      }

      expect(resolvedUpi, equals('rahul@okaxis'));
      expect(resolvedUpi, isNot(equals('alex@okhdfc'))); // Must NOT resolve payer's own UPI
    });

    test('3. User B updates UPI ID -> Subsequent lookup receives new UPI ID', () async {
      final userB = await userRepo.createGuestUser(displayName: 'Rahul');
      await userRepo.updatePaymentInfo('rahul.old@upi');

      var liveUpi = await userRepo.getUserUpi(userB.id);
      expect(liveUpi, equals('rahul.old@upi'));

      // User B updates to new VPA
      await userRepo.updatePaymentInfo('rahul.new@icici');
      liveUpi = await userRepo.getUserUpi(userB.id);
      expect(liveUpi, equals('rahul.new@icici'));
    });
  });
}
