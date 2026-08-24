import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/theme/app_theme.dart';
import 'package:kith_app/core/widgets/app_button.dart';
import 'package:kith_app/core/widgets/currency_display.dart';

void main() {
  testWidgets('Core UI Component Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              const CurrencyDisplay(
                amountInPaise: 600000,
                size: CurrencyDisplaySize.hero,
              ),
              AppButton(
                text: 'New Trip',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('₹6,000'), findsOneWidget);
    expect(find.text('New Trip'), findsOneWidget);
  });
}
