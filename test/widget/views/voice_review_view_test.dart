import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/models/expense_draft.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/views/add_expense/voice_review_view.dart';

void main() {
  final members = [
    TripMember(
      id: 'mbr_1',
      userId: 'usr_1',
      displayName: 'Alice',
      role: 'creator',
      joinedAt: DateTime.now(),
    ),
    TripMember(
      id: 'mbr_2',
      userId: 'usr_2',
      displayName: 'Bob',
      role: 'member',
      joinedAt: DateTime.now(),
    ),
  ];

  Widget buildTestWidget({
    required String transcript,
    ValueChanged<List<ExpenseDraft>>? onConfirmed,
  }) {
    return MaterialApp(
      home: VoiceReviewView(
        initialTranscript: transcript,
        members: members,
        currentUserId: 'usr_1',
        onConfirmed: onConfirmed ?? (_) {},
      ),
    );
  }

  group('VoiceReviewView Widget Tests', () {
    testWidgets('Renders parsed multi-expense drafts and accurate total', (tester) async {
      final transcript = 'Maine 4k train ke diye, 5k club ke diye aur 800 food ke diye.';

      await tester.pumpWidget(buildTestWidget(transcript: transcript));
      await tester.pumpAndSettle();

      // Top bar title
      expect(find.text('Review Spoken Expenses'), findsOneWidget);

      // Transcript card
      expect(find.text('Spoken Transcript'), findsOneWidget);
      expect(find.textContaining('Maine 4k train ke'), findsOneWidget);

      // Header detected expenses count
      expect(find.text('DETECTED EXPENSES (3)'), findsOneWidget);

      // Verify drafts appear
      expect(find.textContaining('Train'), findsWidgets);
      expect(find.textContaining('Club'), findsWidgets);
      expect(find.textContaining('Food'), findsWidgets);

      // Verify total in dock: ₹9,800
      expect(find.textContaining('₹9,800'), findsWidgets);

      // Bottom button
      expect(find.text('Confirm & Save (3)'), findsOneWidget);
    });

    testWidgets('Calls onConfirmed when user taps Confirm & Save', (tester) async {
      final transcript = '500 coffee';
      List<ExpenseDraft>? confirmedDrafts;

      await tester.pumpWidget(
        buildTestWidget(
          transcript: transcript,
          onConfirmed: (drafts) {
            confirmedDrafts = drafts;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirm & Save (1)'), findsOneWidget);
      await tester.tap(find.text('Confirm & Save (1)'));
      await tester.pump();

      expect(confirmedDrafts, isNotNull);
      expect(confirmedDrafts!.length, 1);
      expect(confirmedDrafts!.first.amountInPaise, 50000);
    });

    testWidgets('Can delete an expense item from list', (tester) async {
      final transcript = 'Train 4000, hotel 5000';

      await tester.pumpWidget(buildTestWidget(transcript: transcript));
      await tester.pumpAndSettle();

      expect(find.text('DETECTED EXPENSES (2)'), findsOneWidget);

      // Tap first delete button
      final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Should now have 1 item left
      expect(find.text('DETECTED EXPENSES (1)'), findsOneWidget);
      expect(find.text('Confirm & Save (1)'), findsOneWidget);
    });
  });
}
