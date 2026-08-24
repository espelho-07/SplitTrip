import '../models/settlement_transaction.dart';

class _BalanceNode {
  final String memberId;
  int balance;

  _BalanceNode({required this.memberId, required this.balance});
}

/// Deterministic debt-simplification settlement engine.
/// Reduces complex O(N²) pairwise debt graphs into minimal O(N) direct payments
/// using an optimal greedy bipartite min-cash-flow algorithm.
class SettlementEngine {
  SettlementEngine._();

  /// Simplifies a map of net balances into minimal direct settlements.
  /// Positive balance = Creditor (should receive money).
  /// Negative balance = Debtor (needs to pay money).
  static List<SettlementTransaction> simplifyDebts(Map<String, int> netBalances) {
    final debtors = <_BalanceNode>[];
    final creditors = <_BalanceNode>[];

    netBalances.forEach((memberId, balance) {
      if (balance < 0) {
        debtors.add(_BalanceNode(memberId: memberId, balance: balance));
      } else if (balance > 0) {
        creditors.add(_BalanceNode(memberId: memberId, balance: balance));
      }
    });

    final settlements = <SettlementTransaction>[];

    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      // Sort debtors ascending (most negative first)
      debtors.sort((a, b) => a.balance.compareTo(b.balance));
      // Sort creditors descending (most positive first)
      creditors.sort((a, b) => b.balance.compareTo(a.balance));

      final maxDebtor = debtors.first;
      final maxCreditor = creditors.first;

      final debitAmount = -maxDebtor.balance;
      final creditAmount = maxCreditor.balance;

      final transferAmount = debitAmount < creditAmount ? debitAmount : creditAmount;

      if (transferAmount > 0) {
        settlements.add(SettlementTransaction(
          fromMemberId: maxDebtor.memberId,
          toMemberId: maxCreditor.memberId,
          amountInPaise: transferAmount,
        ));
      }

      maxDebtor.balance += transferAmount;
      maxCreditor.balance -= transferAmount;

      if (maxDebtor.balance == 0) {
        debtors.removeAt(0);
      }
      if (maxCreditor.balance == 0) {
        creditors.removeAt(0);
      }
    }

    return settlements;
  }
}
