import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
import '../../../viewmodels/trip_detail_viewmodel.dart';

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
  final Set<String> _settledTransferKeys = {};

  TripMember? _findMember(Trip activeTrip, String memberId) {
    return activeTrip.members.where((m) => m.id == memberId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Reactively watch TripDetailViewModel for live balance recalculations
    TripDetailViewModel? tripDetailVm;
    try {
      tripDetailVm = context.watch<TripDetailViewModel?>();
    } catch (_) {}

    final activeTrip = tripDetailVm?.trip ?? widget.trip;
    final activeSummary = tripDetailVm?.balanceSummary ?? widget.balanceSummary;
    final settlements = activeSummary.simplifiedSettlements.where((s) {
      return !_settledTransferKeys.contains(s.fromMemberId + s.toMemberId);
    }).toList();

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simplified Settlement',
                      style: AppTypography.titleLarge(isDark: isDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Min-cash-flow algorithm reduced debts to ${settlements.length} direct transfers',
                      style: AppTypography.bodySmall(isDark: isDark),
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
                      'All Balances are Even!',
                      style: AppTypography.titleSmall(isDark: isDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No pending settlement payments required.',
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
                  final fromMember = _findMember(activeTrip, s.fromMemberId);
                  final toMember = _findMember(activeTrip, s.toMemberId);

                  final fromName = fromMember?.displayName ?? 'Member';
                  final toName = toMember?.displayName ?? 'Member';
                  final isPayerCurrentUser = fromMember?.userId == widget.currentUserId;
                  final isReceiverCurrentUser = toMember?.userId == widget.currentUserId;
                  final isTripCreator = activeTrip.creatorId == widget.currentUserId;
                  final canRecord = isPayerCurrentUser || isReceiverCurrentUser || isTripCreator;
                  final isProcessing = _processingTransferIds.contains(s.fromMemberId + s.toMemberId);

                  return SurfaceCard(
                    backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // From Member
                            Row(
                              children: [
                                MemberAvatar(name: fromName, size: 34),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPayerCurrentUser ? 'You' : fromName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    const Text('Pays', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),

                            // Arrow & Amount
                            Column(
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

                            // To Member
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      isReceiverCurrentUser ? 'You' : toName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    const Text('Receives', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                MemberAvatar(name: toName, size: 34),
                              ],
                            ),
                          ],
                        ),

                        // Action Bar: Record payment & UPI Copy
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () {
                                final handle = '${toName.toLowerCase().replaceAll(' ', '')}@upi';
                                Clipboard.setData(ClipboardData(text: handle));
                                HapticHelper.success();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied $handle to clipboard!')),
                                );
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.copy_rounded, size: 13, color: AppColors.emeraldPrimary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'UPI: ${toName.toLowerCase().replaceAll(' ', '')}@upi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (canRecord && widget.onRecordTransfer != null)
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
                                  label: const Text('Mark Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  onPressed: isProcessing
                                      ? null
                                      : () async {
                                          final transferKey = s.fromMemberId + s.toMemberId;
                                          setState(() => _processingTransferIds.add(transferKey));
                                          HapticHelper.medium();
                                          try {
                                            if (widget.onRecordTransfer != null) {
                                              await widget.onRecordTransfer!(
                                                s.fromMemberId,
                                                s.toMemberId,
                                                s.amountInPaise,
                                              );
                                            }
                                            if (mounted) {
                                              setState(() {
                                                _settledTransferKeys.add(transferKey);
                                              });
                                              HapticHelper.success();
                                              ScaffoldMessenger.of(this.context).showSnackBar(
                                                SnackBar(
                                                  behavior: SnackBarBehavior.floating,
                                                  duration: const Duration(seconds: 2),
                                                  content: Text('Payment of ${CurrencyFormatter.formatPaise(s.amountInPaise, currencyCode: activeTrip.currencyCode)} marked as paid!'),
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() => _processingTransferIds.remove(transferKey));
                                            }
                                          }
                                        },
                                ),
                              ),
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
