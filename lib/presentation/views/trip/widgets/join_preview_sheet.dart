import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/kith_brand.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../domain/models/trip_preview.dart';

/// Master Trip Invitation Preview Sheet
class JoinPreviewSheet extends StatelessWidget {
  final TripPreview preview;
  final bool isJoining;
  final VoidCallback onConfirmJoin;
  final VoidCallback onCancel;

  const JoinPreviewSheet({
    super.key,
    required this.preview,
    required this.isJoining,
    required this.onConfirmJoin,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header Tag
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KithLogoMark(size: 14, isDark: isDark),
                const SizedBox(width: 6),
                Text(
                  l10n.joinPreviewTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppColors.emeraldLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Hero Trip Preview Card with Gradient
          Container(
            padding: const EdgeInsets.all(18.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF042F2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    preview.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  preview.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.joinPreviewHost} ${preview.creatorName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Info Breakdown Grid
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  icon: Icons.people_alt_rounded,
                  label: l10n.joinPreviewMembers,
                  value: '${preview.memberCount}',
                  isDark: isDark,
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
                _buildInfoItem(
                  icon: Icons.payments_rounded,
                  label: l10n.joinPreviewCurrency,
                  value: preview.currencyCode,
                  isDark: isDark,
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
                _buildInfoItem(
                  icon: Icons.vpn_key_rounded,
                  label: 'Code',
                  value: preview.inviteCode,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Action Deck
          GestureDetector(
            onTap: isJoining
                ? null
                : () {
                    HapticHelper.medium();
                    onConfirmJoin();
                  },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emeraldLight.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: isJoining
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          l10n.joinPreviewConfirm,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 10),

          TextButton(
            onPressed: () {
              HapticHelper.light();
              onCancel();
            },
            child: Text(
              l10n.joinPreviewCancel,
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.emeraldLight),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }
}
