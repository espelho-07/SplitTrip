import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/kith_widget_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/personal_budget.dart';
import 'package:kith_app/domain/models/personal_debt.dart';
import 'package:kith_app/domain/models/personal_expense.dart';
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
        budgetPaise: 2000000,
        remainingPaise: 755000,
        dailyRunwayPaise: 46000,
        comparisonText: '₹820 less than last month',
        monthName: 'August',
        moneyOwedTotalPaise: 185000,
        topDebts: [
          {'name': 'Rahul', 'amountPaise': 120000},
          {'name': 'Priya', 'amountPaise': 65000},
        ],
        moneyYouOweTotalPaise: 80000,
        topYouOwe: [
          {'name': 'Aman', 'amountPaise': 80000},
        ],
        activeTripId: 'trip_goa_01',
        activeTripTitle: 'Goa \'26',
        activeTripEmoji: '✈️',
        activeTripSpentPaise: 842000,
        activeTripUserBalancePaise: 124000,
        activeTripMemberCount: 3,
        smartHeadline: 'Rahul owes you ₹1,200',
        smartSubtext: 'From Goa trip expenses',
        smartActionLabel: 'Settle',
        smartActionDeepLink: 'kith://personal/debts',
        isPrivacyMode: false,
        isSignedOut: false,
        localeCode: 'en',
        lastUpdatedMillis: 1724670000000,
      );

      final json = snapshot.toJson();
      final restored = KithWidgetSnapshot.fromJson(json);

      expect(restored.spentPaise, equals(1245000));
      expect(restored.budgetPaise, equals(2000000));
      expect(restored.remainingPaise, equals(755000));
      expect(restored.topDebts.length, equals(2));
      expect(restored.topDebts.first['name'], equals('Rahul'));
      expect(restored.topYouOwe.first['name'], equals('Aman'));
      expect(restored.activeTripTitle, equals('Goa \'26'));
      expect(restored.smartHeadline, equals('Rahul owes you ₹1,200'));
      expect(restored.isSignedOut, isFalse);
    });

    test('Signed out snapshot is fully sanitized with zero leaked personal data', () {
      final signedOut = KithWidgetSnapshot.signedOut();
      expect(signedOut.isSignedOut, isTrue);
      expect(signedOut.spentPaise, equals(0));
      expect(signedOut.budgetPaise, equals(0));
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

    test('Smart Kith Intelligence prioritizes high outstanding debts first', () async {
      final now = DateTime.now();
      final debts = PersonalDebtsSummary(
        totalLentPaise: 120000,
        totalBorrowedPaise: 0,
        netBalancePaise: 120000,
        debts: [
          PersonalDebt(
            id: 'debt_01',
            userId: testUser.id,
            personName: 'Rahul',
            debtType: PersonalDebtType.lent,
            initialAmountInPaise: 120000,
            remainingAmountInPaise: 120000,
            date: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await widgetService.syncSnapshot(
        currentUser: testUser,
        debtsSummary: debts,
      );

      final raw = storage.getString('kith_widget_snapshot');
      expect(raw, isNotNull);
      expect(raw, contains('Rahul owes you ₹1200'));
    });

    test('Smart Kith Intelligence surfaces Budget Warning when threshold exceeded', () async {
      final now = DateTime.now();
      final budget = PersonalBudget(
        monthYear: '2026-08',
        monthlyLimitInPaise: 2000000, // ₹20,000
        spentInPaise: 1800000,
        remainingInPaise: 200000,
        hasBudget: true,
        percentageUsed: 90,
      );

      final expenses = [
        PersonalExpense(
          id: 'exp_01',
          userId: testUser.id,
          title: 'Rent & Groceries',
          amountInPaise: 1800000, // ₹18,000 (90% spent)
          category: ExpenseCategory.food,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await widgetService.syncSnapshot(
        currentUser: testUser,
        personalExpenses: expenses,
        budget: budget,
      );

      final raw = storage.getString('kith_widget_snapshot');
      expect(raw, isNotNull);
      expect(raw, contains('left in your'));
      expect(raw, contains('View Budget'));
    });

    test('Smart Kith Intelligence surfaces positive All Clear state when everything settled', () async {
      await widgetService.syncSnapshot(
        currentUser: testUser,
        personalExpenses: const [],
        debtsSummary: PersonalDebtsSummary.empty(),
      );

      final raw = storage.getString('kith_widget_snapshot');
      expect(raw, isNotNull);
      expect(raw, contains('Everything is up to date ✓'));
    });
  });
}
