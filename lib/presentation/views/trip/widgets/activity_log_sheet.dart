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
                          return _buildLogItem(context, log, isDark);
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

  Widget _buildLogItem(BuildContext context, ActivityLog log, bool isDark) {
    final iconData = _getIconForType(log.type);
    final color = _getColorForType(log.type, isDark);
    final formattedTime = _formatRelativeTime(log.createdAt);

    return InkWell(
      onTap: () => _showActivityDetailSheet(context, log, isDark),
      borderRadius: AppRadius.mdBorder,
      child: SurfaceCard(
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
                  const SizedBox(height: 6),
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
                      const Spacer(),
                      Text(
                        'Details ›',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivityDetailSheet(BuildContext context, ActivityLog log, bool isDark) {
    final iconData = _getIconForType(log.type);
    final color = _getColorForType(log.type, isDark);
    final exactTime = DateFormat('EEEE, MMMM d, yyyy · h:mm:ss a').format(log.createdAt.toLocal());
    final relativeTime = _formatRelativeTime(log.createdAt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            borderRadius: AppRadius.topSheetBorder,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, size: 24, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatTypeTag(log.type),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getEventHeading(log.type),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 14),

              // Description Box
              SurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Text(
                  log.description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Structured Key-Value Details
              _buildDetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Performed by',
                value: log.actorName.isNotEmpty ? log.actorName : 'Trip Member',
                isDark: isDark,
              ),
              const SizedBox(height: 12),

              _buildDetailRow(
                icon: Icons.access_time_rounded,
                label: 'Timestamp',
                value: exactTime,
                subtitle: relativeTime,
                isDark: isDark,
              ),
              const SizedBox(height: 12),

              if (log.metadata.containsKey('amountInPaise'))
                _buildDetailRow(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Amount Involved',
                  value: '₹${((log.metadata['amountInPaise'] as int) / 100).toStringAsFixed(2)}',
                  isDark: isDark,
                  valueColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),

              if (log.metadata.containsKey('expenseId')) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Expense ID',
                  value: log.metadata['expenseId'].toString(),
                  isDark: isDark,
                ),
              ],

              const SizedBox(height: 24),

              AppButton(
                text: 'Done',
                variant: AppButtonVariant.primary,
                isFullWidth: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required bool isDark,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime.toLocal());
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(dateTime.toLocal())}';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime.toLocal());
    }
  }

  String _getEventHeading(String type) {
    switch (type) {
      case 'trip_created':
        return 'Trip Created';
      case 'member_joined':
        return 'Member Joined';
      case 'expense_added':
        return 'Expense Added';
      case 'expense_updated':
        return 'Expense Edited';
      case 'expense_deleted':
        return 'Expense Deleted';
      case 'settlement_recorded':
        return 'Payment Settled';
      case 'lifecycle_updated':
        return 'Status Changed';
      default:
        return 'Trip Event';
    }
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
