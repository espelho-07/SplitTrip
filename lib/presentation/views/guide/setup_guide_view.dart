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
            title: 'Change App Language',
            description: 'Switch between English, Hindi (हिन्दी), and Gujarati (ગુજરાતી) instantly without restarting.',
            location: 'Settings → Language',
            actionLabel: 'Change Language',
            icon: Icons.translate_rounded,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) => LanguageSelectSheet.show(ctx),
          ),
          GuideItem(
            title: 'Guest Mode vs Google Account',
            description: 'You can use Kith offline as a guest. When you sign in with Google, all your existing guest records are safely migrated and backed up to the cloud.',
            location: 'Profile → Account & Identity',
            actionLabel: 'View Profile',
            icon: Icons.verified_user_rounded,
            iconColor: AppColors.indigoAccent,
            onAction: (ctx) => ProfileSheet.show(ctx),
          ),
          GuideItem(
            title: 'Expense vs Trips Modes',
            description: 'Use Kith for purely personal finances, exclusively group travel splitting, or both simultaneously.',
            location: 'Profile → Experience Mode',
            actionLabel: 'Customize Experience',
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
            title: 'Add Personal Expense',
            description: 'Log any daily expense in seconds with exact amounts, date, category, and notes.',
            location: 'Expense Tab → Floating + Button',
            actionLabel: 'Add Expense',
            icon: Icons.add_circle_outline_rounded,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) => AddPersonalExpenseSheet.show(ctx),
          ),
          GuideItem(
            title: 'Set Monthly Budget Limit',
            description: 'Set a monthly spending threshold to monitor your spending and receive real-time remaining balance alerts.',
            location: 'Expense Tab → Monthly Budget Card',
            actionLabel: 'Set Budget',
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
            title: 'Lending & Borrowing (Debts)',
            description: 'Track money you have lent to friends or borrowed. Record partial repayments anytime.',
            location: 'Expense Tab → Lending & Borrowing Card',
            actionLabel: 'Open Debts',
            icon: Icons.handshake_outlined,
            iconColor: AppColors.indigoAccent,
            onAction: (ctx) => ctx.push('/personal/debts'),
          ),
          GuideItem(
            title: 'Spending by Category',
            description: 'Analyze your expenditure across Food, Stay, Transport, Shopping, Entertainment, and more.',
            location: 'Expense Tab → Categories Breakdown',
            actionLabel: 'View Categories',
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
            title: 'Create a Group Trip',
            description: 'Create a new trip, pick an emoji, select initial friends, and generate an instant 6-character join code.',
            location: 'Trips Tab → Create Trip +',
            actionLabel: 'Create Trip',
            icon: Icons.flight_takeoff_rounded,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) => ctx.push('/create-trip'),
          ),
          GuideItem(
            title: "Join a Friend's Trip",
            description: "Enter your friend's 6-character invite code to immediately join their trip and sync shared balances.",
            location: 'Trips Tab → Join Trip',
            actionLabel: 'Join Trip',
            icon: Icons.group_add_outlined,
            iconColor: AppColors.tealAccent,
            onAction: (ctx) => ctx.push('/join-trip'),
          ),
          GuideItem(
            title: 'Splitting Options',
            description: 'Split bills equally, by exact amounts, custom shares (e.g. 2:1), or percentages with zero-remainder math.',
            location: 'Trip Detail → Add Trip Expense',
            actionLabel: 'Go to Trips',
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
            title: 'Google Cloud Backup',
            description: 'Sign in with Google to keep all your personal and trip ledgers continuously synced across all your phones and tablets.',
            location: 'Profile → Connected Account',
            actionLabel: 'Open Profile',
            icon: Icons.cloud_done_outlined,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) => ProfileSheet.show(ctx),
          ),
          GuideItem(
            title: 'Cross-Device Restore',
            description: 'If you install Kith on a new device or clear data, simply sign in with the same Google account to restore everything.',
            location: 'Welcome / Onboarding Screen',
            actionLabel: 'View Account',
            icon: Icons.devices_rounded,
            iconColor: AppColors.indigoAccent,
            onAction: (ctx) => ProfileSheet.show(ctx),
          ),
          GuideItem(
            title: 'Signing Out & Security',
            description: 'Signing out purges local cached data to protect your privacy on shared devices. Your cloud records remain completely safe.',
            location: 'Profile → Sign Out',
            actionLabel: 'Open Profile',
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
            title: 'Voice Expense Logging',
            description: 'Speak naturally in English, Hindi, or Hinglish (e.g. "Rahul ko 500 udhar diye" or "Train tickets 2500"). Kith parses payer, amount, and category automatically.',
            location: 'Expense Tab → Mic Button',
            actionLabel: 'Try Voice in Expenses',
            icon: Icons.mic_rounded,
            iconColor: AppColors.emeraldPrimary,
            onAction: (ctx) {
              ctx.go('/home');
            },
          ),
          GuideItem(
            title: 'Receipt Scanning & OCR',
            description: 'Snap a picture of a restaurant or store receipt to auto-extract the total amount and line items.',
            location: 'Add Expense Sheet → Scan Receipt',
            actionLabel: 'Add Expense',
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
