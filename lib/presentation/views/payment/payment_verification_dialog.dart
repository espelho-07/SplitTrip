import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/payment/payment_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../domain/models/payment_verification_request.dart';
import '../../../domain/services/notification_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/trip_detail_viewmodel.dart';
import 'upi_payment_dialog.dart';

/// Modal bottom sheet shown to the Receiver (Payee) when a Payer marks payment as done.
class PaymentVerificationSheet extends StatefulWidget {
  final PaymentVerificationRequest request;
  final VoidCallback? onVerified;

  const PaymentVerificationSheet({
    super.key,
    required this.request,
    this.onVerified,
  });

  static Future<bool?> show(
    BuildContext context, {
    required PaymentVerificationRequest request,
    VoidCallback? onVerified,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentVerificationSheet(
        request: request,
        onVerified: onVerified,
      ),
    );
  }

  @override
  State<PaymentVerificationSheet> createState() => _PaymentVerificationSheetState();
}

class _PaymentVerificationSheetState extends State<PaymentVerificationSheet> {
  bool _isProcessing = false;

  Future<void> _handleConfirmReceived() async {
    setState(() => _isProcessing = true);
    HapticHelper.success();

    final expenseRepo = context.read<ExpenseRepository>();
    final notifService = context.read<NotificationService>();
    final tripDetailVm = Provider.of<TripDetailViewModel?>(context, listen: false);
    final authVm = Provider.of<AuthViewModel?>(context, listen: false);
    final currentUserId = authVm?.currentUser?.id ?? '';

    try {
      await expenseRepo.confirmSettlementVerification(
        tripId: widget.request.tripId,
        verificationId: widget.request.id,
        settlementId: widget.request.settlementId,
        receiverName: widget.request.receiverName,
        payerName: widget.request.payerName,
        amountInPaise: widget.request.amountInPaise,
      );

      // Notify Payer
      await notifService.notifyPaymentConfirmed(
        tripName: widget.request.tripName,
        payerName: widget.request.payerName,
        receiverName: widget.request.receiverName,
        amountInPaise: widget.request.amountInPaise,
        tripId: widget.request.tripId,
      );

      if (tripDetailVm != null && tripDetailVm.trip?.id == widget.request.tripId) {
        await tripDetailVm.refresh(currentUserId);
      }

      if (mounted) {
        Navigator.pop(context, true);
        widget.onVerified?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₹${widget.request.amountInRupees.toStringAsFixed(widget.request.amountInPaise % 100 == 0 ? 0 : 2)} confirmed and settled ✓'),
            backgroundColor: const Color(0xFF14B8A6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm settlement: $e')),
        );
      }
    }
  }

  Future<void> _handleDisputeNotReceived() async {
    setState(() => _isProcessing = true);
    HapticHelper.heavy();

    final expenseRepo = context.read<ExpenseRepository>();
    final notifService = context.read<NotificationService>();
    final tripDetailVm = Provider.of<TripDetailViewModel?>(context, listen: false);
    final authVm = Provider.of<AuthViewModel?>(context, listen: false);
    final currentUserId = authVm?.currentUser?.id ?? '';

    try {
      await expenseRepo.disputeSettlementVerification(
        tripId: widget.request.tripId,
        verificationId: widget.request.id,
        settlementId: widget.request.settlementId,
        receiverName: widget.request.receiverName,
        payerName: widget.request.payerName,
        amountInPaise: widget.request.amountInPaise,
        reason: 'Marked not received by receiver',
      );

      // Notify Payer
      await notifService.notifyPaymentDisputed(
        tripName: widget.request.tripName,
        payerName: widget.request.payerName,
        receiverName: widget.request.receiverName,
        amountInPaise: widget.request.amountInPaise,
        tripId: widget.request.tripId,
      );

      if (tripDetailVm != null && tripDetailVm.trip?.id == widget.request.tripId) {
        await tripDetailVm.refresh(currentUserId);
      }

      if (mounted) {
        Navigator.pop(context, false);
        widget.onVerified?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.request.payerName} has been notified that the payment was not received.'),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedAmt = CurrencyFormatter.formatPaise(widget.request.amountInPaise, currencyCode: 'INR');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, size: 16, color: Color(0xFF14B8A6)),
                SizedBox(width: 6),
                Text(
                  'Payment Verification',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF14B8A6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payer Avatar & Info
          MemberAvatar(name: widget.request.payerName, size: 56),
          const SizedBox(height: 10),

          Text(
            widget.request.payerName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),

          Text(
            'marked payment for "${widget.request.tripName}"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Amount Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Text(
                  formattedAmt,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF14B8A6),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.request.paymentMethod == 'UPI' ? Icons.bolt_rounded : Icons.payments_outlined,
                      size: 14,
                      color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'via ${widget.request.paymentMethod} • ${_formatTime(widget.request.markedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Core Question
          Text(
            'Did you receive $formattedAmt from ${widget.request.payerName}?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Confirming will automatically update all balances in both accounts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
            ),
          ),

          const SizedBox(height: 24),

          // Action 1: Yes, Received
          AppButton(
            text: 'Yes, Received ✓',
            icon: Icons.check_circle_rounded,
            isFullWidth: true,
            isLoading: _isProcessing,
            onPressed: _handleConfirmReceived,
          ),
          const SizedBox(height: 10),

          // Action 2: No, Not Received
          AppButton(
            text: 'No, Not Received',
            variant: AppButtonVariant.secondary,
            isFullWidth: true,
            onPressed: _isProcessing ? null : _handleDisputeNotReceived,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';
    return isToday ? 'Today at $timeStr' : '${dt.day}/${dt.month} $timeStr';
  }
}

/// Modal alert shown to Payer (X) when Receiver (Y) reports that payment was NOT received.
class PaymentDisputeAlertSheet extends StatelessWidget {
  final PaymentVerificationRequest request;
  final VoidCallback? onHandled;

  const PaymentDisputeAlertSheet({
    super.key,
    required this.request,
    this.onHandled,
  });

  static Future<void> show(
    BuildContext context, {
    required PaymentVerificationRequest request,
    VoidCallback? onHandled,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentDisputeAlertSheet(
        request: request,
        onHandled: onHandled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedAmt = CurrencyFormatter.formatPaise(request.amountInPaise, currencyCode: 'INR');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.warning_amber_rounded, size: 32, color: Colors.orange),
          ),
          const SizedBox(height: 14),

          Text(
            'Payment Not Received',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),

          Text(
            '${request.receiverName} indicated they did not receive $formattedAmt for "${request.tripName}".',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),

          // Retry UPI Payment
          AppButton(
            text: 'Retry UPI Payment',
            icon: Icons.bolt_rounded,
            isFullWidth: true,
            onPressed: () {
              Navigator.pop(context);
              UpiPaymentSheet.show(
                context,
                recipientName: request.receiverName,
                initialRecipientUpiId: request.recipientUpiId,
                amountInPaise: request.amountInPaise,
                currencyCode: 'INR',
                tripName: request.tripName,
                tripId: request.tripId,
                fromMemberId: request.payerMemberId,
                toMemberId: request.receiverMemberId,
                paymentService: PaymentService(),
                onConfirmSettlement: ({
                  required String paymentReference,
                  required String recipientUpiId,
                  required String paymentStatus,
                }) async {
                  final expenseRepo = context.read<ExpenseRepository>();
                  await expenseRepo.recordSettlement(
                    tripId: request.tripId,
                    fromMemberId: request.payerMemberId,
                    toMemberId: request.receiverMemberId,
                    amountInPaise: request.amountInPaise,
                    paymentReference: paymentReference,
                    recipientUpiId: recipientUpiId,
                    fromName: request.payerName,
                    toName: request.receiverName,
                    paymentStatus: 'pending_verification',
                    tripName: request.tripName,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),

          // Dismiss
          AppButton(
            text: 'Dismiss / Contact ${request.receiverName}',
            variant: AppButtonVariant.secondary,
            isFullWidth: true,
            onPressed: () {
              final storage = context.read<LocalStorageService>();
              storage.updatePaymentVerificationStatus(request.id, 'dismissed');
              Navigator.pop(context);
              onHandled?.call();
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Global helper that automatically inspects and presents pending payment verifications and dispute alerts.
class PaymentVerificationManager {
  PaymentVerificationManager._();

  static Future<void> checkAndPrompt(BuildContext context) async {
    try {
      final storage = context.read<LocalStorageService>();
      final authVm = Provider.of<AuthViewModel?>(context, listen: false);
      final currentUser = authVm?.currentUser;
      if (currentUser == null) return;

      // 1. Check for incoming pending verifications where current user is the Receiver (Payee)
      final pendingReceiver = storage.getPendingVerificationsForReceiver(
        userId: currentUser.id,
        name: currentUser.displayName,
      );

      if (pendingReceiver.isNotEmpty) {
        final req = PaymentVerificationRequest.fromJson(pendingReceiver.first);
        if (context.mounted) {
          await PaymentVerificationSheet.show(context, request: req);
          return;
        }
      }

      // 2. Check for dispute alerts where current user is the Payer
      final disputedPayer = storage.getDisputedVerificationsForPayer(
        userId: currentUser.id,
        name: currentUser.displayName,
      );

      if (disputedPayer.isNotEmpty) {
        final req = PaymentVerificationRequest.fromJson(disputedPayer.first);
        if (context.mounted) {
          await PaymentDisputeAlertSheet.show(context, request: req);
        }
      }
    } catch (_) {}
  }
}
