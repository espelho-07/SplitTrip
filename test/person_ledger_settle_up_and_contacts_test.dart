import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/services/kith_contacts_service.dart';
import 'package:kith_app/core/utils/whatsapp_share_helper.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/repositories/personal_repository.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/repositories/user_repository.dart';
import 'package:kith_app/data/services/auth_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/domain/models/person_ledger_item.dart';
import 'package:kith_app/domain/models/personal_debt.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/home_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/person_ledger_viewmodel.dart';
import 'package:kith_app/presentation/viewmodels/personal_expense_viewmodel.dart';
import 'package:kith_app/presentation/views/personal/widgets/person_settle_up_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ApiClient apiClient;
  late UserRepository userRepo;
  late AuthService authService;
  late AuthViewModel authVm;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late PersonalRepository personalRepo;
  late PersonLedgerViewModel ledgerVm;

  final testUser = GuestUser(
    id: 'user_me_001',
    displayName: 'Current User',
    avatarUrl: '',
    recoveryKey: 'KITH-1234-5678-ABCD',
    anonymousToken: 'anon_token_123',
    createdAt: DateTime.now(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    syncService = SyncService(storage);
    apiClient = ApiClient();
    authService = AuthService(apiClient: apiClient, storage: storage);
    userRepo = UserRepository(authService: authService);
    authVm = AuthViewModel(userRepo: userRepo);

    await storage.saveUser(testUser.toJson());
    await authVm.initSession();

    tripRepo = TripRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    expenseRepo = ExpenseRepository(storage: storage, syncService: syncService, apiClient: apiClient);
    personalRepo = PersonalRepository(storage: storage, syncService: syncService, apiClient: apiClient);

    ledgerVm = PersonLedgerViewModel(
      personalRepo: personalRepo,
      expenseRepo: expenseRepo,
      tripRepo: tripRepo,
      storage: storage,
    );
  });

  group('WhatsAppShareHelper Tests', () {
    test('normalizes Indian 10-digit phone number to E.164 without plus or spaces', () {
      expect(WhatsAppShareHelper.normalizePhoneNumber('9876543210'), '919876543210');
      expect(WhatsAppShareHelper.normalizePhoneNumber('+91 98765 43210'), '919876543210');
      expect(WhatsAppShareHelper.normalizePhoneNumber('09876543210'), '919876543210');
      expect(WhatsAppShareHelper.normalizePhoneNumber('+1 (555) 123-4567'), '15551234567');
      expect(WhatsAppShareHelper.normalizePhoneNumber(null), '');
      expect(WhatsAppShareHelper.normalizePhoneNumber(''), '');
    });
  });

  group('Unified 1-on-1 Single Chat / Ledger Architecture Tests', () {
    test('unifies 1-on-1 personal debts, trip splits, settlements, and payment verifications into a single timeline', () async {
      const currentUserId = 'user_me_001';
      const targetPersonName = 'Rahul Sharma';
      const targetUserId = 'user_rahul_002';

      // 1. Current user lent to Rahul
      await personalRepo.createPersonalDebt(
        userId: currentUserId,
        personName: targetPersonName,
        debtType: PersonalDebtType.lent,
        amountInPaise: 50000, // ₹500
        description: 'Dinner contribution',
        date: DateTime.now().subtract(const Duration(days: 3)),
      );

      // 2. Rahul lent to current user (Bidirectional 2-party sync)
      await personalRepo.createPersonalDebt(
        userId: targetUserId,
        personName: 'Current User',
        debtType: PersonalDebtType.lent, // Rahul lent -> for Current User it is borrowed!
        amountInPaise: 20000, // ₹200
        description: 'Movie ticket',
        date: DateTime.now().subtract(const Duration(days: 2)),
      );

      // 3. Trip where both users are members
      final trip = Trip(
        id: 'trip_kith_01',
        name: 'Manali Trip',
        emoji: '🏔️',
        creatorId: currentUserId,
        inviteCode: 'MANALI',
        members: [
          TripMember(id: 'm_me', userId: currentUserId, displayName: 'Current User', joinedAt: DateTime.now()),
          TripMember(id: 'm_rahul', userId: targetUserId, displayName: targetPersonName, joinedAt: DateTime.now()),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await storage.saveTrips([trip.toJson()]);

      // Trip Expense: Current user paid ₹600, split ₹300 for Rahul
      final expense = Expense(
        id: 'exp_001',
        tripId: trip.id,
        title: 'Cab ride',
        amountInPaise: 60000,
        category: ExpenseCategory.transport,
        paidById: 'm_me',
        splits: [
          ExpenseSplit(memberId: 'm_me', amountInPaise: 30000),
          ExpenseSplit(memberId: 'm_rahul', amountInPaise: 30000),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await expenseRepo.addExpense(expense);

      // 4. Payment verification record (UPI payment verification item)
      await storage.addPaymentVerification({
        'id': 'pv_001',
        'payerUserId': targetUserId,
        'payerName': targetPersonName,
        'receiverUserId': currentUserId,
        'receiverName': 'Current User',
        'amountInPaise': 15000,
        'status': 'verified',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Load Unified Ledger
      await ledgerVm.loadLedger(
        personName: targetPersonName,
        personUserId: targetUserId,
        personPhone: '9876543210',
        currentUserId: currentUserId,
      );

      expect(ledgerVm.items.isNotEmpty, true);
      // Items must be sorted chronologically
      for (int i = 0; i < ledgerVm.items.length - 1; i++) {
        expect(ledgerVm.items[i].date.isBefore(ledgerVm.items[i + 1].date) || ledgerVm.items[i].date.isAtSameMomentAs(ledgerVm.items[i + 1].date), true);
      }

      // Verify that Net Balance considers all 1-on-1 merged entries
      // Lent ₹500 + Trip Split ₹300 = ₹800 Owed to you
      // Borrowed ₹200 from Rahul = ₹200 Owed by you
      // Net = ₹800 - ₹200 = ₹600 (₹60000 paise)
      expect(ledgerVm.netBalancePaise, 60000);
      expect(ledgerVm.runningBalanceStatusText.contains('Rahul Sharma owes you'), true);
    });
  });

  group('PersonSettleUpSheet Widget Tests', () {
    testWidgets('renders Settle Up Sheet with amount, cash direct settle, and UPI reminder options', (tester) async {
      bool settled = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
            ChangeNotifierProvider<PersonLedgerViewModel>.value(value: ledgerVm),
            Provider<LocalStorageService>.value(value: storage),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      PersonSettleUpSheet.show(
                        context,
                        personName: 'Rohit Verma',
                        personPhone: '919876543210',
                        netBalancePaise: 45000, // ₹450 Rohit owes user
                        onSettled: () => settled = true,
                      );
                    },
                    child: const Text('Open Settle Up'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settle Up'));
      await tester.pumpAndSettle();

      // Verify sheet UI components
      expect(find.text('Settle Up with Rohit Verma'), findsOneWidget);
      expect(find.text('Mark as Received'), findsOneWidget);
      expect(find.text('Remind on WhatsApp'), findsOneWidget);
      expect(find.text('Copy UPI Payment Request Text'), findsOneWidget);

      // Tap Mark as Received
      await tester.tap(find.text('Mark as Received'));
      await tester.pumpAndSettle();

      expect(settled, true);
    });
  });
}
