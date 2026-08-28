import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../data/services/sync_service.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/home_viewmodel.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';
import '../../../widgets/progress/progress.dart';

/// Focused bottom sheet for entering a recovery key and restoring account data.
class RecoveryKeySheet extends StatefulWidget {
  const RecoveryKeySheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticHelper.light();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const RecoveryKeySheet(),
    );
  }

  @override
  State<RecoveryKeySheet> createState() => _RecoveryKeySheetState();
}

class _RecoveryKeySheetState extends State<RecoveryKeySheet> {
  final TextEditingController _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handleRecover() async {
    final authVm = context.read<AuthViewModel>();
    final l10n = context.l10n;
    if (authVm.isLoading) return;

    final key = _keyController.text.trim().toUpperCase();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onboardingErrRecoveryRequired)),
      );
      return;
    }

    HapticHelper.medium();

    final stageNotifier = ValueNotifier<int>(0);
    final stages = [
      ProgressStage(label: l10n.statusRestoring, description: l10n.authRecoveryKey),
      ProgressStage(label: l10n.statusSyncing, description: l10n.authGoogleConnected),
      ProgressStage(label: l10n.statusSaved, description: l10n.tripsBalances),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => ValueListenableBuilder<int>(
        valueListenable: stageNotifier,
        builder: (ctx, activeStage, _) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: KithStageProgress(
                title: l10n.onboardingRestoringDialog,
                stages: stages,
                currentStageIndex: activeStage,
              ),
            ),
          );
        },
      ),
    );

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) stageNotifier.value = 1;
    });
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) stageNotifier.value = 2;
    });

    final user = await authVm.recoverSession(key);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress dialog

      if (user != null) {
        Navigator.pop(context); // Close bottom sheet
        final syncService = context.read<SyncService>();
        final apiClient = context.read<ApiClient>();
        final homeVm = context.read<HomeViewModel>();
        final personalVm = context.read<PersonalExpenseViewModel>();

        await syncService.flushQueue(apiClient);
        await homeVm.loadTrips(user.id);
        await personalVm.loadData(user.id);
        await personalVm.syncTripExpenses(user.id);

        if (mounted) {
          context.go('/home');
          KithSuccessToast.show(context, '${l10n.onboardingWelcomeBack}, ${user.displayName} ✓');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.onboardingErrRecoveryFailed)),
        );
      }
    }
  }

  Future<void> _handleReviewerLogin() async {
    final authVm = context.read<AuthViewModel>();
    final l10n = context.l10n;
    if (authVm.isLoading) return;

    HapticHelper.medium();
    final user = await authVm.signInAsReviewer(email: 'review.nirniq@gmail.com');

    if (user != null && mounted) {
      Navigator.pop(context);
      final syncService = context.read<SyncService>();
      final apiClient = context.read<ApiClient>();
      final homeVm = context.read<HomeViewModel>();
      final personalVm = context.read<PersonalExpenseViewModel>();

      await syncService.flushQueue(apiClient);
      await homeVm.loadTrips(user.id);
      await personalVm.loadData(user.id);
      await personalVm.syncTripExpenses(user.id);

      if (mounted) {
        context.go('/home');
        KithSuccessToast.show(context, '${l10n.onboardingWelcomeBack}, ${user.displayName} ✓');
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
              l10n.onboardingRecoverySheetTitle,
              style: AppTypography.titleMedium(isDark: isDark),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.onboardingRecoverySheetDesc,
              style: AppTypography.bodySmall(isDark: isDark),
            ),
            const SizedBox(height: 20),

            // Recovery Key Input
            TextField(
              controller: _keyController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'KITH-XXXX-YYYY',
                labelText: l10n.authRecoveryKey,
                prefixIcon: const Icon(Icons.key_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onSubmitted: (_) => _handleRecover(),
            ),
            const SizedBox(height: 20),

            // Restore CTA
            AppButton(
              text: l10n.onboardingRecoverySheetCta,
              isFullWidth: true,
              isLoading: authVm.isLoading,
              onPressed: _handleRecover,
            ),

            const SizedBox(height: 12),

            // Play Reviewer Quick Access Button
            Center(
              child: TextButton.icon(
                onPressed: _handleReviewerLogin,
                icon: const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.emeraldPrimary),
                label: Text(
                  'Reviewer Demo Access (review.nirniq@gmail.com)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
