import '../models/expense_split.dart';

/// Pure deterministic financial calculation engine.
/// Operates strictly in integer smallest currency units (paise/cents).
/// Zero floating-point arithmetic errors and zero-sum remainder allocation.
class MoneyEngine {
  MoneyEngine._();

  /// Calculates equal splits across participants.
  /// If total amount is not cleanly divisible (e.g. ₹100.00 / 3 = 3333 paise each + 1 paise remainder),
  /// remainder paise is distributed deterministically 1-by-1 to avoid penny leaks.
  static List<ExpenseSplit> calculateEqualSplits({
    required int totalPaise,
    required List<String> participantMemberIds,
    String? priorityMemberId,
  }) {
    if (participantMemberIds.isEmpty || totalPaise <= 0) {
      return [];
    }

    final count = participantMemberIds.length;
    final baseAmount = totalPaise ~/ count;
    int remainder = totalPaise % count;

    // Order participants such that priority member (e.g. payer) receives the extra remainder paise first
    final orderedIds = List<String>.from(participantMemberIds);
    if (priorityMemberId != null && orderedIds.contains(priorityMemberId)) {
      orderedIds.remove(priorityMemberId);
      orderedIds.insert(0, priorityMemberId);
    }

    final splits = <ExpenseSplit>[];
    for (int i = 0; i < orderedIds.length; i++) {
      final allocatedAmount = baseAmount + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;

      splits.add(ExpenseSplit(
        memberId: orderedIds[i],
        amountInPaise: allocatedAmount,
        percentage: (100.0 / count),
        shares: 1,
      ));
    }

    return splits;
  }

  /// Calculates exact percentage splits.
  /// Reconciles rounding remainders to ensure exact sum matches totalPaise.
  static List<ExpenseSplit> calculatePercentageSplits({
    required int totalPaise,
    required Map<String, double> percentages,
  }) {
    if (percentages.isEmpty || totalPaise <= 0) {
      return [];
    }

    int accumulatedPaise = 0;
    final splits = <ExpenseSplit>[];
    final entries = percentages.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final memberId = entry.key;
      final percent = entry.value;

      int allocated;
      if (i == entries.length - 1) {
        // Last member gets the exact difference to guarantee sum equality
        allocated = totalPaise - accumulatedPaise;
      } else {
        allocated = ((totalPaise * percent) / 100.0).round();
        accumulatedPaise += allocated;
      }

      splits.add(ExpenseSplit(
        memberId: memberId,
        amountInPaise: allocated,
        percentage: percent,
      ));
    }

    return splits;
  }

  /// Calculates share-based splits (e.g. Member A = 2 shares, Member B = 1 share).
  static List<ExpenseSplit> calculateSharesSplits({
    required int totalPaise,
    required Map<String, int> shares,
  }) {
    if (shares.isEmpty || totalPaise <= 0) {
      return [];
    }

    final totalShares = shares.values.fold(0, (sum, val) => sum + val);
    if (totalShares <= 0) return [];

    int accumulatedPaise = 0;
    final splits = <ExpenseSplit>[];
    final entries = shares.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final memberId = entry.key;
      final shareCount = entry.value;

      int allocated;
      if (i == entries.length - 1) {
        // Last member reconciles rounding discrepancy
        allocated = totalPaise - accumulatedPaise;
      } else {
        allocated = ((totalPaise * shareCount) / totalShares).round();
        accumulatedPaise += allocated;
      }

      splits.add(ExpenseSplit(
        memberId: memberId,
        amountInPaise: allocated,
        shares: shareCount,
        percentage: (shareCount / totalShares) * 100.0,
      ));
    }

    return splits;
  }

  /// Verifies if a list of splits sum up strictly to the expected total.
  static bool validateSplits(int totalPaise, List<ExpenseSplit> splits) {
    if (splits.isEmpty) return false;
    final sum = splits.fold(0, (prev, s) => prev + s.amountInPaise);
    return sum == totalPaise;
  }
}
