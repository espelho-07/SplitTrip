import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/kith_widget_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_brand.dart';
import '../../../core/widgets/surface_card.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';

/// Master Interactive Widget Studio for Android Home Screen Widgets.
/// Provides live interactive previews, privacy mode toggles, and 1-tap launcher pinning.
class WidgetGalleryView extends StatefulWidget {
  const WidgetGalleryView({super.key});

  @override
  State<WidgetGalleryView> createState() => _WidgetGalleryViewState();
}

class _WidgetGalleryViewState extends State<WidgetGalleryView> {
  bool _useLiveData = false;

  Future<void> _handlePinWidget(String type, String name) async {
    final widgetService = context.read<KithWidgetService>();
    final l10n = context.l10n;
    HapticHelper.medium();

    final isSupported = await widgetService.isPinningSupported();

    if (!isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.widgetsLongPressHelp),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final success = await widgetService.requestPinWidget(type);
    if (mounted) {
      if (success) {
        HapticHelper.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.widgetsPinButton} - $name ✓'),
            backgroundColor: AppColors.emeraldPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.widgetsLongPressHelp),
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
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Ambient Radial Emerald Aura
          if (isDark)
            Positioned(
              top: -80,
              right: -50,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.emeraldLight.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                // 1. Master Top Bar
                _buildTopBar(context, isDark, l10n),

                // 2. Main Studio Scroll View
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    children: [
                      // Studio Header & Subtitle
                      Text(
                        l10n.widgetsGalleryHeader,
                        style: AppTypography.titleLarge(isDark: isDark).copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.widgetsGallerySub,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Control Strip: Privacy Mode & Data Mode Switcher
                      _buildControlStrip(context, isDark, widgetService, authVm, personalVm, homeVm, l10n),

                      const SizedBox(height: AppSpacing.xl),

                      // Section Header
                      _buildSectionHeader(l10n.widgetsSecAvailable, isDark),
                      const SizedBox(height: 12),

                      // 1. Kith Snapshot (4×2 Hero)
                      _buildWidgetCard(
                        context: context,
                        title: l10n.widgetsCardSnapshotTitle,
                        badge: 'HERO',
                        badgeColor: AppColors.emeraldLight,
                        sizeLabel: '4 × 2 · Medium',
                        description: l10n.widgetsCardSnapshotDesc,
                        previewContent: _buildSnapshotPreview(isDark, widgetService.isPrivacyMode, personalVm),
                        onPin: () => _handlePinWidget('snapshot', l10n.widgetsCardSnapshotTitle),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 2. Quick Add Bar (4×1 VIP)
                      _buildWidgetCard(
                        context: context,
                        title: l10n.widgetsCardQuickAddTitle,
                        badge: 'FASTEST',
                        badgeColor: AppColors.indigoAccent,
                        sizeLabel: '4 × 1 · Compact',
                        description: l10n.widgetsCardQuickAddDesc,
                        previewContent: _buildQuickAddPreview(isDark),
                        onPin: () => _handlePinWidget('quick_add', l10n.widgetsCardQuickAddTitle),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 3. Budget Health Runway (3×2)
                      _buildWidgetCard(
                        context: context,
                        title: l10n.widgetsCardBudgetTitle,
                        badge: 'ESSENTIAL',
                        badgeColor: AppColors.amberAccent,
                        sizeLabel: '3 × 2 · Medium',
                        description: l10n.widgetsCardBudgetDesc,
                        previewContent: _buildBudgetPreview(isDark, widgetService.isPrivacyMode, personalVm),
                        onPin: () => _handlePinWidget('budget', l10n.widgetsCardBudgetTitle),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 4. Debts & Lending Matrix (3×2)
                      _buildWidgetCard(
                        context: context,
                        title: l10n.widgetsCardDebtsTitle,
                        badge: 'BALANCE',
                        badgeColor: AppColors.positiveGreenLight,
                        sizeLabel: '3 × 2 · Medium',
                        description: l10n.widgetsCardDebtsDesc,
                        previewContent: _buildDebtsPreview(isDark, widgetService.isPrivacyMode, personalVm),
                        onPin: () => _handlePinWidget('debts', l10n.widgetsCardDebtsTitle),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 5. Active Trip Card (4×2)
                      _buildWidgetCard(
                        context: context,
                        title: l10n.widgetsCardTripTitle,
                        badge: 'TRAVEL',
                        badgeColor: AppColors.indigoAccent,
                        sizeLabel: '4 × 2 · Medium',
                        description: l10n.widgetsCardTripDesc,
                        previewContent: _buildTripPreview(isDark, widgetService.isPrivacyMode, homeVm),
                        onPin: () => _handlePinWidget('trip', l10n.widgetsCardTripTitle),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 6. Smart Kith Adaptive AI (4×2)
                      _buildWidgetCard(
                        context: context,
                        title: l10n.widgetsCardSmartTitle,
                        badge: 'SIGNATURE',
                        badgeColor: AppColors.emeraldLight,
                        sizeLabel: '4 × 2 · Medium',
                        description: l10n.widgetsCardSmartDesc,
                        previewContent: _buildSmartPreview(isDark),
                        onPin: () => _handlePinWidget('smart', l10n.widgetsCardSmartTitle),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // Launcher Manual Guide Footnote
                      _buildLauncherGuide(context, isDark, l10n),

                      const SizedBox(height: 40),
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

  Widget _buildTopBar(BuildContext context, bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              context.pop();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KithLogoMark(size: 16, isDark: isDark),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'KITH · WIDGET STUDIO',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Live Data Toggle Pill
          GestureDetector(
            onTap: () {
              HapticHelper.selection();
              setState(() => _useLiveData = !_useLiveData);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _useLiveData
                    ? AppColors.emeraldPrimary.withValues(alpha: 0.18)
                    : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _useLiveData ? AppColors.emeraldLight : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _useLiveData ? AppColors.emeraldLight : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _useLiveData ? 'Live' : 'Demo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _useLiveData ? AppColors.emeraldLight : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlStrip(
    BuildContext context,
    bool isDark,
    KithWidgetService widgetService,
    AuthViewModel authVm,
    PersonalExpenseViewModel personalVm,
    HomeViewModel homeVm,
    AppLocalizations l10n,
  ) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (widgetService.isPrivacyMode ? AppColors.amberAccent : AppColors.emeraldLight).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              widgetService.isPrivacyMode ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: widgetService.isPrivacyMode ? AppColors.amberAccent : AppColors.emeraldLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.widgetsPrivacyTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  l10n.widgetsPrivacyDesc,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
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
            activeThumbColor: AppColors.emeraldLight,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.emeraldLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title, Badge & Dimensions
          Row(
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                sizeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Real Realistic Android Widget Frame
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1418) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: previewContent,
          ),

          const SizedBox(height: AppSpacing.md),

          // Action Button
          GestureDetector(
            onTap: onPin,
            child: Container(
              height: 46,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emeraldLight.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_to_home_screen_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.widgetsPinButton,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotPreview(bool isDark, bool isPrivacy, PersonalExpenseViewModel personalVm) {
    final amountStr = _useLiveData
        ? (isPrivacy ? '₹••••' : CurrencyFormatter.formatPaise(personalVm.totalSpentInPaise, currencyCode: 'INR'))
        : (isPrivacy ? '₹••••' : '₹12,450');

    final progressVal = _useLiveData
        ? (personalVm.budget.hasBudget ? (personalVm.budget.percentageUsed / 100.0).clamp(0.0, 1.0) : 0.62)
        : 0.62;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  const KithLogoMark(size: 14, isDark: true),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'KITH · THIS MONTH',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: AppColors.emeraldPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, size: 13, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amountStr,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        Text(
          '₹820 less than last month · On Track',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.emeraldLight,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressVal,
            minHeight: 5,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emeraldLight),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isPrivacy ? 'Budget: ₹••••' : 'Budget: ₹20,000',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            Text(
              isPrivacy ? '₹•••• left' : '₹7,550 left',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.emeraldLight,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
              ),
              borderRadius: BorderRadius.circular(14),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2630) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          ),
          child: const Icon(Icons.mic_rounded, size: 18, color: AppColors.emeraldLight),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2630) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          ),
          child: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.indigoAccent),
        ),
      ],
    );
  }

  Widget _buildBudgetPreview(bool isDark, bool isPrivacy, PersonalExpenseViewModel personalVm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'AUGUST BUDGET HEALTH',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.emeraldLight.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '71% USED',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.emeraldLight),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isPrivacy ? '₹•••• / ₹••••' : '₹14,250 / ₹20,000',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 0.71,
            minHeight: 6,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emeraldLight),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isPrivacy ? '₹•••• left' : '₹5,750 left',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emeraldLight),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isPrivacy ? '₹••••/day' : '₹460/day safe runway',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDebtsPreview(bool isDark, bool isPrivacy, PersonalExpenseViewModel personalVm) {
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.positiveGreenLight),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161D24) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.indigoAccent),
                      alignment: Alignment.center,
                      child: const Text('R', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Rahul Sharma',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isPrivacy ? '₹••••' : '+₹1,200',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.positiveGreenLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161D24) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.roseAccent),
                      alignment: Alignment.center,
                      child: const Text('P', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Priya Patel',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isPrivacy ? '₹••••' : '+₹650',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.positiveGreenLight),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripPreview(bool isDark, bool isPrivacy, HomeViewModel homeVm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                '🏖️ GOA ESCAPE \'26',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Day 3 of 5',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isPrivacy ? '₹•••• total spent' : '₹8,420 total spent',
          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161D24) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Your Net Balance',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isPrivacy ? '₹••••' : '+₹1,240 (You get)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.positiveGreenLight),
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
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.emeraldLight),
            const SizedBox(width: 5),
            Text(
              'KITH INTELLIGENCE ENGINE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.emeraldLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Rahul owes you ₹1,200 for Goa Airbnb',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          'Tap widget on home screen to view lending ledger & 1-tap WhatsApp reminder',
          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
      ],
    );
  }

  Widget _buildLauncherGuide(BuildContext context, bool isDark, AppLocalizations l10n) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_rounded, size: 18, color: AppColors.emeraldLight),
              const SizedBox(width: 8),
              Text(
                l10n.widgetsLauncherHelpTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGuideStep('1', 'Long press any empty area on your Android Home Screen', isDark),
          const SizedBox(height: 8),
          _buildGuideStep('2', 'Select Widgets and scroll down to find Kith', isDark),
          const SizedBox(height: 8),
          _buildGuideStep('3', 'Touch and hold your favorite widget and place it on home screen', isDark),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String number, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.emeraldPrimary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.emeraldLight),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
