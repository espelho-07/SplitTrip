import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/services/notification_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final res = await handler(req);
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expense Activity Notification Pipeline Flutter Tests', () {
    late LocalStorageService storage;
    late NotificationService notifService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      notifService = NotificationService(storage);
    });

    test('1. syncServerNotifications parses EXPENSE_CREATED and maps to NotificationType.expense', () async {
      final mockClient = MockHttpClient((req) async {
        if (req.url.path.endsWith('/notifications')) {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': [
                {
                  'id': 'notif_exp_123',
                  'recipientUserId': 'usr_recipient',
                  'actorUserId': 'usr_hardev',
                  'actorName': 'Hardev',
                  'tripId': 'trip_goa_01',
                  'tripName': 'Goa Trip',
                  'expenseId': 'exp_dinner_99',
                  'type': 'EXPENSE_CREATED',
                  'title': 'New expense added',
                  'body': 'Hardev added ₹2,400 to Goa Trip.',
                  'amountInPaise': 240000,
                  'route': '/trip/trip_goa_01?expenseId=exp_dinner_99',
                  'status': 'UNREAD',
                  'isRead': false,
                  'createdAt': DateTime.now().toIso8601String(),
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      await notifService.syncServerNotifications(apiClient);

      final saved = storage.getSavedNotifications();
      expect(saved.length, 1);
      expect(saved[0]['id'], 'notif_exp_123');
      expect(saved[0]['type'], 'expense');
      expect(saved[0]['route'], '/trip/trip_goa_01?expenseId=exp_dinner_99');
      expect(saved[0]['actionLabel'], 'View Expense');
    });

    test('2. Idempotent notification handling: duplicate sync does not duplicate items in storage', () async {
      final mockClient = MockHttpClient((req) async {
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': [
              {
                'id': 'notif_exp_123',
                'recipientUserId': 'usr_recipient',
                'actorUserId': 'usr_hardev',
                'actorName': 'Hardev',
                'tripId': 'trip_goa_01',
                'expenseId': 'exp_dinner_99',
                'type': 'EXPENSE_CREATED',
                'title': 'New expense added',
                'body': 'Hardev added ₹2,400 to Goa Trip.',
                'route': '/trip/trip_goa_01?expenseId=exp_dinner_99',
                'isRead': false,
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      // Run sync twice
      await notifService.syncServerNotifications(apiClient);
      await notifService.syncServerNotifications(apiClient);

      final saved = storage.getSavedNotifications();
      expect(saved.length, 1);
    });

    test('3. AppLocalizations correctly formats expense notification strings with parameters', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      expect(l10nEn.expenseNotifAddedTitle, 'New expense added');
      expect(l10nEn.expenseNotifAddedBody('Hardev', '₹2,400', 'Goa Trip'), 'Hardev added ₹2,400 to Goa Trip.');
      expect(
        l10nEn.expenseNotifUpdatedAmountBody('Hardev', 'Dinner', '₹2,400', '₹2,800'),
        'Hardev updated Dinner from ₹2,400 to ₹2,800.',
      );
      expect(l10nEn.expenseNotifDeletedTitle, 'Expense removed');

      final l10nHi = AppLocalizations(const Locale('hi'));
      expect(l10nHi.expenseNotifAddedTitle, 'नया खर्च जोड़ा गया');
      expect(l10nHi.expenseNotifAddedBody('Hardev', '₹2,400', 'Goa Trip'), 'Hardev ने Goa Trip में ₹2,400 जोड़े।');
    });
  });
}
