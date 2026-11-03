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
import '../../../viewmodels/admin/admin_feedback_viewmodel.dart';

/// Feedback Inbox section for triage, internal administrative notes, and thread replies.
class AdminFeedbackSection extends StatefulWidget {
  const AdminFeedbackSection({super.key});

  @override
  State<AdminFeedbackSection> createState() => _AdminFeedbackSectionState();
}

class _AdminFeedbackSectionState extends State<AdminFeedbackSection> {
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminFeedbackViewModel>().fetchFeedback();
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminFeedbackViewModel>();
    final dashboardVm = context.watch<AdminDashboardViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAdmin = dashboardVm.currentAdmin;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _buildFeedbackListPane(vm, isDark),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 6,
                  child: vm.selectedFeedback != null
                      ? _buildFeedbackDetailPane(vm, currentAdmin, isDark)
                      : KithSurface(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: const Center(
                            child: EmptyStateView(
                              emoji: '📥',
                              title: 'Select a Feedback Item',
                              subtitle: 'Choose a feedback submission from the inbox to triage, view internal notes, or reply.',
                            ),
                          ),
                        ),
                ),
              ],
            );
          } else {
            // Mobile Layout: List or Full-screen Detail
            if (vm.selectedFeedback != null) {
              return Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => vm.clearSelection(),
                      ),
                      Text(
                        'Back to Feedback Inbox',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(child: _buildFeedbackDetailPane(vm, currentAdmin, isDark)),
                ],
              );
            }
            return _buildFeedbackListPane(vm, isDark);
          }
        },
      ),
    );
  }

  Widget _buildFeedbackListPane(AdminFeedbackViewModel vm, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip('All Categories', null, vm, isDark),
              const SizedBox(width: AppSpacing.xs),
              for (final cat in FeedbackCategory.values) ...[
                _buildCategoryChip(cat.label, cat, vm, isDark),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatusChip('All Statuses', null, vm, isDark),
              const SizedBox(width: AppSpacing.xs),
              for (final st in FeedbackStatus.values) ...[
                _buildStatusChip(st.label, st, vm, isDark),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Feedback List
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
                  : vm.feedbackList.isEmpty
                      ? const Center(
                          child: EmptyStateView(
                            emoji: '📬',
                            title: 'No Feedback Found',
                            subtitle: 'Inbox is clean. No feedback matching current filters.',
                          ),
                        )
                      : ListView.separated(
                          itemCount: vm.feedbackList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = vm.feedbackList[index];
                            final isSelected = vm.selectedFeedback?.id == item.id;
                            return _buildFeedbackItemCard(item, isSelected, vm, isDark);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, FeedbackCategory? cat, AdminFeedbackViewModel vm, bool isDark) {
    final isSelected = vm.selectedCategory == cat;
    return InkWell(
      onTap: () => vm.setCategoryFilter(cat),
      borderRadius: AppRadius.fullBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
              : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
          borderRadius: AppRadius.fullBorder,
          border: Border.all(
            color: isSelected ? Colors.transparent : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isDark ? AppColors.darkBackground : Colors.white)
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, FeedbackStatus? st, AdminFeedbackViewModel vm, bool isDark) {
    final isSelected = vm.selectedStatus == st;
    return InkWell(
      onTap: () => vm.setStatusFilter(st),
      borderRadius: AppRadius.fullBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.indigoAccent : AppColors.indigoAccent)
              : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
          borderRadius: AppRadius.fullBorder,
          border: Border.all(
            color: isSelected ? Colors.transparent : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackItemCard(UserFeedback item, bool isSelected, AdminFeedbackViewModel vm, bool isDark) {
    return KithSurface(
      onTap: () => vm.selectFeedback(item),
      color: isSelected
          ? (isDark ? AppColors.emeraldPrimary.withValues(alpha: 0.15) : AppColors.emeraldPrimary.withValues(alpha: 0.08))
          : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PillBadge(label: item.category.label, color: AppColors.emeraldPrimary),
              PillBadge(label: item.status.label, color: _getStatusColor(item.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.subject,
            style: TextStyle(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item.description,
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 12.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackDetailPane(AdminFeedbackViewModel vm, AdminUser? admin, bool isDark) {
    final item = vm.selectedFeedback!;

    return KithSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Priority Selectors
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.subject,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From: ${item.userDisplayName ?? item.userId} • App: v${item.appVersion ?? "1.0.0"} (${item.platform})',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (admin != null)
                  DropdownButton<FeedbackStatus>(
                    value: item.status,
                    dropdownColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    underline: const SizedBox(),
                    items: FeedbackStatus.values.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.label));
                    }).toList(),
                    onChanged: (newStatus) {
                      if (newStatus != null) {
                        vm.updateStatus(newStatus, admin);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Description
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                borderRadius: AppRadius.mdBorder,
              ),
              child: Text(
                item.description,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Internal Notes Header
            Text(
              'Internal Staff Notes (Restricted)',
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (vm.internalNotes.isEmpty)
              Text(
                'No internal notes attached.',
                style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12),
              )
            else
              for (final note in vm.internalNotes) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.amberAccent.withValues(alpha: isDark ? 0.1 : 0.06),
                    borderRadius: AppRadius.smBorder,
                    border: Border.all(color: AppColors.amberAccent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${note.adminDisplayName}:',
                        style: const TextStyle(color: AppColors.amberAccent, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        note.note,
                        style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],

            // Add Note Input
            if (admin != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _noteCtrl,
                      style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Add an internal staff note...',
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                        border: OutlineInputBorder(borderRadius: AppRadius.smBorder, borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  KithButton(
                    label: 'Note',
                    height: 36,
                    variant: KithButtonVariant.secondary,
                    onPressed: () {
                      if (_noteCtrl.text.trim().isNotEmpty) {
                        vm.addInternalNote(_noteCtrl.text.trim(), admin);
                        _noteCtrl.clear();
                      }
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Thread Replies
            Text(
              'User Reply Thread',
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (vm.replies.isEmpty)
              Text(
                'No replies in this thread yet.',
                style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12),
              )
            else
              for (final reply in vm.replies) ...[
                Align(
                  alignment: reply.isAdminReply ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    constraints: const BoxConstraints(maxWidth: 360),
                    decoration: BoxDecoration(
                      color: reply.isAdminReply
                          ? (isDark ? AppColors.emeraldPrimary.withValues(alpha: 0.3) : AppColors.emeraldPrimary.withValues(alpha: 0.15))
                          : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                      borderRadius: AppRadius.mdBorder,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reply.isAdminReply ? 'KITH Support (${reply.senderDisplayName})' : reply.senderDisplayName,
                          style: TextStyle(
                            color: reply.isAdminReply ? AppColors.emeraldLight : AppColors.indigoAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          reply.message,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

            // Add Reply Composer
            if (admin != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type an official response to the user...',
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                        border: OutlineInputBorder(borderRadius: AppRadius.smBorder, borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  KithButton(
                    label: 'Send Reply',
                    height: 38,
                    onPressed: () {
                      if (_replyCtrl.text.trim().isNotEmpty) {
                        vm.postReply(_replyCtrl.text.trim(), admin);
                        _replyCtrl.clear();
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(FeedbackStatus status) {
    switch (status) {
      case FeedbackStatus.newStatus:
        return AppColors.indigoAccent;
      case FeedbackStatus.underReview:
        return AppColors.amberAccent;
      case FeedbackStatus.inProgress:
        return AppColors.emeraldPrimary;
      case FeedbackStatus.waitingForUser:
        return AppColors.tealAccent;
      case FeedbackStatus.resolved:
        return AppColors.positiveGreenDark;
      case FeedbackStatus.rejected:
        return AppColors.negativeRedDark;
    }
  }
}
