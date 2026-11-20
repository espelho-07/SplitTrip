import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/kith_contacts_service.dart';
import 'package:kith_app/core/utils/kith_calculator_engine.dart';
import 'package:kith_app/core/utils/whatsapp_share_helper.dart';
import 'package:kith_app/core/widgets/kith_description_input_field.dart';
import 'package:kith_app/core/widgets/waveform_visualizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsAppShareHelper Tests', () {
    test('normalizePhoneNumber normalizes 10-digit Indian numbers with 91 prefix', () {
      expect(WhatsAppShareHelper.normalizePhoneNumber('9876543210'), '919876543210');
      expect(WhatsAppShareHelper.normalizePhoneNumber('+91 98765 43210'), '919876543210');
      expect(WhatsAppShareHelper.normalizePhoneNumber('09876543210'), '919876543210');
      expect(WhatsAppShareHelper.normalizePhoneNumber(''), '');
      expect(WhatsAppShareHelper.normalizePhoneNumber(null), '');
    });

    test('normalizePhoneNumber preserves international numbers with country codes', () {
      expect(WhatsAppShareHelper.normalizePhoneNumber('14155552671'), '14155552671');
      expect(WhatsAppShareHelper.normalizePhoneNumber('+44 7911 123456'), '447911123456');
    });
  });

  group('KithDeviceContact Model Tests', () {
    test('serializes and deserializes properly', () {
      final map = {
        'name': 'Aditi Sharma',
        'phone': '+91 98765 43210',
        'photo': 'https://example.com/avatar.png',
      };
      final contact = KithDeviceContact.fromMap(map);
      expect(contact.name, 'Aditi Sharma');
      expect(contact.phone, '+91 98765 43210');
      expect(contact.photo, 'https://example.com/avatar.png');

      final serialized = contact.toMap();
      expect(serialized['name'], 'Aditi Sharma');
      expect(serialized['phone'], '+91 98765 43210');
      expect(serialized['photo'], 'https://example.com/avatar.png');
    });

    test('handles missing or null map values gracefully', () {
      final contact = KithDeviceContact.fromMap({});
      expect(contact.name, '');
      expect(contact.phone, '');
      expect(contact.photo, isNull);
    });
  });

  group('WaveformVisualizer Widget Tests', () {
    testWidgets('renders bars when listening is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WaveformVisualizer(
              isListening: true,
              barCount: 20,
              height: 40.0,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WaveformVisualizer), findsOneWidget);
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('renders idle bars when listening is false and updates smoothly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WaveformVisualizer(
              isListening: false,
              barCount: 16,
              height: 32.0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(WaveformVisualizer), findsOneWidget);

      // Re-pump with isListening true
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WaveformVisualizer(
              isListening: true,
              barCount: 16,
              height: 32.0,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(WaveformVisualizer), findsOneWidget);
    });
  });

  group('KithDescriptionInputField Safeguard Tests', () {
    testWidgets('respects maxLength of 250 characters and does not overflow', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KithDescriptionInputField(
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Attempt to enter 300 characters
      final longText = 'A' * 300;
      await tester.enterText(find.byType(TextField), longText);
      await tester.pumpAndSettle();

      expect(controller.text.length, 250);
    });
  });

  group('KithCalculatorEngine Boundary Security Tests', () {
    test('enforces overflow limits for extreme values', () {
      final res = KithCalculatorEngine.evaluateExpression('1000000001');
      expect(res.status, CalculatorEvaluationStatus.error);
      expect(res.errorMessage, 'Amount exceeds maximum limit');
      expect(res.amountInPaise, 0);
    });

    test('rejects negative results defensively', () {
      final res = KithCalculatorEngine.evaluateExpression('50-100');
      expect(res.status, CalculatorEvaluationStatus.error);
      expect(res.errorMessage, 'Amount cannot be negative');
      expect(res.amountInPaise, 0);
    });

    test('rejects division by zero safely without exception', () {
      final res = KithCalculatorEngine.evaluateExpression('1000/0');
      expect(res.status, CalculatorEvaluationStatus.error);
      expect(res.errorMessage, 'Cannot divide by zero');
      expect(res.amountInPaise, 0);
    });

    test('evaluates valid arithmetic with exact paise precision', () {
      final res = KithCalculatorEngine.evaluateExpression('120.50 + 79.50');
      expect(res.status, CalculatorEvaluationStatus.valid);
      expect(res.amountInPaise, 20000);
      expect(res.previewText, contains('200'));
    });
  });
}
