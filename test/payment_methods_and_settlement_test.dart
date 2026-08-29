import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payment Methods & Settlement Defaults Tests', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
    });

    test('1. Fresh account has empty payment method and unconfigured state', () {
      expect(storage.getPrimaryUpiId(), isNull);
      expect(storage.hasPaymentMethodConfigured(), isFalse);
      expect(storage.isPaymentPromptDismissed(), isFalse);
    });

    test('2. Setting primary UPI marks payment method as configured', () async {
      await storage.setPrimaryUpiId('darpan@okhdfcbank');
      expect(storage.getPrimaryUpiId(), equals('darpan@okhdfcbank'));
      expect(storage.hasPaymentMethodConfigured(), isTrue);

      // Clearing it
      await storage.setPrimaryUpiId(null);
      expect(storage.getPrimaryUpiId(), isNull);
      expect(storage.hasPaymentMethodConfigured(), isFalse);
    });

    test('3. Saved UPI items list persistence extracts default VPA', () async {
      final items = [
        {
          'id': 'upi_1',
          'vpa': 'alice@okaxis',
          'name': 'Alice Smith',
          'appName': 'Google Pay',
          'isDefault': false,
        },
        {
          'id': 'upi_2',
          'vpa': 'alice@paytm',
          'name': 'Alice Smith',
          'appName': 'Paytm UPI',
          'isDefault': true,
        },
      ];

      await storage.setString(LocalStorageService.savedUpiItemsKey, jsonEncode(items));
      expect(storage.getPrimaryUpiId(), equals('alice@paytm'));
      expect(storage.hasPaymentMethodConfigured(), isTrue);
    });

    test('4. Dismissing payment setup prompt is stored persistently', () async {
      expect(storage.isPaymentPromptDismissed(), isFalse);
      await storage.dismissPaymentPrompt();
      expect(storage.isPaymentPromptDismissed(), isTrue);
    });

    test('5. GuestUser model serializes and deserializes upiId correctly', () {
      final user = GuestUser(
        id: 'usr_test_123',
        displayName: 'Darpan Parmar',
        recoveryKey: 'KITH-TEST-1234',
        anonymousToken: 'anon_test_token',
        createdAt: DateTime.now(),
        upiId: 'darpan@okhdfcbank',
      );

      final json = user.toJson();
      expect(json['upiId'], equals('darpan@okhdfcbank'));

      final restored = GuestUser.fromJson(json);
      expect(restored.upiId, equals('darpan@okhdfcbank'));
    });

    test('6. TripMember preserves recipient upiId for direct 1-tap settlement', () {
      final member = TripMember(
        id: 'mbr_rahul_1',
        userId: 'usr_rahul_99',
        displayName: 'Rahul Verma',
        joinedAt: DateTime.now(),
        upiId: 'rahul@oksbi',
      );

      final json = member.toJson();
      expect(json['upiId'], equals('rahul@oksbi'));

      final restored = TripMember.fromJson(json);
      expect(restored.upiId, equals('rahul@oksbi'));
    });
  });
}
