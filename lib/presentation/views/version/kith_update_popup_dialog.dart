import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../viewmodels/version_viewmodel.dart';

/// Ultra-attractive, exciting, premium modal dialog that encourages users
/// to update to the latest Play Store version with high-converting visual polish.
class KithUpdatePopupDialog extends StatelessWidget {
  const KithUpdatePopupDialog({super.key});

  /// Shows the update popup dialog if a new version is available and not yet shown this session.
  static Future<void> showIfAvailable(BuildContext context) async {
    final versionVm = context.read<VersionViewModel?>();
    if (versionVm == null || !versionVm.shouldShowBanner) return;

    // Check if required or optional update
    await showDialog<void>(
      context: context,
      barrierDismissible: !versionVm.shouldBlockApp,
      builder: (dialogCtx) => const KithUpdatePopupDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final versionVm = Provider.of<VersionViewModel>(context);

    final newVersion = versionVm.latestVersionString.isNotEmpty
        ? 'v${versionVm.latestVersionString}'
        : 'New Version';
    final releaseNotes = versionVm.releaseNotes.isNotEmpty
        ? versionVm.releaseNotes
        : '• Lightning-fast group expense syncing\n• Seamless UPI payment confirmation\n• Enhanced offline data safety and bug fixes';

    final isRequired = versionVm.shouldBlockApp;

    return PopScope(
      canPop: !isRequired,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1418) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? const Color(0x3314B8A6) : const Color(0xFF99F6E4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.25 : 0.15),
                blurRadius: 32,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Floating Glowing Rocket Icon
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF14B8A6).withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF14B8A6).withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 2. Pill Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF14B8A6)),
                        const SizedBox(width: 5),
                        Text(
                          '$newVersion is Live on Play Store',
                          style: const TextStyle(
                            color: Color(0xFF14B8A6),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Title & Subtitle
                  Text(
                    'Level Up Your Kith Experience! 🚀',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A fresh update is ready with smoother group splits, instant settlement sync, and enhanced security.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Feature Highlight Chips
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.stars_rounded, size: 16, color: Color(0xFF14B8A6)),
                            const SizedBox(width: 6),
                            Text(
                              "What's New in This Version:",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          releaseNotes,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Primary High-Energy CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticHelper.heavy();
                        final success = await versionVm.triggerUpdate();
                        if (success && context.mounted) {
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor: const Color(0xFF14B8A6).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.bolt_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Update on Play Store ⚡',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 6. Secondary "Later" action (only if not strictly required)
                  if (!isRequired) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        HapticHelper.light();
                        versionVm.dismissBanner();
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text(
                        "I'll update later",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
