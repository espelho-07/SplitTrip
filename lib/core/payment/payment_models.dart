/// State lifecycle for settlement payments.
enum PaymentStatus {
  /// Settlement created or pending payment.
  pending,

  /// UPI application or external gateway was launched.
  initiated,

  /// Waiting for user or webhook confirmation.
  awaitingConfirmation,

  /// Genuinely confirmed and recorded as paid.
  paid,

  /// Payment attempt failed or rejected.
  failed,

  /// Payment cancelled by user.
  cancelled;

  String get key => name;

  static PaymentStatus fromKey(String? key) {
    if (key == null) return PaymentStatus.pending;
    return PaymentStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == key.toLowerCase(),
      orElse: () => PaymentStatus.pending,
    );
  }
}

/// Immutable payment request specification.
class PaymentRequest {
  final String recipientUpiId;
  final String recipientName;
  final int amountInPaise;
  final String currencyCode;
  final String transactionNote;
  final String transactionRef;
  final String? tripId;
  final String? settlementId;
  final DateTime createdAt;

  PaymentRequest({
    required this.recipientUpiId,
    required this.recipientName,
    required this.amountInPaise,
    this.currencyCode = 'INR',
    required this.transactionNote,
    required this.transactionRef,
    this.tripId,
    this.settlementId,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        assert(amountInPaise > 0, 'Payment amount must be greater than 0 paise');

  double get amountInRupees => amountInPaise / 100.0;

  String get formattedRupees => (amountInPaise / 100.0).toStringAsFixed(2);

  Map<String, dynamic> toJson() => {
    'recipientUpiId': recipientUpiId,
    'recipientName': recipientName,
    'amountInPaise': amountInPaise,
    'currencyCode': currencyCode,
    'transactionNote': transactionNote,
    'transactionRef': transactionRef,
    'tripId': tripId,
    'settlementId': settlementId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PaymentRequest.fromJson(Map<String, dynamic> json) => PaymentRequest(
    recipientUpiId: json['recipientUpiId'] as String? ?? '',
    recipientName: json['recipientName'] as String? ?? '',
    amountInPaise: json['amountInPaise'] as int? ?? 0,
    currencyCode: json['currencyCode'] as String? ?? 'INR',
    transactionNote: json['transactionNote'] as String? ?? '',
    transactionRef: json['transactionRef'] as String? ?? '',
    tripId: json['tripId'] as String?,
    settlementId: json['settlementId'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );
}

/// Result returned after a payment action or provider execution.
class PaymentResult {
  final PaymentStatus status;
  final bool isVerified;
  final String? transactionReference;
  final String message;
  final DateTime timestamp;
  final String? rawResponse;

  const PaymentResult({
    required this.status,
    required this.isVerified,
    this.transactionReference,
    required this.message,
    required this.timestamp,
    this.rawResponse,
  });

  factory PaymentResult.initiated({
    required String transactionReference,
    String message = 'Payment initiated in UPI app',
  }) {
    return PaymentResult(
      status: PaymentStatus.initiated,
      isVerified: false,
      transactionReference: transactionReference,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  factory PaymentResult.success({
    required String transactionReference,
    bool isVerified = true,
    String message = 'Payment completed successfully',
  }) {
    return PaymentResult(
      status: PaymentStatus.paid,
      isVerified: isVerified,
      transactionReference: transactionReference,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  factory PaymentResult.failed({
    String? transactionReference,
    required String message,
  }) {
    return PaymentResult(
      status: PaymentStatus.failed,
      isVerified: false,
      transactionReference: transactionReference,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  factory PaymentResult.cancelled({
    String? transactionReference,
    String message = 'Payment cancelled by user',
  }) {
    return PaymentResult(
      status: PaymentStatus.cancelled,
      isVerified: false,
      transactionReference: transactionReference,
      message: message,
      timestamp: DateTime.now(),
    );
  }
}

/// Discovered installed UPI application descriptor.
class UpiAppInfo {
  final String appName;
  final String? packageName;
  final String scheme;

  const UpiAppInfo({
    required this.appName,
    this.packageName,
    this.scheme = 'upi',
  });
}
