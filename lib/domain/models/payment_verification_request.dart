/// Represents a 2-sided payment verification handshake request between Payer and Receiver.
class PaymentVerificationRequest {
  final String id;
  final String settlementId;
  final String tripId;
  final String tripName;
  final String payerMemberId;
  final String? payerUserId;
  final String payerName;
  final String receiverMemberId;
  final String? receiverUserId;
  final String receiverName;
  final int amountInPaise;
  final String paymentMethod;
  final String? paymentReference;
  final String? recipientUpiId;
  final String? note;
  final String status; // 'pending_verification', 'confirmed', 'disputed', 'proof_submitted', 'cancelled'
  final DateTime markedAt;
  final DateTime? respondedAt;
  final String? disputeReason;
  final String? transactionRef;
  final String? proofImageUrl;
  final String? proofNote;

  const PaymentVerificationRequest({
    required this.id,
    required this.settlementId,
    required this.tripId,
    required this.tripName,
    required this.payerMemberId,
    this.payerUserId,
    required this.payerName,
    required this.receiverMemberId,
    this.receiverUserId,
    required this.receiverName,
    required this.amountInPaise,
    this.paymentMethod = 'UPI',
    this.paymentReference,
    this.recipientUpiId,
    this.note,
    this.status = 'pending_verification',
    required this.markedAt,
    this.respondedAt,
    this.disputeReason,
    this.transactionRef,
    this.proofImageUrl,
    this.proofNote,
  });

  bool get isPending => status == 'pending_verification' || status == 'marked_paid';
  bool get isConfirmed => status == 'confirmed' || status == 'paid' || status == 'settled';
  bool get isDisputed => status == 'disputed' || status == 'not_received';
  bool get isProofSubmitted => status == 'proof_submitted';
  bool get isCancelled => status == 'cancelled';

  double get amountInRupees => amountInPaise / 100.0;

  PaymentVerificationRequest copyWith({
    String? id,
    String? settlementId,
    String? tripId,
    String? tripName,
    String? payerMemberId,
    String? payerUserId,
    String? payerName,
    String? receiverMemberId,
    String? receiverUserId,
    String? receiverName,
    int? amountInPaise,
    String? paymentMethod,
    String? paymentReference,
    String? recipientUpiId,
    String? note,
    String? status,
    DateTime? markedAt,
    DateTime? respondedAt,
    String? disputeReason,
    String? transactionRef,
    String? proofImageUrl,
    String? proofNote,
  }) {
    return PaymentVerificationRequest(
      id: id ?? this.id,
      settlementId: settlementId ?? this.settlementId,
      tripId: tripId ?? this.tripId,
      tripName: tripName ?? this.tripName,
      payerMemberId: payerMemberId ?? this.payerMemberId,
      payerUserId: payerUserId ?? this.payerUserId,
      payerName: payerName ?? this.payerName,
      receiverMemberId: receiverMemberId ?? this.receiverMemberId,
      receiverUserId: receiverUserId ?? this.receiverUserId,
      receiverName: receiverName ?? this.receiverName,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      recipientUpiId: recipientUpiId ?? this.recipientUpiId,
      note: note ?? this.note,
      status: status ?? this.status,
      markedAt: markedAt ?? this.markedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      disputeReason: disputeReason ?? this.disputeReason,
      transactionRef: transactionRef ?? this.transactionRef,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      proofNote: proofNote ?? this.proofNote,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'settlementId': settlementId,
    'tripId': tripId,
    'tripName': tripName,
    'payerMemberId': payerMemberId,
    'payerUserId': payerUserId,
    'payerName': payerName,
    'receiverMemberId': receiverMemberId,
    'receiverUserId': receiverUserId,
    'receiverName': receiverName,
    'amountInPaise': amountInPaise,
    'paymentMethod': paymentMethod,
    'paymentReference': paymentReference,
    'recipientUpiId': recipientUpiId,
    'note': note,
    'status': status,
    'markedAt': markedAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
    'disputeReason': disputeReason,
    'transactionRef': transactionRef,
    'proofImageUrl': proofImageUrl,
    'proofNote': proofNote,
  };

  factory PaymentVerificationRequest.fromJson(Map<String, dynamic> json) {
    return PaymentVerificationRequest(
      id: json['id'] as String? ?? 'pvr_',
      settlementId: json['settlementId'] as String? ?? '',
      tripId: json['tripId'] as String? ?? '',
      tripName: json['tripName'] as String? ?? 'Trip',
      payerMemberId: json['payerMemberId'] as String? ?? '',
      payerUserId: json['payerUserId'] as String?,
      payerName: json['payerName'] as String? ?? 'Member',
      receiverMemberId: json['receiverMemberId'] as String? ?? '',
      receiverUserId: json['receiverUserId'] as String?,
      receiverName: json['receiverName'] as String? ?? 'Member',
      amountInPaise: (json['amountInPaise'] as num?)?.toInt() ?? 0,
      paymentMethod: json['paymentMethod'] as String? ?? 'UPI',
      paymentReference: json['paymentReference'] as String?,
      recipientUpiId: json['recipientUpiId'] as String?,
      note: json['note'] as String?,
      status: json['status'] as String? ?? 'pending_verification',
      markedAt: json['markedAt'] != null
          ? DateTime.tryParse(json['markedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      respondedAt: json['respondedAt'] != null
          ? DateTime.tryParse(json['respondedAt'] as String)
          : null,
      disputeReason: json['disputeReason'] as String?,
      transactionRef: json['transactionRef'] as String?,
      proofImageUrl: json['proofImageUrl'] as String?,
      proofNote: json['proofNote'] as String?,
    );
  }
}
