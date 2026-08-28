import 'payment_models.dart';

/// Abstract payment provider interface.
/// Allows swapping payment providers (UPI intent, Razorpay, Cashfree, etc.)
/// without altering settlement or balance business logic.
abstract class PaymentProvider {
  /// Unique identifier of the provider (e.g. 'upi_intent', 'razorpay').
  String get providerId;

  /// User-facing name of the provider (e.g. 'UPI Direct', 'Razorpay Gateway').
  String get providerName;

  /// Whether this provider offers independent, cryptographic server verification.
  /// Standard client-side UPI intents return false.
  bool get supportsVerification;

  /// Checks if the payment provider is available on the current device and network.
  Future<bool> isAvailable();

  /// Initiates a payment transfer for the given request.
  Future<PaymentResult> initiatePayment(PaymentRequest request);
}
