import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../domain/models/payment_verification_request.dart';
import '../../../domain/services/notification_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/trip_detail_viewmodel.dart';

/// Premium dedicated full-screen modal / bottom sheet for verifying and acknowledging payments.
/// Designed specifically for Kith's financial trustworthiness.
class PaymentVerificationView extends StatefulWidget {
  final PaymentVerificationRequest request;
  final VoidCallback? onVerified;

  const PaymentVerificationView({
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
      enableDrag: true,
      builder: (ctx) => PaymentVerificationView(
        request: request,
        onVerified: onVerified,
      ),
    );
  }

  @override
  State<PaymentVerificationView> createState() => _PaymentVerificationViewState();
}

class _PaymentVerificationViewState extends State<PaymentVerificationView> {
  bool _isProcessing = false;
  bool _isProofExpanded = false;
  String? _errorMessage;

  bool get _isAlreadyConfirmed =>
      widget.request.status == 'confirmed' || widget.request.status == 'settled' || widget.request.status == 'paid';

  bool get _isDisputed =>
      widget.request.status == 'disputed' || widget.request.status == 'not_received';

  bool get _hasProof =>
      (widget.request.proofImageUrl != null && widget.request.proofImageUrl!.isNotEmpty) ||
      (widget.request.transactionRef != null && widget.request.transactionRef!.isNotEmpty) ||
      (widget.request.proofNote != null && widget.request.proofNote!.isNotEmpty);

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return 'Recently';
    return DateFormat('d MMM · h:mm a').format(dt);
  }

  Future<void> _handleConfirmReceived() async {
    if (_isProcessing || _isAlreadyConfirmed) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
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
            content: Text(
              'Payment of ${CurrencyFormatter.formatPaise(widget.request.amountInPaise, currencyCode: 'INR')} confirmed and settled ✓',
            ),
            backgroundColor: AppColors.positiveGreenLight,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Unable to confirm payment. Please check your connection and try again.';
        });
      }
    }
  }

  Future<void> _handleDisputeNotReceived() async {
    if (_isProcessing || _isAlreadyConfirmed) return;

    // Confirm dialog before raising dispute
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Not Received?'),
        content: Text(
          '${widget.request.payerName} will be notified that you have not received this payment yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negativeRedLight),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("I Didn't Receive It"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
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
            content: Text(
              '${widget.request.payerName} has been notified that the payment was not received.',
            ),
            backgroundColor: AppColors.amberAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Unable to report issue. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedAmount =
        CurrencyFormatter.formatPaise(widget.request.amountInPaise, currencyCode: 'INR');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131720) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Badge Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isAlreadyConfirmed
                            ? AppColors.positiveGreenLight.withValues(alpha: 0.12)
                            : _isDisputed
                                ? AppColors.negativeRedLight.withValues(alpha: 0.12)
                                : AppColors.emeraldLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isAlreadyConfirmed
                                ? Icons.check_circle_rounded
                                : _isDisputed
                                    ? Icons.warning_amber_rounded
                                    : Icons.verified_user_rounded,
                            size: 16,
                            color: _isAlreadyConfirmed
                                ? AppColors.positiveGreenLight
                                : _isDisputed
                                    ? AppColors.negativeRedLight
                                    : AppColors.emeraldLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isAlreadyConfirmed
                                ? 'PAYMENT CONFIRMED'
                                : _isDisputed
                                    ? 'PAYMENT DISPUTED'
                                    : 'PAYMENT VERIFICATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: _isAlreadyConfirmed
                                  ? AppColors.positiveGreenLight
                                  : _isDisputed
                                      ? AppColors.negativeRedLight
                                      : AppColors.emeraldLight,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Payer Subtitle
                    Text(
                      '${widget.request.payerName} says they paid you',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Giant Focal Amount
                    Text(
                      formattedAmount,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),

                    // Trip Context Pill
                    if (widget.request.tripName.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flight_takeoff_rounded, size: 14, color: AppColors.emeraldLight),
                            const SizedBox(width: 6),
                            Text(
                              widget.request.tripName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Stale / Already Confirmed Banner
                    if (_isAlreadyConfirmed) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.positiveGreenLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.positiveGreenLight.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.positiveGreenLight, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Payment Already Confirmed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.positiveGreenLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'This settlement is completed and settled.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Financial Details Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Paid by',
                            valueWidget: Row(
                              children: [
                                MemberAvatar(name: widget.request.payerName, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  widget.request.payerName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            isDark: isDark,
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            icon: Icons.person_rounded,
                            label: 'Paid to',
                            valueWidget: Row(
                              children: [
                                MemberAvatar(name: widget.request.receiverName, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.request.receiverName} (You)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            isDark: isDark,
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            icon: Icons.schedule_rounded,
                            label: 'Marked paid',
                            value: _formatTimestamp(widget.request.markedAt),
                            isDark: isDark,
                          ),
                          if (widget.request.paymentReference != null &&
                              widget.request.paymentReference!.isNotEmpty) ...[
                            const Divider(height: 20),
                            _buildDetailRow(
                              icon: Icons.receipt_long_rounded,
                              label: 'Reference / UTR',
                              value: widget.request.paymentReference!,
                              isDark: isDark,
                              isMonospace: true,
                            ),
                          ],
                          if (widget.request.recipientUpiId != null &&
                              widget.request.recipientUpiId!.isNotEmpty) ...[
                            const Divider(height: 20),
                            _buildDetailRow(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'UPI ID',
                              value: widget.request.recipientUpiId!,
                              isDark: isDark,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Payment Proof Section (if attached)
                    if (_hasProof) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.emeraldLight.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.attachment_rounded, size: 18, color: AppColors.emeraldLight),
                                const SizedBox(width: 8),
                                const Text(
                                  'PAYMENT PROOF ATTACHED',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                    color: AppColors.emeraldLight,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(() => _isProofExpanded = !_isProofExpanded),
                                  child: Text(
                                    _isProofExpanded ? 'Hide' : 'View Proof',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.emeraldLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (widget.request.proofNote != null &&
                                widget.request.proofNote!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '"${widget.request.proofNote}"',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                            if (_isProofExpanded && widget.request.proofImageUrl != null) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  widget.request.proofImageUrl!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 100,
                                    color: Colors.black12,
                                    alignment: Alignment.center,
                                    child: const Text('Image preview unavailable'),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.negativeRedLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.negativeRedLight, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Action Buttons (Rule 21, 23)
                    if (!_isAlreadyConfirmed) ...[
                      Text(
                        'Did you receive this payment?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Primary CTA: I Received It
                      AppButton(
                        text: 'I RECEIVED IT',
                        icon: Icons.check_circle_outline_rounded,
                        variant: AppButtonVariant.primary,
                        isFullWidth: true,
                        isLoading: _isProcessing,
                        onPressed: _handleConfirmReceived,
                      ),

                      const SizedBox(height: 12),

                      // Secondary CTA: I Didn't Receive It
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : Colors.black54,
                            side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text(
                            "I DIDN'T RECEIVE IT",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          onPressed: _isProcessing ? null : _handleDisputeNotReceived,
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF1E2430) : const Color(0xFFE2E8F0),
                            foregroundColor: isDark ? Colors.white : Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
    required bool isDark,
    bool isMonospace = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const Spacer(),
        if (valueWidget != null)
          valueWidget
        else if (value != null)
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: isMonospace ? 'monospace' : null,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
      ],
    );
  }
}
