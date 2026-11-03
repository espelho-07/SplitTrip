import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/presentation/viewmodels/locale_viewmodel.dart';
import 'package:kith_app/presentation/views/guide/setup_guide_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kith Setup Guide Widget Tests', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
    });

    testWidgets('Renders all 5 Guide categories and header info', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final localeVm = LocaleViewModel(storage: storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: localeVm),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
            ],
            home: const SetupGuideView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header
      expect(find.text('How Kith Works'), findsOneWidget);

      // Check category tabs
      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('Cloud Backup & Sync'), findsOneWidget);
      expect(find.text('Trips & Group Splits'), findsOneWidget);

      // Check items under Getting Started (default selected category)
      expect(find.text('Change App Language'), findsOneWidget);
      expect(find.text('Home Screen Widgets'), findsOneWidget);
    });

    testWidgets('Switching categories updates guide items', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final localeVm = LocaleViewModel(storage: storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: localeVm),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
            ],
            home: const SetupGuideView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Trips & Group Splits tab
      await tester.tap(find.text('Trips & Group Splits'));
      await tester.pumpAndSettle();

      expect(find.text('Create a Group Trip'), findsOneWidget);
      expect(find.text("Join a Friend's Trip"), findsOneWidget);
      expect(find.text('Settle Balances & Simplify Debts'), findsOneWidget);
    });
  });
}
