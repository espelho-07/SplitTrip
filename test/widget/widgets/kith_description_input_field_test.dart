import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/widgets/kith_description_input_field.dart';

void main() {
  group('KithDescriptionInputField Widget Tests', () {
    testWidgets('renders label, icon, placeholder, and accepts multiline text', (tester) async {
      final controller = TextEditingController();
      String? changedVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KithDescriptionInputField(
              controller: controller,
              label: 'EXPENSE DETAILS',
              hintText: 'What was this expense for?',
              onChanged: (val) => changedVal = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EXPENSE DETAILS'), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
      expect(find.text('What was this expense for?'), findsOneWidget);

      // Enter multiline text
      await tester.enterText(find.byType(TextField), 'First line\nSecond line\nThird line');
      await tester.pumpAndSettle();

      expect(controller.text, 'First line\nSecond line\nThird line');
      expect(changedVal, 'First line\nSecond line\nThird line');
    });

    testWidgets('clear button removes text and fires callback', (tester) async {
      final controller = TextEditingController(text: 'Team Dinner');
      String? changedVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KithDescriptionInputField(
              controller: controller,
              onChanged: (val) => changedVal = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Team Dinner'), findsOneWidget);
      final clearBtn = find.byIcon(Icons.close_rounded);
      expect(clearBtn, findsOneWidget);

      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(controller.text, '');
      expect(changedVal, '');
    });

    testWidgets('quick suggestion chips update controller and fire selection callback', (tester) async {
      final controller = TextEditingController();
      String? selectedSuggestion;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KithDescriptionInputField(
              controller: controller,
              suggestions: const ['Dinner', 'Coffee', 'Fuel', 'Groceries'],
              onSuggestionSelected: (s) => selectedSuggestion = s,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Fuel'), findsOneWidget);

      await tester.tap(find.text('Fuel'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Fuel');
      expect(selectedSuggestion, 'Fuel');
    });
  });
}
