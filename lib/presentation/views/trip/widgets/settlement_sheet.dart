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
import '../../../../core/utils/whatsapp_share_helper.dart';
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
  final Set<String> _expandedMemberIds = {};
  late PaymentService _paymentService;
  bool _showEveryone = false;

  @override
  void initState() {
    super.initState();
    PaymentService? providerService;
    try {
      providerService = context.read<PaymentService>();
    } catch (_) {}
    _paymentService = widget.paymentService ?? providerService ?? PaymentService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final curMember = _getCurrentMember();
      if (curMember != null && mounted) {
        setState(() {
          _expandedMemberIds.add(curMember.id);
        });
      } else if (widget.trip.members.isNotEmpty && mounted) {
        setState(() {
          _expandedMemberIds.add(widget.trip.members.first.id);
        });
      }
    });
  }

  TripMember? _findMember(String memberId) {
    return widget.trip.members.where((m) => m.id == memberId).firstOrNull;
  }

  String get _effectiveCurrentUserId {
    if (widget.currentUserId.isNotEmpty) return widget.currentUserId;
    try {
      final storage = context.read<LocalStorageService>();
      final u = storage.getSavedUser();
      if (u != null && u['id'] != null) return u['id'].toString();
    } catch (_) {}
    return widget.trip.creatorId;
  }

  TripMember? _getCurrentMember() {
    final curUid = _effectiveCurrentUserId;
    return widget.trip.members.where((m) => m.userId == curUid || m.id == curUid).firstOrNull;
  }

  bool _isMySettlement(dynamic s) {
    final curMember = _getCurrentMember();
    final curUid = _effectiveCurrentUserId;
    final fromMember = _findMember(s.fromMemberId);
    final toMember = _findMember(s.toMemberId);

    final isPayer = (curMember != null && s.fromMemberId == curMember.id) ||
        (fromMember?.userId != null && fromMember!.userId == curUid) ||
        (s.fromMemberId == curUid);

    final isReceiver = (curMember != null && s.toMemberId == curMember.id) ||
        (toMember?.userId != null && toMember!.userId == curUid) ||
        (s.toMemberId == curUid);

    return isPayer || isReceiver;
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1418) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
            ),
          ),
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

  void _showDetailedHisabModal({
    required BuildContext context,
    required bool isDark,
    required TripMember? memberA,
    required TripMember? memberB,
    required String fromMemberId,
    required String toMemberId,
    required int settlementAmountInPaise,
  }) {
    final fromName = memberA?.displayName ?? 'Member';
    final toName = memberB?.displayName ?? 'Member';
    final expenseRepo = context.read<ExpenseRepository>();
    final allExpenses = expenseRepo.getCachedExpenses(widget.trip.id);
    final cachedSettlements = expenseRepo.getCachedSettlements(widget.trip.id);

    // 1. Items where memberA paid and memberB participated
    final aPaidItems = <Map<String, dynamic>>[];
    // 2. Items where memberB paid and memberA participated
    final bPaidItems = <Map<String, dynamic>>[];
    // 3. Shared group expenses where someone else paid
    final sharedGroupItems = <Map<String, dynamic>>[];

    int totalAPaidForB = 0;
    int totalBPaidForA = 0;

    for (final exp in allExpenses) {
      if (exp.isDeleted) continue;
      final aSplit = exp.splits.where((s) => s.memberId == fromMemberId).firstOrNull;
      final bSplit = exp.splits.where((s) => s.memberId == toMemberId).firstOrNull;

      if (exp.paidById == fromMemberId && bSplit != null) {
        totalAPaidForB += bSplit.amountInPaise;
        aPaidItems.add({
          'title': exp.title,
          'date': exp.createdAt,
          'totalAmount': exp.amountInPaise,
          'shareAmount': bSplit.amountInPaise,
          'category': exp.category,
          'payerName': fromName,
          'debtorName': toName,
        });
      } else if (exp.paidById == toMemberId && aSplit != null) {
        totalBPaidForA += aSplit.amountInPaise;
        bPaidItems.add({
          'title': exp.title,
          'date': exp.createdAt,
          'totalAmount': exp.amountInPaise,
          'shareAmount': aSplit.amountInPaise,
          'category': exp.category,
          'payerName': toName,
          'debtorName': fromName,
        });
      } else if (aSplit != null && bSplit != null) {
        final payer = _findMember(exp.paidById);
        sharedGroupItems.add({
          'title': exp.title,
          'date': exp.createdAt,
          'totalAmount': exp.amountInPaise,
          'aShare': aSplit.amountInPaise,
          'bShare': bSplit.amountInPaise,
          'payerName': payer?.displayName ?? 'Group Member',
          'category': exp.category,
        });
      }
    }

    // Previous direct payments
    final directSettlements = cachedSettlements.where((cs) {
      final matches = (cs['fromMemberId'] == fromMemberId && cs['toMemberId'] == toMemberId) ||
          (cs['fromMemberId'] == toMemberId && cs['toMemberId'] == fromMemberId);
      final isSettled = cs['isSettled'] as bool? ?? false;
      final st = cs['status'] as String?;
      return matches && (isSettled || st == 'paid' || st == 'confirmed' || st == 'completed');
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1418) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF14B8A6)),
                            const SizedBox(width: 8),
                            Text(
                              'Detailed Hisab',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Breakdown between $fromName and $toName',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(modalCtx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Settlement Amount Highlight
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$fromName pays $toName',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatPaise(settlementAmountInPaise, currencyCode: widget.trip.currencyCode),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    if (aPaidItems.isEmpty && bPaidItems.isEmpty && directSettlements.isEmpty && sharedGroupItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text(
                            'No direct transactions recorded between $fromName and $toName.\nDebts are simplified across group expenses.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),

                    // Section A: Where fromName paid and toName shared
                    if (aPaidItems.isNotEmpty) ...[
                      Text(
                        '$fromName paid ($toName owes share)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF14B8A6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in aPaidItems)
                        _buildHisabItemRow(
                          isDark: isDark,
                          title: item['title'] as String,
                          subtitle: '$fromName paid ${CurrencyFormatter.formatPaise(item['totalAmount'] as int, currencyCode: widget.trip.currencyCode)}',
                          shareText: '+${CurrencyFormatter.formatPaise(item['shareAmount'] as int, currencyCode: widget.trip.currencyCode)}',
                          isPositive: true,
                        ),
                      const SizedBox(height: 14),
                    ],

                    // Section B: Where toName paid and fromName shared
                    if (bPaidItems.isNotEmpty) ...[
                      Text(
                        '$toName paid ($fromName owes share)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in bPaidItems)
                        _buildHisabItemRow(
                          isDark: isDark,
                          title: item['title'] as String,
                          subtitle: '$toName paid ${CurrencyFormatter.formatPaise(item['totalAmount'] as int, currencyCode: widget.trip.currencyCode)}',
                          shareText: '-${CurrencyFormatter.formatPaise(item['shareAmount'] as int, currencyCode: widget.trip.currencyCode)}',
                          isPositive: false,
                        ),
                      const SizedBox(height: 14),
                    ],

                    // Section C: Direct Payments Made Prior
                    if (directSettlements.isNotEmpty) ...[
                      const Text(
                        'Past Settlements Cleared',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final cs in directSettlements)
                        _buildHisabItemRow(
                          isDark: isDark,
                          title: 'Direct Transfer',
                          subtitle: cs['fromMemberId'] == fromMemberId ? '$fromName paid $toName' : '$toName paid $fromName',
                          shareText: CurrencyFormatter.formatPaise((cs['amountInPaise'] as num).toInt(), currencyCode: widget.trip.currencyCode),
                          isPositive: cs['fromMemberId'] == fromMemberId,
                        ),
                      const SizedBox(height: 14),
                    ],

                    // Section D: Group Shared Expenses
                    if (sharedGroupItems.isNotEmpty) ...[
                      Text(
                        'Shared Group Expenses (${sharedGroupItems.length})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Group expenses where both participated and debts were algorithmically minimized:',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in sharedGroupItems)
                        _buildHisabItemRow(
                          isDark: isDark,
                          title: item['title'] as String,
                          subtitle: '${item['payerName']} paid • $fromName: ${CurrencyFormatter.formatPaise(item['aShare'] as int, currencyCode: widget.trip.currencyCode)} • $toName: ${CurrencyFormatter.formatPaise(item['bShare'] as int, currencyCode: widget.trip.currencyCode)}',
                          shareText: 'Shared',
                          isPositive: true,
                          neutralTag: true,
                        ),
                      const SizedBox(height: 14),
                    ],

                    // Summary math breakdown card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131A20) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Summary Reconciliation',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$fromName paid for $toName:', style: const TextStyle(fontSize: 12)),
                              Text(CurrencyFormatter.formatPaise(totalAPaidForB, currencyCode: widget.trip.currencyCode), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$toName paid for $fromName:', style: const TextStyle(fontSize: 12)),
                              Text(CurrencyFormatter.formatPaise(totalBPaidForA, currencyCode: widget.trip.currencyCode), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Final Settlement Amount:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              Text(
                                CurrencyFormatter.formatPaise(settlementAmountInPaise, currencyCode: widget.trip.currencyCode),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF14B8A6)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHisabItemRow({
    required bool isDark,
    required String title,
    required String subtitle,
    required String shareText,
    required bool isPositive,
    bool neutralTag = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: neutralTag
                  ? (isDark ? Colors.white12 : Colors.black12)
                  : (isPositive
                      ? const Color(0xFF14B8A6).withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              shareText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: neutralTag
                    ? (isDark ? Colors.white70 : Colors.black87)
                    : (isPositive ? const Color(0xFF14B8A6) : Colors.orange.shade800),
              ),
            ),
          ),
        ],
      ),
    );
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

    // 1. Filter settlements involving current user
    final mySettlements = settlements.where((s) => _isMySettlement(s)).toList();

    // 2. Compute current user's total net balance
    int myTotalYouOwe = 0;
    int myTotalYouAreOwed = 0;
    final curMember = _getCurrentMember();
    final curUid = _effectiveCurrentUserId;

    for (final s in settlements) {
      final fromMember = _findMember(s.fromMemberId);
      final toMember = _findMember(s.toMemberId);
      final isPayer = (curMember != null && s.fromMemberId == curMember.id) ||
          (fromMember?.userId != null && fromMember!.userId == curUid) ||
          (s.fromMemberId == curUid);
      final isReceiver = (curMember != null && s.toMemberId == curMember.id) ||
          (toMember?.userId != null && toMember!.userId == curUid) ||
          (s.toMemberId == curUid);

      if (isPayer) {
        myTotalYouOwe += s.amountInPaise;
      } else if (isReceiver) {
        myTotalYouAreOwed += s.amountInPaise;
      }
    }
    final myNetBalance = myTotalYouAreOwed - myTotalYouOwe;

    // Active settlements to display based on toggle
    final displayedSettlements = _showEveryone ? settlements : mySettlements;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
          // Header with safe Expanded
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settlementTitle,
                      style: AppTypography.titleLarge(isDark: isDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.settlementSubtitle,
                      style: AppTypography.bodySmall(isDark: isDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              children: [
                // User Net Balance Summary Hero Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: myNetBalance > 0
                          ? [const Color(0xFF0D9488), const Color(0xFF14B8A6)]
                          : myNetBalance < 0
                              ? [const Color(0xFFB91C1C), const Color(0xFFEF4444)]
                              : (isDark
                                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                  : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)]),
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          myNetBalance > 0
                              ? Icons.arrow_downward_rounded
                              : myNetBalance < 0
                                  ? Icons.arrow_upward_rounded
                                  : Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              myNetBalance > 0
                                  ? 'Total you will receive'
                                  : myNetBalance < 0
                                      ? 'Total you owe'
                                      : 'All settled up',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              myNetBalance != 0
                                  ? CurrencyFormatter.formatPaise(myNetBalance.abs(), currencyCode: widget.trip.currencyCode)
                                  : 'Zero outstanding dues 🎉',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Segmented Toggle Tabs: [ My Dues ] | [ View Everyone ]
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticHelper.selection();
                            setState(() => _showEveryone = false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_showEveryone
                                  ? (isDark ? const Color(0xFF222C36) : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !_showEveryone
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'My Dues (${mySettlements.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: !_showEveryone ? FontWeight.w700 : FontWeight.w500,
                                color: !_showEveryone
                                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                    : (isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticHelper.selection();
                            setState(() => _showEveryone = true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _showEveryone
                                  ? (isDark ? const Color(0xFF222C36) : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _showEveryone
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'View Everyone (${settlements.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _showEveryone ? FontWeight.w700 : FontWeight.w500,
                                color: _showEveryone
                                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                    : (isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                // SECTION 1: Active Dues & Debts
                if (displayedSettlements.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 44,
                            color: AppColors.positiveGreenLight,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            !_showEveryone
                                ? 'You have no pending dues!'
                                : l10n.settlementEmptyTitle,
                            style: AppTypography.titleSmall(isDark: isDark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            !_showEveryone
                                ? 'All your shared expenses are settled.'
                                : l10n.settlementEmptyDesc,
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_showEveryone) ...[
                  _buildEveryoneMemberCollapsibleList(
                    context: context,
                    isDark: isDark,
                    allSettlements: settlements,
                    cachedSettlements: cachedSettlements,
                  ),
                ] else ...[
                  for (int index = 0; index < displayedSettlements.length; index++) ...[
                    _buildActiveSettlementCard(
                      context: context,
                      isDark: isDark,
                      s: displayedSettlements[index],
                      cachedSettlements: cachedSettlements,
                    ),
                    if (index < displayedSettlements.length - 1) const SizedBox(height: AppSpacing.md),
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

          // Bottom spacer for comfortable scroll
          const SizedBox(height: 8),
        ],
      ),
    );
  }


  Widget _buildEveryoneMemberCollapsibleList({
    required BuildContext context,
    required bool isDark,
    required List<dynamic> allSettlements,
    required List<Map<String, dynamic>> cachedSettlements,
  }) {
    final curMember = _getCurrentMember();
    final curUid = _effectiveCurrentUserId;

    // Sort members so Current User is always first, followed by others sorted by name
    final sortedMembers = List<TripMember>.from(widget.trip.members)
      ..sort((a, b) {
        final aIsMe = (curMember != null && a.id == curMember.id) || a.userId == curUid;
        final bIsMe = (curMember != null && b.id == curMember.id) || b.userId == curUid;
        if (aIsMe) return -1;
        if (bIsMe) return 1;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

    return Column(
      children: [
        for (int i = 0; i < sortedMembers.length; i++) ...[
          _buildMemberCollapsibleCard(
            context: context,
            isDark: isDark,
            member: sortedMembers[i],
            allSettlements: allSettlements,
            cachedSettlements: cachedSettlements,
          ),
          if (i < sortedMembers.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildMemberCollapsibleCard({
    required BuildContext context,
    required bool isDark,
    required TripMember member,
    required List<dynamic> allSettlements,
    required List<Map<String, dynamic>> cachedSettlements,
  }) {
    final l10n = context.l10n;
    final curMember = _getCurrentMember();
    final curUid = _effectiveCurrentUserId;
    final isMe = (curMember != null && member.id == curMember.id) || member.userId == curUid;

    // Outgoing dues (member needs to pay someone)
    final toPay = allSettlements.where((s) {
      final f = _findMember(s.fromMemberId);
      return s.fromMemberId == member.id || (f != null && f.userId == member.userId && member.userId.isNotEmpty);
    }).toList();

    // Incoming dues (someone needs to pay member)
    final toReceive = allSettlements.where((s) {
      final t = _findMember(s.toMemberId);
      return s.toMemberId == member.id || (t != null && t.userId == member.userId && member.userId.isNotEmpty);
    }).toList();

    int totalOutgoingPaise = 0;
    for (final s in toPay) {
      totalOutgoingPaise += (s.amountInPaise as int);
    }
    int totalIncomingPaise = 0;
    for (final s in toReceive) {
      totalIncomingPaise += (s.amountInPaise as int);
    }

    final netInPaise = totalIncomingPaise - totalOutgoingPaise;
    final isExpanded = _expandedMemberIds.contains(member.id);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.6 : 0.45)
              : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          width: isMe ? 1.4 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header: Tap to toggle expand/collapse
            InkWell(
              onTap: () {
                HapticHelper.light();
                setState(() {
                  if (isExpanded) {
                    _expandedMemberIds.remove(member.id);
                  } else {
                    _expandedMemberIds.add(member.id);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    MemberAvatar(
                      name: member.displayName,
                      avatarUrl: member.avatarUrl,
                      size: 38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member.displayName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l10n.translate('balance_you'),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.emeraldPrimary,
                                    ),
                                  ),
                                ),
                              ],
                              if (member.isVirtual) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF64748B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'VIRTUAL',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            toPay.isEmpty && toReceive.isEmpty
                                ? 'All settled • ₹0 dues'
                                : (netInPaise > 0
                                    ? 'Gets back ${CurrencyFormatter.formatPaise(netInPaise, currencyCode: widget.trip.currencyCode)} • ${toReceive.length} incoming'
                                    : (netInPaise < 0
                                        ? 'Owes ${CurrencyFormatter.formatPaise(netInPaise.abs(), currencyCode: widget.trip.currencyCode)} • ${toPay.length} outgoing'
                                        : '${toPay.length} to pay • ${toReceive.length} to receive')),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Net balance pill badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: toPay.isEmpty && toReceive.isEmpty
                            ? (isDark ? const Color(0xFF13221C) : const Color(0xFFECFDF5))
                            : (netInPaise > 0
                                ? (isDark ? const Color(0xFF13221C) : const Color(0xFFECFDF5))
                                : (netInPaise < 0
                                    ? (isDark ? const Color(0xFF281414) : const Color(0xFFFEF2F2))
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)))),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: toPay.isEmpty && toReceive.isEmpty
                              ? AppColors.emeraldPrimary.withValues(alpha: 0.3)
                              : (netInPaise > 0
                                  ? AppColors.positiveGreenLight.withValues(alpha: 0.4)
                                  : (netInPaise < 0
                                      ? AppColors.negativeRedLight.withValues(alpha: 0.4)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)))),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        toPay.isEmpty && toReceive.isEmpty
                            ? 'Settled'
                            : (netInPaise > 0
                                ? '+${CurrencyFormatter.formatPaise(netInPaise, currencyCode: widget.trip.currencyCode)}'
                                : (netInPaise < 0
                                    ? '-${CurrencyFormatter.formatPaise(netInPaise.abs(), currencyCode: widget.trip.currencyCode)}'
                                    : '₹0')),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: toPay.isEmpty && toReceive.isEmpty
                              ? AppColors.emeraldPrimary
                              : (netInPaise > 0
                                  ? AppColors.positiveGreenLight
                                  : (netInPaise < 0
                                      ? AppColors.negativeRedLight
                                      : (isDark ? Colors.white70 : const Color(0xFF475569)))),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded content: Outgoing & Incoming breakdowns with "View in detail" button
            if (isExpanded) ...[
              const Divider(height: 1, thickness: 0.8),
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (toPay.isEmpty && toReceive.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.positiveGreenLight),
                            const SizedBox(width: 8),
                            Text(
                              '${member.displayName} has settled all expenses!',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // SECTION: OWES / TO PAY
                    if (toPay.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 13,
                            decoration: BoxDecoration(
                              color: AppColors.negativeRedLight,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'OWES / TO PAY (${toPay.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.negativeRedLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final s in toPay) ...[
                        _buildMemberSubTransferCard(
                          context: context,
                          isDark: isDark,
                          s: s,
                          member: member,
                          isOutgoing: true,
                          cachedSettlements: cachedSettlements,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],

                    // SECTION: WILL RECEIVE / IS OWED
                    if (toReceive.isNotEmpty) ...[
                      if (toPay.isNotEmpty) const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 13,
                            decoration: BoxDecoration(
                              color: AppColors.positiveGreenLight,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'WILL RECEIVE / IS OWED (${toReceive.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.positiveGreenLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final s in toReceive) ...[
                        _buildMemberSubTransferCard(
                          context: context,
                          isDark: isDark,
                          s: s,
                          member: member,
                          isOutgoing: false,
                          cachedSettlements: cachedSettlements,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberSubTransferCard({
    required BuildContext context,
    required bool isDark,
    required dynamic s,
    required TripMember member,
    required bool isOutgoing,
    required List<Map<String, dynamic>> cachedSettlements,
  }) {
    final fromMember = _findMember(s.fromMemberId);
    final toMember = _findMember(s.toMemberId);
    final fromName = fromMember?.displayName ?? 'Member';
    final toName = toMember?.displayName ?? 'Member';
    final curMember = _getCurrentMember();
    final curUid = _effectiveCurrentUserId;

    final isPayerCurrentUser = (fromMember?.userId == curUid) || (s.fromMemberId == curMember?.id) || (s.fromMemberId == curUid);
    final isReceiverCurrentUser = (toMember?.userId == curUid) || (s.toMemberId == curMember?.id) || (s.toMemberId == curUid);
    final isTripCreator = widget.trip.creatorId == widget.currentUserId;
    final canRecord = isPayerCurrentUser || isReceiverCurrentUser || isTripCreator;
    final transferKey = s.fromMemberId + s.toMemberId;
    final isProcessing = _processingTransferIds.contains(transferKey);
    final isPaid = _paidTransferKeys.contains(transferKey);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C24) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF23303E) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isOutgoing ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
                      size: 16,
                      color: isOutgoing ? AppColors.negativeRedLight : AppColors.positiveGreenLight,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isOutgoing ? 'Pays $toName' : 'Receives from $fromName',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatPaise(s.amountInPaise, currencyCode: widget.trip.currencyCode),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isOutgoing ? AppColors.negativeRedLight : AppColors.positiveGreenLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Action bar: "View in detail" button + Payment / Receipt Action
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // "View in detail" button
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showDetailedHisabModal(
                  context: context,
                  isDark: isDark,
                  memberA: fromMember,
                  memberB: toMember,
                  fromMemberId: s.fromMemberId,
                  toMemberId: s.toMemberId,
                  settlementAmountInPaise: s.amountInPaise,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF14B8A6)),
                      SizedBox(width: 5),
                      Text(
                        'View in detail',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF14B8A6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (canRecord && widget.onRecordTransfer != null && !isPaid) ...[
                if (isPayerCurrentUser && toMember?.upiId != null) ...[
                  FilledButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _handleSettlementAction(
                              fromMemberId: s.fromMemberId,
                              toMemberId: s.toMemberId,
                              fromName: fromName,
                              toName: toName,
                              amountInPaise: s.amountInPaise,
                              isPayerCurrentUser: true,
                              isReceiverCurrentUser: false,
                            ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 32),
                      backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.fullBorder),
                    ),
                    icon: isProcessing
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.flash_on_rounded, size: 13),
                    label: const Text('Pay via UPI', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ] else ...[
                  OutlinedButton.icon(
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
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                      ),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.fullBorder),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 13),
                    label: Text(
                      isReceiverCurrentUser
                          ? 'Mark Received'
                          : (isPayerCurrentUser ? 'Mark Paid' : 'Record Payment'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ],
            ],
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
    final curMember = _getCurrentMember();
    final curUid = _effectiveCurrentUserId;
    final isPayerCurrentUser = (fromMember?.userId == curUid) || (s.fromMemberId == curMember?.id) || (s.fromMemberId == curUid);
    final isReceiverCurrentUser = (toMember?.userId == curUid) || (s.toMemberId == curMember?.id) || (s.toMemberId == curUid);
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // From Member (Payer)
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    MemberAvatar(name: fromName, size: 34),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isPayerCurrentUser ? l10n.translate('balance_you') : fromName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l10n.settlementPaysLabel,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow & Amount
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.emeraldPrimary),
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
              Expanded(
                flex: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isReceiverCurrentUser ? l10n.translate('balance_you') : toName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l10n.settlementReceivesLabel,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
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
            if (toMember?.upiId != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.settlementUpiReadyTag(toMember!.upiId!),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // "View in detail" button
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showDetailedHisabModal(
                    context: context,
                    isDark: isDark,
                    memberA: fromMember,
                    memberB: toMember,
                    fromMemberId: s.fromMemberId,
                    toMemberId: s.toMemberId,
                    settlementAmountInPaise: s.amountInPaise,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF14B8A6)),
                        SizedBox(width: 5),
                        Text(
                          'View in detail',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF14B8A6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (!isPaid && !isAlreadySettledInCache)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      final formattedAmt = CurrencyFormatter.formatPaise(s.amountInPaise, currencyCode: widget.trip.currencyCode);
                      final reminderText = 'Hey $fromName! Just a friendly reminder for our trip "${widget.trip.name}" on Kith: your share of $formattedAmt is pending settlement with $toName. Let me know when settled!';
                      WhatsAppShareHelper.sendWhatsAppMessage(
                        context: context,
                        text: reminderText,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF25D366).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share_rounded, size: 14, color: Color(0xFF25D366)),
                          SizedBox(width: 5),
                          Text(
                            'Remind',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ],
                      ),
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
                          shape: const RoundedRectangleBorder(borderRadius: AppRadius.fullBorder),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
}
