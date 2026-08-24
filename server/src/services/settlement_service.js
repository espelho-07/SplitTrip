const crypto = require('crypto');

class SettlementService {
  /**
   * Greedy min-cash-flow graph reduction algorithm.
   * Transforms O(N^2) pairwise debts into minimal O(N) direct transfers.
   * Preserves 100% integer paise conservation.
   */
  simplifyDebts(netBalances) {
    // Separate creditors and debtors
    const debtors = [];
    const creditors = [];

    for (const [memberId, balance] of Object.entries(netBalances)) {
      if (balance < 0) {
        debtors.push({ memberId, amount: -balance });
      } else if (balance > 0) {
        creditors.push({ memberId, amount: balance });
      }
    }

    // Sort descending for minimal transactions
    debtors.sort((a, b) => b.amount - a.amount);
    creditors.sort((a, b) => b.amount - a.amount);

    const transactions = [];
    let dIdx = 0;
    let cIdx = 0;

    while (dIdx < debtors.length && cIdx < creditors.length) {
      const debtor = debtors[dIdx];
      const creditor = creditors[cIdx];

      const settleAmount = Math.min(debtor.amount, creditor.amount);

      if (settleAmount > 0) {
        transactions.push({
          id: `stl_${crypto.randomUUID().replace(/-/g, '').substring(0, 10)}`,
          fromMemberId: debtor.memberId,
          toMemberId: creditor.memberId,
          amountInPaise: settleAmount,
          currency: 'INR',
          isRecorded: false,
          recordedAt: null,
        });

        debtor.amount -= settleAmount;
        creditor.amount -= settleAmount;
      }

      if (debtor.amount === 0) dIdx++;
      if (creditor.amount === 0) cIdx++;
    }

    return transactions;
  }
}

module.exports = new SettlementService();
