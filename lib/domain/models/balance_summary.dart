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

  Map<String, dynamic> toJson() => {
    'totalTripSpendingInPaise': totalTripSpentInPaise,
    'netBalancesInPaise': memberNetBalances,
    'currentUserNetBalanceInPaise': currentUserNetBalanceInPaise,
    'debtsToPay': debtsToPay.map((d) => d.toJson()).toList(),
    'debtsToReceive': debtsToReceive.map((d) => d.toJson()).toList(),
    'simplifiedSettlements': simplifiedSettlements.map((s) => s.toJson()).toList(),
  };

  factory BalanceSummary.fromJson(Map<String, dynamic> json) {
    final rawNet = json['netBalancesInPaise'] as Map<String, dynamic>? ?? {};
    final netBalances = rawNet.map((k, v) => MapEntry(k, (v as num).toInt()));

    final rawSettlements = json['simplifiedSettlements'] as List? ?? [];
    final settlements = rawSettlements
        .map((s) => SettlementTransaction.fromJson(s as Map<String, dynamic>))
        .toList();

    final rawToPay = json['debtsToPay'] as List? ?? [];
    final debtsToPay = rawToPay
        .map((d) => DebtTransfer.fromJson(d as Map<String, dynamic>))
        .toList();

    final rawToReceive = json['debtsToReceive'] as List? ?? [];
    final debtsToReceive = rawToReceive
        .map((d) => DebtTransfer.fromJson(d as Map<String, dynamic>))
        .toList();

    return BalanceSummary(
      totalTripSpentInPaise: (json['totalTripSpendingInPaise'] as num?)?.toInt() ?? 0,
      memberNetBalances: netBalances,
      currentUserNetBalanceInPaise: (json['currentUserNetBalanceInPaise'] as num?)?.toInt() ?? 0,
      debtsToPay: debtsToPay,
      debtsToReceive: debtsToReceive,
      simplifiedSettlements: settlements,
    );
  }

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
