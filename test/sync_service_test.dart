import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    syncService = SyncService(storage);
  });

  group('SyncService Tests', () {
    test('Enqueues mutations and persists them to storage', () async {
      await syncService.enqueueMutation(MutationType.addExpense, {
        'tripId': 'trip_100',
        'title': 'Dinner',
        'amountInPaise': 50000,
      });

      final pending = syncService.getPendingMutations();
      expect(pending.length, 1);
      expect(pending.first.type, MutationType.addExpense);
      expect(pending.first.payload['title'], 'Dinner');
    });

    test('Flushes queue against ApiClient and clears completed mutations', () async {
      final processedRequests = <String>[];

      final mockClient = MockClient((request) async {
        processedRequests.add(request.url.path);
        return http.Response(
          jsonEncode({
            'data': {'success': true}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);

      await syncService.enqueueMutation(MutationType.createTrip, {'name': 'Goa'});
      await syncService.enqueueMutation(MutationType.addExpense, {'tripId': 't1', 'title': 'Fuel'});

      expect(syncService.getPendingMutations().length, 2);

      await syncService.flushQueue(apiClient);

      expect(syncService.getPendingMutations().length, 0);
      expect(processedRequests.length, 2);
      expect(processedRequests.any((p) => p.contains('/trips')), isTrue);
    });
  });
}
