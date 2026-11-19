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
import 'payment_verification_view.dart';
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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

          // Send Payment Proof
          AppButton(
            text: 'Send Payment Proof',
            icon: Icons.upload_file_rounded,
            isFullWidth: true,
            onPressed: () {
              Navigator.pop(context);
              PaymentProofSheet.show(
                context,
                request: request,
                isPayer: true,
                onHandled: onHandled,
              );
            },
          ),
          const SizedBox(height: 10),

          // Retry UPI Payment
          AppButton(
            text: 'Retry UPI Payment',
            variant: AppButtonVariant.secondary,
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
                paymentService: context.read<PaymentService>(),
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
            variant: AppButtonVariant.ghost,
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
    ),
  );
  }
}

/// Modal sheet for submitting or reviewing payment proof (UTR / Note / Screenshot).
class PaymentProofSheet extends StatefulWidget {
  final PaymentVerificationRequest request;
  final bool isPayer;
  final VoidCallback? onHandled;

  const PaymentProofSheet({
    super.key,
    required this.request,
    this.isPayer = true,
    this.onHandled,
  });

  static Future<bool?> show(
    BuildContext context, {
    required PaymentVerificationRequest request,
    bool isPayer = true,
    VoidCallback? onHandled,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentProofSheet(
        request: request,
        isPayer: isPayer,
        onHandled: onHandled,
      ),
    );
  }

  @override
  State<PaymentProofSheet> createState() => _PaymentProofSheetState();
}

class _PaymentProofSheetState extends State<PaymentProofSheet> {
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _refController.text = widget.request.transactionRef ?? widget.request.paymentReference ?? '';
    _noteController.text = widget.request.proofNote ?? widget.request.note ?? '';
  }

  @override
  void dispose() {
    _refController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitProof() async {
    final ref = _refController.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Transaction Reference / UTR number')),
      );
      HapticHelper.heavy();
      return;
    }

    setState(() => _isProcessing = true);
    HapticHelper.success();

    final expenseRepo = context.read<ExpenseRepository>();
    final notifService = context.read<NotificationService>();
    final tripDetailVm = Provider.of<TripDetailViewModel?>(context, listen: false);
    final authVm = Provider.of<AuthViewModel?>(context, listen: false);
    final currentUserId = authVm?.currentUser?.id ?? '';

    try {
      await expenseRepo.submitSettlementProof(
        tripId: widget.request.tripId,
        verificationId: widget.request.id,
        settlementId: widget.request.settlementId,
        receiverName: widget.request.receiverName,
        payerName: widget.request.payerName,
        amountInPaise: widget.request.amountInPaise,
        transactionRef: ref,
        proofNote: _noteController.text.trim(),
      );

      await notifService.notifyPaymentProofSubmitted(
        tripName: widget.request.tripName,
        payerName: widget.request.payerName,
        receiverName: widget.request.receiverName,
        amountInPaise: widget.request.amountInPaise,
        tripId: widget.request.tripId,
        transactionRef: ref,
      );

      if (tripDetailVm != null && tripDetailVm.trip?.id == widget.request.tripId) {
        await tripDetailVm.refresh(currentUserId);
      }

      if (mounted) {
        Navigator.pop(context, true);
        widget.onHandled?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment proof submitted to ${widget.request.receiverName} ✓'),
            backgroundColor: const Color(0xFF14B8A6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit proof: $e')),
        );
      }
    }
  }

  Future<void> _handleReceiverConfirm() async {
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
        widget.onHandled?.call();
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

  Future<void> _handleReceiverDispute() async {
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
        reason: 'Proof reviewed but payment not found in account',
      );

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
        widget.onHandled?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.request.payerName} notified that payment is still not received.'),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedAmt = CurrencyFormatter.formatPaise(widget.request.amountInPaise, currencyCode: 'INR');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1418) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF14B8A6), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isPayer ? 'Submit Payment Proof' : 'Review Payment Proof',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '$formattedAmt for "${widget.request.tripName}"',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (widget.isPayer) ...[
              Text(
                'Transaction Reference / UTR (12 digits)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _refController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'e.g. 423589123456 or UPI ref',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Note / Bank Remarks (Optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 2,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'e.g. Sent via Google Pay at 10:15 PM',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              AppButton(
                text: 'Submit Proof to ${widget.request.receiverName}',
                icon: Icons.check_circle_outline_rounded,
                isFullWidth: true,
                isLoading: _isProcessing,
                onPressed: _handleSubmitProof,
              ),
            ] else ...[
              // Receiver view
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payer', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
                        Text(widget.request.payerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Amount', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
                        Text(formattedAmt, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF14B8A6))),
                      ],
                    ),
                    if (widget.request.transactionRef != null && widget.request.transactionRef!.isNotEmpty) ...[
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ref / UTR', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
                          SelectableText(
                            widget.request.transactionRef!,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ],
                    if (widget.request.proofNote != null && widget.request.proofNote!.isNotEmpty) ...[
                      const Divider(height: 16),
                      Text('Payer Note:', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Text(widget.request.proofNote!, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              AppButton(
                text: 'Yes, Received ✓',
                icon: Icons.check_circle_rounded,
                isFullWidth: true,
                isLoading: _isProcessing,
                onPressed: _handleReceiverConfirm,
              ),
              const SizedBox(height: 10),

              AppButton(
                text: 'Still Not Received',
                variant: AppButtonVariant.secondary,
                isFullWidth: true,
                onPressed: _isProcessing ? null : _handleReceiverDispute,
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    ),
  );
  }
}

/// Global helper that automatically inspects and presents pending payment verifications and dispute alerts.
class PaymentVerificationManager {
  PaymentVerificationManager._();

  static Future<void> checkAndPrompt(BuildContext context, {bool syncServer = true}) async {
    try {
      final storage = context.read<LocalStorageService>();
      final authVm = Provider.of<AuthViewModel?>(context, listen: false);
      final currentUser = authVm?.currentUser;
      if (currentUser == null) return;

      if (syncServer) {
        try {
          final expenseRepo = context.read<ExpenseRepository>();
          await expenseRepo.syncPendingVerifications(currentUser.id);
        } catch (_) {}
      }

      if (!context.mounted) return;

      // 1. Check for incoming pending verifications where current user is the Receiver (Payee)
      final pendingReceiver = storage.getPendingVerificationsForReceiver(
        userId: currentUser.id,
        name: currentUser.displayName,
      );

      if (pendingReceiver.isNotEmpty) {
        final req = PaymentVerificationRequest.fromJson(pendingReceiver.first);
        if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
          await PaymentVerificationView.show(context, request: req);
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
        if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
          await PaymentDisputeAlertSheet.show(context, request: req);
        }
      }
    } catch (_) {}
  }
}
