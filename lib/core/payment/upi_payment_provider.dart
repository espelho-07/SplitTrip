import 'package:url_launcher/url_launcher.dart';
import 'payment_models.dart';
import 'payment_provider.dart';
import 'upi_validator.dart';

/// Concrete NPCI-compliant UPI Intent Payment Provider.
///
/// Uses standard `upi://pay` deep linking to trigger installed UPI apps
/// (Google Pay, PhonePe, Paytm, BHIM, Cred, Amazon Pay, etc.).
///
/// SECURITY INVARIANT:
/// This provider marks `supportsVerification: false` and returns `isVerified: false`
/// on all initiated payments because returning from an external app intent does NOT
/// guarantee banking settlement without independent server webhook confirmation.
class UpiPaymentProvider implements PaymentProvider {
  @override
  String get providerId => 'upi_intent';

  @override
  String get providerName => 'UPI Direct App';

  @override
  bool get supportsVerification => false;

  /// Builds a standard NPCI UPI URI string for the given payment request.
  Uri buildUpiUri(PaymentRequest request) {
    final queryParameters = <String, String>{
      'pa': UpiValidator.normalizeUpiId(request.recipientUpiId),
      'pn': request.recipientName.trim(),
      'am': (request.amountInPaise / 100.0).toStringAsFixed(2),
      'cu': request.currencyCode.isNotEmpty ? request.currencyCode : 'INR',
      'tn': request.transactionNote.trim(),
      'tr': request.transactionRef.trim(),
    };

    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: queryParameters,
    );
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final testUri = Uri(
        scheme: 'upi',
        host: 'pay',
        queryParameters: {'pa': 'test@upi', 'pn': 'Test', 'am': '1.00', 'cu': 'INR'},
      );
      return await canLaunchUrl(testUri);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<PaymentResult> initiatePayment(PaymentRequest request) async {
    if (!UpiValidator.isValidUpiId(request.recipientUpiId)) {
      return PaymentResult.failed(
        transactionReference: request.transactionRef,
        message: 'Invalid recipient UPI ID format (${request.recipientUpiId}).',
      );
    }

    if (request.amountInPaise <= 0) {
      return PaymentResult.failed(
        transactionReference: request.transactionRef,
        message: 'Payment amount must be greater than zero.',
      );
    }

    final uri = buildUpiUri(request);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        return PaymentResult.initiated(
          transactionReference: request.transactionRef,
          message: 'Launched UPI payment application for ₹${request.formattedRupees}.',
        );
      } else {
        return PaymentResult.failed(
          transactionReference: request.transactionRef,
          message: 'Could not open any UPI application. Please ensure a UPI app is installed.',
        );
      }
    } catch (e) {
      return PaymentResult.failed(
        transactionReference: request.transactionRef,
        message: 'Failed to launch UPI application: $e',
      );
    }
  }
}
