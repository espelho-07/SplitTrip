import 'settlement_transaction.dart';

/// Represents a single debt transfer between two members.
class DebtTransfer {
  final String fromMemberId;
  final String toMemberId;
  final int amountInPaise;

  const DebtTransfer({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountInPaise,
  });

  Map<String, dynamic> toJson() => {
    'fromMemberId': fromMemberId,
    'toMemberId': toMemberId,
    'amountInPaise': amountInPaise,
  };

  factory DebtTransfer.fromJson(Map<String, dynamic> json) => DebtTransfer(
    fromMemberId: json['fromMemberId'] as String,
    toMemberId: json['toMemberId'] as String,
    amountInPaise: json['amountInPaise'] as int,
  );
}

/// Comprehensive balance snapshot for a Trip.
class BalanceSummary {
  final int totalTripSpentInPaise;
  final Map<String, int> memberNetBalances;
  final int currentUserNetBalanceInPaise;
  final List<DebtTransfer> debtsToPay;
  final List<DebtTransfer> debtsToReceive;
  final List<SettlementTransaction> simplifiedSettlements;

  const BalanceSummary({
    required this.totalTripSpentInPaise,
    required this.memberNetBalances,
    required this.currentUserNetBalanceInPaise,
    required this.debtsToPay,
    required this.debtsToReceive,
    required this.simplifiedSettlements,
  });

  bool get isCurrentUserOwed => currentUserNetBalanceInPaise > 0;
  bool get isCurrentUserInDebt => currentUserNetBalanceInPaise < 0;
  bool get isCurrentUserSettled => currentUserNetBalanceInPaise == 0;

  static BalanceSummary empty() {
    return const BalanceSummary(
      totalTripSpentInPaise: 0,
      memberNetBalances: {},
      currentUserNetBalanceInPaise: 0,
      debtsToPay: [],
      debtsToReceive: [],
      simplifiedSettlements: [],
    );
  }
}
