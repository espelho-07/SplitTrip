import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/kith_components.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../../domain/models/admin/admin_models.dart';
import '../../../viewmodels/admin/admin_dashboard_viewmodel.dart';

/// Admin Settings & Security Posture Section.
class AdminSettingsSection extends StatelessWidget {
  const AdminSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminDashboardViewModel>();
    final admin = vm.currentAdmin;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administrative Security & Session Settings',
            style: TextStyle(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Active session security credentials, role boundaries, and platform health status.',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Admin Profile Card
          if (admin != null)
            KithSurface(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                    child: Text(
                      admin.displayName.isNotEmpty ? admin.displayName[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              admin.displayName,
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            PillBadge(label: admin.role.label, color: AppColors.emeraldPrimary),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          admin.email,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${admin.id} • Granted: ${admin.grantedAt.toLocal().toString().split(" ")[0]}',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  KithButton(
                    label: 'Sign Out',
                    variant: KithButtonVariant.destructive,
                    height: 38,
                    onPressed: () => vm.signOut(),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Granular Permissions Matrix for Current Role
          if (admin != null)
            KithSurface(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Granted Permissions for ${admin.role.label}',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: AdminPermission.values.map((p) {
                      final has = admin.hasPermission(p);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: has
                              ? (isDark ? AppColors.emeraldPrimary.withValues(alpha: 0.15) : AppColors.emeraldPrimary.withValues(alpha: 0.08))
                              : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                          borderRadius: AppRadius.smBorder,
                          border: Border.all(
                            color: has
                                ? AppColors.emeraldPrimary.withValues(alpha: 0.3)
                                : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              has ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                              size: 14,
                              color: has ? AppColors.emeraldLight : AppColors.darkTextMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.name,
                              style: TextStyle(
                                color: has
                                    ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                fontSize: 12,
                                fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Platform & Security Health Status
          KithSurface(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Environment & Database Connectivity',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildStatusRow('Target Environment', AppConfig.environment.toUpperCase(), true, isDark),
                const SizedBox(height: AppSpacing.xs),
                _buildStatusRow(
                  'Supabase Connection',
                  SupabaseConfig.isConfigured ? 'Connected (Fail-Closed)' : 'Unconfigured',
                  SupabaseConfig.isConfigured,
                  isDark,
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildStatusRow(
                  'Migration 20261101000007',
                  vm.isBackendUnavailable ? 'Pending Staging Authorization' : 'Applied & Verified',
                  !vm.isBackendUnavailable,
                  isDark,
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildStatusRow('PostgreSQL Engine', 'PostgreSQL 17.11 (Managed)', true, isDark),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Super Admin: Role Management Access
          if (admin != null && admin.hasPermission(AdminPermission.manageAdminRoles))
            KithSurface(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.emeraldLight, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Administrative Role Management (Super Admin)',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'As a Super Administrator, you are authorized to assign, modify, or revoke administrative roles for platform operators. All role modifications are written to the immutable audit ledger.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      KithButton(
                        label: 'View Active Administrators',
                        variant: KithButtonVariant.secondary,
                        height: 36,
                        onPressed: () async {
                          try {
                            final admins = await vm.adminService.listAdmins();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Active administrators registered: ${admins.length}'),
                                  backgroundColor: AppColors.emeraldPrimary,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Admin roles backend pending migration 000007: $e'),
                                  backgroundColor: AppColors.darkSurfaceCard,
                                ),
                              );
                            }
                          }
                        },
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

  Widget _buildStatusRow(String label, String value, bool isHealthy, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            fontSize: 13,
          ),
        ),
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isHealthy ? AppColors.positiveGreenDark : AppColors.amberAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
