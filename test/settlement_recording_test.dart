import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/balance_summary.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/settlement_transaction.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/services/trip_export_service.dart';

void main() {
  group('TripExportService Tests', () {
    final members = [
      TripMember(
        id: 'm1',
        userId: 'u1',
        displayName: 'Aarav Sharma',
        role: 'creator',
        joinedAt: DateTime(2026, 1, 1),
      ),
      TripMember(
        id: 'm2',
        userId: 'u2',
        displayName: 'Priya Patel',
        role: 'member',
        joinedAt: DateTime(2026, 1, 1),
      ),
    ];

    final trip = Trip(
      id: 't1',
      name: 'Manali Snow Trek',
      emoji: '🏔️',
      coverGradientIndex: 0,
      currencyCode: 'INR',
      creatorId: 'u1',
      inviteCode: 'MNL123',
      lifecycleState: TripLifecycle.active,
      members: members,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final expenses = [
      Expense(
        id: 'e1',
        tripId: 't1',
        title: 'Cab to Manali',
        amountInPaise: 400000,
        category: ExpenseCategory.transport,
        paidById: 'm1',
        splitType: SplitType.equal,
        splits: [
          const ExpenseSplit(memberId: 'm1', amountInPaise: 200000),
          const ExpenseSplit(memberId: 'm2', amountInPaise: 200000),
        ],
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
      ),
      Expense(
        id: 'e2',
        tripId: 't1',
        title: 'Cafe Dinner',
        amountInPaise: 150000,
        category: ExpenseCategory.food,
        paidById: 'm2',
        splitType: SplitType.equal,
        splits: [
          const ExpenseSplit(memberId: 'm1', amountInPaise: 75000),
          const ExpenseSplit(memberId: 'm2', amountInPaise: 75000),
        ],
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
      ),
    ];

    final balanceSummary = BalanceSummary(
      totalTripSpentInPaise: 550000,
      memberNetBalances: {'m1': 125000, 'm2': -125000},
      currentUserNetBalanceInPaise: 125000,
      debtsToPay: const [],
      debtsToReceive: const [],
      simplifiedSettlements: const [
        SettlementTransaction(
          fromMemberId: 'm2',
          toMemberId: 'm1',
          amountInPaise: 125000,
        ),
      ],
    );

    test('Generates structured human-readable plain text export summary', () {
      final summary = TripExportService.generateTextSummary(
        trip: trip,
        expenses: expenses,
        balanceSummary: balanceSummary,
      );

      expect(summary, contains('🏔️ Manali Snow Trek — Financial Summary'));
      expect(summary, contains('Total Spending: INR 5500.00'));
      expect(summary, contains('TRANSPORT: INR 4000.00'));
      expect(summary, contains('FOOD: INR 1500.00'));
      expect(summary, contains('Priya Patel pays Aarav Sharma: INR 1250.00'));
    });

    test('Generates properly quoted CSV table report', () {
      final csv = TripExportService.generateCsvSummary(
        trip: trip,
        expenses: expenses,
      );

      expect(csv, contains('Date,Title,Category,PaidBy,Amount,SplitType,Participants'));
      expect(csv, contains('"Cab to Manali","transport","Aarav Sharma","4000.00","equal","2"'));
      expect(csv, contains('"Cafe Dinner","food","Priya Patel","1500.00","equal","2"'));
    });
  });

  group('Settlement Confirmation & Notification UI Tests', () {
    test('Localization keys format dynamic variables accurately', () {
      final en = AppLocalizations(const Locale('en'));
      final hi = AppLocalizations(const Locale('hi'));
      final gu = AppLocalizations(const Locale('gu'));

      expect(en.settlementMarkPaidDesc('Rahul'), contains('paid to Rahul'));
      expect(en.settlementNotifBody('Darpan', '₹1,000'), 'Darpan marked ₹1,000 as paid to you.');

      expect(hi.settlementMarkPaidDesc('राहुल'), contains('राहुल'));
      expect(hi.settlementNotifBody('दर्पण', '₹1,000'), contains('दर्पण'));

      expect(gu.settlementMarkPaidDesc('રાહુલ'), contains('રાહુલ'));
      expect(gu.settlementNotifBody('દર્પણ', '₹1,000'), contains('દર્પણ'));
    });
  });
}
