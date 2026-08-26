import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';

enum FeatureCraftingType { voice, receipt }

class FeatureCraftingHero extends StatefulWidget {
  final FeatureCraftingType type;
  final VoidCallback onSwitchToManual;

  const FeatureCraftingHero({
    super.key,
    required this.type,
    required this.onSwitchToManual,
  });

  @override
  State<FeatureCraftingHero> createState() => _FeatureCraftingHeroState();
}

class _FeatureCraftingHeroState extends State<FeatureCraftingHero> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final isVoice = widget.type == FeatureCraftingType.voice;

    final title = isVoice ? l10n.expenseVoiceCraftingTitle : l10n.expenseReceiptCraftingTitle;
    final desc = isVoice ? l10n.expenseVoiceCraftingDesc : l10n.expenseReceiptCraftingDesc;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.sm),

          // 1. CINEMATIC HERO COMPOSITION STACK
          SizedBox(
            height: 250,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double t = reduceMotion ? 0.0 : _controller.value;
                final double float1 = math.sin(t * math.pi) * 6.0;
                final double float2 = math.cos(t * math.pi) * 5.0;
                final double float3 = math.sin((t + 0.4) * math.pi) * 7.0;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Ambient Background Glow Aura
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (isVoice ? AppColors.emeraldPrimary : AppColors.amberAccent)
                                .withValues(alpha: isDark ? 0.22 : 0.14),
                            (isVoice ? AppColors.indigoAccent : AppColors.roseAccent)
                                .withValues(alpha: isDark ? 0.12 : 0.06),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),

                    // Central Visual Hero
                    if (isVoice)
                      _buildVoiceOrb(t, isDark)
                    else
                      _buildReceiptScanner(t, isDark),

                    // Floating Interactive Tag 1 (Top Left)
                    Positioned(
                      top: 24 + float1,
                      left: 12,
                      child: _buildFloatingTag(
                        icon: isVoice ? Icons.train_rounded : Icons.receipt_rounded,
                        label: isVoice ? l10n.expenseVoiceTagTrain : l10n.expenseReceiptTagTotal,
                        accentColor: isVoice ? AppColors.emeraldPrimary : AppColors.amberAccent,
                        isDark: isDark,
                      ),
                    ),

                    // Floating Interactive Tag 2 (Bottom Right)
                    Positioned(
                      bottom: 24 + float2,
                      right: 12,
                      child: _buildFloatingTag(
                        icon: isVoice ? Icons.restaurant_rounded : Icons.storefront_rounded,
                        label: isVoice ? l10n.expenseVoiceTagDinner : l10n.expenseReceiptTagMerchant,
                        accentColor: isVoice ? AppColors.indigoAccent : AppColors.emeraldPrimary,
                        isDark: isDark,
                      ),
                    ),

                    // Floating Interactive Tag 3 (Top Right / Bottom Left)
                    Positioned(
                      top: isVoice ? 36 + float3 : null,
                      bottom: isVoice ? null : 16 + float3,
                      right: isVoice ? 16 : null,
                      left: isVoice ? null : 20,
                      child: _buildFloatingTag(
                        icon: isVoice ? Icons.local_taxi_rounded : Icons.percent_rounded,
                        label: isVoice ? l10n.expenseVoiceTagCab : l10n.expenseReceiptTagTax,
                        accentColor: isVoice ? AppColors.amberAccent : AppColors.indigoAccent,
                        isDark: isDark,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 2. STATUS BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: (isVoice ? AppColors.emeraldPrimary : AppColors.amberAccent).withValues(alpha: 0.12),
              borderRadius: AppRadius.fullBorder,
              border: Border.all(
                color: (isVoice ? AppColors.emeraldPrimary : AppColors.amberAccent).withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isVoice ? AppColors.emeraldPrimary : AppColors.amberAccent,
                    boxShadow: [
                      BoxShadow(
                        color: (isVoice ? AppColors.emeraldPrimary : AppColors.amberAccent).withValues(alpha: 0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  l10n.expenseCraftingBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: isDark
                        ? (isVoice ? AppColors.emeraldLight : AppColors.amberAccent)
                        : (isVoice ? AppColors.emeraldDark : Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // 3. TITLE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge(isDark: isDark).copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // 4. DESCRIPTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              desc,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.45,
                fontSize: 13.5,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 5. NEXT UPDATE TIMELINE PILL
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              borderRadius: AppRadius.mdBorder,
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: isVoice ? AppColors.emeraldPrimary : AppColors.amberAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.expenseCraftingNextUpdate,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 6. ACTION CTA: SWITCH TO MANUAL
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: AppButton(
              text: l10n.expenseCraftingSwitchManual,
              icon: Icons.edit_note_rounded,
              onPressed: () {
                HapticHelper.light();
                widget.onSwitchToManual();
              },
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildVoiceOrb(double progress, bool isDark) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Expanding Pulse Ring
          CustomPaint(
            size: const Size(150, 150),
            painter: _VoiceWavePainter(
              progress: progress,
              color: AppColors.emeraldPrimary,
            ),
          ),

          // Core Glass Orb
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.emeraldLight,
                  AppColors.emeraldPrimary,
                  AppColors.indigoAccent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptScanner(double progress, bool isDark) {
    return Container(
      width: 130,
      height: 150,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(
          color: (isDark ? AppColors.amberAccent : Colors.amber.shade700).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Receipt Mock Texture Lines
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: AppRadius.fullBorder,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 80,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                    borderRadius: AppRadius.fullBorder,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 65,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                    borderRadius: AppRadius.fullBorder,
                  ),
                ),
                const Spacer(),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 30,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: AppRadius.fullBorder,
                      ),
                    ),
                    Container(
                      width: 35,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.amberAccent,
                        borderRadius: AppRadius.fullBorder,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Animated Laser Sweep Beam
          Positioned(
            top: (130 * progress).clamp(10.0, 130.0),
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.amberAccent,
                    Colors.white,
                    AppColors.amberAccent,
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amberAccent.withValues(alpha: 0.8),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTag({
    required IconData icon,
    required String label,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceCard.withValues(alpha: 0.90)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: AppRadius.fullBorder,
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accentColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceWavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _VoiceWavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 1; i <= 3; i++) {
      final double waveProgress = (progress + (i * 0.33)) % 1.0;
      final double radius = 38.0 + (waveProgress * 34.0);
      final double opacity = (1.0 - waveProgress).clamp(0.0, 1.0) * 0.45;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
