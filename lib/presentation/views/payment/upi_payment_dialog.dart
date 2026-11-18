import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/payment/payment_models.dart';
import '../../../core/payment/payment_service.dart';
import '../../../core/payment/upi_validator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../core/widgets/member_avatar.dart';

/// Modal bottom sheet providing the Pay via UPI + Mark Paid settlement experience.
class UpiPaymentSheet extends StatefulWidget {
  final String recipientName;
  final String? initialRecipientUpiId;
  final int amountInPaise;
  final String currencyCode;
  final String tripName;
  final String tripId;
  final String fromMemberId;
  final String toMemberId;
  final PaymentService paymentService;
  final Future<void> Function({
    required String paymentReference,
    required String recipientUpiId,
    required String paymentStatus,
  }) onConfirmSettlement;

  const UpiPaymentSheet({
    super.key,
    required this.recipientName,
    this.initialRecipientUpiId,
    required this.amountInPaise,
    this.currencyCode = 'INR',
    required this.tripName,
    required this.tripId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.paymentService,
    required this.onConfirmSettlement,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String recipientName,
    String? initialRecipientUpiId,
    required int amountInPaise,
    String currencyCode = 'INR',
    required String tripName,
    required String tripId,
    required String fromMemberId,
    required String toMemberId,
    required PaymentService paymentService,
    required Future<void> Function({
      required String paymentReference,
      required String recipientUpiId,
      required String paymentStatus,
    }) onConfirmSettlement,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UpiPaymentSheet(
        recipientName: recipientName,
        initialRecipientUpiId: initialRecipientUpiId,
        amountInPaise: amountInPaise,
        currencyCode: currencyCode,
        tripName: tripName,
        tripId: tripId,
        fromMemberId: fromMemberId,
        toMemberId: toMemberId,
        paymentService: paymentService,
        onConfirmSettlement: onConfirmSettlement,
      ),
    );
  }

  @override
  State<UpiPaymentSheet> createState() => _UpiPaymentSheetState();
}

class _UpiPaymentSheetState extends State<UpiPaymentSheet> {
  late TextEditingController _upiController;
  bool _isEditingUpi = false;
  bool _isInitiated = false;
  bool _isRecording = false;
  bool _showQrCode = false;
  String? _errorMessage;
  String? _activePaymentRef;

  @override
  void initState() {
    super.initState();
    final defaultVpa = widget.initialRecipientUpiId?.trim() ?? '';
    _upiController = TextEditingController(text: defaultVpa);
    if (defaultVpa.isEmpty) {
      _isEditingUpi = true;
    }
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  String get _dynamicPaymentUri {
    final vpa = _upiController.text.trim();
    final amt = (widget.amountInPaise / 100.0).toStringAsFixed(2);
    final note = Uri.encodeComponent('Settlement for ${widget.tripName}');
    final name = Uri.encodeComponent(widget.recipientName);
    return 'upi://pay?pa=$vpa&pn=$name&am=$amt&cu=${widget.currencyCode}&tn=$note';
  }

  Future<void> _handlePayViaUpi() async {
    final vpa = _upiController.text.trim();
    if (!UpiValidator.isValidUpiId(vpa)) {
      setState(() {
        _errorMessage = 'Please enter a valid UPI ID (e.g. name@bank)';
        _isEditingUpi = true;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    final request = PaymentService.createSettlementPaymentRequest(
      recipientUpiId: vpa,
      recipientName: widget.recipientName,
      amountInPaise: widget.amountInPaise,
      tripName: widget.tripName,
      tripId: widget.tripId,
      fromMemberId: widget.fromMemberId,
      toMemberId: widget.toMemberId,
    );

    final result = await widget.paymentService.pay(request);

    if (!mounted) return;

    if (result.status == PaymentStatus.initiated || result.status == PaymentStatus.paid) {
      setState(() {
        _isInitiated = true;
        _activePaymentRef = result.transactionReference ?? request.transactionRef;
      });
    } else if (result.status == PaymentStatus.failed) {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  Future<void> _handleConfirmPaid({required bool fromUpi}) async {
    setState(() => _isRecording = true);
    HapticHelper.success();

    final vpa = _upiController.text.trim();
    final ref = _activePaymentRef ??
        'MANUAL_${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

    try {
      await widget.onConfirmSettlement(
        paymentReference: ref,
        recipientUpiId: vpa.isNotEmpty ? vpa : 'manual_cash',
        paymentStatus: fromUpi ? 'completed' : 'manual_settled',
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _errorMessage = 'Failed to record settlement: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedAmount = CurrencyFormatter.formatPaise(
      widget.amountInPaise,
      currencyCode: widget.currencyCode,
    );
    final hasDefaultUpi = widget.initialRecipientUpiId != null && widget.initialRecipientUpiId!.trim().isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          if (!_isInitiated) ...[
            // ─── STAGE 1: Pay via UPI or Mark Paid ───────────────────
            Text(
              'Settle Balance',
              style: AppTypography.titleMedium(isDark: isDark),
            ),
            const SizedBox(height: 16),

            MemberAvatar(name: widget.recipientName, size: 54),
            const SizedBox(height: 8),

            Text(
              widget.recipientName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              formattedAmount,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Recipient Status Banner if no UPI configured
            if (!hasDefaultUpi) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.recipientName} has not added a UPI ID yet. You can type/paste their UPI ID below or settle via cash and tap "Mark as Paid".',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // UPI ID Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasDefaultUpi
                      ? AppColors.emeraldPrimary.withValues(alpha: 0.35)
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasDefaultUpi ? Icons.verified_user_rounded : Icons.account_balance_wallet_outlined,
                            size: 16,
                            color: hasDefaultUpi ? AppColors.emeraldPrimary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasDefaultUpi ? 'Recipient Configured UPI' : 'Recipient UPI ID',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: hasDefaultUpi ? AppColors.emeraldPrimary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticHelper.selection();
                          setState(() => _isEditingUpi = !_isEditingUpi);
                        },
                        child: Text(
                          _isEditingUpi ? 'Done' : 'Change',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_isEditingUpi)
                    TextField(
                      controller: _upiController,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      decoration: KithInputDecoration.borderless(
                        hintText: 'e.g. ${widget.recipientName.toLowerCase().replaceAll(' ', '')}@upi',
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    )
                  else
                    Text(
                      _upiController.text.isNotEmpty
                          ? _upiController.text
                          : 'No UPI ID saved (Tap Change to enter)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: _upiController.text.isNotEmpty
                            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                            : Colors.orangeAccent,
                      ),
                    ),
                ],
              ),
            ),

            // Live QR Toggle and View
            if (_upiController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  HapticHelper.selection();
                  setState(() => _showQrCode = !_showQrCode);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showQrCode ? Icons.qr_code_rounded : Icons.qr_code_2_rounded,
                        size: 16,
                        color: AppColors.emeraldPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _showQrCode ? 'Hide QR Code' : 'Show Instant QR Code',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showQrCode) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
                    ],
                  ),
                  child: QrImageView(
                    data: _dynamicPaymentUri,
                    version: QrVersions.auto,
                    size: 160.0,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action 1: Pay via UPI
            AppButton(
              text: 'Pay via UPI',
              icon: Icons.bolt_rounded,
              isFullWidth: true,
              isLoading: widget.paymentService.isProcessing,
              onPressed: _handlePayViaUpi,
            ),
            const SizedBox(height: 10),

            // Action 2: I'll pay manually / Mark as Paid
            AppButton(
              text: "I'll pay manually / Mark as Paid",
              variant: AppButtonVariant.secondary,
              isFullWidth: true,
              isLoading: _isRecording,
              onPressed: () => _handleConfirmPaid(fromUpi: false),
            ),
          ] else ...[
            // ─── STAGE 2: Payment Initiated Verification Confirmation ─
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.open_in_new_rounded,
                size: 26,
                color: AppColors.emeraldPrimary,
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Payment Initiated',
              style: AppTypography.titleMedium(isDark: isDark),
            ),
            const SizedBox(height: 6),

            Text(
              'Did you complete the payment of $formattedAmount to ${widget.recipientName} in your UPI app?',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Confirmation Action: Yes, Mark as Paid
            AppButton(
              text: 'Yes, Mark as Paid',
              icon: Icons.check_circle_rounded,
              isFullWidth: true,
              isLoading: _isRecording,
              onPressed: () => _handleConfirmPaid(fromUpi: true),
            ),
            const SizedBox(height: 10),

            // Cancel / Not yet
            AppButton(
              text: 'Not yet / Incomplete',
              variant: AppButtonVariant.secondary,
              isFullWidth: true,
              onPressed: () {
                HapticHelper.selection();
                setState(() => _isInitiated = false);
              },
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    ),
  );
  }
}
