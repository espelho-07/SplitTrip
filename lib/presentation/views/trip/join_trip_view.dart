import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/join_trip_viewmodel.dart';

class JoinTripView extends StatefulWidget {
  const JoinTripView({super.key});

  @override
  State<JoinTripView> createState() => _JoinTripViewState();
}

class _JoinTripViewState extends State<JoinTripView> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final joinVm = context.read<JoinTripViewModel>();
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();

    final user = authVm.currentUser;
    if (user == null) return;

    final trip = await joinVm.joinTrip(user);
    if (trip != null && mounted) {
      await homeVm.loadTrips(user.id);
      if (mounted) {
        context.go('/trip/${trip.id}');
      }
    }
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
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8.0,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        hintText: 'KITH00',
                        hintStyle: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8.0,
                        ),
                      ),
                      onChanged: joinVm.setCode,
                      onSubmitted: (_) => _handleJoin(),
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
                      text: 'Join Trip',
                      icon: Icons.login_rounded,
                      isFullWidth: true,
                      isLoading: joinVm.isJoining,
                      onPressed: _handleJoin,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // QR Code Scan Interface
              Center(
                child: Column(
                  children: [
                    Container(
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
                        Icons.qr_code_2_rounded,
                        size: 80,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Or point camera at QR code',
                      style: AppTypography.bodySmall(isDark: isDark),
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
