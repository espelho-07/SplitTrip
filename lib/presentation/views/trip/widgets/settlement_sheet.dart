import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
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
import '../../../../domain/models/balance_summary.dart';
import '../../../../domain/models/trip.dart';
import '../../../../domain/models/trip_member.dart';
import '../../../widgets/progress/progress.dart';

class SettlementSheet extends StatefulWidget {
  final Trip trip;
  final BalanceSummary balanceSummary;
  final String currentUserId;
  final VoidCallback? onMarkSettled;
  final Future<void> Function(String fromMemberId, String toMemberId, int amountInPaise)? onRecordTransfer;

  const SettlementSheet({
    super.key,
    required this.trip,
    required this.balanceSummary,
    required this.currentUserId,
    this.onMarkSettled,
    this.onRecordTransfer,
  });

  @override
  State<SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<SettlementSheet> {
  final Set<String> _processingTransferIds = {};
  final Set<String> _paidTransferKeys = {};

  TripMember? _findMember(String memberId) {
    return widget.trip.members.where((m) => m.id == memberId).firstOrNull;
  }

  Future<void> _confirmAndRecordTransfer(
    String fromMemberId,
    String toMemberId,
    String fromName,
    String toName,
    int amountInPaise,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final formattedAmount = CurrencyFormatter.formatPaise(amountInPaise, currencyCode: widget.trip.currencyCode);

    final shouldRecord = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          borderRadius: AppRadius.topSheetBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.settlementMarkPaidTitle,
              style: AppTypography.titleMedium(isDark: isDark),
            ),
            const SizedBox(height: 16),
            MemberAvatar(name: toName, size: 48),
            const SizedBox(height: 8),
            Text(
              toName,
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
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settlementMarkPaidDesc(toName),
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(isDark: isDark).copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: l10n.actionCancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(bCtx, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: l10n.settlementMarkPaidBtn,
                    variant: AppButtonVariant.primary,
                    onPressed: () => Navigator.pop(bCtx, true),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );

    if (shouldRecord == true && widget.onRecordTransfer != null) {
      final transferKey = fromMemberId + toMemberId;
      if (_processingTransferIds.contains(transferKey)) return; // Debounce guard

      setState(() => _processingTransferIds.add(transferKey));
      HapticHelper.medium();
      try {
        await widget.onRecordTransfer!(fromMemberId, toMemberId, amountInPaise);
        if (mounted) {
          setState(() {
            _paidTransferKeys.add(transferKey);
          });
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settlements = widget.balanceSummary.simplifiedSettlements;

    return Container(
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
                    'Settle Up',
                    style: AppTypography.titleLarge(isDark: isDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fewest payments needed to balance everyone out',
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

          const SizedBox(height: AppSpacing.lg),

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
                      'All Settled Up!',
                      style: AppTypography.titleSmall(isDark: isDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Everyone is paid up. No transfers needed.',
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: settlements.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final s = settlements[index];
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

                  return SurfaceCard(
                    backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // From Member
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
                                          isPayerCurrentUser ? 'You' : fromName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Text('Pays', style: TextStyle(fontSize: 11, color: Colors.grey)),
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

                            // To Member
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          isReceiverCurrentUser ? 'You' : toName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Text('Receives', style: TextStyle(fontSize: 11, color: Colors.grey)),
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

                        // Action Bar: Record payment & deliberate confirmation
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Direct member payment',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),

                            if (canRecord && widget.onRecordTransfer != null) ...[
                              if (isPaid)
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
                                        'Paid',
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
                                  height: 32,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                      foregroundColor: isDark ? Colors.black : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBorder),
                                    ),
                                    icon: isProcessing
                                        ? const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.check_rounded, size: 14),
                                    label: Text(context.l10n.settlementMarkPaidBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    onPressed: isProcessing
                                        ? null
                                        : () => _confirmAndRecordTransfer(
                                              s.fromMemberId,
                                              s.toMemberId,
                                              fromName,
                                              toName,
                                              s.amountInPaise,
                                            ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: AppSpacing.lg),

          if (widget.onMarkSettled != null)
            AppButton(
              text: 'Mark Entire Trip as Settled',
              icon: Icons.check_circle_rounded,
              isFullWidth: true,
              onPressed: () {
                Navigator.pop(context);
                widget.onMarkSettled!();
              },
            ),
        ],
      ),
    );
  }
}
