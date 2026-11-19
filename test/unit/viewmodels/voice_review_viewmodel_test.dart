import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/domain/enums/expense_category.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/viewmodels/voice_review_viewmodel.dart';

void main() {
  final members = [
    TripMember(
      id: 'mbr_1',
      userId: 'usr_1',
      displayName: 'Alice',
      role: 'creator',
      joinedAt: DateTime.now(),
    ),
    TripMember(
      id: 'mbr_2',
      userId: 'usr_2',
      displayName: 'Bob',
      role: 'member',
      joinedAt: DateTime.now(),
    ),
  ];

  group('VoiceReviewViewModel Tests', () {
    test('Initializes with compound transcript and calculates total in paise', () {
      final vm = VoiceReviewViewModel(
        initialTranscript: 'Maine 4k train ke diye, 5k club ke diye aur 800 food ke diye.',
        members: members,
        currentUserId: 'usr_1',
      );

      expect(vm.count, 3);
      expect(vm.totalInPaise, 980000); // ₹9,800
      expect(vm.isValid, isTrue);
    });

    test('Updates title, amount, and category cleanly', () {
      final vm = VoiceReviewViewModel(
        initialTranscript: '500 coffee',
        members: members,
        currentUserId: 'usr_1',
      );

      expect(vm.count, 1);
      final id = vm.items.first.id;

      vm.updateTitle(id, 'Specialty Coffee');
      vm.updateAmount(id, 65000); // 650 INR
      vm.updateCategory(id, ExpenseCategory.food);

      expect(vm.items.first.title, 'Specialty Coffee');
      expect(vm.items.first.amountInPaise, 65000);
      expect(vm.items.first.category, ExpenseCategory.food);
      expect(vm.totalInPaise, 65000);
    });

    test('Adds and removes items dynamically', () {
      final vm = VoiceReviewViewModel(
        initialTranscript: '500 coffee',
        members: members,
        currentUserId: 'usr_1',
      );

      expect(vm.count, 1);

      vm.addItem(title: 'Snacks', amountInPaise: 20000, category: ExpenseCategory.food);
      expect(vm.count, 2);
      expect(vm.totalInPaise, 70000); // 500 + 200 = 700 INR

      final firstId = vm.items.first.id;
      vm.removeItem(firstId);
      expect(vm.count, 1);
      expect(vm.items.first.title, 'Snacks');
      expect(vm.totalInPaise, 20000);
    });

    test('Reparses transcript correctly', () {
      final vm = VoiceReviewViewModel(
        initialTranscript: '500 coffee',
        members: members,
        currentUserId: 'usr_1',
      );

      expect(vm.count, 1);

      vm.reparse('Train 4000, hotel 5000, food 800');
      expect(vm.count, 3);
      expect(vm.totalInPaise, 980000);
    });

    test('Exports to valid ExpenseDrafts', () {
      final vm = VoiceReviewViewModel(
        initialTranscript: 'Train 4000, hotel 5000',
        members: members,
        currentUserId: 'usr_1',
      );

      final drafts = vm.toExpenseDrafts();
      expect(drafts.length, 2);
      expect(drafts[0].amountInPaise, 400000);
      expect(drafts[1].amountInPaise, 500000);
    });
  });
}
