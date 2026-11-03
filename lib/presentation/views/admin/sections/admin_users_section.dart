import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/kith_components.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../../domain/models/admin/admin_models.dart';
import '../../../viewmodels/admin/admin_dashboard_viewmodel.dart';
import '../../../viewmodels/admin/admin_users_viewmodel.dart';
import '../widgets/admin_confirm_dialog.dart';

/// User Administration module with searchable, filtered account directory and safe suspension actions.
class AdminUsersSection extends StatefulWidget {
  const AdminUsersSection({super.key});

  @override
  State<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends State<AdminUsersSection> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUsersViewModel>().fetchUsers(reset: true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmSuspend(BuildContext context, ManagedUser user) async {
    final dashboardVm = context.read<AdminDashboardViewModel>();
    final usersVm = context.read<AdminUsersViewModel>();
    final currentAdmin = dashboardVm.currentAdmin;

    if (currentAdmin == null || !currentAdmin.hasPermission(AdminPermission.suspendUsers)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access Denied: You do not possess the suspendUsers permission.')),
      );
      return;
    }

    final reason = await AdminConfirmDialog.show(
      context,
      title: 'Suspend User Account',
      message: 'Suspending ${user.displayName} (${user.id}) will immediately revoke all access to KITH data. This action is recorded in the permanent audit ledger.',
      confirmLabel: 'Suspend Account',
      isDestructive: true,
      requireReason: true,
      reasonHint: 'State the security or policy justification for this suspension...',
    );

    if (reason != null && context.mounted) {
      final success = await usersVm.suspendUser(
        user: user,
        reason: reason,
        currentAdmin: currentAdmin,
      );
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User account ${user.id} has been suspended ✓'),
            backgroundColor: AppColors.negativeRedDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmUnsuspend(BuildContext context, ManagedUser user) async {
    final dashboardVm = context.read<AdminDashboardViewModel>();
    final usersVm = context.read<AdminUsersViewModel>();
    final currentAdmin = dashboardVm.currentAdmin;

    if (currentAdmin == null || !currentAdmin.hasPermission(AdminPermission.suspendUsers)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access Denied: You do not possess the suspendUsers permission.')),
      );
      return;
    }

    final confirm = await AdminConfirmDialog.show(
      context,
      title: 'Unsuspend User Account',
      message: 'Restore access for ${user.displayName} (${user.id})? Account will immediately regain normal access.',
      confirmLabel: 'Restore Access',
      isDestructive: false,
      requireReason: false,
    );

    if (confirm != null && context.mounted) {
      final success = await usersVm.unsuspendUser(
        user: user,
        currentAdmin: currentAdmin,
      );
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User account ${user.id} access restored ✓'),
            backgroundColor: AppColors.emeraldPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminUsersViewModel>();
    final dashboardVm = context.watch<AdminDashboardViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSuspend = dashboardVm.can(AdminPermission.suspendUsers);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (val) => vm.setSearchQuery(val),
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: 13.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search users by name, email, or user ID...',
                    hintStyle: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      size: 20,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              vm.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: const BorderSide(color: AppColors.emeraldPrimary, width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: () => vm.fetchUsers(reset: true),
                tooltip: 'Refresh directory',
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Cohort Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Users', UserFilterType.all, vm, isDark),
                const SizedBox(width: AppSpacing.xs),
                _buildFilterChip('Registered (OAuth)', UserFilterType.registered, vm, isDark),
                const SizedBox(width: AppSpacing.xs),
                _buildFilterChip('Guest Sessions', UserFilterType.guest, vm, isDark),
                const SizedBox(width: AppSpacing.xs),
                _buildFilterChip('Suspended', UserFilterType.suspended, vm, isDark),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // User Directory List / Data Cards
          Expanded(
            child: vm.isLoading && vm.users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : vm.errorMessage != null
                    ? Center(
                        child: Text(
                          vm.errorMessage!,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      )
                    : vm.users.isEmpty
                        ? const Center(
                            child: EmptyStateView(
                              emoji: '👥',
                              title: 'No User Accounts Found',
                              subtitle: 'No user accounts match the current filter criteria.',
                            ),
                          )
                        : ListView.separated(
                            itemCount: vm.users.length + (vm.hasMore ? 1 : 0),
                            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              if (index == vm.users.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    child: KithButton(
                                      label: 'Load More Users',
                                      variant: KithButtonVariant.secondary,
                                      onPressed: () => vm.fetchUsers(),
                                    ),
                                  ),
                                );
                              }

                              final user = vm.users[index];
                              return _buildUserCard(context, user, canSuspend, isDark);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, UserFilterType type, AdminUsersViewModel vm, bool isDark) {
    final isSelected = vm.activeFilter == type;
    return InkWell(
      onTap: () => vm.setFilter(type),
      borderRadius: AppRadius.fullBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
              : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
          borderRadius: AppRadius.fullBorder,
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isDark ? AppColors.darkBackground : Colors.white)
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, ManagedUser user, bool canSuspend, bool isDark) {
    return KithSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            radius: 20,
            child: Icon(
              user.isGuest ? Icons.person_outline_rounded : Icons.verified_user_rounded,
              size: 20,
              color: user.isGuest ? AppColors.amberAccent : AppColors.emeraldPrimary,
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
                      user.displayName,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (user.isSuspended)
                      const PillBadge(label: 'Suspended', color: AppColors.negativeRedDark)
                    else if (user.isGuest)
                      const PillBadge(label: 'Guest', color: AppColors.amberAccent)
                    else
                      const PillBadge(label: 'Registered', color: AppColors.emeraldPrimary),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${user.id} ${user.email != null ? "• ${user.email}" : ""}',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.isSuspended && user.suspensionReason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Reason: ${user.suspensionReason}',
                    style: const TextStyle(
                      color: AppColors.negativeRedDark,
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canSuspend)
            user.isSuspended
                ? KithButton(
                    label: 'Unsuspend',
                    variant: KithButtonVariant.secondary,
                    height: 36,
                    onPressed: () => _confirmUnsuspend(context, user),
                  )
                : KithButton(
                    label: 'Suspend',
                    variant: KithButtonVariant.destructive,
                    height: 36,
                    onPressed: () => _confirmSuspend(context, user),
                  ),
        ],
      ),
    );
  }
}
