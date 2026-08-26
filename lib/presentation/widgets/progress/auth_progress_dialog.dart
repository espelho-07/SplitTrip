import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/services/sync_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';

class AuthProgressStep {
  final String title;
  final String description;
  final double targetPercentage;

  const AuthProgressStep({
    required this.title,
    required this.description,
    required this.targetPercentage,
  });
}

/// A modern, high-polish full-screen / modal progress dialog with animated percentage,
/// live stage checklists, and status indicators during Google Sign-In and Cloud Restore.
class AuthProgressDialog extends StatefulWidget {
  const AuthProgressDialog({super.key});

  /// Opens the progress dialog and executes the complete Google Sign-In + Cloud Restore sequence.
  static Future<bool> startGoogleSignIn(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => const AuthProgressDialog(),
    );
    return result ?? false;
  }

  @override
  State<AuthProgressDialog> createState() => _AuthProgressDialogState();
}

class _AuthProgressDialogState extends State<AuthProgressDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  double _progress = 0.05;
  String _statusTitle = 'Connecting to Google…';
  String _statusSubtitle = 'Opening account picker';
  int _activeStepIndex = 0;
  String? _errorMessage;
  bool _isSuccess = false;
  String? _userName;

  static const List<AuthProgressStep> _steps = [
    AuthProgressStep(
      title: 'Google Sign-In',
      description: 'Selecting Google account & verifying credentials',
      targetPercentage: 0.25,
    ),
    AuthProgressStep(
      title: 'Authenticating Identity',
      description: 'Connecting to Kith Cloud Ledger',
      targetPercentage: 0.50,
    ),
    AuthProgressStep(
      title: 'Restoring Trips & Members',
      description: 'Hydrating group expenses & live balances',
      targetPercentage: 0.75,
    ),
    AuthProgressStep(
      title: 'Syncing Personal Finances',
      description: 'Downloading expenses, debts & monthly budgets',
      targetPercentage: 0.95,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeSignInFlow();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateProgress(double target, String title, String subtitle, int stepIndex) {
    if (!mounted) return;
    setState(() {
      _progress = target;
      _statusTitle = title;
      _statusSubtitle = subtitle;
      _activeStepIndex = stepIndex;
    });
    HapticHelper.light();
  }

  Future<void> _executeSignInFlow() async {
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final personalVm = context.read<PersonalExpenseViewModel>();
    final apiClient = context.read<ApiClient>();
    final syncService = context.read<SyncService>();

    try {
      // Allow bottom sheet transition to settle cleanly
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      // Step 1: Google Account Picker
      _updateProgress(
        0.15,
        'Connecting to Google…',
        'Please select your account from the popup',
        0,
      );

      final GoogleAuthResult? googleResult = await GoogleAuthService.signIn();
      if (googleResult == null) {
        // User cancelled picker
        if (mounted) Navigator.of(context).pop(false);
        return;
      }

      // Step 2: Canonicalize User & Token in Cloud
      _updateProgress(
        0.40,
        'Verifying Identity…',
        'Linking canonical cloud profile for ${googleResult.email}',
        1,
      );

      final user = await authVm.signInWithGoogle(
        email: googleResult.email,
        displayName: googleResult.displayName,
        googleId: googleResult.googleId,
        photoUrl: googleResult.avatarUrl,
        supabaseUserId: googleResult.supabaseUserId,
      );

      if (user == null) {
        throw Exception(authVm.errorMessage ?? 'Could not authenticate with cloud server.');
      }

      _userName = user.displayName;

      // Step 3: Flush Local Queues & Fetch Trips
      _updateProgress(
        0.65,
        'Restoring Trips & Balances…',
        'Downloading your active trips, members & expenses',
        2,
      );

      try {
        await syncService.flushQueue(apiClient);
      } catch (_) {}

      await homeVm.loadTrips(user.id);

      // Step 4: Fetch Personal Expenses, Debts, Budgets
      _updateProgress(
        0.88,
        'Syncing Personal Ledger…',
        'Restoring personal expenses, lending records & budget',
        3,
      );

      await personalVm.loadData(user.id);
      await personalVm.syncTripExpenses(user.id);

      // Step 5: 100% Success
      if (!mounted) return;
      setState(() {
        _progress = 1.0;
        _isSuccess = true;
        _activeStepIndex = 4;
        _statusTitle = 'Welcome back, ${_userName ?? 'there'}! ✓';
        _statusSubtitle = 'Everything is up to date';
      });
      HapticHelper.success();

      // Smooth auto-navigation after celebration
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      if (e.failure == GoogleSignInFailure.cancelled) {
        Navigator.of(context).pop(false);
        return;
      }
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentInt = (_progress * 100).toInt().clamp(0, 100);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Central Circular Progress with Percentage & Badge
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glowing Ring Pulse
              AnimatedBuilder(
                animation: _pulseController,
                builder: (ctx, child) {
                  return Container(
                    width: 120 + (_pulseController.value * 8),
                    height: 120 + (_pulseController.value * 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_isSuccess ? AppColors.emeraldPrimary : AppColors.indigoAccent)
                          .withValues(alpha: 0.08 + (_pulseController.value * 0.08)),
                    ),
                  );
                },
              ),

              // Circular Progress Indicator
              SizedBox(
                width: 110,
                height: 110,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _progress),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (ctx, val, _) {
                    return CircularProgressIndicator(
                      value: val,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isSuccess
                            ? AppColors.emeraldPrimary
                            : _errorMessage != null
                                ? Colors.redAccent
                                : AppColors.emeraldPrimary,
                      ),
                    );
                  },
                ),
              ),

              // Center Content: Percentage or Success Icon
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSuccess)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 44,
                      color: AppColors.emeraldPrimary,
                    ).animate().scale(duration: 300.ms, curve: Curves.elasticOut)
                  else if (_errorMessage != null)
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: Colors.redAccent,
                    )
                  else ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: percentInt.toDouble()),
                      duration: const Duration(milliseconds: 300),
                      builder: (ctx, val, _) {
                        return Text(
                          '${val.toInt()}%',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        );
                      },
                    ),
                    Text(
                      'SYNCING',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Dynamic Status Title
          Text(
            _statusTitle,
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge(isDark: isDark).copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 4),

          // Dynamic Status Subtitle / Error
          Text(
            _errorMessage ?? _statusSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _errorMessage != null
                  ? Colors.redAccent
                  : isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Linear Animated Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _progress),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (ctx, val, _) {
                  return LinearProgressIndicator(
                    value: val,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isSuccess
                          ? AppColors.emeraldPrimary
                          : _errorMessage != null
                              ? Colors.redAccent
                              : AppColors.emeraldPrimary,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Step-by-Step Stage Checklist
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              borderRadius: AppRadius.mdBorder,
            ),
            child: Column(
              children: List.generate(_steps.length, (index) {
                final step = _steps[index];
                final isDone = _isSuccess || _activeStepIndex > index;
                final isCurrent = !_isSuccess && _activeStepIndex == index && _errorMessage == null;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      // Step Status Icon
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppColors.emeraldPrimary
                              : isCurrent
                                  ? AppColors.emeraldPrimary.withValues(alpha: 0.2)
                                  : isDark
                                      ? Colors.white12
                                      : Colors.black12,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                              : isCurrent
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldPrimary),
                                      ),
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Step Label
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrent || isDone ? FontWeight.w700 : FontWeight.w500,
                                color: isDone
                                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                                    : isCurrent
                                        ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (isDone)
                        const Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                        _progress = 0.05;
                      });
                      _executeSignInFlow();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emeraldPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
                    ),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
