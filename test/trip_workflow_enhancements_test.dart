import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/models/balance_summary.dart';
import 'package:kith_app/domain/models/settlement_transaction.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/views/trip/widgets/settlement_sheet.dart';
import 'package:kith_app/presentation/views/trip/widgets/trip_completion_modal.dart';

void main() {
  group('Trip Workflow Enhancements & Widgets', () {
    final now = DateTime.now();
    final testTrip = Trip(
      id: 'trip-1',
      name: 'Goa Trip 2026',
      creatorId: 'u1',
      inviteCode: 'GOA123',
      members: [
        TripMember(id: 'm1', userId: 'u1', displayName: 'Darpan', role: 'creator', joinedAt: now),
        TripMember(id: 'm2', userId: 'u2', displayName: 'Rahul', role: 'member', joinedAt: now),
      ],
      createdAt: now,
      updatedAt: now,
    );

    testWidgets('TripCompletionModal renders destination title, total spend, and done CTA', (tester) async {
      const summary = BalanceSummary(
        totalTripSpentInPaise: 1500000, // Rs 15,000
        memberNetBalances: {'m1': 750000, 'm2': -750000},
        currentUserNetBalanceInPaise: 750000,
        debtsToPay: [],
        debtsToReceive: [],
        simplifiedSettlements: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TripCompletionModal.show(
                  context,
                  trip: testTrip,
                  balanceSummary: summary,
                  expenseCount: 4,
                ),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Trip Completed!'), findsOneWidget);
      expect(find.textContaining('Goa Trip 2026'), findsOneWidget);
      expect(find.text('TOTAL SPENT'), findsOneWidget);
      expect(find.text('4 items'), findsOneWidget);
      expect(find.text('All Balances Settled'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('SettlementSheet renders Mark Paid button and removes settled item reactively on tap', (tester) async {
      bool transferRecorded = false;

      const summaryWithPending = BalanceSummary(
        totalTripSpentInPaise: 500000,
        memberNetBalances: {'m1': 250000, 'm2': -250000},
        currentUserNetBalanceInPaise: 250000,
        debtsToPay: [],
        debtsToReceive: [DebtTransfer(fromMemberId: 'm2', toMemberId: 'm1', amountInPaise: 250000)],
        simplifiedSettlements: [
          SettlementTransaction(
            fromMemberId: 'm2',
            toMemberId: 'm1',
            amountInPaise: 250000,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettlementSheet(
              trip: testTrip,
              balanceSummary: summaryWithPending,
              currentUserId: 'u1',
              onRecordTransfer: (from, to, amount) async {
                transferRecorded = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Simplified Settlement'), findsOneWidget);
      expect(find.text('Mark Paid'), findsOneWidget);

      // Tap Mark Paid
      await tester.tap(find.text('Mark Paid'));
      await tester.pumpAndSettle();

      expect(transferRecorded, isTrue);
      // Item is marked paid and filtered out of pending list reactively
      expect(find.text('All Balances are Even!'), findsOneWidget);
    });
  });
}
