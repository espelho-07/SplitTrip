import '../models/balance_summary.dart';
import '../models/expense.dart';
import '../models/trip_member.dart';
import 'settlement_engine.dart';

/// Aggregates expenses and settlements to calculate real-time member net balances,
/// total trip spending, personal owed/owed-to breakdowns, and simplified settlements.
class BalanceEngine {
  BalanceEngine._();

  static BalanceSummary calculateBalances({
    required List<TripMember> members,
    required List<Expense> expenses,
    List<dynamic> settlements = const [],
    required String currentUserId,
  }) {
    if (members.isEmpty) {
      return BalanceSummary.empty();
    }

    final activeExpenses = expenses.where((e) => !e.isDeleted).toList();

    int totalSpent = 0;
    final paidMap = <String, int>{};
    final shareMap = <String, int>{};

    // Initialize all members with 0
    for (final member in members) {
      paidMap[member.id] = 0;
      shareMap[member.id] = 0;
    }

    // Process all active expenses
    for (final expense in activeExpenses) {
      totalSpent += expense.amountInPaise;

      // Credit the payer
      paidMap[expense.paidById] = (paidMap[expense.paidById] ?? 0) + expense.amountInPaise;

      // Debit each participant's allocated share
      for (final split in expense.splits) {
        shareMap[split.memberId] = (shareMap[split.memberId] ?? 0) + split.amountInPaise;
      }
    }

    // Process all settlements (direct debt clearance transfers between members)
    for (final s in settlements) {
      String? fromId;
      String? toId;
      int amt = 0;
      bool isPaid = false;

      if (s is Map<String, dynamic>) {
        fromId = s['fromMemberId'] as String?;
        toId = s['toMemberId'] as String?;
        amt = (s['amountInPaise'] as num?)?.toInt() ?? 0;
        final status = s['status'] as String?;
        final isSettled = s['isSettled'] as bool? ?? false;
        isPaid = isSettled || status == 'paid' || status == 'confirmed' || status == 'manual_settled' || status == 'completed';
      } else if (s != null) {
        try {
          fromId = (s as dynamic).fromMemberId as String?;
          toId = (s as dynamic).toMemberId as String?;
          amt = (s as dynamic).amountInPaise as int? ?? 0;
          final isSettled = (s as dynamic).isSettled as bool? ?? false;
          final status = (s as dynamic).status?.toString();
          isPaid = isSettled || status == 'paid' || status == 'confirmed' || status == 'PaymentStatus.paid' || status == 'PaymentStatus.confirmed' || status == 'manual_settled' || status == 'completed';
        } catch (_) {}
      }

      if (isPaid && fromId != null && toId != null && amt > 0) {
        // fromId transferred amt to toId.
        // Therefore fromId is credited +amt (they paid their debt),
        // and toId is debited +amt (they collected their receivable).
        paidMap[fromId] = (paidMap[fromId] ?? 0) + amt;
        shareMap[toId] = (shareMap[toId] ?? 0) + amt;
      }
    }

    // Compute net balance per member: Net = Paid - Share
    final netBalances = <String, int>{};
    for (final member in members) {
      final paid = paidMap[member.id] ?? 0;
      final share = shareMap[member.id] ?? 0;
      netBalances[member.id] = paid - share;
    }

    // Find the current member id that matches the current user's userId
    final currentMember = members.where((m) => m.userId == currentUserId).firstOrNull;
    final currentMemberId = currentMember?.id ?? currentUserId;
    final currentUserNet = netBalances[currentMemberId] ?? 0;

    // Run settlement simplification
    final simplifiedSettlements = SettlementEngine.simplifyDebts(netBalances);

    // Extract user-specific debts
    final debtsToPay = <DebtTransfer>[];
    final debtsToReceive = <DebtTransfer>[];

    for (final s in simplifiedSettlements) {
      if (s.fromMemberId == currentMemberId) {
        debtsToPay.add(DebtTransfer(
          fromMemberId: s.fromMemberId,
          toMemberId: s.toMemberId,
          amountInPaise: s.amountInPaise,
        ));
      } else if (s.toMemberId == currentMemberId) {
        debtsToReceive.add(DebtTransfer(
          fromMemberId: s.fromMemberId,
          toMemberId: s.toMemberId,
          amountInPaise: s.amountInPaise,
        ));
      }
    }

    return BalanceSummary(
      totalTripSpentInPaise: totalSpent,
      memberNetBalances: netBalances,
      currentUserNetBalanceInPaise: currentUserNet,
      debtsToPay: debtsToPay,
      debtsToReceive: debtsToReceive,
      simplifiedSettlements: simplifiedSettlements,
    );
  }
}
