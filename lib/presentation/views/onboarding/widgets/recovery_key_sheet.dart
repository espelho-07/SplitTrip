import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/recovery_key_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../recovery_progress_view.dart';

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
  bool _isSubmitting = false;

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
    final l10n = context.l10n;
    if (_isSubmitting) return;

    final rawInput = _keyController.text.trim();
    final key = RecoveryKeyService.normalizeKey(rawInput);
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onboardingErrRecoveryRequired)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticHelper.medium();

    final navigator = Navigator.of(context);
    navigator.pop(); // Dismiss sheet smoothly

    // Transition immediately to dedicated recovery progress screen
    RecoveryProgressView.push(context, key);
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
              text: _isSubmitting ? 'Verifying key...' : l10n.onboardingRecoverySheetCta,
              isFullWidth: true,
              isLoading: _isSubmitting,
              onPressed: _handleRecover,
            ),
          ],
        ),
      ),
    );
  }
}
