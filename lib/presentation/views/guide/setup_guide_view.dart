import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/surface_card.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../home/widgets/profile_sheet.dart';
import '../language/language_select_sheet.dart';
import '../personal/widgets/add_personal_expense_sheet.dart';
import '../personal/widgets/set_budget_dialog.dart';

class GuideItem {
  final String title;
  final String description;
  final String location;
  final String actionLabel;
  final IconData icon;
  final Color iconColor;
  final void Function(BuildContext context) onAction;

  const GuideItem({
    required this.title,
    required this.description,
    required this.location,
    required this.actionLabel,
    required this.icon,
    required this.iconColor,
    required this.onAction,
  });
}

class GuideSection {
  final String title;
  final String emoji;
  final List<GuideItem> items;

  const GuideSection({
    required this.title,
    required this.emoji,
    required this.items,
  });
}

/// Comprehensive, actionable "How Kith Works" Setup Guide view.
class SetupGuideView extends StatefulWidget {
  const SetupGuideView({super.key});

  @override
  State<SetupGuideView> createState() => _SetupGuideViewState();
}

class _SetupGuideViewState extends State<SetupGuideView> {
  int _selectedSectionIndex = 0;

  List<GuideSection> _buildSections(BuildContext context) {
    final l10n = context.l10n;

    return [
      GuideSection(
        title: l10n.guideSecGettingStarted,
        emoji: '🚀',
        items: [
          GuideItem(
            title: l10n.guideItem1_1Title,
            description: l10n.guideItem1_1Desc,
            location: l10n.guideItem1_1Loc,
            actionLabel: l10n.guideItem1_1Act,
            icon: Icons.widgets_outlined,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) => ctx.push('/widgets'),
          ),
          GuideItem(
            title: l10n.guideItem1_2Title,
            description: l10n.guideItem1_2Desc,
            location: l10n.guideItem1_2Loc,
            actionLabel: l10n.guideItem1_2Act,
            icon: Icons.translate_rounded,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) => LanguageSelectSheet.show(ctx),
          ),
          GuideItem(
            title: l10n.guideItem1_3Title,
            description: l10n.guideItem1_3Desc,
            location: l10n.guideItem1_3Loc,
            actionLabel: l10n.guideItem1_3Act,
            icon: Icons.verified_user_rounded,
            iconColor: AppColors.indigoAccent,
            onAction: (ctx) => ProfileSheet.show(ctx),
          ),
          GuideItem(
            title: l10n.guideItem1_4Title,
            description: l10n.guideItem1_4Desc,
            location: l10n.guideItem1_4Loc,
            actionLabel: l10n.guideItem1_4Act,
            icon: Icons.dashboard_customize_rounded,
            iconColor: AppColors.tealAccent,
            onAction: (ctx) => ProfileSheet.show(ctx),
          ),
        ],
      ),
      GuideSection(
        title: l10n.guideSecPersonal,
        emoji: '💰',
        items: [
          GuideItem(
            title: l10n.guideItem2_1Title,
            description: l10n.guideItem2_1Desc,
            location: l10n.guideItem2_1Loc,
            actionLabel: l10n.guideItem2_1Act,
            icon: Icons.add_circle_outline_rounded,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) => AddPersonalExpenseSheet.show(ctx),
          ),
          GuideItem(
            title: l10n.guideItem2_2Title,
            description: l10n.guideItem2_2Desc,
            location: l10n.guideItem2_2Loc,
            actionLabel: l10n.guideItem2_2Act,
            icon: Icons.savings_outlined,
            iconColor: Colors.amber,
            onAction: (ctx) {
              final personalVm = ctx.read<PersonalExpenseViewModel>();
              final monthYear = DateFormat('yyyy-MM').format(personalVm.selectedMonth);
              final limit = personalVm.budget.monthlyLimitInPaise;
              SetBudgetDialog.show(
                ctx,
                currentBudgetPaise: limit,
                monthYear: monthYear,
              );
            },
          ),
          GuideItem(
            title: l10n.guideItem2_3Title,
            description: l10n.guideItem2_3Desc,
            location: l10n.guideItem2_3Loc,
            actionLabel: l10n.guideItem2_3Act,
            icon: Icons.handshake_outlined,
            iconColor: AppColors.indigoAccent,
            onAction: (ctx) => ctx.push('/personal/debts'),
          ),
          GuideItem(
            title: l10n.guideItem2_4Title,
            description: l10n.guideItem2_4Desc,
            location: l10n.guideItem2_4Loc,
            actionLabel: l10n.guideItem2_4Act,
            icon: Icons.donut_large_rounded,
            iconColor: Colors.purpleAccent,
            onAction: (ctx) => ctx.push('/personal/categories'),
          ),
        ],
      ),
      GuideSection(
        title: l10n.guideSecTrips,
        emoji: '🏖️',
        items: [
          GuideItem(
            title: l10n.guideItem3_1Title,
            description: l10n.guideItem3_1Desc,
            location: l10n.guideItem3_1Loc,
            actionLabel: l10n.guideItem3_1Act,
            icon: Icons.flight_takeoff_rounded,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) => ctx.push('/create-trip'),
          ),
          GuideItem(
            title: l10n.guideItem3_2Title,
            description: l10n.guideItem3_2Desc,
            location: l10n.guideItem3_2Loc,
            actionLabel: l10n.guideItem3_2Act,
            icon: Icons.group_add_outlined,
            iconColor: AppColors.tealAccent,
            onAction: (ctx) => ctx.push('/join-trip'),
          ),
          GuideItem(
            title: l10n.guideItem3_3Title,
            description: l10n.guideItem3_3Desc,
            location: l10n.guideItem3_3Loc,
            actionLabel: l10n.guideItem3_3Act,
            icon: Icons.call_split_rounded,
            iconColor: Colors.deepOrangeAccent,
            onAction: (ctx) {
              ctx.go('/home');
            },
          ),
        ],
      ),
      GuideSection(
        title: l10n.guideSecCloud,
        emoji: '☁️',
        items: [
          GuideItem(
            title: l10n.guideItem4_1Title,
            description: l10n.guideItem4_1Desc,
            location: l10n.guideItem4_1Loc,
            actionLabel: l10n.guideItem4_1Act,
            icon: Icons.cloud_done_outlined,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) => ProfileSheet.show(ctx),
          ),
          GuideItem(
            title: l10n.guideItem4_2Title,
            description: l10n.guideItem4_2Desc,
            location: l10n.guideItem4_2Loc,
            actionLabel: l10n.guideItem4_2Act,
            icon: Icons.devices_rounded,
            iconColor: AppColors.indigoAccent,
            onAction: (ctx) => ProfileSheet.show(ctx),
          ),
          GuideItem(
            title: l10n.guideItem4_3Title,
            description: l10n.guideItem4_3Desc,
            location: l10n.guideItem4_3Loc,
            actionLabel: l10n.guideItem4_3Act,
            icon: Icons.lock_outline_rounded,
            iconColor: Colors.redAccent,
            onAction: (ctx) => ProfileSheet.show(ctx),
          ),
        ],
      ),
      GuideSection(
        title: l10n.guideSecVoice,
        emoji: '🎙️',
        items: [
          GuideItem(
            title: l10n.guideItem5_1Title,
            description: l10n.guideItem5_1Desc,
            location: l10n.guideItem5_1Loc,
            actionLabel: l10n.guideItem5_1Act,
            icon: Icons.mic_rounded,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) {
              ctx.go('/home');
            },
          ),
          GuideItem(
            title: l10n.guideItem5_2Title,
            description: l10n.guideItem5_2Desc,
            location: l10n.guideItem5_2Loc,
            actionLabel: l10n.guideItem5_2Act,
            icon: Icons.receipt_long_rounded,
            iconColor: Colors.cyan,
            onAction: (ctx) => AddPersonalExpenseSheet.show(ctx),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final sections = _buildSections(context);
    final currentSection = sections[_selectedSectionIndex];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.guideTitle,
          style: AppTypography.titleLarge(isDark: isDark).copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Tabs
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: sections.length,
                itemBuilder: (ctx, idx) {
                  final sec = sections[idx];
                  final isSelected = _selectedSectionIndex == idx;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Row(
                        children: [
                          Text(sec.emoji),
                          const SizedBox(width: 6),
                          Text(sec.title),
                        ],
                      ),
                      selectedColor: isDark
                          ? AppColors.emeraldPrimary.withValues(alpha: 0.25)
                          : AppColors.emeraldPrimary.withValues(alpha: 0.15),
                      checkmarkColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      onSelected: (_) {
                        HapticHelper.selection();
                        setState(() => _selectedSectionIndex = idx);
                      },
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Content List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                physics: const BouncingScrollPhysics(),
                itemCount: currentSection.items.length,
                itemBuilder: (ctx, itemIdx) {
                  final item = currentSection.items[itemIdx];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: SurfaceCard(
                      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Icon + Title
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: item.iconColor.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.smBorder,
                                ),
                                child: Icon(item.icon, color: item.iconColor, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          // Description
                          Text(
                            item.description,
                            style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                              height: 1.4,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Location tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                                const SizedBox(width: 4),
                                Text(
                                  item.location,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Direct Action Button
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                HapticHelper.medium();
                                item.onAction(context);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: isDark
                                    ? AppColors.emeraldPrimary.withValues(alpha: 0.2)
                                    : AppColors.emeraldPrimary.withValues(alpha: 0.12),
                                foregroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              label: Text(
                                item.actionLabel,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
