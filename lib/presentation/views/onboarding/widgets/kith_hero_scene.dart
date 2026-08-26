import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/member_avatar.dart';

/// A cinematic, layered visual scene combining personal finance,
/// a subtle travel journey route, and live split expense chips.
/// 100% pure Flutter rendering — lightweight, high frame rate, zero network overhead.
class KithHeroScene extends StatefulWidget {
  const KithHeroScene({super.key});

  @override
  State<KithHeroScene> createState() => _KithHeroSceneState();
}

class _KithHeroSceneState extends State<KithHeroScene> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Keep proportional height between 210 and 260dp
        final double height = math.min(260.0, math.max(210.0, width * 0.65));

        return AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final double t = reduceMotion ? 0.0 : _animController.value;
            final double float1 = math.sin(t * math.pi) * 5.0;
            final double float2 = math.cos(t * math.pi) * 4.0;
            final double float3 = math.sin((t + 0.5) * math.pi) * 4.5;

            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // 1. BACKGROUND: Ambient Route Painter & Destination Nodes
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _JourneyRoutePainter(
                        isDark: isDark,
                        progress: t,
                      ),
                    ),
                  ),

                  // Destination Node 1: Left Top (Manali)
                  Positioned(
                    top: height * 0.08,
                    left: 12,
                    child: _buildLocationPill(
                      label: '🏔️ Manali',
                      isDark: isDark,
                    ),
                  ),

                  // Destination Node 2: Right Bottom (Goa)
                  Positioned(
                    bottom: height * 0.08,
                    right: 12,
                    child: _buildLocationPill(
                      label: '🏖️ ${l10n.onboardingSceneTrip}',
                      isDark: isDark,
                    ),
                  ),

                  // 2. LAYER 1 (Top Right): Minimalist Personal Budget Card
                  Positioned(
                    top: height * 0.12 + float1,
                    right: 16,
                    child: _buildPersonalFinanceCard(
                      isDark: isDark,
                      l10n: l10n,
                    ),
                  ),

                  // 3. LAYER 2 (Left Center): Group Trip Expense Card
                  Positioned(
                    top: height * 0.38 + float2,
                    left: 14,
                    child: _buildTripExpenseCard(
                      isDark: isDark,
                      l10n: l10n,
                    ),
                  ),

                  // 4. LAYER 3 (Center Bottom): Micro Settlement Chip
                  Positioned(
                    bottom: height * 0.06 + float3,
                    child: _buildSettlementChip(
                      isDark: isDark,
                      l10n: l10n,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLocationPill({
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildPersonalFinanceCard({
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    return Container(
      width: 185,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B22) : Colors.white,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(
          color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.onboardingSceneBudget,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.positiveGreenLight,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '₹18,400',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Clean progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: 0.74,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripExpenseCard({
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    return Container(
      width: 205,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D24) : Colors.white,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.amberAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('🍕', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onboardingSceneDinner,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      l10n.onboardingSceneSplit,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '₹850',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Overlapping Avatars & Per person pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 52,
                height: 18,
                child: Stack(
                  children: const [
                    Positioned(left: 0, child: MemberAvatar(name: 'Aarav', size: 18)),
                    Positioned(left: 14, child: MemberAvatar(name: 'Priya', size: 18)),
                    Positioned(left: 28, child: MemberAvatar(name: 'Rohan', size: 18)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '₹283 / person',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementChip({
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F161C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🚕', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            '${l10n.onboardingSceneCab} · ₹320',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.positiveGreenLight.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n.onboardingSceneSettled,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.positiveGreenDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for an abstract, glowing journey path linking travel destinations.
class _JourneyRoutePainter extends CustomPainter {
  final bool isDark;
  final double progress;

  _JourneyRoutePainter({required this.isDark, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Glowing S-curve path
    final path = Path()
      ..moveTo(w * 0.18, h * 0.22)
      ..cubicTo(
        w * 0.40,
        h * 0.05,
        w * 0.60,
        h * 0.70,
        w * 0.82,
        h * 0.78,
      );

    final glowPaint = Paint()
      ..color = (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..color = (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_JourneyRoutePainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.progress != progress;
  }
}
