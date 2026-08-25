import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/join_trip_viewmodel.dart';
import '../../widgets/progress/progress.dart';
import 'qr_scanner_view.dart';
import 'widgets/join_preview_sheet.dart';

class JoinTripView extends StatefulWidget {
  final String? initialCode;

  const JoinTripView({super.key, this.initialCode});

  @override
  State<JoinTripView> createState() => _JoinTripViewState();
}

class _JoinTripViewState extends State<JoinTripView> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!.trim().toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePreviewOrJoin(widget.initialCode!.trim().toUpperCase());
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handlePreviewOrJoin([String? directCode]) async {
    final joinVm = context.read<JoinTripViewModel>();
    final authVm = context.read<AuthViewModel>();

    final user = authVm.currentUser;
    if (user == null) return;

    if (directCode != null) {
      joinVm.setCode(directCode);
      _codeController.text = directCode;
    }

    final preview = await joinVm.fetchPreview();
    if (preview != null && mounted) {
      _showPreviewSheet(preview);
    } else if (mounted) {
      HapticHelper.error();
      final err = joinVm.errorMessage ?? 'Could not find a trip for code "${joinVm.code}". Please verify and retry.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.negativeRedDark,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleOpenQrScanner() async {
    HapticHelper.medium();
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerView()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      _handlePreviewOrJoin(scannedCode);
    }
  }

  void _showPreviewSheet(dynamic preview) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Consumer<JoinTripViewModel>(
          builder: (context, joinVm, child) {
            return JoinPreviewSheet(
              preview: preview,
              isJoining: joinVm.isJoining,
              onConfirmJoin: () async {
                final authVm = context.read<AuthViewModel>();
                final homeVm = context.read<HomeViewModel>();
                final user = authVm.currentUser;
                if (user == null) return;

                Navigator.of(bottomSheetContext).pop();

                final stageNotifier = ValueNotifier<int>(0);
                final stages = const [
                  ProgressStage(label: 'Checking invite code', description: 'Validating membership token'),
                  ProgressStage(label: 'Joining trip', description: 'Adding your ledger to group'),
                  ProgressStage(label: 'Syncing trip', description: 'Fetching expenses and balances'),
                ];

                // Show progress dialog
                showDialog(
                  context: this.context,
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
                            title: 'Joining trip…',
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

                final trip = await joinVm.joinTrip(user);

                if (mounted) {
                  Navigator.of(this.context, rootNavigator: true).pop(); // Dismiss progress

                  if (trip != null) {
                    await homeVm.loadTrips(user.id);
                    if (mounted) {
                      GoRouter.of(this.context).go('/trip/${trip.id}');
                      KithSuccessToast.show(this.context, "You're in ✓");
                    }
                  } else {
                    HapticHelper.error();
                    final err = joinVm.errorMessage ?? 'Could not join trip. Please check your network and retry.';
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(err),
                        backgroundColor: AppColors.negativeRedDark,
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: 'Retry',
                          textColor: Colors.white,
                          onPressed: () => _handlePreviewOrJoin(preview.inviteCode),
                        ),
                      ),
                    );
                  }
                }
              },
              onCancel: () {
                Navigator.of(bottomSheetContext).pop();
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final joinVm = context.watch<JoinTripViewModel>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Join a Trip'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Join Code',
                style: AppTypography.titleLarge(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ask your friend or trip creator for the 6-character trip code or QR invite.',
                style: AppTypography.bodyMedium(isDark: isDark),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Code Input Card
              SurfaceCard(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8.0,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        hintText: 'KITH00',
                        counterText: '',
                        hintStyle: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8.0,
                        ),
                      ),
                      onChanged: joinVm.setCode,
                      onSubmitted: (_) => _handlePreviewOrJoin(),
                    ),
                    if (joinVm.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        joinVm.errorMessage!,
                        style: TextStyle(
                          color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      text: 'Find Trip',
                      icon: Icons.search_rounded,
                      isFullWidth: true,
                      isLoading: joinVm.isLoadingPreview || joinVm.isJoining,
                      onPressed: _handlePreviewOrJoin,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // QR Code Scan Action Card
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _handleOpenQrScanner,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                          borderRadius: AppRadius.xlBorder,
                          border: Border.all(
                            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 72,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton.icon(
                      onPressed: _handleOpenQrScanner,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Scan QR Code Invite'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
