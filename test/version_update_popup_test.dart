import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/app_version_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/presentation/viewmodels/version_viewmodel.dart';
import 'package:kith_app/presentation/views/version/kith_update_popup_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KithUpdatePopupDialog Tests', () {
    late LocalStorageService storage;
    late SyncService syncService;
    late AppVersionService versionService;
    late VersionViewModel versionVm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      syncService = SyncService(storage);
      versionService = AppVersionService(
        apiClient: ApiClient(),
        storage: storage,
        syncService: syncService,
      );
      versionVm = VersionViewModel(versionService: versionService);
    });

    testWidgets('1. Renders attractive update dialog with rocket icon, highlights, and CTA button', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<VersionViewModel>.value(value: versionVm),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: KithUpdatePopupDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
      expect(find.text('Level Up Your Kith Experience! 🚀'), findsOneWidget);
      expect(find.text('Update on Play Store ⚡'), findsOneWidget);
      expect(find.text("I'll update later"), findsOneWidget);
    });
  });
}
