import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/payment/payment_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/currency_display.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../../domain/models/balance_summary.dart';
import '../../../../domain/models/payment_verification_request.dart';
import '../../../../domain/models/trip.dart';
import '../../../../domain/models/trip_member.dart';
import '../../../widgets/progress/progress.dart';
import '../../payment/payment_verification_dialog.dart';
import '../../payment/upi_payment_dialog.dart';
import '../../../../domain/services/notification_service.dart';
import '../../../viewmodels/trip_detail_viewmodel.dart';

typedef RecordSettlementCallback = Future<void> Function(
  String fromMemberId,
  String toMemberId,
  int amountInPaise, {
  String? paymentReference,
  String? recipientUpiId,
  String? fromName,
  String? toName,
  String? paymentStatus,
});

class SettlementSheet extends StatefulWidget {
  final Trip trip;
  final BalanceSummary balanceSummary;
  final String currentUserId;
  final VoidCallback? onMarkSettled;
  final RecordSettlementCallback? onRecordTransfer;
  final PaymentService? paymentService;

  const SettlementSheet({
    super.key,
    required this.trip,
    required this.balanceSummary,
    required this.currentUserId,
    this.onMarkSettled,
    this.onRecordTransfer,
    this.paymentService,
  });

  @override
  State<SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<SettlementSheet> {
  final Set<String> _processingTransferIds = {};
  final Set<String> _paidTransferKeys = {};
  late PaymentService _paymentService;

  @override
  void initState() {
    super.initState();
    _paymentService = widget.paymentService ?? PaymentService();
  }

  TripMember? _findMember(String memberId) {
    return widget.trip.members.where((m) => m.id == memberId).firstOrNull;
  }

  Future<void> _handleSettlementAction({
    required String fromMemberId,
    required String toMemberId,
    required String fromName,
    required String toName,
    required int amountInPaise,
    required bool isPayerCurrentUser,
    required bool isReceiverCurrentUser,
  }) async {
    final transferKey = fromMemberId + toMemberId;
    if (_processingTransferIds.contains(transferKey)) return;

    final l10n = context.l10n;

    // SCENARIO 1: Current User is RECEIVER (Creditor)
    // Rahul owes Me -> I tap "Mark Received" to confirm I got the money
    if (isReceiverCurrentUser) {
      final confirmed = await _showConfirmReceivedDialog(
        fromName: fromName,
        amountInPaise: amountInPaise,
      );

      if (confirmed == true && mounted && widget.onRecordTransfer != null) {
        setState(() => _processingTransferIds.add(transferKey));
        try {
          await widget.onRecordTransfer!(
            fromMemberId,
            toMemberId,
            amountInPaise,
            paymentReference: 'manual_rcvd_${DateTime.now().millisecondsSinceEpoch}',
            fromName: fromName,
            toName: toName,
            paymentStatus: 'completed',
          );
          if (mounted) {
            setState(() => _paidTransferKeys.add(transferKey));
            HapticHelper.success();
            KithSuccessToast.show(context, 'Payment of ${CurrencyFormatter.formatPaise(amountInPaise, currencyCode: widget.trip.currencyCode)} marked as received ✓');
          }
        } finally {
          if (mounted) {
            setState(() => _processingTransferIds.remove(transferKey));
          }
        }
      }
      return;
    }

    // SCENARIO 2: Current User is PAYER (Debtor)
    // I owe Rahul -> I tap "Pay Rahul" to open UPI pay with Rahul's UPI ID
    if (isPayerCurrentUser) {
      final toMember = _findMember(toMemberId);
      final userRepo = context.read<UserRepository>();
      String? recipientUpi = toMember?.upiId;

      if ((recipientUpi == null || recipientUpi.isEmpty) && toMember?.userId != null) {
        try {
          final liveUpi = await userRepo.getUserUpi(toMember!.userId);
          if (liveUpi != null && liveUpi.isNotEmpty) {
            recipientUpi = liveUpi;
          }
        } catch (_) {}
      }

      if (!mounted) return;

      final success = await UpiPaymentSheet.show(
        context,
        recipientName: toName,
        initialRecipientUpiId: recipientUpi,
        amountInPaise: amountInPaise,
        currencyCode: widget.trip.currencyCode,
        tripName: widget.trip.name,
        tripId: widget.trip.id,
        fromMemberId: fromMemberId,
        toMemberId: toMemberId,
        paymentService: _paymentService,
        onConfirmSettlement: ({
          required String paymentReference,
          required String recipientUpiId,
          required String paymentStatus,
        }) async {
          if (widget.onRecordTransfer != null) {
            setState(() => _processingTransferIds.add(transferKey));
            try {
              await widget.onRecordTransfer!(
                fromMemberId,
                toMemberId,
                amountInPaise,
                paymentReference: paymentReference,
                recipientUpiId: recipientUpiId,
                fromName: fromName,
                toName: toName,
                paymentStatus: 'pending_verification',
              );
            } finally {
              if (mounted) {
                setState(() => _processingTransferIds.remove(transferKey));
              }
            }
          }
        },
      );

      if (success == true && mounted) {
        setState(() {
          _paidTransferKeys.add(transferKey);
        });
        HapticHelper.success();
        KithSuccessToast.show(
          context,
          'Payment marked as paid. Waiting for $toName to confirm receipt.',
        );
      }
      return;
    }

    // SCENARIO 3: Third Party / Creator recording for others (Alice pays Bob)
    if (widget.onRecordTransfer != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
          title: Text(l10n.settlementRecordDialogTitle),
          content: Text(l10n.settlementRecordDialogBody(fromName, CurrencyFormatter.formatPaise(amountInPaise, currencyCode: widget.trip.currencyCode), toName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.emeraldPrimary),
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(l10n.actionConfirm),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        setState(() => _processingTransferIds.add(transferKey));
        try {
          await widget.onRecordTransfer!(
            fromMemberId,
            toMemberId,
            amountInPaise,
            paymentReference: 'creator_record_${DateTime.now().millisecondsSinceEpoch}',
            fromName: fromName,
            toName: toName,
            paymentStatus: 'completed',
          );
          if (mounted) {
            setState(() => _paidTransferKeys.add(transferKey));
            HapticHelper.success();
            KithSuccessToast.show(context, l10n.settlementPaidSuccess);
          }
        } finally {
          if (mounted) {
            setState(() => _processingTransferIds.remove(transferKey));
          }
        }
      }
    }
  }

  Future<bool?> _showConfirmReceivedDialog({
    required String fromName,
    required int amountInPaise,
  }) {
    final storage = context.read<LocalStorageService>();
    final myUpiId = storage.getPrimaryUpiId();
    final formattedAmt = CurrencyFormatter.formatPaise(amountInPaise, currencyCode: widget.trip.currencyCode);
    final l10n = context.l10n;

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1418) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
            ),
          ),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settlementConfirmReceivedTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          l10n.settlementConfirmReceivedBody(formattedAmt, fromName),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.settlementAmountToClear, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      formattedAmt,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF14B8A6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (myUpiId != null && myUpiId.isNotEmpty) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticHelper.medium();
                          Clipboard.setData(ClipboardData(text: myUpiId));
                          Navigator.pop(ctx, false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.settlementUpiCopiedToast(myUpiId)),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text(l10n.settlementShareMyUpi),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(l10n.settlementYesReceived, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleReceiverConfirmDirect({
    required String settlementId,
    required String verificationId,
    required String payerName,
    required String receiverName,
    required int amountInPaise,
    required String transferKey,
  }) async {
    if (_processingTransferIds.contains(transferKey)) return;
    setState(() => _processingTransferIds.add(transferKey));
    HapticHelper.success();

    final expenseRepo = context.read<ExpenseRepository>();
    final notifService = context.read<NotificationService>();
    final tripDetailVm = Provider.of<TripDetailViewModel?>(context, listen: false);

    try {
      await expenseRepo.confirmSettlementVerification(
        tripId: widget.trip.id,
        verificationId: verificationId,
        settlementId: settlementId,
        receiverName: receiverName,
        payerName: payerName,
        amountInPaise: amountInPaise,
      );

      await notifService.notifyPaymentConfirmed(
        tripName: widget.trip.name,
        payerName: payerName,
        receiverName: receiverName,
        amountInPaise: amountInPaise,
        tripId: widget.trip.id,
      );

      if (tripDetailVm != null) {
        await tripDetailVm.refresh(widget.currentUserId);
      }

      if (mounted) {
        setState(() => _paidTransferKeys.add(transferKey));
        KithSuccessToast.show(
          context,
          'Payment of ${CurrencyFormatter.formatPaise(amountInPaise, currencyCode: widget.trip.currencyCode)} confirmed and settled ✓',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm settlement: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingTransferIds.remove(transferKey));
      }
    }
  }

  Future<void> _handleReceiverDisputeDirect({
    required String settlementId,
    required String verificationId,
    required String payerName,
    required String receiverName,
    required int amountInPaise,
    required String transferKey,
  }) async {
    if (_processingTransferIds.contains(transferKey)) return;
    setState(() => _processingTransferIds.add(transferKey));
    HapticHelper.heavy();

    final expenseRepo = context.read<ExpenseRepository>();
    final notifService = context.read<NotificationService>();
    final tripDetailVm = Provider.of<TripDetailViewModel?>(context, listen: false);

    try {
      await expenseRepo.disputeSettlementVerification(
        tripId: widget.trip.id,
        verificationId: verificationId,
        settlementId: settlementId,
        receiverName: receiverName,
        payerName: payerName,
        amountInPaise: amountInPaise,
        reason: 'Marked not received by receiver',
      );

      await notifService.notifyPaymentDisputed(
        tripName: widget.trip.name,
        payerName: payerName,
        receiverName: receiverName,
        amountInPaise: amountInPaise,
        tripId: widget.trip.id,
      );

      if (tripDetailVm != null) {
        await tripDetailVm.refresh(widget.currentUserId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$payerName has been notified that the payment was not received.'),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingTransferIds.remove(transferKey));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final tripDetailVm = Provider.of<TripDetailViewModel?>(context);
    final effectiveBalanceSummary = tripDetailVm?.balanceSummary ?? widget.balanceSummary;
    final settlements = effectiveBalanceSummary.simplifiedSettlements;

    final expenseRepo = context.read<ExpenseRepository>();
    final cachedSettlements = expenseRepo.getCachedSettlements(widget.trip.id);
    final settledHistory = cachedSettlements.where((s) {
      final isSettled = s['isSettled'] as bool? ?? false;
      final st = s['status'] as String?;
      return isSettled || st == 'paid' || st == 'confirmed' || st == 'completed';
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: AppSpacing.bottomSheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settlementTitle,
                    style: AppTypography.titleLarge(isDark: isDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.settlementSubtitle,
                    style: AppTypography.bodySmall(isDark: isDark),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          Expanded(
            child: ListView(
              children: [
                // SECTION 1: Active Dues & Debts
                if (settlements.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 48,
                            color: AppColors.positiveGreenLight,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.settlementEmptyTitle,
                            style: AppTypography.titleSmall(isDark: isDark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.settlementEmptyDesc,
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  for (int index = 0; index < settlements.length; index++) ...[
                    _buildActiveSettlementCard(
                      context: context,
                      isDark: isDark,
                      s: settlements[index],
                      cachedSettlements: cachedSettlements,
                    ),
                    if (index < settlements.length - 1) const SizedBox(height: AppSpacing.md),
                  ],
                ],

                // SECTION 2: Settlement History
                if (settledHistory.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.history_rounded, size: 18, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        'Settlement History (${settledHistory.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final stl in settledHistory)
                    _buildSettledHistoryCard(
                      context: context,
                      isDark: isDark,
                      stl: stl,
                    ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),

          if (widget.onMarkSettled != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: AppButton(
                text: l10n.settlementMarkAllDone,
                icon: Icons.check_circle_rounded,
                isFullWidth: true,
                onPressed: _handleMarkAllDone,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveSettlementCard({
    required BuildContext context,
    required bool isDark,
    required dynamic s,
    required List<Map<String, dynamic>> cachedSettlements,
  }) {
    final l10n = context.l10n;
    final fromMember = _findMember(s.fromMemberId);
    final toMember = _findMember(s.toMemberId);

    final fromName = fromMember?.displayName ?? 'Member';
    final toName = toMember?.displayName ?? 'Member';
    final isPayerCurrentUser = fromMember?.userId == widget.currentUserId;
    final isReceiverCurrentUser = toMember?.userId == widget.currentUserId;
    final isTripCreator = widget.trip.creatorId == widget.currentUserId;
    final canRecord = isPayerCurrentUser || isReceiverCurrentUser || isTripCreator;
    final transferKey = s.fromMemberId + s.toMemberId;
    final isProcessing = _processingTransferIds.contains(transferKey);
    final isPaid = _paidTransferKeys.contains(transferKey);

    final isAlreadySettledInCache = cachedSettlements.any((cs) {
      final matchesPair = (cs['fromMemberId'] == s.fromMemberId && cs['toMemberId'] == s.toMemberId) ||
          (fromMember?.userId != null && cs['fromUserId'] == fromMember!.userId && toMember?.userId != null && cs['toUserId'] == toMember!.userId);
      final isSettled = cs['isSettled'] as bool? ?? false;
      final st = cs['status'] as String?;
      return matchesPair && (isSettled || st == 'paid' || st == 'confirmed' || st == 'completed' || st == 'manual_settled');
    });

    // Look up in-flight settlement state for this pair
    final inFlight = cachedSettlements.where((cs) {
      final matchesPair = (cs['fromMemberId'] == s.fromMemberId && cs['toMemberId'] == s.toMemberId) ||
          (fromMember?.userId != null && cs['fromUserId'] == fromMember!.userId && toMember?.userId != null && cs['toUserId'] == toMember!.userId);
      final isSettled = cs['isSettled'] as bool? ?? false;
      final st = cs['status'] as String?;
      final isNotSettled = !isSettled && st != 'paid' && st != 'confirmed' && st != 'completed';
      return matchesPair && isNotSettled;
    }).firstOrNull;

    final inFlightStatus = inFlight?['status'] as String?;
    final inFlightSettlementId = inFlight?['id'] as String? ?? 'stl_${s.fromMemberId}_${s.toMemberId}';
    final inFlightVerificationId = 'pvr_$inFlightSettlementId';

    // Dynamic CTA Label based on role
    String actionButtonLabel;
    IconData actionButtonIcon;
    if (isReceiverCurrentUser) {
      actionButtonLabel = l10n.settlementMarkReceivedBtn;
      actionButtonIcon = Icons.check_circle_outline_rounded;
    } else if (isPayerCurrentUser) {
      actionButtonLabel = l10n.settlementPayPersonBtn(toName);
      actionButtonIcon = Icons.bolt_rounded;
    } else {
      actionButtonLabel = l10n.settlementRecordPaymentBtn;
      actionButtonIcon = Icons.edit_note_rounded;
    }

    return SurfaceCard(
      backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // From Member (Payer)
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MemberAvatar(name: fromName, size: 34),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPayerCurrentUser ? l10n.translate('balance_you') : fromName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(l10n.settlementPaysLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow & Amount
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.emeraldPrimary),
                    const SizedBox(height: 2),
                    CurrencyDisplay(
                      amountInPaise: s.amountInPaise,
                      size: CurrencyDisplaySize.medium,
                      colorMode: CurrencyColorMode.neutral,
                      currencyCode: widget.trip.currencyCode,
                    ),
                  ],
                ),
              ),

              // To Member (Receiver)
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isReceiverCurrentUser ? l10n.translate('balance_you') : toName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(l10n.settlementReceivesLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    MemberAvatar(name: toName, size: 34),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // IN-FLIGHT STATE: AWAITING CONFIRMATION
          if (inFlightStatus == 'marked_paid' || inFlightStatus == 'pending_verification') ...[
            if (isReceiverCurrentUser) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$fromName marked payment as sent',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14B8A6),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              icon: isProcessing
                                  ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_circle_rounded, size: 14),
                              label: const Text('Yes, Received ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              onPressed: isProcessing
                                  ? null
                                  : () => _handleReceiverConfirmDirect(
                                        settlementId: inFlightSettlementId,
                                        verificationId: inFlightVerificationId,
                                        payerName: fromName,
                                        receiverName: toName,
                                        amountInPaise: s.amountInPaise,
                                        transferKey: transferKey,
                                      ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade800,
                                side: BorderSide(color: Colors.orange.shade400),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: isProcessing
                                  ? null
                                  : () => _handleReceiverDisputeDirect(
                                        settlementId: inFlightSettlementId,
                                        verificationId: inFlightVerificationId,
                                        payerName: fromName,
                                        receiverName: toName,
                                        amountInPaise: s.amountInPaise,
                                        transferKey: transferKey,
                                      ),
                              child: const Text('Not Received', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (isPayerCurrentUser) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment Sent • Waiting for $toName to confirm',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You marked this as paid. You cannot pay again while confirmation is in progress. Once $toName confirms, your balance will clear automatically.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Awaiting confirmation from $toName',
                  style: const TextStyle(fontSize: 11.5, color: Colors.amber),
                ),
              ),
            ],
          ] else if (inFlightStatus == 'disputed' || inFlightStatus == 'not_received') ...[
            // IN-FLIGHT STATE: DISPUTED
            if (isPayerCurrentUser) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$toName reported payment was not received',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.upload_file_rounded, size: 14),
                        label: const Text('Send Payment Proof', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          PaymentProofSheet.show(
                            context,
                            request: PaymentVerificationRequest(
                              id: inFlightVerificationId,
                              settlementId: inFlightSettlementId,
                              tripId: widget.trip.id,
                              tripName: widget.trip.name,
                              payerMemberId: s.fromMemberId,
                              payerName: fromName,
                              receiverMemberId: s.toMemberId,
                              receiverName: toName,
                              amountInPaise: s.amountInPaise,
                              markedAt: DateTime.now(),
                            ),
                            isPayer: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Payment reported not received',
                  style: const TextStyle(fontSize: 11.5, color: Colors.red),
                ),
              ),
            ],
          ] else if (inFlightStatus == 'proof_submitted') ...[
            // IN-FLIGHT STATE: PROOF SUBMITTED
            if (isReceiverCurrentUser) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF14B8A6)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$fromName submitted payment proof',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF14B8A6)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.visibility_rounded, size: 14),
                        label: const Text('Review Payment Proof', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          PaymentProofSheet.show(
                            context,
                            request: PaymentVerificationRequest(
                              id: inFlightVerificationId,
                              settlementId: inFlightSettlementId,
                              tripId: widget.trip.id,
                              tripName: widget.trip.name,
                              payerMemberId: s.fromMemberId,
                              payerName: fromName,
                              receiverMemberId: s.toMemberId,
                              receiverName: toName,
                              amountInPaise: s.amountInPaise,
                              transactionRef: inFlight?['transactionRef'] as String?,
                              proofNote: inFlight?['proofNote'] as String?,
                              markedAt: DateTime.now(),
                            ),
                            isPayer: false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Proof submitted • Awaiting review by $toName',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF14B8A6)),
                ),
              ),
            ],
          ] else ...[
            // NORMAL UNPAID DEBT
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  toMember?.upiId != null ? l10n.settlementUpiReadyTag(toMember!.upiId!) : (isReceiverCurrentUser ? l10n.settlementYouOwed : l10n.settlementDirectMember),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),

                if (canRecord && widget.onRecordTransfer != null) ...[
                  if (isPaid || isAlreadySettledInCache)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15),
                        borderRadius: AppRadius.fullBorder,
                        border: Border.all(
                          color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.settlementSettledBadge,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 34,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBorder),
                          elevation: 0,
                        ),
                        icon: isProcessing
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(actionButtonIcon, size: 15),
                        label: Text(
                          actionButtonLabel,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        onPressed: isProcessing
                            ? null
                            : () => _handleSettlementAction(
                                  fromMemberId: s.fromMemberId,
                                  toMemberId: s.toMemberId,
                                  fromName: fromName,
                                  toName: toName,
                                  amountInPaise: s.amountInPaise,
                                  isPayerCurrentUser: isPayerCurrentUser,
                                  isReceiverCurrentUser: isReceiverCurrentUser,
                                ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettledHistoryCard({
    required BuildContext context,
    required bool isDark,
    required Map<String, dynamic> stl,
  }) {
    final fromMemberId = stl['fromMemberId'] as String? ?? '';
    final toMemberId = stl['toMemberId'] as String? ?? '';
    final fromMember = _findMember(fromMemberId);
    final toMember = _findMember(toMemberId);
    final fromName = fromMember?.displayName ?? (stl['fromName'] as String?) ?? 'Member';
    final toName = toMember?.displayName ?? (stl['toName'] as String?) ?? 'Member';
    final amountInPaise = (stl['amountInPaise'] as num?)?.toInt() ?? 0;
    final formattedAmt = CurrencyFormatter.formatPaise(amountInPaise, currencyCode: widget.trip.currencyCode);
    final settledDate = stl['confirmedAt'] ?? stl['settledAt'] ?? stl['createdAt'];
    String dateStr = '';
    if (settledDate != null) {
      try {
        final dt = DateTime.parse(settledDate as String);
        dateStr = ' • ${dt.day}/${dt.month}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A20) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          MemberAvatar(name: fromName, size: 28),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          MemberAvatar(name: toName, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fromName paid $toName',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Settled$dateStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              formattedAmt,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF14B8A6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMarkAllDone() {
    final remainingSettlements = widget.balanceSummary.simplifiedSettlements;
    final totalPendingPaise = remainingSettlements.fold(0, (sum, s) => sum + s.amountInPaise);

    if (totalPendingPaise > 0) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final formattedTotal = CurrencyFormatter.formatPaise(totalPendingPaise, currencyCode: widget.trip.currencyCode);

      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pending Payments Remaining',
                  style: AppTypography.titleMedium(isDark: isDark),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'There is still $formattedTotal pending across members in this trip.\n\nAre you sure you want to mark all remaining bills as settled and complete the trip?',
                style: AppTypography.bodyMedium(isDark: isDark),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(
                'Review Payments',
                style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
              ),
              onPressed: () {
                Navigator.pop(dCtx);
                Navigator.pop(context);
                final tripDetailVm = Provider.of<TripDetailViewModel?>(context, listen: false);
                if (tripDetailVm != null) {
                  tripDetailVm.settleAllRemainingDues(widget.currentUserId);
                  KithSuccessToast.show(context, '🎉 All bills marked as settled & trip completed!');
                } else {
                  widget.onMarkSettled?.call();
                }
              },
              child: const Text('Yes, Settle All & Complete'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
      widget.onMarkSettled?.call();
    }
  }
}
