import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/widgets/kith_amount_calculator_field.dart';

void main() {
  group('KithAmountCalculatorField Widget Tests', () {
    testWidgets('uses numeric keyboard with decimal option by default', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KithAmountCalculatorField(
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, const TextInputType.numberWithOptions(decimal: true, signed: true));
    });

    testWidgets('operator toolbar enters mathematical symbols at cursor position', (tester) async {
      final controller = TextEditingController(text: '100');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KithAmountCalculatorField(
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap '+' operator
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      expect(controller.text, '100+');

      // Tap '2', '3' using in-app keypad toggle or text entry
      controller.text = '100+23';
      controller.selection = const TextSelection.collapsed(offset: 6);
      await tester.pumpAndSettle();

      // Check that live preview pill is rendered
      expect(find.textContaining('123'), findsWidgets);

      // Tap '×' operator
      controller.text = '23';
      controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();
      expect(controller.text, '23×');
    });

    testWidgets('live preview resolves expression into evaluated amount when tapped', (tester) async {
      final controller = TextEditingController(text: '100+23');
      int? updatedPaise;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KithAmountCalculatorField(
              controller: controller,
              onAmountChanged: (paise) => updatedPaise = paise,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(updatedPaise, 12300);

      // Find preview pill
      final previewPill = find.textContaining('123');
      expect(previewPill, findsWidgets);

      // Tap preview to apply
      await tester.tap(previewPill.first);
      await tester.pumpAndSettle();

      expect(controller.text, '123');
    });

    testWidgets('backspace and clear buttons work as expected', (tester) async {
      final controller = TextEditingController(text: '500+2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KithAmountCalculatorField(
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Backspace
      await tester.tap(find.text('⌫'));
      await tester.pumpAndSettle();
      expect(controller.text, '500+');

      // Clear icon
      final clearIcon = find.byIcon(Icons.cancel_rounded);
      expect(clearIcon, findsOneWidget);
      await tester.tap(clearIcon);
      await tester.pumpAndSettle();
      expect(controller.text, '');
    });

    testWidgets('in-app keypad toggle displays full calculator pad with digits and operations', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KithAmountCalculatorField(
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle keypad
      final toggleBtn = find.byIcon(Icons.dialpad_rounded);
      expect(toggleBtn, findsOneWidget);
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Digits 0-9 and operators should now be visible on screen
      expect(find.text('7'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();
      expect(controller.text, '7');
    });
  });
}
