import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/services/local_storage_service.dart';

/// 3-Screen Fullscreen Interactive Onboarding Walkthrough Flow.
///
/// Features:
/// 1. Slide 1: Group Trips & Zero-Leakage Bill Splitting
/// 2. Slide 2: Personal Finances, Budget Runway & Voice AI
/// 3. Slide 3: 1-Tap UPI Settlements, QR Code & Offline Sync
///
/// Smooth swipeable PageView with animated indicator pills, Skip button,
/// and seamless transition to the Login / Auth experience.
class WalkthroughView extends StatefulWidget {
  const WalkthroughView({super.key});

  @override
  State<WalkthroughView> createState() => _WalkthroughViewState();
}

class _WalkthroughViewState extends State<WalkthroughView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeWalkthrough() async {
    HapticHelper.success();
    final storage = context.read<LocalStorageService>();
    await storage.setOnboardingCompleted(true);
    if (mounted) {
      context.go('/onboarding');
    }
  }

  void _nextPage() {
    HapticHelper.selection();
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeWalkthrough();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final bgColor = isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC);

    final slides = [
      _WalkthroughSlideData(
        badge: 'SMART GROUP EXPENSES',
        badgeColor: AppColors.emeraldPrimary,
        title: 'Split Trips &\nGroup Adventures',
        description: 'Effortlessly create trips, split group bills with friends, and calculate zero-leakage balances in realtime.',
        visualBuilder: (isDark) => _buildTripSplitVisual(isDark),
      ),
      _WalkthroughSlideData(
        badge: 'OFFLINE P2P RADAR',
        badgeColor: AppColors.indigoAccent,
        title: 'Nearby Friends &\nOffline P2P Sync',
        description: 'Discover nearby travel companions via Bluetooth & Wi-Fi radar, and sync expenses seamlessly without internet.',
        visualBuilder: (isDark) => _buildP2pRadarVisual(isDark),
      ),
      _WalkthroughSlideData(
        badge: 'INSTANT UPI PAYMENTS',
        badgeColor: AppColors.amberAccent,
        title: '1-Tap UPI Settlements\n& Live QR',
        description: 'Settle debts with one tap directly into Google Pay, PhonePe, or Paytm with instant cloud sync and offline backup.',
        visualBuilder: (isDark) => _buildUpiSettlementVisual(isDark),
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: bgColor,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: bgColor,
            ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // ─── TOP BAR: BRAND & SKIP BUTTON ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.emeraldPrimary, Color(0xFF10B981)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.blur_on_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'KITH',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            color: isDark ? Colors.white : AppColors.darkSurfaceCard,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _completeWalkthrough,
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: Text(
                        l10n.actionSkip,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── SLIDE CAROUSEL ─────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: slides.length,
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),

                          // Visual Illustration Area
                          slide.visualBuilder(isDark)
                              .animate(key: ValueKey('vis_$index'))
                              .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                              .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1), duration: 450.ms),

                          const Spacer(),

                          // Category Badge Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: slide.badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: slide.badgeColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              slide.badge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: slide.badgeColor,
                              ),
                            ),
                          )
                              .animate(key: ValueKey('badge_$index'))
                              .fadeIn(delay: 100.ms, duration: 300.ms),

                          const SizedBox(height: 16),

                          // Slide Headline
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: AppTypography.titleLarge(isDark: isDark).copyWith(
                              height: 1.15,
                              fontSize: 26,
                            ),
                          )
                              .animate(key: ValueKey('title_$index'))
                              .fadeIn(delay: 150.ms, duration: 350.ms)
                              .slideY(begin: 0.1, end: 0, duration: 350.ms),

                          const SizedBox(height: 12),

                          // Slide Subtitle
                          Text(
                            slide.description,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                              height: 1.45,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          )
                              .animate(key: ValueKey('desc_$index'))
                              .fadeIn(delay: 200.ms, duration: 350.ms),

                          const SizedBox(height: 32),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ─── BOTTOM CONTROLS & INDICATOR ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Indicator Dots / Pills
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        final isActive = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.emeraldPrimary
                                : (isDark ? Colors.white24 : Colors.black12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    // Primary Action Button
                    AppButton(
                      text: _currentPage == 2 ? 'Start Exploring Kith →' : 'Continue →',
                      isFullWidth: true,
                      onPressed: _nextPage,
                    ),

                    const SizedBox(height: 12),

                    // Quick Jump to Login
                    GestureDetector(
                      onTap: _completeWalkthrough,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'Already have an account? Sign In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                          ),
                        ),
                      ),
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

  // ─── SLIDE 1 VISUAL: GROUP EXPENSE SPLIT ─────────────────────────────────
  Widget _buildTripSplitVisual(bool isDark) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.emeraldPrimary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Goa Beach Villa 🌴',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.darkSurfaceCard,
                      ),
                    ),
                    Text(
                      '4 Friends • Split Equally',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '₹12,400',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: AppColors.emeraldPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniAvatarPill('You', '₹3,100', isDark, isPositive: true),
              _buildMiniAvatarPill('Priya', '₹3,100', isDark, isPositive: false),
              _buildMiniAvatarPill('Rohan', '₹3,100', isDark, isPositive: false),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SLIDE 2 VISUAL: OFFLINE P2P RADAR ──────────────────────────
  Widget _buildP2pRadarVisual(bool isDark) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.emeraldPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Nearby Friends Radar',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'P2P Mesh',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A20) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering_rounded, size: 20, color: AppColors.indigoAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct Sync Active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '3 peers connected without internet',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.emeraldPrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SLIDE 3 VISUAL: 1-TAP UPI SETTLEMENTS ───────────────────────────────
  Widget _buildUpiSettlementVisual(bool isDark) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amberAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.amberAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settle with Rahul',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : AppColors.darkSurfaceCard,
                      ),
                    ),
                    Text(
                      'rahul@okhdfcbank',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified_rounded, color: AppColors.emeraldPrimary, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.emeraldPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Pay ₹1,250 via UPI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAvatarPill(String name, String amount, bool isDark, {required bool isPositive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isPositive ? AppColors.emeraldPrimary : AppColors.indigoAccent,
            child: Text(
              name[0],
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isPositive ? AppColors.emeraldPrimary : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkthroughSlideData {
  final String badge;
  final Color badgeColor;
  final String title;
  final String description;
  final Widget Function(bool isDark) visualBuilder;

  const _WalkthroughSlideData({
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.description,
    required this.visualBuilder,
  });
}
