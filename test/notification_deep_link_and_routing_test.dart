import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/fcm_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/services/notification_service.dart';
import 'package:kith_app/presentation/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Deep-Link Parsing Tests (AppRouter)', () {
    test('Parses full kith://kith.app custom scheme with query parameters', () {
      const uri = 'kith://kith.app/trip/trip_abc?expenseId=exp_xyz';
      final route = AppRouter.parseDeepLinkToRoute(uri);
      expect(route, '/trip/trip_abc?expenseId=exp_xyz');
    });

    test('Parses short kith://trip scheme with authority-as-path and query parameters', () {
      const uri = 'kith://trip/trip_123?settlementId=stl_456';
      final route = AppRouter.parseDeepLinkToRoute(uri);
      expect(route, '/trip/trip_123?settlementId=stl_456');
    });

    test('Parses https://kith.app Universal Link with expense query parameters', () {
      const uri = 'https://kith.app/trip/trip_789?expenseId=exp_000';
      final route = AppRouter.parseDeepLinkToRoute(uri);
      expect(route, '/trip/trip_789?expenseId=exp_000');
    });

    test('Parses join trip deep link with invite code and claimToken into canonical route', () {
      const uri = 'https://kith.app/join?code=TRIP99&claimToken=sec_tok_123';
      final route = AppRouter.parseDeepLinkToRoute(uri);
      expect(route, '/join-trip?code=TRIP99&token=sec_tok_123');
    });

    test('Parses relative trip route path directly', () {
      const uri = '/trip/trip_relative/members';
      final route = AppRouter.parseDeepLinkToRoute(uri);
      expect(route, '/trip/trip_relative/members');
    });

    test('Handles query string without path separator gracefully', () {
      const uri = 'kith://kith.app/join?code=XYZ123';
      final route = AppRouter.parseDeepLinkToRoute(uri);
      expect(route, '/join-trip?code=XYZ123');
    });

    test('Returns null for empty or invalid URI', () {
      expect(AppRouter.parseDeepLinkToRoute(''), isNull);
      expect(AppRouter.parseDeepLinkToRoute('   '), isNull);
    });
  });

  group('FCM Payload Route Extraction Tests (FcmService)', () {
    test('Normalizes explicit custom scheme route from notification payload', () {
      final data = {
        'route': 'kith://kith.app/trip/trip_99?expenseId=exp_123',
      };
      final route = FcmService.extractRouteFromData(data);
      expect(route, '/trip/trip_99?expenseId=exp_123');
    });

    test('Infers trip expense route when tripId and expenseId are present', () {
      final data = {
        'tripId': 'trip_abc',
        'expenseId': 'exp_def',
        'type': 'expense_created',
      };
      final route = FcmService.extractRouteFromData(data);
      expect(route, '/trip/trip_abc?expenseId=exp_def');
    });

    test('Infers settlement verification route when tripId and settlementId are present', () {
      final data = {
        'tripId': 'trip_abc',
        'settlementId': 'stl_xyz',
        'type': 'settlement_marked_paid',
      };
      final route = FcmService.extractRouteFromData(data);
      expect(route, '/trip/trip_abc?settlementId=stl_xyz');
    });

    test('Infers trip members route when type is member_joined', () {
      final data = {
        'tripId': 'trip_abc',
        'type': 'member_joined',
      };
      final route = FcmService.extractRouteFromData(data);
      expect(route, '/trip/trip_abc/members');
    });

    test('Infers trip overview route when only tripId is present', () {
      final data = {
        'tripId': 'trip_abc',
        'type': 'trip_completed',
      };
      final route = FcmService.extractRouteFromData(data);
      expect(route, '/trip/trip_abc');
    });

    test('Infers personal ledger route when personName is provided', () {
      final data = {
        'personName': 'Aarav Sharma',
      };
      final route = FcmService.extractRouteFromData(data);
      expect(route, '/person-ledger?name=Aarav%20Sharma');
    });
  });

  group('Phase 6 Notification Contract & Sync Tests', () {
    test('syncServerNotifications successfully parses wrapped { data: [...], unreadCount: ... } response', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final notifService = NotificationService(storage);

      final mockPayload = {
        'data': [
          {
            'id': 'notif_server_1',
            'type': 'EXPENSE_CREATED',
            'title': 'New Expense in Goa Trip',
            'body': 'Rahul added ₹1,200 for Dinner',
            'route': '/trip/trip_goa?expenseId=exp_dinner',
            'createdAt': '2026-11-09T08:00:00.000Z',
            'isRead': false,
          },
          {
            'id': 'notif_server_2',
            'type': 'MEMBER_JOINED',
            'title': 'Member joined trip',
            'body': 'Sneha joined Goa Trip',
            'route': '/trip/trip_goa/members',
            'createdAt': '2026-11-09T08:05:00.000Z',
            'isRead': false,
          }
        ],
        'unreadCount': 2
      };

      final mockClient = MockClient((request) async {
        expect(request.url.path.endsWith('/notifications'), isTrue);
        return http.Response(
          jsonEncode(mockPayload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      await notifService.syncServerNotifications(apiClient);

      final saved = storage.getSavedNotifications();
      expect(saved.length, 2);
      expect(saved[0]['id'], 'notif_server_2');
      expect(saved[0]['route'], '/trip/trip_goa/members');
      expect(saved[0]['type'], NotificationType.trip.name);

      expect(saved[1]['id'], 'notif_server_1');
      expect(saved[1]['route'], '/trip/trip_goa?expenseId=exp_dinner');
      expect(saved[1]['type'], NotificationType.expense.name);
    });
  });
}
