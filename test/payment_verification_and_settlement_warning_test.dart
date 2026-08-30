import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/payment_verification_request.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/services/notification_service.dart';
import 'package:kith_app/presentation/viewmodels/trip_detail_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('2-Sided Payment Verification Model & Storage Tests', () {
    test('1. PaymentVerificationRequest serialization, deserialization and status getters', () {
      final now = DateTime(2026, 8, 30, 10, 30);
      final req = PaymentVerificationRequest(
        id: 'pvr_123',
        settlementId: 'stl_456',
        tripId: 'trip_789',
        tripName: 'Girnar Trip',
        payerMemberId: 'm_x',
        payerUserId: 'u_x',
        payerName: 'Rohan',
        receiverMemberId: 'm_y',
        receiverUserId: 'u_y',
        receiverName: 'Priya',
        amountInPaise: 50000,
        paymentMethod: 'UPI',
        paymentReference: 'UPI_REF_999',
        recipientUpiId: 'priya@upi',
        note: 'Settlement for dinner',
        status: 'pending_verification',
        markedAt: now,
      );

      expect(req.isPending, isTrue);
      expect(req.isConfirmed, isFalse);
      expect(req.isDisputed, isFalse);
      expect(req.amountInRupees, 500.0);

      final json = req.toJson();
      expect(json['id'], 'pvr_123');
      expect(json['tripName'], 'Girnar Trip');
      expect(json['payerName'], 'Rohan');
      expect(json['receiverName'], 'Priya');
      expect(json['amountInPaise'], 50000);
      expect(json['status'], 'pending_verification');

      final fromJson = PaymentVerificationRequest.fromJson(json);
      expect(fromJson.id, req.id);
      expect(fromJson.tripName, req.tripName);
      expect(fromJson.payerName, req.payerName);
      expect(fromJson.receiverName, req.receiverName);
      expect(fromJson.amountInPaise, req.amountInPaise);
      expect(fromJson.isPending, isTrue);

      final confirmed = req.copyWith(status: 'confirmed', respondedAt: DateTime.now());
      expect(confirmed.isConfirmed, isTrue);
      expect(confirmed.isPending, isFalse);

      final disputed = req.copyWith(status: 'disputed', disputeReason: 'Not received in bank');
      expect(disputed.isDisputed, isTrue);
      expect(disputed.disputeReason, 'Not received in bank');
    });

    test('2. LocalStorageService persists, updates, and queries pending receiver verifications and dispute alerts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final req1 = {
        'id': 'pvr_1',
        'settlementId': 'stl_1',
        'tripId': 'trip_1',
        'tripName': 'Girnar Trip',
        'payerMemberId': 'm_x',
        'payerUserId': 'user_x',
        'payerName': 'Rohan',
        'receiverMemberId': 'm_y',
        'receiverUserId': 'user_y',
        'receiverName': 'Priya',
        'amountInPaise': 50000,
        'status': 'pending_verification',
        'markedAt': DateTime.now().toIso8601String(),
      };

      await storage.addPaymentVerification(req1);
      final saved = storage.getSavedPaymentVerifications();
      expect(saved.length, 1);
      expect(saved.first['id'], 'pvr_1');

      // Query pending for receiver user_y
      final pendingForY = storage.getPendingVerificationsForReceiver(userId: 'user_y');
      expect(pendingForY.length, 1);
      expect(pendingForY.first['payerName'], 'Rohan');

      // Receiver non-matching should return empty
      final pendingForZ = storage.getPendingVerificationsForReceiver(userId: 'user_z');
      expect(pendingForZ.isEmpty, isTrue);

      // Receiver disputes payment
      await storage.updatePaymentVerificationStatus('pvr_1', 'disputed', reason: 'Did not receive in account');

      // Now pending for receiver should be empty
      expect(storage.getPendingVerificationsForReceiver(userId: 'user_y').isEmpty, isTrue);

      // Disputed query for Payer user_x should return the dispute
      final disputedForX = storage.getDisputedVerificationsForPayer(userId: 'user_x');
      expect(disputedForX.length, 1);
      expect(disputedForX.first['disputeReason'], 'Did not receive in account');
    });
  });

  group('2-Sided Settlement Handshake in ExpenseRepository Tests', () {
    test('3. Payer marks paid -> Receiver confirms -> Balances and status update to settled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final syncService = SyncService(storage);
      final apiClient = ApiClient();
      final expenseRepo = ExpenseRepository(
        apiClient: apiClient,
        storage: storage,
        syncService: syncService,
      );

      // Payer X marks payment to Y for 500
      await expenseRepo.recordSettlement(
        tripId: 'trip_girnar',
        fromMemberId: 'm_x',
        toMemberId: 'm_y',
        amountInPaise: 50000,
        settlementId: 'stl_girnar_1',
        fromName: 'Rohan',
        toName: 'Priya',
        tripName: 'Girnar Trip',
        paymentStatus: 'pending_verification',
      );

      // Verify cached settlements locally
      final cached = expenseRepo.getCachedSettlements('trip_girnar');
      expect(cached.length, 1);
      expect(cached.first['status'], 'pending_verification');
      expect(cached.first['isSettled'], isFalse);

      // Receiver Priya confirms receipt
      await expenseRepo.confirmSettlementVerification(
        tripId: 'trip_girnar',
        verificationId: 'pvr_stl_girnar_1',
        settlementId: 'stl_girnar_1',
        receiverName: 'Priya',
        payerName: 'Rohan',
        amountInPaise: 50000,
      );

      final updatedSettlements = expenseRepo.getCachedSettlements('trip_girnar');
      expect(updatedSettlements.first['status'], 'paid');
      expect(updatedSettlements.first['isSettled'], isTrue);

      // Activity logs should record confirmation
      final logs = storage.getSavedActivityLogs('trip_girnar');
      expect(logs.any((l) => (l['description'] as String).contains('Priya confirmed receiving')), isTrue);
    });

    test('4. Receiver disputes payment -> Status becomes disputed, remains unsettled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final syncService = SyncService(storage);
      final apiClient = ApiClient();
      final expenseRepo = ExpenseRepository(
        apiClient: apiClient,
        storage: storage,
        syncService: syncService,
      );

      await expenseRepo.recordSettlement(
        tripId: 'trip_girnar',
        fromMemberId: 'm_x',
        toMemberId: 'm_y',
        amountInPaise: 50000,
        settlementId: 'stl_girnar_2',
        fromName: 'Rohan',
        toName: 'Priya',
        tripName: 'Girnar Trip',
        paymentStatus: 'pending_verification',
      );

      // Receiver Priya disputes
      await expenseRepo.disputeSettlementVerification(
        tripId: 'trip_girnar',
        verificationId: 'pvr_stl_girnar_2',
        settlementId: 'stl_girnar_2',
        receiverName: 'Priya',
        payerName: 'Rohan',
        amountInPaise: 50000,
        reason: 'Not received in bank account',
      );

      final updatedSettlements = expenseRepo.getCachedSettlements('trip_girnar');
      expect(updatedSettlements.first['status'], 'disputed');
      expect(updatedSettlements.first['isSettled'], isFalse);

      final logs = storage.getSavedActivityLogs('trip_girnar');
      expect(logs.any((l) => (l['description'] as String).contains('reported that ₹500.00 was NOT received')), isTrue);
    });
  });

  group('NotificationService Payment Alerts Tests', () {
    test('5. NotificationService dispatches marked-paid, confirmed, and disputed notifications', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final notifService = NotificationService(storage);
      await notifService.init();

      await notifService.notifyPaymentMarkedPaid(
        tripName: 'Girnar Trip',
        payerName: 'Rohan',
        receiverName: 'Priya',
        amountInPaise: 50000,
        verificationId: 'pvr_test',
        tripId: 'trip_girnar',
      );

      await notifService.notifyPaymentConfirmed(
        tripName: 'Girnar Trip',
        payerName: 'Rohan',
        receiverName: 'Priya',
        amountInPaise: 50000,
        tripId: 'trip_girnar',
      );

      await notifService.notifyPaymentDisputed(
        tripName: 'Girnar Trip',
        payerName: 'Rohan',
        receiverName: 'Priya',
        amountInPaise: 50000,
        tripId: 'trip_girnar',
      );

      final notifs = notifService.getNotifications();
      expect(notifs.length, 3);
      expect(notifs.any((n) => n.title.contains('Payment Verification')), isTrue);
      expect(notifs.any((n) => n.title.contains('Payment Received ✓')), isTrue);
      expect(notifs.any((n) => n.title.contains('Payment Not Received ⚠️')), isTrue);
    });
  });

  group('TripDetailViewModel Settle All Dues & Warning Tests', () {
    test('6. settleAllRemainingDues marks all pending transfers as settled and completes trip', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final syncService = SyncService(storage);
      final apiClient = ApiClient();
      final tripRepo = TripRepository(apiClient: apiClient, storage: storage, syncService: syncService);
      final expenseRepo = ExpenseRepository(apiClient: apiClient, storage: storage, syncService: syncService);

      final trip = Trip(
        id: 'trip_manali',
        name: 'Manali Trip',
        currencyCode: 'INR',
        creatorId: 'user_1',
        inviteCode: 'MANALI99',
        members: [
          TripMember(id: 'm1', userId: 'user_1', displayName: 'Darpan', joinedAt: DateTime.now()),
          TripMember(id: 'm2', userId: 'user_2', displayName: 'Rohan', joinedAt: DateTime.now()),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lifecycleState: TripLifecycle.active,
      );

      await storage.saveTrips([trip.toJson()]);

      // Add an expense of 1000 paid by Darpan, split equally with Rohan (Rohan owes Darpan 500)
      final expense = Expense(
        id: 'exp_1',
        tripId: 'trip_manali',
        title: 'Dinner in Old Manali',
        amountInPaise: 100000,
        category: ExpenseCategory.food,
        paidById: 'm1',
        splits: [
          ExpenseSplit(memberId: 'm1', amountInPaise: 50000),
          ExpenseSplit(memberId: 'm2', amountInPaise: 50000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await storage.saveExpenses('trip_manali', [expense.toJson()]);

      final vm = TripDetailViewModel(
        tripRepo: tripRepo,
        expenseRepo: expenseRepo,
      );

      await vm.loadTrip('trip_manali', 'user_1');
      expect(vm.balanceSummary.simplifiedSettlements.length, 1);
      expect(vm.balanceSummary.simplifiedSettlements.first.amountInPaise, 50000);

      // Settle all remaining dues
      await vm.settleAllRemainingDues('user_1');

      // Balances should now be completely 0 and trip marked as settled
      expect(vm.trip?.lifecycleState, TripLifecycle.settled);
      expect(vm.balanceSummary.simplifiedSettlements.isEmpty, isTrue);
    });
  });
}
