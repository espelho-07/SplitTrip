import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';

/// Modal dialog shown immediately after account creation to showcase the user's Recovery Key.
class RecoveryKeyCreatedSheet extends StatelessWidget {
  final String recoveryKey;
  final VoidCallback onDismissed;

  const RecoveryKeyCreatedSheet({
    super.key,
    required this.recoveryKey,
    required this.onDismissed,
  });

  static Future<void> show(
    BuildContext context, {
    required String recoveryKey,
    required VoidCallback onDismissed,
  }) {
    HapticHelper.success();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecoveryKeyCreatedSheet(
        recoveryKey: recoveryKey,
        onDismissed: () {
          Navigator.of(ctx).pop();
          onDismissed();
        },
      ),
    );
  }

  void _copyKey(BuildContext context) {
    Clipboard.setData(ClipboardData(text: recoveryKey));
    HapticHelper.success();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recovery Key copied to clipboard! Keep it safe.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shield Icon with ambient emerald glow
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                border: Border.all(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.shield_outlined,
                  color: AppColors.emeraldPrimary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Text(
              'Your Recovery Key',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Explanatory Subtitle
            Text(
              'This is your permanent recovery credential. If you switch phones or reinstall Kith, use this key to restore all your trips and expenses.',
              style: TextStyle(
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Monospace Key Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      recoveryKey,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 1.2,
                        color: isDark ? AppColors.emeraldLight : const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    color: AppColors.emeraldPrimary,
                    tooltip: 'Copy Key',
                    onPressed: () => _copyKey(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Info hint badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_outlined, size: 16, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stored securely with salted hashing on cloud.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dismiss & Explore Button
            AppButton(
              text: "I've Saved It — Continue",
              onPressed: () {
                HapticHelper.medium();
                onDismissed();
              },
            ),
          ],
        ),
      ),
    );
  }
}
