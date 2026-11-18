import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/domain/models/expense.dart';
import 'package:kith_app/domain/models/expense_split.dart';
import 'package:kith_app/presentation/viewmodels/add_expense_viewmodel.dart';
import 'package:kith_app/data/repositories/expense_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;
  late ExpenseRepository expenseRepo;
  late AddExpenseViewModel addExpenseVm;

  final now = DateTime.now();
  final testTrip = Trip(
    id: 'test_trip_123',
    name: 'Goa Trip',
    emoji: '🏖️',
    currencyCode: 'INR',
    inviteCode: 'GOA123',
    creatorId: 'user_darpan',
    members: [
      TripMember(
        id: 'member_darpan',
        userId: 'user_darpan',
        displayName: 'Darpan',
        isClaimed: true,
        joinedAt: now,
      ),
      TripMember(
        id: 'member_rahul',
        userId: 'user_rahul',
        displayName: 'Rahul',
        isClaimed: true,
        joinedAt: now,
      ),
    ],
    lifecycleState: TripLifecycle.active,
    createdAt: now,
    updatedAt: now,
  );

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
    addExpenseVm = AddExpenseViewModel(expenseRepo: expenseRepo);
    addExpenseVm.init(trip: testTrip, currentUserId: 'user_darpan');
  });

  test('AddExpenseViewModel: description is optional, isValid is true without title', () {
    addExpenseVm.setAmountInPaise(50000); // ₹500
    addExpenseVm.toggleParticipant('member_rahul');
    addExpenseVm.setTitle(''); // Empty description

    expect(addExpenseVm.isValid, isTrue,
        reason: 'Expense with valid amount and participant must be valid even if title is empty');
  });

  test('AddExpenseViewModel: saveExpense auto-defaults empty title to Category displayName or Expense', () async {
    addExpenseVm.setAmountInPaise(25000); // ₹250
    addExpenseVm.toggleParticipant('member_rahul');
    addExpenseVm.setCategory(ExpenseCategory.food);
    addExpenseVm.setTitle(''); // Empty description

    final saved = await addExpenseVm.saveExpense('test_trip_123');
    expect(saved, isNotNull);
    expect(saved!.title, equals(ExpenseCategory.food.displayName));
    expect(saved.amountInPaise, equals(25000));
  });

  test('Detailed Hisab: pairwise expense breakdown accurately tracks shared amounts', () {
    final expenses = [
      Expense(
        id: 'exp_1',
        tripId: testTrip.id,
        title: 'Dinner at Beach',
        amountInPaise: 50000, // ₹500
        category: ExpenseCategory.food,
        paidById: 'member_darpan',
        splits: const [
          ExpenseSplit(memberId: 'member_darpan', amountInPaise: 25000),
          ExpenseSplit(memberId: 'member_rahul', amountInPaise: 25000), // Rahul owes ₹250
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Expense(
        id: 'exp_2',
        tripId: testTrip.id,
        title: 'Cab ride',
        amountInPaise: 10000, // ₹100
        category: ExpenseCategory.transport,
        paidById: 'member_rahul',
        splits: const [
          ExpenseSplit(memberId: 'member_darpan', amountInPaise: 5000), // Darpan owes ₹50
          ExpenseSplit(memberId: 'member_rahul', amountInPaise: 5000),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    // Compute direct hisab between Darpan (member_darpan) and Rahul (member_rahul)
    int darpanPaidForRahul = 0;
    int rahulPaidForDarpan = 0;

    for (final exp in expenses) {
      final darpanSplit = exp.splits.where((s) => s.memberId == 'member_darpan').firstOrNull;
      final rahulSplit = exp.splits.where((s) => s.memberId == 'member_rahul').firstOrNull;

      if (exp.paidById == 'member_darpan' && rahulSplit != null) {
        darpanPaidForRahul += rahulSplit.amountInPaise.toInt();
      }
      if (exp.paidById == 'member_rahul' && darpanSplit != null) {
        rahulPaidForDarpan += darpanSplit.amountInPaise.toInt();
      }
    }

    expect(darpanPaidForRahul, equals(25000)); // ₹250
    expect(rahulPaidForDarpan, equals(5000));  // ₹50
    final netRahulOwesDarpan = darpanPaidForRahul - rahulPaidForDarpan;
    expect(netRahulOwesDarpan, equals(20000)); // ₹200 net
  });

  test('View Everyone: correctly groups transfers per member with net totals and sorting', () {
    final s1 = {
      'fromMemberId': 'member_rahul',
      'toMemberId': 'member_darpan',
      'amountInPaise': 20000,
    };
    final memberDarpan = testTrip.members[0];
    final memberRahul = testTrip.members[1];

    // Outgoing & incoming verification
    final rahulOutgoing = [s1].where((s) => s['fromMemberId'] == memberRahul.id).toList();
    final rahulIncoming = [s1].where((s) => s['toMemberId'] == memberRahul.id).toList();
    final darpanOutgoing = [s1].where((s) => s['fromMemberId'] == memberDarpan.id).toList();
    final darpanIncoming = [s1].where((s) => s['toMemberId'] == memberDarpan.id).toList();

    expect(rahulOutgoing.length, equals(1));
    expect(rahulIncoming.length, equals(0));
    expect(darpanOutgoing.length, equals(0));
    expect(darpanIncoming.length, equals(1));

    final rahulNet = rahulIncoming.fold<int>(0, (sum, s) => sum + (s['amountInPaise'] as int)) -
        rahulOutgoing.fold<int>(0, (sum, s) => sum + (s['amountInPaise'] as int));
    final darpanNet = darpanIncoming.fold<int>(0, (sum, s) => sum + (s['amountInPaise'] as int)) -
        darpanOutgoing.fold<int>(0, (sum, s) => sum + (s['amountInPaise'] as int));

    expect(rahulNet, equals(-20000)); // Owes ₹200
    expect(darpanNet, equals(20000));  // Gets ₹200
  });
}
