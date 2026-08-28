import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/presentation/views/help/help_faq_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildFaqTestWidget({Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('gu')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HelpFaqView(),
    );
  }

  group('Master FAQ & Knowledge Base Suite', () {
    testWidgets('1. Renders Master Hero, Stats pill, Search bar, and Categories', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildFaqTestWidget());
      await tester.pumpAndSettle();

      // Verify Brand & Hero Headline
      expect(find.text('KITH · HELP'), findsOneWidget);
      expect(find.text('Help & Knowledge'), findsOneWidget);
      expect(find.textContaining('13 Categories'), findsOneWidget);

      // Verify Setup Guide Banner
      expect(find.text('Interactive Setup Guide'), findsOneWidget);

      // Verify Search hint
      expect(find.textContaining('Search questions'), findsOneWidget);

      // Verify category chips
      expect(find.text('ALL TOPICS'), findsOneWidget);
      expect(find.text('ACCOUNT & SECURITY'), findsWidgets);
    });

    testWidgets('2. Expands FAQ accordion card on tap and reveals detailed answer & pro-tip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildFaqTestWidget());
      await tester.pumpAndSettle();

      // Find first FAQ card
      final firstFaq = find.text('How do I get started with Kith?');
      expect(firstFaq, findsOneWidget);

      // Tap to expand
      await tester.tap(firstFaq);
      await tester.pumpAndSettle();

      // Verify answer and pro-tip are now revealed
      expect(find.textContaining('You can start immediately as an anonymous guest'), findsOneWidget);
      expect(find.textContaining('Pro-Tip:'), findsOneWidget);
      expect(find.text('Was this helpful?'), findsWidgets);
      expect(find.text('👍 Yes'), findsWidgets);
      expect(find.text('👎 No'), findsWidgets);
    });

    testWidgets('3. Submitting micro-feedback shows confirmation message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildFaqTestWidget());
      await tester.pumpAndSettle();

      // Expand first FAQ card
      final firstFaq = find.text('How do I get started with Kith?');
      await tester.tap(firstFaq);
      await tester.pumpAndSettle();

      // Tap Yes feedback on the expanded card
      final yesBtn = find.text('👍 Yes').first;
      await tester.ensureVisible(yesBtn);
      await tester.tap(yesBtn);
      await tester.pumpAndSettle();

      // Verify confirmation
      expect(find.text('Thanks for your feedback! ✓'), findsOneWidget);
    });

    testWidgets('4. Searching queries dynamically filters question results', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildFaqTestWidget());
      await tester.pumpAndSettle();

      // Enter search query "Recovery"
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Recovery');
      await tester.pumpAndSettle();

      // Verify filtered results
      expect(find.text('What is a Recovery Key and how does it protect me?'), findsOneWidget);
      expect(find.text('How do I switch between Personal Expenses and Trips?'), findsNothing);
    });

    testWidgets('5. Renders correctly in Hindi (hi) localization', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildFaqTestWidget(locale: const Locale('hi')));
      await tester.pumpAndSettle();

      // Verify Hindi strings
      expect(find.text('सहायता और ज्ञानकोष'), findsOneWidget);
      expect(find.text('सभी विषय'), findsOneWidget);
      expect(find.text('खाता और सुरक्षा'), findsWidgets);
    });

    testWidgets('6. Renders correctly in Gujarati (gu) localization', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildFaqTestWidget(locale: const Locale('gu')));
      await tester.pumpAndSettle();

      // Verify Gujarati strings
      expect(find.text('સહાય અને જ્ઞાનકોશ'), findsOneWidget);
      expect(find.text('તમામ વિષયો'), findsOneWidget);
      expect(find.text('ખાતું અને સુરક્ષા'), findsWidgets);
    });
  });
}
