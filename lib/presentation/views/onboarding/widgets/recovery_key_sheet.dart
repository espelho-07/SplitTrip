import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/recovery_key_service.dart';
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
  bool _isRestoring = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      final normalized = RecoveryKeyService.normalizeKey(text);
      _keyController.text = normalized.isNotEmpty ? normalized : text.toUpperCase();
      HapticHelper.selection();
    }
  }

  Future<void> _handleRecover() async {
    final authVm = context.read<AuthViewModel>();
    final l10n = context.l10n;
    if (_isRestoring || authVm.isLoading) return;

    final rawInput = _keyController.text.trim();
    final key = RecoveryKeyService.normalizeKey(rawInput);
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onboardingErrRecoveryRequired)),
      );
      return;
    }

    setState(() => _isRestoring = true);
    HapticHelper.medium();

    try {
      final user = await authVm.recoverSession(key);

      if (!mounted) return;

      if (user != null) {
        Navigator.pop(context); // Close bottom sheet
        final syncService = context.read<SyncService>();
        final apiClient = context.read<ApiClient>();
        final homeVm = context.read<HomeViewModel>();
        final personalVm = context.read<PersonalExpenseViewModel>();

        await syncService.reconcileWithCloud(user.effectiveAccountId, apiClient: apiClient);
        await homeVm.loadTrips(user.id);
        await personalVm.loadData(user.id);
        await personalVm.syncTripExpenses(user.id);

        if (mounted) {
          context.go('/home');
          KithSuccessToast.show(context, '${l10n.onboardingWelcomeBack}, ${user.displayName} ✓');
        }
      } else {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recovery key is incorrect. Please verify and try again.'),
            backgroundColor: AppColors.negativeRedDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.negativeRedDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'KITH-XXXX-XXXX-XXXX-XXXX',
                labelText: l10n.authRecoveryKey,
                prefixIcon: const Icon(Icons.key_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded, size: 20),
                  tooltip: 'Paste from clipboard',
                  onPressed: _pasteFromClipboard,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onSubmitted: (_) => _handleRecover(),
            ),
            const SizedBox(height: 20),

            // Restore CTA
            AppButton(
              text: _isRestoring ? 'Restoring your Kith data...' : l10n.onboardingRecoverySheetCta,
              isFullWidth: true,
              isLoading: _isRestoring,
              onPressed: _handleRecover,
            ),
          ],
        ),
      ),
    );
  }
}
