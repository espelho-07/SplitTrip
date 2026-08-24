import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/currency_display.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../domain/models/balance_summary.dart';
import '../../../../domain/models/trip.dart';
import '../../../../domain/models/trip_member.dart';

class SettlementSheet extends StatelessWidget {
  final Trip trip;
  final BalanceSummary balanceSummary;
  final String currentUserId;
  final VoidCallback? onMarkSettled;

  const SettlementSheet({
    super.key,
    required this.trip,
    required this.balanceSummary,
    required this.currentUserId,
    this.onMarkSettled,
  });

  TripMember? _findMember(String memberId) {
    return trip.members.where((m) => m.id == memberId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settlements = balanceSummary.simplifiedSettlements;

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
                  final fromMember = _findMember(s.fromMemberId);
                  final toMember = _findMember(s.toMemberId);

                  final fromName = fromMember?.displayName ?? 'Member';
                  final toName = toMember?.displayName ?? 'Member';
                  final isPayerCurrentUser = fromMember?.userId == currentUserId;
                  final isReceiverCurrentUser = toMember?.userId == currentUserId;

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
                                  currencyCode: trip.currencyCode,
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

                        // Copy UPI ID action if recipient has a UPI handle or default
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'UPI: ${toName.toLowerCase().replaceAll(' ', '')}@upi',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                final handle = '${toName.toLowerCase().replaceAll(' ', '')}@upi';
                                Clipboard.setData(ClipboardData(text: handle));
                                HapticHelper.success();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied $handle to clipboard!')),
                                );
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 14, color: AppColors.emeraldPrimary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Copy UPI',
                                    style: TextStyle(
                                      color: AppColors.emeraldPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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

          if (onMarkSettled != null)
            AppButton(
              text: 'Mark Entire Trip as Settled',
              icon: Icons.check_circle_rounded,
              isFullWidth: true,
              onPressed: () {
                Navigator.pop(context);
                onMarkSettled!();
              },
            ),
        ],
      ),
    );
  }
}
