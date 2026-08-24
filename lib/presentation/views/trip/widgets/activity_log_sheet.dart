import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../domain/models/activity_log.dart';

class ActivityLogSheet extends StatelessWidget {
  final List<ActivityLog> logs;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const ActivityLogSheet({
    super.key,
    required this.logs,
    this.isLoading = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: AppSpacing.bottomSheetPadding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 22,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip Activity', style: AppTypography.titleLarge(isDark: isDark)),
                    Text('Everything that happened in this trip', style: AppTypography.bodySmall(isDark: isDark)),
                  ],
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: onRefresh,
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No activity logs yet',
                              style: AppTypography.titleMedium(isDark: isDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Trip creation, expenses, edits, and settlements will appear here.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall(isDark: isDark),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return _buildLogItem(log, isDark);
                        },
                      ),
          ),

          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: 'Close',
            variant: AppButtonVariant.secondary,
            isFullWidth: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(ActivityLog log, bool isDark) {
    final iconData = _getIconForType(log.type);
    final color = _getColorForType(log.type, isDark);
    final formattedTime = DateFormat('MMM d, h:mm a').format(log.createdAt.toLocal());

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppRadius.smBorder,
            ),
            child: Icon(iconData, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.description,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatTypeTag(log.type),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'trip_created':
        return Icons.flight_takeoff_rounded;
      case 'member_joined':
        return Icons.person_add_rounded;
      case 'expense_added':
        return Icons.add_shopping_cart_rounded;
      case 'expense_updated':
        return Icons.edit_note_rounded;
      case 'expense_deleted':
        return Icons.delete_outline_rounded;
      case 'settlement_recorded':
        return Icons.handshake_outlined;
      case 'lifecycle_updated':
        return Icons.flag_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getColorForType(String type, bool isDark) {
    switch (type) {
      case 'trip_created':
        return isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
      case 'member_joined':
        return Colors.blueAccent;
      case 'expense_added':
        return isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
      case 'expense_updated':
        return AppColors.amberAccent;
      case 'expense_deleted':
        return isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
      case 'settlement_recorded':
        return Colors.tealAccent;
      case 'lifecycle_updated':
        return Colors.purpleAccent;
      default:
        return isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    }
  }

  String _formatTypeTag(String type) {
    switch (type) {
      case 'trip_created':
        return 'CREATED';
      case 'member_joined':
        return 'MEMBER';
      case 'expense_added':
        return 'EXPENSE';
      case 'expense_updated':
        return 'EDITED';
      case 'expense_deleted':
        return 'DELETED';
      case 'settlement_recorded':
        return 'SETTLED';
      case 'lifecycle_updated':
        return 'STATUS';
      default:
        return 'INFO';
    }
  }
}
