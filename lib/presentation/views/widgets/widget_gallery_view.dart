import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/kith_widget_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';

class WidgetGalleryView extends StatefulWidget {
  const WidgetGalleryView({super.key});

  @override
  State<WidgetGalleryView> createState() => _WidgetGalleryViewState();
}

class _WidgetGalleryViewState extends State<WidgetGalleryView> {
  Future<void> _handlePinWidget(String type, String name) async {
    final widgetService = context.read<KithWidgetService>();
    HapticHelper.medium();

    final isSupported = await widgetService.isPinningSupported();

    if (!isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Long press your home screen and select Widgets → Kith to add $name.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final success = await widgetService.requestPinWidget(type);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $name widget to home screen! ✓'),
            backgroundColor: AppColors.emeraldPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Long press your home screen to place $name widget.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final widgetService = context.watch<KithWidgetService>();
    final authVm = context.watch<AuthViewModel>();
    final personalVm = context.watch<PersonalExpenseViewModel>();
    final homeVm = context.watch<HomeViewModel>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Home Screen Widgets'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        children: [
          // Header Intro
          Text(
            'Keep Kith on your home screen',
            style: AppTypography.titleLarge(isDark: isDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Glanceable numbers, live budgets, debts and 1-tap expense logging without opening the app.',
            style: AppTypography.bodyMedium(isDark: isDark),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Privacy Mode Card
          SurfaceCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  widgetService.isPrivacyMode ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: widgetService.isPrivacyMode ? AppColors.amberAccent : AppColors.emeraldPrimary,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy Mode',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        'Mask financial amounts as ₹•••• on lock & home screens',
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: widgetService.isPrivacyMode,
                  onChanged: (val) async {
                    HapticHelper.selection();
                    await widgetService.setPrivacyMode(val);
                    await widgetService.syncSnapshot(
                      currentUser: authVm.currentUser,
                      personalExpenses: personalVm.expenses,
                      budget: personalVm.budget,
                      debtsSummary: personalVm.debtsSummary,
                      trips: homeVm.trips,
                      tripBalances: homeVm.tripBalances,
                    );
                  },
                  activeThumbColor: AppColors.emeraldPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Section Title
          Text(
            'AVAILABLE WIDGETS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 1. Kith Snapshot (Hero)
          _buildWidgetCard(
            context: context,
            title: 'Kith Snapshot',
            badge: 'HERO',
            badgeColor: AppColors.emeraldPrimary,
            sizeLabel: '4 × 2 · Medium',
            description: 'Instant overview of your monthly spending, budget runway progress, and 1-tap quick expense logging.',
            previewContent: _buildSnapshotPreview(isDark, widgetService.isPrivacyMode),
            onPin: () => _handlePinWidget('snapshot', 'Kith Snapshot'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2. Quick Add
          _buildWidgetCard(
            context: context,
            title: 'Quick Add Bar',
            badge: 'FASTEST',
            badgeColor: AppColors.indigoAccent,
            sizeLabel: '4 × 1 · Compact',
            description: 'One-tap entry for new expenses, hands-free voice logging, and camera receipt scanning.',
            previewContent: _buildQuickAddPreview(isDark),
            onPin: () => _handlePinWidget('quick_add', 'Quick Add'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 3. Budget Tracker
          _buildWidgetCard(
            context: context,
            title: 'Budget Tracker',
            badge: 'ESSENTIAL',
            badgeColor: AppColors.amberAccent,
            sizeLabel: '3 × 2 · Medium',
            description: 'Live monthly budget health bar with automatic daily runway calculations to prevent overspending.',
            previewContent: _buildBudgetPreview(isDark, widgetService.isPrivacyMode),
            onPin: () => _handlePinWidget('budget', 'Budget Tracker'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 4. Money Owed & You Owe
          _buildWidgetCard(
            context: context,
            title: 'Debts & Lending',
            badge: 'BALANCE',
            badgeColor: AppColors.emeraldPrimary,
            sizeLabel: '3 × 2 · Medium',
            description: 'Keep track of friends who owe you money and balances you need to repay at a single glance.',
            previewContent: _buildDebtsPreview(isDark, widgetService.isPrivacyMode),
            onPin: () => _handlePinWidget('debts', 'Debts & Lending'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 5. Active Trip
          _buildWidgetCard(
            context: context,
            title: 'Active Trip',
            badge: 'TRAVEL',
            badgeColor: AppColors.indigoAccent,
            sizeLabel: '4 × 2 · Medium',
            description: 'Live spending, member count and personal net balance for your ongoing trip.',
            previewContent: _buildTripPreview(isDark, widgetService.isPrivacyMode),
            onPin: () => _handlePinWidget('trip', 'Active Trip'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 6. Smart Kith Intelligence
          _buildWidgetCard(
            context: context,
            title: 'Smart Kith',
            badge: 'SIGNATURE',
            badgeColor: AppColors.emeraldPrimary,
            sizeLabel: '4 × 2 · Medium',
            description: 'Intelligent card dynamically ranking the single most critical financial action based on live state.',
            previewContent: _buildSmartPreview(isDark),
            onPin: () => _handlePinWidget('smart', 'Smart Kith'),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Instructions Footnote
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.emeraldPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adding from your home screen',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You can also touch & hold any empty spot on your phone\'s home screen, tap Widgets, and scroll to Kith to pick your preferred size.',
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildWidgetCard({
    required BuildContext context,
    required String title,
    required String badge,
    required Color badgeColor,
    required String sizeLabel,
    required String description,
    required Widget previewContent,
    required VoidCallback onPin,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Badge
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                sizeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTypography.bodySmall(isDark: isDark),
          ),
          const SizedBox(height: AppSpacing.md),

          // Live Interactive Card Preview Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF2E2E38) : const Color(0xFFE4E4E7),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: previewContent,
          ),
          const SizedBox(height: AppSpacing.md),

          // Add to Home Screen CTA
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: 'Add to Home Screen',
              icon: Icons.add_to_home_screen_rounded,
              variant: AppButtonVariant.primary,
              height: 44.0,
              isFullWidth: true,
              onPressed: onPin,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotPreview(bool isDark, bool isPrivacy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'KITH · THIS MONTH',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.emeraldPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isPrivacy ? '₹••••' : '₹12,450',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        Text(
          '₹820 less than last month',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 0.62,
            minHeight: 5,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emeraldPrimary),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isPrivacy ? 'Budget: ₹••••' : 'Budget: ₹20,000',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            Text(
              isPrivacy ? '₹•••• left' : '₹7,550 left',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.emeraldPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAddPreview(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.emeraldPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Expense',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF27272E) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.mic_rounded, size: 16, color: AppColors.emeraldPrimary),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF27272E) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.indigoAccent),
        ),
      ],
    );
  }

  Widget _buildBudgetPreview(bool isDark, bool isPrivacy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AUGUST BUDGET',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const Text(
              '71%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isPrivacy ? '₹•••• / ₹••••' : '₹14,250 / ₹20,000',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 0.71,
            minHeight: 6,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emeraldPrimary),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isPrivacy ? '₹•••• left' : '₹5,750 left',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
            ),
            Text(
              isPrivacy ? '₹••••/day' : '₹460/day',
              style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDebtsPreview(bool isDark, bool isPrivacy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YOU\'RE OWED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            Text(
              isPrivacy ? '₹••••' : '₹1,850',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF27272E) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rahul', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              Text(isPrivacy ? '₹••••' : '₹1,200', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF27272E) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Priya', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              Text(isPrivacy ? '₹••••' : '₹650', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripPreview(bool isDark, bool isPrivacy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('✈️ GOA \'26', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            Text(
              '3 members',
              style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isPrivacy ? '₹•••• spent' : '₹8,420 spent',
          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF27272E) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your balance', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              Text(
                isPrivacy ? '₹••••' : '+₹1,240',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmartPreview(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.emeraldPrimary),
            SizedBox(width: 4),
            Text(
              'KITH INTELLIGENCE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.emeraldPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Rahul owes you ₹1,200',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        Text(
          'Tap to view lending record & settle',
          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
      ],
    );
  }
}
