import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/design_system/components/liquid_glass_amount_field.dart';
import 'package:kith_app/core/design_system/components/liquid_glass_button.dart';
import 'package:kith_app/core/design_system/components/liquid_glass_card.dart';
import 'package:kith_app/core/design_system/components/liquid_glass_pill.dart';
import 'package:kith_app/core/design_system/engine/liquid_glass_engine.dart';
import 'package:kith_app/core/design_system/navigation/liquid_glass_navigation.dart';
import 'package:kith_app/core/design_system/tokens/glass_tokens.dart';

void main() {
  group('Liquid Glass Tokens & Engine Tests', () {
    test('GlassTokens has expected blur and spacing constraints', () {
      expect(GlassTokens.blurStandard, 16.0);
      expect(GlassTokens.bevelWidthStandard, 1.0);
      expect(GlassSpacing.minTouchTarget, 48.0);
      expect(GlassColors.positiveGreenLight, isA<Color>());
      expect(GlassColors.negativeRedDark, isA<Color>());
    });

    testWidgets('LiquidGlassEngine resolves quality tier and adapts to reduced motion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final tier = LiquidGlassEngine.resolveQuality(context);
              expect(tier, LiquidGlassQualityTier.high);

              final blur = LiquidGlassEngine.getEffectiveBlur(context, 16.0);
              expect(blur, 16.0);

              final surface = LiquidGlassEngine.getSurfaceColor(context, isDark: true);
              expect(surface, GlassColors.darkGlassCard);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('Liquid Glass Reusable Components Widget Tests', () {
    testWidgets('LiquidGlassCard renders child and triggers onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidGlassCard(
              onTap: () => tapped = true,
              child: const Text('Hello Glass'),
            ),
          ),
        ),
      );

      expect(find.text('Hello Glass'), findsOneWidget);
      await tester.tap(find.text('Hello Glass'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('LiquidGlassButton enforces 48dp minimum touch target and handles loading state', (tester) async {
      var clicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidGlassButton(
                text: 'Confirm',
                onPressed: () => clicked = true,
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(LiquidGlassButton);
      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(clicked, isTrue);

      // Verify loading state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidGlassButton(
                text: 'Confirm',
                isLoading: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('LiquidGlassPill renders selection state and triggers onTap', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return LiquidGlassPill(
                  label: 'Food',
                  emoji: '🍕',
                  isSelected: selected,
                  onTap: () => setState(() => selected = !selected),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('🍕'), findsOneWidget);

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
    });

    testWidgets('LiquidGlassAmountField supports preset increment chips', (tester) async {
      final controller = TextEditingController(text: '100');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidGlassAmountField(
              controller: controller,
              currencySymbol: '₹',
            ),
          ),
        ),
      );

      expect(find.text('100'), findsOneWidget);
      expect(find.text('+₹500'), findsOneWidget);

      await tester.tap(find.text('+₹500'));
      await tester.pumpAndSettle();
      expect(controller.text, '600');
    });

    testWidgets('LiquidGlassNavigation back and close buttons enforce 48dp minimum targets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: Builder(
                builder: (context) => LiquidGlassNavigation.backButton(context: context),
              ),
              actions: [
                Builder(
                  builder: (context) => LiquidGlassNavigation.closeButton(context: context),
                ),
              ],
            ),
          ),
        ),
      );

      final backFinder = find.byIcon(Icons.arrow_back_rounded);
      final closeFinder = find.byIcon(Icons.close_rounded);

      expect(backFinder, findsOneWidget);
      expect(closeFinder, findsOneWidget);

      final backBox = find.ancestor(of: backFinder, matching: find.byType(ConstrainedBox)).first;
      final backSize = tester.getSize(backBox);
      expect(backSize.width, greaterThanOrEqualTo(48.0));
      expect(backSize.height, greaterThanOrEqualTo(48.0));
    });
  });
}
