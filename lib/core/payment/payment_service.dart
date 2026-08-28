import 'package:flutter/foundation.dart';
import 'payment_models.dart';
import 'payment_provider.dart';
import 'upi_payment_provider.dart';
import 'upi_validator.dart';

/// Payment orchestrator for Kith.
///
/// Dispatches payment requests to the active payment provider,
/// generates deterministic idempotent references, and validates inputs.
class PaymentService extends ChangeNotifier {
  final Map<String, PaymentProvider> _providers = {};
  String _activeProviderId = 'upi_intent';
  bool _isProcessing = false;
  PaymentResult? _lastResult;

  PaymentService({PaymentProvider? defaultProvider}) {
    final upi = defaultProvider ?? UpiPaymentProvider();
    _activeProviderId = upi.providerId;
    registerProvider(upi);
  }

  bool get isProcessing => _isProcessing;
  PaymentResult? get lastResult => _lastResult;
  PaymentProvider? get activeProvider => _providers[_activeProviderId];

  void registerProvider(PaymentProvider provider) {
    _providers[provider.providerId] = provider;
  }

  void setActiveProvider(String providerId) {
    if (_providers.containsKey(providerId)) {
      _activeProviderId = providerId;
      notifyListeners();
    }
  }

  /// Generates a deterministic, unique, idempotent transaction reference.
  static String generateTransactionReference({
    required String tripId,
    required String fromMemberId,
    required String toMemberId,
    int? timestampMs,
  }) {
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final cleanTripId = tripId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final cleanFrom = fromMemberId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final cleanTo = toMemberId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return 'kith_${cleanTripId}_${cleanFrom}_${cleanTo}_$ts';
  }

  /// Creates a validated PaymentRequest for a settlement transfer.
  static PaymentRequest createSettlementPaymentRequest({
    required String recipientUpiId,
    required String recipientName,
    required int amountInPaise,
    required String tripName,
    required String tripId,
    required String fromMemberId,
    required String toMemberId,
    String? settlementId,
  }) {
    final ref = generateTransactionReference(
      tripId: tripId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
    );

    return PaymentRequest(
      recipientUpiId: UpiValidator.normalizeUpiId(recipientUpiId),
      recipientName: recipientName.trim(),
      amountInPaise: amountInPaise,
      currencyCode: 'INR',
      transactionNote: 'Kith: $tripName settlement',
      transactionRef: ref,
      tripId: tripId,
      settlementId: settlementId,
    );
  }

  /// Initiates payment through the currently configured provider.
  Future<PaymentResult> pay(PaymentRequest request) async {
    final provider = activeProvider;
    if (provider == null) {
      final result = PaymentResult.failed(
        transactionReference: request.transactionRef,
        message: 'No active payment provider configured.',
      );
      _lastResult = result;
      notifyListeners();
      return result;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final result = await provider.initiatePayment(request);
      _lastResult = result;
      return result;
    } catch (e) {
      final result = PaymentResult.failed(
        transactionReference: request.transactionRef,
        message: 'Payment execution error: $e',
      );
      _lastResult = result;
      return result;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Checks if any compatible UPI application is available.
  Future<bool> isUpiAvailable() async {
    final provider = _providers['upi_intent'];
    if (provider == null) return false;
    return await provider.isAvailable();
  }
}
