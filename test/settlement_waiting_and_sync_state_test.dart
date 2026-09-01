import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/widgets/shimmer_skeleton.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/engine/balance_engine.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/split_type.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settlement Waiting States, Duplicate Prevention & Skeleton Loaders', () {
    late LocalStorageService storage;
    late SyncService syncService;
    late ExpenseRepository expenseRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      syncService = SyncService(storage);
      expenseRepo = ExpenseRepository(
        storage: storage,
        syncService: syncService,
        apiClient: ApiClient(),
      );

      final user = GuestUser(
        id: 'usr_payer_1',
        displayName: 'Payer User',
        recoveryKey: 'KITH-1111-2222',
        anonymousToken: 'tok_payer_1',
        createdAt: DateTime.now(),
      );
      await storage.saveUser(user.toJson());
    });

    test('1. Marking payment as paid records pending_verification state and prevents duplicate payment', () async {
      const tripId = 'trip_goa_101';
      const fromMemberId = 'mem_payer_1';
      const toMemberId = 'mem_receiver_2';
      const amountPaise = 50000;

      // 1. Record manual payment (Payer marks paid)
      await expenseRepo.recordSettlement(
        tripId: tripId,
        fromMemberId: fromMemberId,
        toMemberId: toMemberId,
        amountInPaise: amountPaise,
        paymentStatus: 'pending_verification',
        paymentReference: 'upi_ref_12345',
        fromName: 'Payer User',
        toName: 'Receiver User',
      );

      // Verify cached settlements in local storage
      final cached = expenseRepo.getCachedSettlements(tripId);
      expect(cached.isNotEmpty, isTrue);

      final settlement = cached.first;
      expect(settlement['fromMemberId'], equals(fromMemberId));
      expect(settlement['toMemberId'], equals(toMemberId));
      expect(settlement['amountInPaise'], equals(amountPaise));
      expect(settlement['status'], equals('pending_verification'));
      expect(settlement['isSettled'], isFalse);

      // Verify pending in-flight state blocks duplicate
      final isPending = cached.any((s) {
        final matches = s['fromMemberId'] == fromMemberId && s['toMemberId'] == toMemberId;
        final isSettled = s['isSettled'] as bool? ?? false;
        final st = s['status'] as String?;
        return matches && !isSettled && (st == 'pending_verification' || st == 'marked_paid');
      });
      expect(isPending, isTrue);
    });

    test('2. Receiver confirmation transitions settlement to confirmed and completes dues', () async {
      const tripId = 'trip_goa_101';
      const fromMemberId = 'mem_payer_1';
      const toMemberId = 'mem_receiver_2';
      const settlementId = 'stl_test_999';

      final initialSettlement = {
        'id': settlementId,
        'tripId': tripId,
        'fromMemberId': fromMemberId,
        'toMemberId': toMemberId,
        'amountInPaise': 50000,
        'status': 'pending_verification',
        'isSettled': false,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await storage.saveTripSettlements(tripId, [initialSettlement]);

      // Confirm receipt
      await expenseRepo.confirmSettlementVerification(
        tripId: tripId,
        verificationId: 'pvr_$settlementId',
        settlementId: settlementId,
        receiverName: 'Receiver User',
        payerName: 'Payer User',
        amountInPaise: 50000,
      );

      final updated = expenseRepo.getCachedSettlements(tripId);
      expect(updated.first['status'], equals('confirmed'));
      expect(updated.first['isSettled'], isTrue);
    });

    testWidgets('3. Shimmer skeleton composite widgets render properly without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  BalanceCardSkeleton(),
                  ExpenseCardSkeleton(),
                  SizedBox(
                    height: 400,
                    child: PersonLedgerSkeleton(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(BalanceCardSkeleton), findsOneWidget);
      expect(find.byType(ExpenseCardSkeleton), findsOneWidget);
      expect(find.byType(PersonLedgerSkeleton), findsOneWidget);
    });

    test('4. BalanceEngine immediately calculates 0 net debt once settlement is confirmed (even if matched via userId)', () {
      final now = DateTime.now();
      final memberA = TripMember(id: 'mem_A', userId: 'usr_A', displayName: 'User A', role: 'member', joinedAt: now);
      final memberB = TripMember(id: 'mem_B', userId: 'usr_B', displayName: 'User B', role: 'member', joinedAt: now);

      final expense = Expense(
        id: 'exp_1',
        tripId: 'trip_1',
        title: 'Dinner',
        amountInPaise: 10000,
        paidById: 'mem_A',
        category: ExpenseCategory.food,
        splitType: SplitType.equal,
        splits: [
          ExpenseSplit(memberId: 'mem_A', amountInPaise: 5000),
          ExpenseSplit(memberId: 'mem_B', amountInPaise: 5000),
        ],
        createdAt: now,
        updatedAt: now,
      );

      // Before settlement: B owes A ₹50
      final summaryBefore = BalanceEngine.calculateBalances(
        members: [memberA, memberB],
        expenses: [expense],
        settlements: [],
        currentUserId: 'usr_B',
      );
      expect(summaryBefore.debtsToPay.isNotEmpty, isTrue);
      expect(summaryBefore.debtsToPay.first.amountInPaise, equals(5000));

      // After settlement: B paid A ₹50 (recorded with userId 'usr_B' & 'usr_A')
      final summaryAfter = BalanceEngine.calculateBalances(
        members: [memberA, memberB],
        expenses: [expense],
        settlements: [
          {
            'fromMemberId': 'usr_B',
            'toMemberId': 'usr_A',
            'amountInPaise': 5000,
            'status': 'confirmed',
            'isSettled': true,
          }
        ],
        currentUserId: 'usr_B',
      );
      expect(summaryAfter.debtsToPay.isEmpty, isTrue);
      expect(summaryAfter.currentUserNetBalanceInPaise, equals(0));
      expect(summaryAfter.isCurrentUserSettled, isTrue);
    });
  });
}
