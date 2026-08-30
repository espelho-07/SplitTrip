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
  final DateTime? markedPaidAt;
  final DateTime? confirmedAt;
  final DateTime? disputedAt;
  final DateTime? proofSubmittedAt;
  final String? paymentReference;
  final String? recipientUpiId;
  final String? payerName;
  final String? recipientName;
  final String? note;
  final String? transactionRef;
  final String? proofImageUrl;
  final String? proofNote;
  final String? disputeReason;

  const SettlementTransaction({
    this.id,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountInPaise,
    this.isSettled = false,
    this.status = PaymentStatus.pending,
    this.settledAt,
    this.markedPaidAt,
    this.confirmedAt,
    this.disputedAt,
    this.proofSubmittedAt,
    this.paymentReference,
    this.recipientUpiId,
    this.payerName,
    this.recipientName,
    this.note,
    this.transactionRef,
    this.proofImageUrl,
    this.proofNote,
    this.disputeReason,
  });

  bool get isAwaitingConfirmation => status.isAwaitingConfirmation;
  bool get isDisputed => status.isDisputed;
  bool get isProofSubmitted => status.isProofSubmitted;

  SettlementTransaction copyWith({
    String? id,
    String? fromMemberId,
    String? toMemberId,
    int? amountInPaise,
    bool? isSettled,
    PaymentStatus? status,
    DateTime? settledAt,
    DateTime? markedPaidAt,
    DateTime? confirmedAt,
    DateTime? disputedAt,
    DateTime? proofSubmittedAt,
    String? paymentReference,
    String? recipientUpiId,
    String? payerName,
    String? recipientName,
    String? note,
    String? transactionRef,
    String? proofImageUrl,
    String? proofNote,
    String? disputeReason,
  }) {
    return SettlementTransaction(
      id: id ?? this.id,
      fromMemberId: fromMemberId ?? this.fromMemberId,
      toMemberId: toMemberId ?? this.toMemberId,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      isSettled: isSettled ?? this.isSettled,
      status: status ?? this.status,
      settledAt: settledAt ?? this.settledAt,
      markedPaidAt: markedPaidAt ?? this.markedPaidAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      disputedAt: disputedAt ?? this.disputedAt,
      proofSubmittedAt: proofSubmittedAt ?? this.proofSubmittedAt,
      paymentReference: paymentReference ?? this.paymentReference,
      recipientUpiId: recipientUpiId ?? this.recipientUpiId,
      payerName: payerName ?? this.payerName,
      recipientName: recipientName ?? this.recipientName,
      note: note ?? this.note,
      transactionRef: transactionRef ?? this.transactionRef,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      proofNote: proofNote ?? this.proofNote,
      disputeReason: disputeReason ?? this.disputeReason,
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
    'markedPaidAt': markedPaidAt?.toIso8601String(),
    'confirmedAt': confirmedAt?.toIso8601String(),
    'disputedAt': disputedAt?.toIso8601String(),
    'proofSubmittedAt': proofSubmittedAt?.toIso8601String(),
    'paymentReference': paymentReference,
    'recipientUpiId': recipientUpiId,
    'payerName': payerName,
    'recipientName': recipientName,
    'note': note,
    'transactionRef': transactionRef,
    'proofImageUrl': proofImageUrl,
    'proofNote': proofNote,
    'disputeReason': disputeReason,
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
      isSettled: rawSettled || resolvedStatus.isSettled,
      status: resolvedStatus,
      settledAt: json['settledAt'] != null
          ? DateTime.tryParse(json['settledAt'] as String)
          : null,
      markedPaidAt: json['markedPaidAt'] != null
          ? DateTime.tryParse(json['markedPaidAt'] as String)
          : null,
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.tryParse(json['confirmedAt'] as String)
          : null,
      disputedAt: json['disputedAt'] != null
          ? DateTime.tryParse(json['disputedAt'] as String)
          : null,
      proofSubmittedAt: json['proofSubmittedAt'] != null
          ? DateTime.tryParse(json['proofSubmittedAt'] as String)
          : null,
      paymentReference: json['paymentReference'] as String?,
      recipientUpiId: json['recipientUpiId'] as String?,
      payerName: json['payerName'] as String?,
      recipientName: json['recipientName'] as String?,
      note: json['note'] as String?,
      transactionRef: json['transactionRef'] as String?,
      proofImageUrl: json['proofImageUrl'] as String?,
      proofNote: json['proofNote'] as String?,
      disputeReason: json['disputeReason'] as String?,
    );
  }
}
