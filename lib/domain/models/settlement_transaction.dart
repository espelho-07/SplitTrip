import '../../core/payment/payment_models.dart';

/// A simplified direct settlement between two members.
class SettlementTransaction {
  final String? id;
  final String fromMemberId;
  final String toMemberId;
  final int amountInPaise;
  final bool isSettled;
  final PaymentStatus status;
  final DateTime? settledAt;
  final String? paymentReference;
  final String? recipientUpiId;
  final String? payerName;
  final String? recipientName;
  final String? note;

  const SettlementTransaction({
    this.id,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountInPaise,
    this.isSettled = false,
    this.status = PaymentStatus.pending,
    this.settledAt,
    this.paymentReference,
    this.recipientUpiId,
    this.payerName,
    this.recipientName,
    this.note,
  });

  SettlementTransaction copyWith({
    String? id,
    String? fromMemberId,
    String? toMemberId,
    int? amountInPaise,
    bool? isSettled,
    PaymentStatus? status,
    DateTime? settledAt,
    String? paymentReference,
    String? recipientUpiId,
    String? payerName,
    String? recipientName,
    String? note,
  }) {
    return SettlementTransaction(
      id: id ?? this.id,
      fromMemberId: fromMemberId ?? this.fromMemberId,
      toMemberId: toMemberId ?? this.toMemberId,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      isSettled: isSettled ?? this.isSettled,
      status: status ?? this.status,
      settledAt: settledAt ?? this.settledAt,
      paymentReference: paymentReference ?? this.paymentReference,
      recipientUpiId: recipientUpiId ?? this.recipientUpiId,
      payerName: payerName ?? this.payerName,
      recipientName: recipientName ?? this.recipientName,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'fromMemberId': fromMemberId,
    'toMemberId': toMemberId,
    'amountInPaise': amountInPaise,
    'isSettled': isSettled,
    'status': status.key,
    'settledAt': settledAt?.toIso8601String(),
    'paymentReference': paymentReference,
    'recipientUpiId': recipientUpiId,
    'payerName': payerName,
    'recipientName': recipientName,
    'note': note,
  };

  factory SettlementTransaction.fromJson(Map<String, dynamic> json) {
    final rawSettled = json['isSettled'] as bool? ?? false;
    final rawStatusKey = json['status'] as String?;
    final resolvedStatus = rawStatusKey != null
        ? PaymentStatus.fromKey(rawStatusKey)
        : (rawSettled ? PaymentStatus.paid : PaymentStatus.pending);

    return SettlementTransaction(
      id: json['id'] as String?,
      fromMemberId: json['fromMemberId'] as String,
      toMemberId: json['toMemberId'] as String,
      amountInPaise: json['amountInPaise'] as int,
      isSettled: rawSettled || resolvedStatus == PaymentStatus.paid,
      status: resolvedStatus,
      settledAt: json['settledAt'] != null
          ? DateTime.parse(json['settledAt'] as String)
          : null,
      paymentReference: json['paymentReference'] as String?,
      recipientUpiId: json['recipientUpiId'] as String?,
      payerName: json['payerName'] as String?,
      recipientName: json['recipientName'] as String?,
      note: json['note'] as String?,
    );
  }
}
