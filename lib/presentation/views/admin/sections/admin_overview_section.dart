import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/kith_components.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../viewmodels/admin/admin_dashboard_viewmodel.dart';
import '../widgets/admin_metric_card.dart';

/// Overview Section of the Admin Control Center showing platform KPIs, trends, and health signals.
class AdminOverviewSection extends StatelessWidget {
  const AdminOverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminDashboardViewModel>();
    final summary = vm.summary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Refresh Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Executive Platform Overview',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Real-time metrics, active user cohorts, and system activity telemetry.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: vm.isLoading ? null : () => vm.loadOverviewMetrics(),
                tooltip: 'Refresh Metrics',
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Pending Migration Banner (if backend tables not yet deployed)
          if (vm.isBackendUnavailable)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.amberAccent.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: AppRadius.mdBorder,
                border: Border.all(color: AppColors.amberAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.amberAccent, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Admin Control Center migration (20261101000007) is pending execution on staging. Metrics are operating in fail-closed safe mode.',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Primary KPI Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900
                  ? 4
                  : (constraints.maxWidth > 600 ? 2 : 1);
              final childAspectRatio = constraints.maxWidth > 900 ? 1.6 : 2.0;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: childAspectRatio,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  AdminMetricCard(
                    title: 'Total Accounts',
                    value: summary?.totalUsers.toString() ?? '—',
                    subtitle: '${summary?.registeredUsers ?? 0} registered • ${summary?.guestUsers ?? 0} guest',
                    icon: Icons.people_outline_rounded,
                    isLoading: vm.isLoading && summary == null,
                    onTap: () => vm.setSection(AdminSection.users),
                  ),
                  AdminMetricCard(
                    title: 'Daily Active (DAU)',
                    value: summary?.dau.toString() ?? '—',
                    subtitle: 'WAU: ${summary?.wau ?? 0} • MAU: ${summary?.mau ?? 0}',
                    icon: Icons.bolt_rounded,
                    iconColor: AppColors.emeraldLight,
                    isLoading: vm.isLoading && summary == null,
                    onTap: () => vm.setSection(AdminSection.analytics),
                  ),
                  AdminMetricCard(
                    title: 'Guest Conversion',
                    value: summary != null ? '${(summary.guestToRegisteredConversionRate * 100).toStringAsFixed(1)}%' : '—',
                    subtitle: 'Guest users converted to Google accounts',
                    icon: Icons.sync_alt_rounded,
                    iconColor: AppColors.indigoAccent,
                    isLoading: vm.isLoading && summary == null,
                  ),
                  AdminMetricCard(
                    title: 'Suspended Accounts',
                    value: summary?.suspendedUsers.toString() ?? '0',
                    subtitle: 'Safely locked from platform access',
                    icon: Icons.block_flipped,
                    iconColor: AppColors.negativeRedDark,
                    isLoading: vm.isLoading && summary == null,
                    onTap: () => vm.setSection(AdminSection.users),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Platform & System Health Distribution
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final cards = [
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: KithSurface(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Platform Distribution',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const PillBadge(label: 'Telemetry', color: AppColors.emeraldPrimary),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildPlatformRow(
                          'Android Hardware',
                          summary?.platformDistribution['android'] ?? 0,
                          summary?.totalUsers ?? 1,
                          Icons.android_rounded,
                          AppColors.emeraldLight,
                          isDark,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildPlatformRow(
                          'iOS Native',
                          summary?.platformDistribution['ios'] ?? 0,
                          summary?.totalUsers ?? 1,
                          Icons.apple_rounded,
                          AppColors.indigoAccent,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isWide ? AppSpacing.md : 0, height: isWide ? 0 : AppSpacing.md),
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: KithSurface(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Operational Quick Actions',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const PillBadge(label: 'Console', color: AppColors.indigoAccent),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            KithButton(
                              label: 'Manage Users',
                              icon: Icons.people_outline_rounded,
                              variant: KithButtonVariant.secondary,
                              onPressed: () => vm.setSection(AdminSection.users),
                            ),
                            KithButton(
                              label: 'Feedback Inbox',
                              icon: Icons.inbox_outlined,
                              variant: KithButtonVariant.secondary,
                              onPressed: () => vm.setSection(AdminSection.feedback),
                            ),
                            KithButton(
                              label: 'New Announcement',
                              icon: Icons.campaign_outlined,
                              variant: KithButtonVariant.secondary,
                              onPressed: () => vm.setSection(AdminSection.announcements),
                            ),
                            KithButton(
                              label: 'Audit Ledger',
                              icon: Icons.security_outlined,
                              variant: KithButtonVariant.secondary,
                              onPressed: () => vm.setSection(AdminSection.auditLogs),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ];

              return isWide ? Row(children: cards) : Column(children: cards);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformRow(
    String label,
    int count,
    int total,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '$count accounts (${(pct * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: AppRadius.fullBorder,
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
