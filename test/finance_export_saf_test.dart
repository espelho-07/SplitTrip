import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/platform_migration_channel.dart';
import 'package:kith_app/data/services/finance_export_bridge_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformMigrationChannel & SplitTrip SAF Export Tests', () {
    late LocalStorageService storage;
    late FinanceExportBridgeService exportService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'kith_personal_expenses': jsonEncode([
          {
            'id': 'pe_saf_01',
            'title': 'Taxi Fare',
            'amountInPaise': 45000,
            'category': 'travel',
          }
        ]),
        'kith_personal_debts': jsonEncode([
          {
            'id': 'pd_saf_01',
            'personName': 'Gaurav',
            'debtType': 'lent',
            'initialAmountInPaise': 100000,
          }
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      exportService = FinanceExportBridgeService(storage: storage);
    });

    test('isPlatformChannelSupported returns false on non-Android host without exception', () async {
      final supported = await PlatformMigrationChannel.isPlatformChannelSupported();
      expect(supported, isFalse);
    });

    test('SAF and share helper methods return safe defaults on non-Android platform', () async {
      final jsonString = exportService.exportToJsonString();
      expect(jsonString, contains('pe_saf_01'));
      expect(jsonString, contains('pd_saf_01'));

      final saveResult = await PlatformMigrationChannel.saveFileViaSAF(
        fileName: 'kith_test_export.json',
        content: jsonString,
      );
      expect(saveResult, isNull);

      final shareResult = await PlatformMigrationChannel.sharePayload(
        title: 'Share Export',
        content: jsonString,
      );
      expect(shareResult, isFalse);
    });
  });
}
