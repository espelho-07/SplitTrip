import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/balance_summary.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kith Premium Widget Ecosystem & Intelligence Tests', () {
    late LocalStorageService storage;
    late KithWidgetService widgetService;

    final testUser = GuestUser(
      id: 'usr_test_01',
      displayName: 'Alice',
      recoveryKey: 'KITH-TEST-1234',
      anonymousToken: 'anon_tok_123',
      createdAt: DateTime.now(),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      widgetService = KithWidgetService(storage: storage);
    });

    test('KithWidgetSnapshot serializes and deserializes cleanly without data loss', () {
      final snapshot = KithWidgetSnapshot(
        spentPaise: 1245000,
        budgetPaise: 0,
        remainingPaise: 0,
        dailyRunwayPaise: 0,
        comparisonText: 'Trip expenses',
        monthName: 'August',
        moneyOwedTotalPaise: 185000,
        topDebts: const [],
        moneyYouOweTotalPaise: 80000,
        topYouOwe: const [],
        activeTripId: 'trip_goa_01',
        activeTripTitle: 'Goa \'26',
        activeTripEmoji: '✈️',
        activeTripSpentPaise: 842000,
        activeTripUserBalancePaise: 124000,
        activeTripMemberCount: 3,
        smartHeadline: 'You\'re owed ₹1,240 in Goa \'26',
        smartSubtext: 'Unsettled balances pending from friends',
        smartActionLabel: 'Settle',
        smartActionDeepLink: 'kith://trip/trip_goa_01',
        isPrivacyMode: false,
        isSignedOut: false,
        localeCode: 'en',
        lastUpdatedMillis: 1724670000000,
      );

      final json = snapshot.toJson();
      final restored = KithWidgetSnapshot.fromJson(json);

      expect(restored.spentPaise, equals(1245000));
      expect(restored.activeTripTitle, equals('Goa \'26'));
      expect(restored.smartHeadline, equals('You\'re owed ₹1,240 in Goa \'26'));
      expect(restored.isSignedOut, isFalse);
    });

    test('Signed out snapshot is fully sanitized with zero leaked data', () {
      final signedOut = KithWidgetSnapshot.signedOut();
      expect(signedOut.isSignedOut, isTrue);
      expect(signedOut.spentPaise, equals(0));
      expect(signedOut.topDebts, isEmpty);
      expect(signedOut.topYouOwe, isEmpty);
      expect(signedOut.activeTripId, isEmpty);
      expect(signedOut.smartHeadline, equals('Welcome to Kith'));
      expect(signedOut.smartActionDeepLink, equals('kith://auth'));
    });

    test('Privacy mode toggles and persists correctly', () async {
      expect(widgetService.isPrivacyMode, isFalse);
      await widgetService.setPrivacyMode(true);
      expect(widgetService.isPrivacyMode, isTrue);

      final reloadedService = KithWidgetService(storage: storage);
      expect(reloadedService.isPrivacyMode, isTrue);
    });

    test('Smart Kith Intelligence prioritizes active trip with balance', () async {
      final now = DateTime.now();
      final sampleTrip = Trip(
        id: 'trip_01',
        name: 'Manali Heights',
        emoji: '🏔️',
        creatorId: testUser.id,
        inviteCode: 'MANA99',
        lifecycleState: TripLifecycle.active,
        members: [
          TripMember(
            id: 'm1',
            userId: testUser.id,
            displayName: 'Alice',
            joinedAt: now,
          ),
          TripMember(
            id: 'm2',
            userId: 'user_02',
            displayName: 'Bob',
            joinedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final balances = {
        'trip_01': BalanceSummary(
          currentUserNetBalanceInPaise: 150000, // ₹1,500 owed to user
          totalTripSpentInPaise: 450000,
          memberNetBalances: const {},
          debtsToPay: const [],
          debtsToReceive: const [],
          simplifiedSettlements: const [],
        ),
      };

      await widgetService.syncSnapshot(
        currentUser: testUser,
        trips: [sampleTrip],
        tripBalances: balances,
      );

      final raw = storage.getString('kith_widget_snapshot');
      expect(raw, isNotNull);
      expect(raw, contains("You're owed ₹1500 in Manali Heights"));
    });

    test('Smart Kith Intelligence surfaces positive All Clear state when everything settled', () async {
      await widgetService.syncSnapshot(
        currentUser: testUser,
        trips: const [],
        tripBalances: const {},
      );

      final raw = storage.getString('kith_widget_snapshot');
      expect(raw, isNotNull);
      expect(raw, contains('Everything is up to date ✓'));
    });

    test('AppRouter.handleDeepLink safely processes all widget URIs without throwing exceptions', () {
      final deepLinks = [
        'kith://home',
        'kith://create-trip',
        'kith://create-trip/',
        'kith://expense/add',
        'kith://trips',
        'kith://trip/trip_sample_01',
        'kith://widgets',
        'kith://guide',
        'kith://help',
        'kith://cloud-settings',
        'kith://auth',
        'kith://join?code=KITH99',
        'kith://unknown-route-safely-fallback',
        '/',
        '',
      ];

      for (final link in deepLinks) {
        expect(() => AppRouter.handleDeepLink(link), returnsNormally);
      }
    });
  });
}
