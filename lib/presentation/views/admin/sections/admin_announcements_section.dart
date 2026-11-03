import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/kith_components.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../../domain/models/admin/admin_models.dart';
import '../../../viewmodels/admin/admin_announcements_viewmodel.dart';
import '../../../viewmodels/admin/admin_dashboard_viewmodel.dart';

/// Announcement Management Section for targeted broadcasts, scheduling, and expiration.
class AdminAnnouncementsSection extends StatefulWidget {
  const AdminAnnouncementsSection({super.key});

  @override
  State<AdminAnnouncementsSection> createState() => _AdminAnnouncementsSectionState();
}

class _AdminAnnouncementsSectionState extends State<AdminAnnouncementsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminAnnouncementsViewModel>().fetchAnnouncements();
    });
  }

  void _showCreateDialog(BuildContext context) {
    final dashboardVm = context.read<AdminDashboardViewModel>();
    final currentAdmin = dashboardVm.currentAdmin;
    if (currentAdmin == null) return;

    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    AnnouncementAudience audience = AnnouncementAudience.all;
    AnnouncementPriority priority = AnnouncementPriority.normal;
    DateTime startsAt = DateTime.now();
    DateTime? expiresAt = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Broadcast Announcement',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Announcement Title', isDense: true),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: msgCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Message Body', isDense: true),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<AnnouncementAudience>(
                        initialValue: audience,
                        decoration: const InputDecoration(labelText: 'Target Audience Segment', isDense: true),
                        items: AnnouncementAudience.values.map((a) {
                          return DropdownMenuItem(value: a, child: Text(a.label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => audience = val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<AnnouncementPriority>(
                        initialValue: priority,
                        decoration: const InputDecoration(labelText: 'Priority Tier', isDense: true),
                        items: AnnouncementPriority.values.map((p) {
                          return DropdownMenuItem(value: p, child: Text(p.label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => priority = val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          KithButton(
                            label: 'Cancel',
                            variant: KithButtonVariant.tertiary,
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          KithButton(
                            label: 'Publish Broadcast',
                            onPressed: () async {
                              if (titleCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) return;
                              final success = await context.read<AdminAnnouncementsViewModel>().createAnnouncement(
                                title: titleCtrl.text.trim(),
                                message: msgCtrl.text.trim(),
                                priority: priority,
                                targetAudience: audience,
                                startsAt: startsAt,
                                expiresAt: expiresAt,
                                currentAdmin: currentAdmin,
                              );
                              if (success && ctx.mounted) {
                                Navigator.of(ctx).pop();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminAnnouncementsViewModel>();
    final dashboardVm = context.watch<AdminDashboardViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAdmin = dashboardVm.currentAdmin;
    final canManage = dashboardVm.can(AdminPermission.manageAnnouncements);

    return Padding(
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
                    'Targeted Announcements',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Audience-segmented announcements with publication scheduling and expiration.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (canManage)
                KithButton(
                  label: 'New Broadcast',
                  icon: Icons.campaign_rounded,
                  onPressed: () => _showCreateDialog(context),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.errorMessage != null
                    ? Center(
                        child: Text(
                          vm.errorMessage!,
                          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      )
                    : vm.announcements.isEmpty
                        ? const Center(
                            child: EmptyStateView(
                              emoji: '📢',
                              title: 'No Broadcast Announcements',
                              subtitle: 'No active or scheduled announcements. Create a broadcast to inform users.',
                            ),
                          )
                        : ListView.separated(
                            itemCount: vm.announcements.length,
                            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final item = vm.announcements[index];
                              return KithSurface(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                item.title,
                                                style: TextStyle(
                                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: AppSpacing.xs),
                                              PillBadge(label: item.targetAudience.label, color: AppColors.indigoAccent),
                                              const SizedBox(width: AppSpacing.xs),
                                              if (item.isActive)
                                                const PillBadge(label: 'Live', color: AppColors.positiveGreenDark)
                                              else
                                                const PillBadge(label: 'Expired', color: AppColors.darkTextMuted),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.message,
                                            style: TextStyle(
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'By ${item.createdByName ?? item.createdBy} • Starts: ${item.startsAt.toLocal().toString().split(".")[0]}',
                                            style: TextStyle(
                                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (canManage && item.isActive && currentAdmin != null)
                                      KithButton(
                                        label: 'Expire Now',
                                        variant: KithButtonVariant.destructive,
                                        height: 36,
                                        onPressed: () => vm.expireAnnouncement(
                                          announcement: item,
                                          currentAdmin: currentAdmin,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
