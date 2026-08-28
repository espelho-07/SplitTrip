import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/models/trip_preview.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/join_trip_viewmodel.dart';
import '../../widgets/progress/progress.dart';

class TripPreviewView extends StatefulWidget {
  final String? code;

  const TripPreviewView({super.key, this.code});

  @override
  State<TripPreviewView> createState() => _TripPreviewViewState();
}

class _TripPreviewViewState extends State<TripPreviewView> {
  TripPreview? _preview;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPreview();
    });
  }

  Future<void> _fetchPreview() async {
    final code = widget.code?.trim().toUpperCase() ?? '';
    if (code.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No invite code provided';
      });
      return;
    }

    final joinVm = context.read<JoinTripViewModel>();
    final preview = await joinVm.fetchPreview(code);
    if (mounted) {
      setState(() {
        _preview = preview;
        _isLoading = false;
        if (preview == null) {
          _error = 'Trip not found or code expired';
        }
      });
    }
  }

  Future<void> _executeJoin() async {
    if (_preview == null) return;
    final authVm = context.read<AuthViewModel>();
    final joinVm = context.read<JoinTripViewModel>();
    final l10n = context.l10n;

    final user = authVm.currentUser;
    if (user == null) return;

    final stageNotifier = ValueNotifier<int>(0);
    final stages = [
      ProgressStage(label: l10n.joinStageValidating, description: 'Code: ${_preview!.inviteCode}'),
      ProgressStage(label: l10n.joinStageJoining, description: user.displayName),
      ProgressStage(label: l10n.joinStageSyncing, description: l10n.tripsBalances),
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
                title: l10n.tripsJoin,
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

    final trip = await joinVm.joinTrip(user, _preview!.inviteCode);
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      if (trip != null) {
        HapticHelper.success();
        context.read<HomeViewModel>().loadTrips(user.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.joinSuccessToast),
            backgroundColor: AppColors.emeraldPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/trip/${trip.id}');
      } else {
        HapticHelper.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(joinVm.errorMessage ?? 'Could not join trip'),
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.joinPreviewTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldLight))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.negativeRedDark),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.pop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  children: [
                    // Hero Trip Preview Card with Gradient
                    Container(
                      padding: const EdgeInsets.all(22.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF042F2E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _preview!.emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _preview!.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.joinPreviewHost} ${_preview!.creatorName}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Info Breakdown Grid
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoItem(
                            icon: Icons.people_alt_rounded,
                            label: l10n.joinPreviewMembers,
                            value: '${_preview!.memberCount}',
                            isDark: isDark,
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                          ),
                          _buildInfoItem(
                            icon: Icons.payments_rounded,
                            label: l10n.joinPreviewCurrency,
                            value: _preview!.currencyCode,
                            isDark: isDark,
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                          ),
                          _buildInfoItem(
                            icon: Icons.vpn_key_rounded,
                            label: 'Code',
                            value: _preview!.inviteCode,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Join Action CTA Button
                    GestureDetector(
                      onTap: () {
                        HapticHelper.medium();
                        _executeJoin();
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emeraldLight.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              l10n.joinPreviewConfirm,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.emeraldLight),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }
}
