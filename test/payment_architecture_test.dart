import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kith_app/core/localization/app_localizations.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/payment/payment_models.dart';
import 'package:kith_app/core/payment/payment_provider.dart';
import 'package:kith_app/core/payment/payment_service.dart';
import 'package:kith_app/core/payment/upi_payment_provider.dart';
import 'package:kith_app/core/payment/upi_validator.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/balance_summary.dart';
import 'package:kith_app/domain/models/settlement_transaction.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/views/payment/upi_payment_dialog.dart';
import 'package:kith_app/presentation/views/trip/widgets/settlement_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock payment provider for test isolation.
class MockUpiPaymentProvider implements PaymentProvider {
  bool shouldSucceed = true;
  bool supportsVerificationValue = false;
  PaymentRequest? lastInitiatedRequest;

  @override
  String get providerId => 'mock_upi';

  @override
  String get providerName => 'Mock UPI Provider';

  @override
  bool get supportsVerification => supportsVerificationValue;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<PaymentResult> initiatePayment(PaymentRequest request) async {
    lastInitiatedRequest = request;
    if (!UpiValidator.isValidUpiId(request.recipientUpiId)) {
      return PaymentResult.failed(
        transactionReference: request.transactionRef,
        message: 'Invalid recipient UPI ID format',
      );
    }

    if (shouldSucceed) {
      return PaymentResult.initiated(
        transactionReference: request.transactionRef,
        message: 'Launched mock UPI app for ₹${request.formattedRupees}',
      );
    } else {
      return PaymentResult.failed(
        transactionReference: request.transactionRef,
        message: 'Mock UPI launch failed',
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late MockUpiPaymentProvider mockProvider;
  late PaymentService paymentService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    mockProvider = MockUpiPaymentProvider();
    paymentService = PaymentService(defaultProvider: mockProvider);
  });

  group('1. UPI Validator & Security Specification Tests', () {
    test('Validates well-formed UPI VPAs across Indian banking handles', () {
      expect(UpiValidator.isValidUpiId('rohan@okhdfcbank'), isTrue);
      expect(UpiValidator.isValidUpiId('9876543210@paytm'), isTrue);
      expect(UpiValidator.isValidUpiId('priya.sharma@ybl'), isTrue);
      expect(UpiValidator.isValidUpiId('karan_123@axl'), isTrue);
      expect(UpiValidator.isValidUpiId('merchant-pay@upi'), isTrue);
      expect(UpiValidator.isValidUpiId('darpan@apl'), isTrue);
      expect(UpiValidator.isValidUpiId('student@fam'), isTrue);
    });

    test('Rejects malformed, incomplete, or dangerous injection strings', () {
      expect(UpiValidator.isValidUpiId(''), isFalse);
      expect(UpiValidator.isValidUpiId(null), isFalse);
      expect(UpiValidator.isValidUpiId('plainstring'), isFalse);
      expect(UpiValidator.isValidUpiId('@okhdfcbank'), isFalse);
      expect(UpiValidator.isValidUpiId('user@'), isFalse);
      expect(UpiValidator.isValidUpiId('a@b'), isFalse); // Too short
      expect(UpiValidator.isValidUpiId('user with spaces@upi'), isFalse);
      expect(UpiValidator.isValidUpiId('user@upi?amount=500'), isFalse);
      expect(UpiValidator.isValidUpiId('user@upi#malicious'), isFalse);
    });

    test('Detects UPI PSP provider name accurately', () {
      expect(UpiValidator.detectProviderName('rohan@okhdfcbank'), 'Google Pay');
      expect(UpiValidator.detectProviderName('priya@ybl'), 'PhonePe');
      expect(UpiValidator.detectProviderName('karan@paytm'), 'Paytm');
      expect(UpiValidator.detectProviderName('shop@apl'), 'Amazon Pay');
      expect(UpiValidator.detectProviderName('admin@upi'), 'BHIM / NPCI');
      expect(UpiValidator.detectProviderName('darpan@customhandle'), 'UPI');
    });
  });

  group('2. UPI Payment Provider & URL Generation Tests', () {
    test('Constructs standard RFC-compliant NPCI UPI Deep Link URI', () {
      final realUpiProvider = UpiPaymentProvider();
      final request = PaymentRequest(
        recipientUpiId: 'rohan@okhdfcbank',
        recipientName: 'Rohan Sharma',
        amountInPaise: 125000, // ₹ 1,250.00
        currencyCode: 'INR',
        transactionNote: 'Kith: Goa Trip settlement',
        transactionRef: 'kith_stl_trip123_m1_m2_1700000000',
      );

      final uri = realUpiProvider.buildUpiUri(request);

      expect(uri.scheme, 'upi');
      expect(uri.host, 'pay');
      expect(uri.queryParameters['pa'], 'rohan@okhdfcbank');
      expect(uri.queryParameters['pn'], 'Rohan Sharma');
      expect(uri.queryParameters['am'], '1250.00');
      expect(uri.queryParameters['cu'], 'INR');
      expect(uri.queryParameters['tn'], 'Kith: Goa Trip settlement');
      expect(uri.queryParameters['tr'], 'kith_stl_trip123_m1_m2_1700000000');
    });

    test('Strict Security Rule: supportsVerification is FALSE for UPI intent', () {
      final realUpiProvider = UpiPaymentProvider();
      expect(realUpiProvider.supportsVerification, isFalse);
    });
  });

  group('3. PaymentService Orchestration & Idempotency Tests', () {
    test('Generates deterministic, unique transaction reference', () {
      final ref1 = PaymentService.generateTransactionReference(
        tripId: 'trip-goa-2026',
        fromMemberId: 'mem_darpan',
        toMemberId: 'mem_rohan',
        timestampMs: 1700000000000,
      );

      expect(ref1, 'kith_tripgoa2026_memdarpan_memrohan_1700000000000');
    });

    test('Initiates payment and returns PaymentStatus.initiated with isVerified: false', () async {
      final request = PaymentService.createSettlementPaymentRequest(
        recipientUpiId: 'rohan@okhdfcbank',
        recipientName: 'Rohan',
        amountInPaise: 250000, // ₹ 2,500.00
        tripName: 'Manali 2026',
        tripId: 'trip_manali',
        fromMemberId: 'mem_1',
        toMemberId: 'mem_2',
      );

      final result = await paymentService.pay(request);

      expect(result.status, PaymentStatus.initiated);
      expect(result.isVerified, isFalse); // Never claim false verification!
      expect(result.transactionReference, startsWith('kith_tripmanali_mem1_mem2_'));
    });

    test('Rejects payment with invalid UPI ID and returns PaymentStatus.failed', () async {
      final request = PaymentRequest(
        recipientUpiId: 'invalid_upi_no_at',
        recipientName: 'Rohan',
        amountInPaise: 50000,
        transactionNote: 'Test',
        transactionRef: 'ref_123',
      );

      final result = await paymentService.pay(request);

      expect(result.status, PaymentStatus.failed);
      expect(result.isVerified, isFalse);
      expect(result.message, contains('Invalid recipient UPI ID format'));
    });
  });

  group('4. UpiPaymentSheet UI & No-False-Payment-Success Flow', () {
    testWidgets('Renders recipient info, amount, and handles Pay via UPI -> Payment Initiated -> Confirm', (tester) async {
      bool recorded = false;
      String? recordedRef;
      String? recordedStatus;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: UpiPaymentSheet(
              recipientName: 'Rohan Sharma',
              initialRecipientUpiId: 'rohan@okhdfcbank',
              amountInPaise: 125000,
              currencyCode: 'INR',
              tripName: 'Goa Holiday',
              tripId: 'trip_goa_01',
              fromMemberId: 'mem_darpan',
              toMemberId: 'mem_rohan',
              paymentService: paymentService,
              onConfirmSettlement: ({
                required String paymentReference,
                required String recipientUpiId,
                required String paymentStatus,
              }) async {
                recorded = true;
                recordedRef = paymentReference;
                recordedStatus = paymentStatus;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial State: Shows recipient name, formatted amount ₹1,250, and UPI ID
      expect(find.text('Settle Balance'), findsOneWidget);
      expect(find.text('Rohan Sharma'), findsOneWidget);
      expect(find.text('₹1,250'), findsOneWidget);
      expect(find.text('rohan@okhdfcbank'), findsOneWidget);
      expect(find.text('Pay via UPI'), findsOneWidget);
      expect(find.text("I'll pay manually / Mark as Paid"), findsOneWidget);

      // 2. Tap "Pay via UPI"
      await tester.tap(find.text('Pay via UPI'));
      await tester.pumpAndSettle();

      // 3. Stage 2 Verification: Shows "Payment Initiated" and asks for confirmation
      expect(find.text('Payment Initiated'), findsOneWidget);
      expect(find.text('Did you complete the payment of ₹1,250 to Rohan Sharma in your UPI app?'), findsOneWidget);
      expect(find.text('Yes, Mark as Paid'), findsOneWidget);
      expect(find.text('Not yet / Incomplete'), findsOneWidget);
      expect(recorded, isFalse); // Has NOT been recorded yet!

      // 4. User taps "Yes, Mark as Paid"
      await tester.tap(find.text('Yes, Mark as Paid'));
      await tester.pumpAndSettle();

      // 5. Verification: Now genuinely recorded!
      expect(recorded, isTrue);
      expect(recordedStatus == 'completed' || recordedStatus == 'paid', isTrue);
      expect(recordedRef, startsWith('kith_tripgoa01_memdarpan_memrohan_'));
    });

    testWidgets('Manual Mark as Paid flow immediately records without requiring UPI app launch', (tester) async {
      bool recorded = false;
      String? recordedStatus;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: UpiPaymentSheet(
              recipientName: 'Priya Patel',
              initialRecipientUpiId: '',
              amountInPaise: 65000,
              currencyCode: 'INR',
              tripName: 'Udaipur Trip',
              tripId: 'trip_udaipur',
              fromMemberId: 'mem_1',
              toMemberId: 'mem_2',
              paymentService: paymentService,
              onConfirmSettlement: ({
                required String paymentReference,
                required String recipientUpiId,
                required String paymentStatus,
              }) async {
                recorded = true;
                recordedStatus = paymentStatus;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap manual "I'll pay manually / Mark as Paid"
      await tester.tap(find.text("I'll pay manually / Mark as Paid"));
      await tester.pumpAndSettle();

      expect(recorded, isTrue);
      expect(recordedStatus == 'manual_settled' || recordedStatus == 'paid', isTrue);
    });
  });

  group('5. SettlementSheet Integration & Repositories', () {
    testWidgets('SettlementSheet renders list of debts and opens payment sheet', (tester) async {
      final trip = Trip(
        id: 'trip_kith_01',
        name: 'Manali Expedition',
        creatorId: 'usr_darpan',
        inviteCode: 'MANALI',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        members: [
          TripMember(
            id: 'mem_1',
            userId: 'usr_darpan',
            displayName: 'Darpan Parmar',
            joinedAt: DateTime.now(),
          ),
          TripMember(
            id: 'mem_2',
            userId: 'usr_rohan',
            displayName: 'Rohan Sharma',
            upiId: 'rohan@okhdfcbank',
            joinedAt: DateTime.now(),
          ),
        ],
      );

      final balanceSummary = BalanceSummary(
        totalTripSpentInPaise: 500000,
        memberNetBalances: {'mem_1': -125000, 'mem_2': 125000},
        currentUserNetBalanceInPaise: -125000,
        debtsToPay: const [
          DebtTransfer(fromMemberId: 'mem_1', toMemberId: 'mem_2', amountInPaise: 125000),
        ],
        debtsToReceive: const [],
        simplifiedSettlements: const [
          SettlementTransaction(
            fromMemberId: 'mem_1',
            toMemberId: 'mem_2',
            amountInPaise: 125000,
          ),
        ],
      );

      final apiClient = ApiClient();
      final syncService = SyncService(storage);
      final expenseRepo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<LocalStorageService>.value(value: storage),
            Provider<ExpenseRepository>.value(value: expenseRepo),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: SettlementSheet(
                trip: trip,
                balanceSummary: balanceSummary,
                currentUserId: 'usr_darpan',
                paymentService: paymentService,
                onRecordTransfer: (from, to, amount, {paymentReference, recipientUpiId, fromName, toName, paymentStatus}) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settle Up'), findsOneWidget);
      expect(find.text('You'), findsOneWidget); // Payer is current user
      expect(find.text('Rohan Sharma'), findsOneWidget);
      expect(find.text('Pay Rohan Sharma'), findsOneWidget);
      expect(find.text('UPI: rohan@okhdfcbank'), findsOneWidget);
    });

    test('ExpenseRepository saves idempotent settlement and logs local activity', () async {
      final apiClient = ApiClient();
      final syncService = SyncService(storage);
      final expenseRepo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: apiClient,
      );

      await expenseRepo.recordSettlement(
        tripId: 'trip_100',
        fromMemberId: 'mem_a',
        toMemberId: 'mem_b',
        fromName: 'Darpan',
        toName: 'Rohan',
        amountInPaise: 125000,
        settlementId: 'stl_unique_123',
        paymentReference: 'kith_stl_ref_999',
        recipientUpiId: 'rohan@okhdfcbank',
      );

      // Verify stored in local storage
      final settlements = storage.getSavedTripSettlements('trip_100');
      expect(settlements.length, 1);
      expect(settlements.first['id'], 'stl_unique_123');
      expect(settlements.first['amountInPaise'], 125000);
      expect(settlements.first['recipientUpiId'], 'rohan@okhdfcbank');
      expect(settlements.first['paymentReference'], 'kith_stl_ref_999');

      // Verify activity logged
      final activities = storage.getSavedActivityLogs('trip_100');
      expect(activities.length, 1);
      expect(activities.first['description'], contains('Darpan marked ₹1250.00 as paid to Rohan'));

      // Re-recording with SAME ID does NOT duplicate (Idempotency)
      await expenseRepo.recordSettlement(
        tripId: 'trip_100',
        fromMemberId: 'mem_a',
        toMemberId: 'mem_b',
        fromName: 'Darpan',
        toName: 'Rohan',
        amountInPaise: 125000,
        settlementId: 'stl_unique_123',
      );

      final recheckedSettlements = storage.getSavedTripSettlements('trip_100');
      expect(recheckedSettlements.length, 1);
    });
  });
}
