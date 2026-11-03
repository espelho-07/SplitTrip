import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../core/widgets/pill_badge.dart';
import '../../../domain/models/admin/admin_models.dart';
import '../../viewmodels/admin/admin_dashboard_viewmodel.dart';
import 'admin_login_view.dart';
import 'sections/admin_analytics_section.dart';
import 'sections/admin_announcements_section.dart';
import 'sections/admin_audit_logs_section.dart';
import 'sections/admin_feature_requests_section.dart';
import 'sections/admin_feedback_section.dart';
import 'sections/admin_overview_section.dart';
import 'sections/admin_settings_section.dart';
import 'sections/admin_users_section.dart';
import 'widgets/admin_permission_guard.dart';

/// Responsive administrative console shell with desktop navigation rail and mobile drawer.
class AdminShellView extends StatefulWidget {
  final AdminSection? initialSection;

  const AdminShellView({super.key, this.initialSection});

  @override
  State<AdminShellView> createState() => _AdminShellViewState();
}

class _AdminShellViewState extends State<AdminShellView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<AdminDashboardViewModel>();
      if (widget.initialSection != null) {
        vm.setSection(widget.initialSection!);
      }
      vm.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminDashboardViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // While checking initial authentication/role, avoid login flicker
    if (vm.isLoading && !vm.isAuthenticated) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.emeraldPrimary),
        ),
      );
    }

    // Gate entry: if not authenticated, render the login view
    if (!vm.isAuthenticated) {
      return const AdminLoginView();
    }

    final admin = vm.currentAdmin!;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 850;

          if (isDesktop) {
            return Row(
              children: [
                // Desktop Navigation Rail
                _buildSidebar(vm, admin, isDark),

                // Main Content Surface
                Expanded(
                  child: Column(
                    children: [
                      _buildTopHeader(vm, admin, isDark, isDesktop: true),
                      Expanded(child: _buildActiveSection(vm, admin)),
                    ],
                  ),
                ),
              ],
            );
          } else {
            // Mobile Shell with Drawer
            return Scaffold(
              backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              appBar: AppBar(
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                elevation: 0,
                title: Text(
                  vm.currentSection.label,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    tooltip: 'Sign Out',
                    onPressed: () => vm.signOut(),
                  ),
                ],
              ),
              drawer: Drawer(
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                child: _buildSidebar(vm, admin, isDark, isDrawer: true),
              ),
              body: _buildActiveSection(vm, admin),
            );
          }
        },
      ),
    );
  }

  Widget _buildSidebar(AdminDashboardViewModel vm, AdminUser admin, bool isDark, {bool isDrawer = false}) {
    return Container(
      width: isDrawer ? null : 240,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.emeraldLight, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KITH Control',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Administration',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.8),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
              children: AdminSection.values.map((section) {
                final isSelected = vm.currentSection == section;
                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppColors.emeraldPrimary.withValues(alpha: 0.15) : AppColors.emeraldPrimary.withValues(alpha: 0.08))
                        : Colors.transparent,
                    borderRadius: AppRadius.mdBorder,
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      isSelected ? section.filledIcon : section.outlineIcon,
                      size: 19,
                      color: isSelected
                          ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    title: Text(
                      section.label,
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      vm.setSection(section);
                      if (isDrawer) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Footer Admin Profile Strip
          const Divider(height: 1, thickness: 0.8),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.emeraldPrimary.withValues(alpha: 0.2),
                  child: Text(
                    admin.displayName.isNotEmpty ? admin.displayName[0].toUpperCase() : 'A',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.emeraldLight),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        admin.displayName,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        admin.role.label,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(AdminDashboardViewModel vm, AdminUser admin, bool isDark, {required bool isDesktop}) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Console',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                vm.currentSection.label,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Row(
            children: [
              PillBadge(label: admin.role.label, color: AppColors.emeraldPrimary),
              const SizedBox(width: AppSpacing.sm),
              KithButton(
                label: 'Sign Out',
                variant: KithButtonVariant.tertiary,
                height: 32,
                onPressed: () => vm.signOut(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSection(AdminDashboardViewModel vm, AdminUser admin) {
    switch (vm.currentSection) {
      case AdminSection.overview:
        return const AdminOverviewSection();

      case AdminSection.users:
        return AdminPermissionGuard(
          permission: AdminPermission.manageUsers,
          currentRole: admin.role,
          child: const AdminUsersSection(),
        );

      case AdminSection.feedback:
        return AdminPermissionGuard(
          permission: AdminPermission.viewFeedback,
          currentRole: admin.role,
          child: const AdminFeedbackSection(),
        );

      case AdminSection.featureRequests:
        return const AdminFeatureRequestsSection();

      case AdminSection.analytics:
        return AdminPermissionGuard(
          permission: AdminPermission.viewAnalytics,
          currentRole: admin.role,
          child: const AdminAnalyticsSection(),
        );

      case AdminSection.announcements:
        return AdminPermissionGuard(
          permission: AdminPermission.manageAnnouncements,
          currentRole: admin.role,
          child: const AdminAnnouncementsSection(),
        );

      case AdminSection.auditLogs:
        return AdminPermissionGuard(
          permission: AdminPermission.viewAuditLogs,
          currentRole: admin.role,
          child: const AdminAuditLogsSection(),
        );

      case AdminSection.settings:
        return const AdminSettingsSection();
    }
  }
}
