import 'recovery_key_created_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/enums/app_experience_mode.dart';
import '../../../router/app_router.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/locale_viewmodel.dart';
import '../../../widgets/progress/progress.dart';

/// Compact, focused bottom sheet for configuring a guest user session.
class GuestSetupSheet extends StatefulWidget {
  const GuestSetupSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticHelper.light();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const GuestSetupSheet(),
    );
  }

  @override
  State<GuestSetupSheet> createState() => _GuestSetupSheetState();
}

class _GuestSetupSheetState extends State<GuestSetupSheet> {
  final TextEditingController _nameController = TextEditingController();
  final AppExperienceMode _selectedMode = AppExperienceMode.tripsOnly;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleStart() async {
    final authVm = context.read<AuthViewModel>();
    final localeVm = context.read<LocaleViewModel>();
    final l10n = context.l10n;
    if (authVm.isLoading || _isSubmitting) return;

    final rawName = _nameController.text.trim();
    final name = rawName.isEmpty ? 'Traveler' : rawName;

    setState(() => _isSubmitting = true);
    HapticHelper.medium();
    localeVm.markInitialLanguageSelected();

    try {
      final user = await authVm.createGuestSession(name, _selectedMode);
      if (mounted) {
        Navigator.of(context).pop();
      }
      final rootCtx = AppRouter.navigatorKey.currentContext;
      if (rootCtx != null && rootCtx.mounted) {
        await RecoveryKeyCreatedSheet.show(
          rootCtx,
          recoveryKey: user.recoveryKey,
          onDismissed: () {
            rootCtx.go('/home');
            KithSuccessToast.show(rootCtx, l10n.onboardingWelcomeToast);
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop();
      }
      final rootCtx = AppRouter.navigatorKey.currentContext;
      if (rootCtx != null && rootCtx.mounted) {
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          SnackBar(content: Text(l10n.onboardingErrGuestFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: bottomInset + MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Text(
              l10n.onboardingGuestSheetTitle,
              style: AppTypography.titleMedium(isDark: isDark),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.onboardingGuestSheetDesc,
              style: AppTypography.bodySmall(isDark: isDark),
            ),
            const SizedBox(height: 18),

            // Display Name Input
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: l10n.onboardingNameHint,
                labelText: l10n.onboardingGuestName,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onSubmitted: (_) => _handleStart(),
            ),
            const SizedBox(height: 24),

            // Start CTA
            AppButton(
              text: l10n.onboardingGuestSheetCta,
              isFullWidth: true,
              isLoading: authVm.isLoading,
              onPressed: _handleStart,
            ),
          ],
        ),
      ),
    );
  }

}
