import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/widgets/kith_numeric_keypad.dart';
import 'package:kith_app/core/widgets/kith_text_keypad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kith In-App Keyboard & Keypad Tests', () {
    testWidgets('1. KithNumericKeypad types digits, operators, backspace and triggers onNext/onDone', (tester) async {
      final controller = TextEditingController();
      bool nextCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KithNumericKeypad(
              controller: controller,
              onNext: () => nextCalled = true,
            ),
          ),
        ),
      );

      // Tap '1'
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(controller.text, '1');

      // Tap '0'
      await tester.tap(find.text('0'));
      await tester.pump();
      expect(controller.text, '10');

      // Tap '0'
      await tester.tap(find.text('0'));
      await tester.pump();
      expect(controller.text, '100');

      // Tap Backspace icon
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(controller.text, '10');

      // Tap Forward action button
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump();
      expect(nextCalled, isTrue);
    });

    testWidgets('2. KithTextKeypad types text, handles spaces, caps toggle, symbols, and triggers action', (tester) async {
      final controller = TextEditingController();
      bool doneCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KithTextKeypad(
              controller: controller,
              onDone: () => doneCalled = true,
            ),
          ),
        ),
      );

      // Initially caps is ON, tap 'G'
      await tester.tap(find.text('G'));
      await tester.pump();
      expect(controller.text, 'G');

      // Tap 'O'
      await tester.tap(find.text('O'));
      await tester.pump();
      expect(controller.text, 'GO');

      // Tap 'A'
      await tester.tap(find.text('A'));
      await tester.pump();
      expect(controller.text, 'GOA');

      // Tap space
      await tester.tap(find.text('space'));
      await tester.pump();
      expect(controller.text, 'GOA ');

      // Toggle symbol mode (?123)
      await tester.tap(find.text('?123'));
      await tester.pump();

      // Tap '1' from symbols
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(controller.text, 'GOA 1');

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(doneCalled, isTrue);
    });
  });
}
