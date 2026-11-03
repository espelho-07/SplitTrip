import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/kith_components.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../viewmodels/admin/admin_dashboard_viewmodel.dart';
import '../widgets/admin_metric_card.dart';

/// Product Health & Privacy-Allowlisted Analytics Section.
class AdminAnalyticsSection extends StatelessWidget {
  const AdminAnalyticsSection({super.key});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Analytics & Cohort Telemetry',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Privacy-first telemetry: zero PII, strict event allowlist, aggregated cohort retention.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                onPressed: () => vm.loadOverviewMetrics(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Explicit Unavailable Banner when Server-Side Aggregation RPC is Pending
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
                      'Server-side analytics aggregation RPC is unavailable. Platform analytics require database migration 20261101000007.',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Active User Engagement Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800 ? 3 : 1;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 2.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  AdminMetricCard(
                    title: 'Daily Active Users (DAU)',
                    value: summary?.dau.toString() ?? '—',
                    subtitle: 'Unique active accounts in past 24h',
                    icon: Icons.calendar_today_rounded,
                  ),
                  AdminMetricCard(
                    title: 'Weekly Active Users (WAU)',
                    value: summary?.wau.toString() ?? '—',
                    subtitle: 'Unique active accounts in past 7 days',
                    icon: Icons.date_range_rounded,
                    iconColor: AppColors.indigoAccent,
                  ),
                  AdminMetricCard(
                    title: 'Monthly Active Users (MAU)',
                    value: summary?.mau.toString() ?? '—',
                    subtitle: 'Unique active accounts in past 30 days',
                    icon: Icons.event_repeat_rounded,
                    iconColor: AppColors.tealAccent,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Retention & Conversion Indicators
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final cards = [
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: KithSurface(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Monthly Cohort Retention',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                            ),
                            PillBadge(label: 'WAU / MAU', color: AppColors.emeraldPrimary),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          summary != null ? '${(summary.retentionRate * 100).toStringAsFixed(1)}%' : '—',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Calculated as weekly active ratio over monthly active cohort.',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isWide ? AppSpacing.md : 0, height: isWide ? 0 : AppSpacing.md),
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: KithSurface(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Guest-to-OAuth Conversion',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                            ),
                            PillBadge(label: 'Conversion', color: AppColors.indigoAccent),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          summary != null
                              ? '${(summary.guestToRegisteredConversionRate * 100).toStringAsFixed(1)}%'
                              : '—',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Percentage of accounts linking verified Google identity.',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];

              return isWide ? Row(children: cards) : Column(children: cards);
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Privacy Allowlist Notice Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              borderRadius: AppRadius.mdBorder,
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 18, color: AppColors.emeraldLight),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Privacy & Audit Guarantee',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'KITH strictly audits analytics ingestion. Disallowed payload keys (passwords, tokens, recovery keys, personal contacts, financial amounts) are stripped before storage.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
