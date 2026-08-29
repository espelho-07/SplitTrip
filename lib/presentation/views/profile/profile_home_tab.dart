import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../domain/enums/app_experience_mode.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../../data/services/sync_service.dart';
import '../../router/app_router.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../widgets/progress/progress.dart';
import '../cloud/cloud_sync_sheet.dart';
import '../language/language_select_sheet.dart';
import '../onboarding/interactive_tutorial_sheet.dart';
import '../settings/widgets/beta_feedback_sheet.dart';

class ProfileHomeTab extends StatelessWidget {
  const ProfileHomeTab({super.key});

  Future<void> _handleNirniqSignIn(BuildContext context) async {
    final authVm = context.read<AuthViewModel>();
    if (authVm.isLoading) return;

    HapticHelper.medium();
    await AuthProgressDialog.startNirniqSignIn(context);
  }

  void _showConnectedAppsSheet(BuildContext context, bool isDark) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hub_rounded, color: Color(0xFF0D9488), size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileConnectedApps,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      l10n.profileConnectedAppsDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Kith Active App Tile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.emeraldPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kith',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          l10n.profileConnectedAppsKith,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.emeraldPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CONNECTED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Future Nirniq ecosystem apps teaser
            Center(
              child: Text(
                l10n.profileConnectedAppsFuture,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) async {
    final l10n = context.l10n;
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final personalVm = context.read<PersonalExpenseViewModel>();
    final storage = context.read<LocalStorageService>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: Text(l10n.authSignOutTitle),
        content: Text(l10n.authSignOutDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.authSignOutConfirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AppRouter.router.go('/onboarding');
      await authVm.logout();
      await storage.clearAllUserData();
      homeVm.clearData();
      personalVm.clearData();

      final rootCtx = AppRouter.navigatorKey.currentContext;
      if (rootCtx != null && rootCtx.mounted) {
        KithSuccessToast.show(rootCtx, l10n.authSignOutSuccess);
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context) async {
    final l10n = context.l10n;
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final personalVm = context.read<PersonalExpenseViewModel>();
    final storage = context.read<LocalStorageService>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: Text(l10n.profileDeleteDialogTitle),
        content: Text(l10n.profileDeleteDialogDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negativeRedDark),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.profileDeleteConfirmBtn),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AppRouter.router.go('/onboarding');
      await authVm.deleteAccount();
      await storage.clearAllUserData();
      homeVm.clearData();
      personalVm.clearData();

      final rootCtx = AppRouter.navigatorKey.currentContext;
      if (rootCtx != null && rootCtx.mounted) {
        KithSuccessToast.show(rootCtx, l10n.profileDeleteSuccess);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final homeVm = context.watch<HomeViewModel>();
    final personalVm = context.watch<PersonalExpenseViewModel>();
    final themeVm = context.watch<ThemeViewModel>();

    LocaleViewModel? localeVm;
    try {
      localeVm = context.watch<LocaleViewModel>();
    } catch (_) {}

    final storage = context.watch<LocalStorageService>();
    SyncService? syncService;
    try {
      syncService = context.watch<SyncService>();
    } catch (_) {}

    final l10n = context.l10n;

    final user = authVm.currentUser;
    final displayName = user?.displayName ?? 'Darpan Parmar';
    final isNirniqLinked = user?.isNirniqLinked ?? false;
    final pendingCount = syncService?.pendingCount ?? 0;

    final tripsCount = homeVm.trips.length;
    final expensesCount = personalVm.expenses.length;
    final totalSpentPaise = homeVm.totalSpentOnTripsInPaise + personalVm.totalSpentInPaise;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      children: [
        // ─── 1. Profile Header & Identity ──────────────────────────────
        Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  MemberAvatar(
                    name: displayName,
                    avatarUrl: user?.avatarUrl,
                    size: 84,
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF14B8A6),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: (isNirniqLinked ? AppColors.emeraldPrimary : AppColors.indigoAccent)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isNirniqLinked ? l10n.profileNirniqConnected : l10n.profileGuestAccount,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isNirniqLinked ? AppColors.emeraldPrimary : AppColors.indigoAccent,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isNirniqLinked ? (user?.email ?? '') : '@${displayName.toLowerCase().replaceAll(' ', '')}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ─── 2. Stats Bar: Trips | Expenses | Total Spent ──────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1418) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('$tripsCount', 'Trips', isDark),
              _buildStatDivider(isDark),
              _buildStatItem('$expensesCount', 'Expenses', isDark),
              _buildStatDivider(isDark),
              _buildStatItem(
                CurrencyFormatter.formatPaise(totalSpentPaise, currencyCode: 'INR'),
                'Total Spent',
                isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── 3. SECTION: Account & Cloud ──────────────────────────────
        _buildSectionHeader('Nirniq Account & Cloud Sync', isDark),
        _buildMenuSection(
          isDark: isDark,
          children: [
            if (!isNirniqLinked)
              _buildMenuItem(
                icon: Icons.verified_user_rounded,
                title: l10n.profileConnectNirniq,
                subtitle: l10n.profileConnectNirniqDesc,
                iconColor: AppColors.emeraldPrimary,
                isDark: isDark,
                onTap: () => _handleNirniqSignIn(context),
              )
            else
              _buildMenuItem(
                icon: Icons.hub_rounded,
                title: l10n.profileConnectedApps,
                subtitle: l10n.profileConnectedAppsDesc,
                iconColor: const Color(0xFF0D9488),
                isDark: isDark,
                onTap: () => _showConnectedAppsSheet(context, isDark),
              ),
            _buildMenuItem(
              icon: Icons.key_rounded,
              title: l10n.authRecoveryKey,
              subtitle: user?.recoveryKey ?? 'N/A',
              iconColor: AppColors.emeraldPrimary,
              trailing: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  if (user?.recoveryKey != null) {
                    Clipboard.setData(ClipboardData(text: user!.recoveryKey));
                    HapticHelper.success();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.profileRecoveryCopied), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
              ),
              isDark: isDark,
              showArrow: false,
              onTap: () {
                if (user?.recoveryKey != null) {
                  Clipboard.setData(ClipboardData(text: user!.recoveryKey));
                  HapticHelper.success();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileRecoveryCopied), behavior: SnackBarBehavior.floating),
                  );
                }
              },
            ),
            _buildMenuItem(
              icon: Icons.cloud_sync_rounded,
              title: l10n.authCloudSync,
              subtitle: pendingCount > 0 ? '$pendingCount pending updates' : '✓ Synced in realtime',
              isDark: isDark,
              onTap: () => CloudSyncSheet.show(context),
            ),
            _buildMenuItem(
              icon: Icons.dns_outlined,
              title: 'Cloud Storage & Backups',
              subtitle: 'Configure offline auto-sync interval',
              isDark: isDark,
              onTap: () => context.push('/cloud-settings'),
            ),
            _buildMenuItem(
              icon: Icons.payment_rounded,
              title: 'Payment Methods',
              subtitle: storage.hasPaymentMethodConfigured()
                  ? '✓ Primary: ${storage.getPrimaryUpiId()}'
                  : 'UPI ID & QR code (Not set)',
              isDark: isDark,
              onTap: () => context.push('/payment-methods'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── 4. SECTION: Preferences & Appearance ──────────────────────
        _buildSectionHeader('Preferences & Appearance', isDark),
        _buildMenuSection(
          isDark: isDark,
          children: [
            _buildMenuItem(
              icon: Icons.translate_rounded,
              title: l10n.profileLanguage,
              subtitle: localeVm != null
                  ? '${localeVm.currentLanguage.flagEmoji} ${localeVm.currentLanguage.nativeName}'
                  : '🇮🇳 English',
              isDark: isDark,
              onTap: () => LanguageSelectSheet.show(context),
            ),
            _buildMenuItem(
              icon: Icons.auto_awesome_mosaic_rounded,
              title: 'App Experience Mode',
              subtitle: authVm.appExperienceMode == AppExperienceMode.tripsOnly
                  ? 'Trips Only (Focused)'
                  : 'Trips & Expenses (Full)',
              isDark: isDark,
              onTap: () => _showExperienceModeSheet(context, authVm, isDark),
            ),
            _buildMenuItem(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Live trip alerts & settlements',
              isDark: isDark,
              onTap: () => context.push('/notifications'),
            ),
            _buildMenuItem(
              icon: Icons.widgets_outlined,
              title: 'Android Widget Studio',
              subtitle: 'Homescreen quick glance cards',
              isDark: isDark,
              onTap: () => context.push('/widgets'),
            ),
            _buildMenuItem(
              icon: Icons.settings_outlined,
              title: 'Advanced Settings',
              subtitle: 'Security, biometrics & data export',
              isDark: isDark,
              onTap: () => context.push('/settings'),
            ),
            // Dark Mode Switch Item
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Icon(
                    Icons.dark_mode_outlined,
                    size: 20,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          isDark ? 'OLED Obsidian Black Theme' : 'Crisp Pure White Theme',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isDark,
                    activeTrackColor: const Color(0xFF14B8A6),
                    onChanged: (val) {
                      HapticHelper.selection();
                      themeVm.toggleTheme();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── 5. SECTION: Help & Support ─────────────────────────────────
        _buildSectionHeader('Help & Community', isDark),
        _buildMenuSection(
          isDark: isDark,
          children: [
            _buildMenuItem(
              icon: Icons.menu_book_rounded,
              title: l10n.guideTitle,
              subtitle: l10n.guideSubtitle,
              isDark: isDark,
              onTap: () => context.push('/guide'),
            ),
            _buildMenuItem(
              icon: Icons.help_outline_rounded,
              title: 'Help & FAQs',
              subtitle: 'Frequently asked questions & math guide',
              isDark: isDark,
              onTap: () => context.push('/help'),
            ),
            _buildMenuItem(
              icon: Icons.auto_stories_outlined,
              title: l10n.profileTour,
              subtitle: l10n.profileTourDesc,
              isDark: isDark,
              onTap: () => InteractiveTutorialSheet.show(context),
            ),
            _buildMenuItem(
              icon: Icons.shield_outlined,
              title: l10n.profilePrivacyPolicy,
              subtitle: 'Local-first zero telemetry guarantee',
              isDark: isDark,
              onTap: () => context.push('/privacy-policy'),
            ),
            _buildMenuItem(
              icon: Icons.feedback_outlined,
              title: l10n.profileFeedback,
              subtitle: 'Send feedback directly to creator',
              isDark: isDark,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const BetaFeedbackSheet(currentScreenContext: 'Profile Tab'),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── 6. SECTION: Danger Zone ────────────────────────────────────
        _buildSectionHeader('Account Actions', isDark),
        _buildMenuSection(
          isDark: isDark,
          children: [
            _buildMenuItem(
              icon: Icons.logout_rounded,
              title: 'Logout',
              titleColor: const Color(0xFFEF4444),
              isDark: isDark,
              showArrow: false,
              onTap: () => _showSignOutDialog(context),
            ),
            _buildMenuItem(
              icon: Icons.delete_forever_rounded,
              title: 'Delete Account & Data',
              titleColor: AppColors.negativeRedDark,
              isDark: isDark,
              showArrow: false,
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ],
        ),

        const SizedBox(height: 24),

        Center(
          child: Column(
            children: [
              Text(
                'Kith',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'by Nirniq · Paise-Perfect Split',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'v2.2.0 (Build 42)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 28,
      color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildMenuSection({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    Widget? trailing,
    bool showArrow = true,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticHelper.light();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? (isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A)),
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (showArrow)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
              ),
          ],
        ),
      ),
    );
  }

  void _showExperienceModeSheet(BuildContext context, AuthViewModel authVm, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bCtx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1418) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'App Experience Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose your preferred focus between full ledger or trip-only experience',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            _buildExperienceModeOption(
              context: context,
              title: 'Trips & Expenses',
              subtitle: 'Full experience with personal expense ledger, analytics, and group trip splits',
              icon: Icons.pie_chart_outline_rounded,
              isSelected: authVm.appExperienceMode == AppExperienceMode.all,
              isDark: isDark,
              onTap: () async {
                HapticHelper.selection();
                await authVm.setAppExperienceMode(AppExperienceMode.all);
                if (bCtx.mounted) Navigator.pop(bCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switched to Trips & Expenses mode'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            _buildExperienceModeOption(
              context: context,
              title: 'Trips Only',
              subtitle: 'Streamlined UI focused purely on group trips, splits, and instant settlements',
              icon: Icons.flight_takeoff_rounded,
              isSelected: authVm.appExperienceMode == AppExperienceMode.tripsOnly,
              isDark: isDark,
              onTap: () async {
                HapticHelper.selection();
                await authVm.setAppExperienceMode(AppExperienceMode.tripsOnly);
                if (bCtx.mounted) Navigator.pop(bCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switched to Trips Only mode'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceModeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.18 : 0.08)
                : (isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF14B8A6)
                  : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF14B8A6).withValues(alpha: 0.2)
                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? const Color(0xFF14B8A6)
                      : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF14B8A6),
                  size: 22,
                )
              else
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
