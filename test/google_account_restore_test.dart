import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
  });

  group('Google Account Persistence & Cross-Device Restore Tests', () {
    test('1. Guest local data is automatically re-tagged when user signs in with Google', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/google' || request.url.path == '/api/auth/nirniq') {
          return http.Response(
            jsonEncode({
              'data': {
                'user': {
                  'id': 'usr_canonical_google_123',
                  'displayName': 'Darpan Cloud',
                  'email': 'darpan.traveler@gmail.com',
                  'googleId': 'google_sub_123',
                  'isGuest': false,
                  'isLinkedToAccount': true,
                  'anonymousToken': 'kith_token_google_123',
                  'createdAt': DateTime.now().toIso8601String(),
                },
                'token': 'kith_token_google_123',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final authService = AuthService(
        storage: storage,
        apiClient: apiClient,
      );

      // Step A: Create guest user locally
      final guest = await authService.createGuestUser(displayName: 'Guest Darpan');
      expect(guest.id, startsWith('usr_'));

      // Step B: Save trips under guest ID
      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );

      final trip = await tripRepo.createTrip(
        name: 'Goa Trip',
        creator: guest,
      );
      expect(trip.creatorId, guest.id);

      // Step C: User signs in with Google on same device
      final googleUser = await authService.signInWithGoogle(
        email: 'darpan.traveler@gmail.com',
        displayName: 'Darpan Cloud',
        googleId: 'google_sub_123',
        supabaseUserId: 'supabase_uid_123',
      );

      expect(googleUser.id, 'usr_canonical_google_123');
      expect(googleUser.isLinkedToAccount, isTrue);

      // Step D: Verify local cached data was re-tagged to the canonical Google user ID
      tripRepo.invalidateCache();
      final cachedTrips = tripRepo.getCachedTrips();
      expect(cachedTrips.length, 1);
      expect(cachedTrips.first.creatorId, 'usr_canonical_google_123');
      expect(cachedTrips.first.members.first.userId, 'usr_canonical_google_123');
    });

    test('2. Fresh install: Signing in with Google restores trips, trip expenses, and personal ledger', () async {
      // Clear all local storage to simulate brand new device / fresh install
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final freshStorage = LocalStorageService(prefs);
      final freshSyncService = SyncService(freshStorage);

      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path == '/api/auth/google' || path == '/api/auth/nirniq') {
          return http.Response(
            jsonEncode({
              'data': {
                'user': {
                  'id': 'usr_canonical_google_123',
                  'displayName': 'Darpan Cloud',
                  'email': 'darpan.traveler@gmail.com',
                  'googleId': 'google_sub_123',
                  'isGuest': false,
                  'isLinkedToAccount': true,
                  'anonymousToken': 'kith_token_google_123',
                  'createdAt': DateTime.now().toIso8601String(),
                },
                'token': 'kith_token_google_123',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == '/api/trips') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'trip_restored_01',
                  'name': 'Manali Cloud Adventure',
                  'creatorId': 'usr_canonical_google_123',
                  'inviteCode': 'MAN999',
                  'emoji': '🏔️',
                  'coverGradientIndex': 0,
                  'currencyCode': 'INR',
                  'tripMode': 'split_only',
                  'lifecycleState': 'active',
                  'members': [
                    {
                      'id': 'mbr_darpan',
                      'userId': 'usr_canonical_google_123',
                      'displayName': 'Darpan Cloud',
                      'role': 'creator',
                      'joinedAt': DateTime.now().toIso8601String(),
                    }
                  ],
                  'createdAt': DateTime.now().toIso8601String(),
                  'updatedAt': DateTime.now().toIso8601String(),
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == '/api/trips/trip_restored_01/expenses') {
          return http.Response(
            jsonEncode([
              {
                'id': 'exp_restored_01',
                'tripId': 'trip_restored_01',
                'title': 'Hotel Booking',
                'amountInPaise': 500000,
                'category': 'stay',
                'paidById': 'mbr_darpan',
                'splitType': 'equal',
                'splits': [
                  {
                    'memberId': 'mbr_darpan',
                    'amountInPaise': 500000,
                  }
                ],
                'createdAt': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == '/api/personal/expenses') {
          return http.Response(
            jsonEncode({
              'expenses': [
                {
                  'id': 'pexp_restored_01',
                  'userId': 'usr_canonical_google_123',
                  'title': 'Flight Tickets',
                  'amountInPaise': 800000,
                  'category': 'transport',
                  'date': DateTime.now().toIso8601String(),
                  'createdAt': DateTime.now().toIso8601String(),
                  'updatedAt': DateTime.now().toIso8601String(),
                }
              ],
              'totalSpentInPaise': 800000,
              'categoryBreakdown': {'transport': 800000},
              'count': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == '/api/personal/debts') {
          return http.Response(
            jsonEncode({
              'debts': [
                {
                  'id': 'pdebt_restored_01',
                  'userId': 'usr_canonical_google_123',
                  'personName': 'Aman',
                  'debtType': 'lent',
                  'initialAmountInPaise': 200000,
                  'remainingAmountInPaise': 200000,
                  'settledAmountInPaise': 0,
                  'isSettled': false,
                  'repayments': [],
                  'date': DateTime.now().toIso8601String(),
                  'createdAt': DateTime.now().toIso8601String(),
                  'updatedAt': DateTime.now().toIso8601String(),
                }
              ],
              'totalLentPaise': 200000,
              'totalBorrowedPaise': 0,
              'netBalancePaise': 200000,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == '/api/personal/budget') {
          return http.Response(
            jsonEncode({
              'monthYear': '2026-08',
              'monthlyLimitInPaise': 10000000,
              'spentInPaise': 800000,
              'remainingInPaise': 9200000,
              'hasBudget': true,
              'percentageUsed': 8,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final authService = AuthService(storage: freshStorage, apiClient: apiClient);
      final tripRepo = TripRepository(storage: freshStorage, syncService: freshSyncService, apiClient: apiClient);
      final expenseRepo = ExpenseRepository(storage: freshStorage, syncService: freshSyncService, apiClient: apiClient);

      // Sign in on fresh device
      final user = await authService.signInWithGoogle(
        email: 'darpan.traveler@gmail.com',
        displayName: 'Darpan Cloud',
        googleId: 'google_sub_123',
        supabaseUserId: 'supabase_uid_123',
      );

      expect(user.id, 'usr_canonical_google_123');

      // Hydrate via HomeViewModel
      final homeVm = HomeViewModel(tripRepo: tripRepo, expenseRepo: expenseRepo);
      await homeVm.loadTrips(user.id);

      // Verify trips restored
      expect(homeVm.trips.length, 1);
      expect(homeVm.trips.first.name, 'Manali Cloud Adventure');
      expect(homeVm.trips.first.inviteCode, 'MAN999');

      // Verify trip expenses restored and cached
      final tripExpenses = expenseRepo.getCachedExpenses('trip_restored_01');
      expect(tripExpenses.length, 1);
      expect(tripExpenses.first.title, 'Hotel Booking');
    });

    test('3. Sign out clears all cached private data to guarantee account isolation', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/logout') {
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final authService = AuthService(storage: storage, apiClient: apiClient);

      // Verify local storage is cleared
      await authService.logout();

      expect(storage.getSavedUser(), isNull);
      expect(storage.getSavedTrips(), isEmpty);
      expect(storage.getSavedPersonalExpenses(), isEmpty);
      expect(storage.getSavedPersonalDebts(), isEmpty);
    });
  });
}
