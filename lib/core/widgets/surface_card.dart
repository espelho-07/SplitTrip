import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radius.dart';
import '../utils/haptic_feedback_helper.dart';

/// Refined Apple-grade card surface that adapts cleanly between light and layered dark modes.
/// Includes smooth tactile scale micro-interaction when tapped.
class SurfaceCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final bool hasElevation;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.hasElevation = true,
  });

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _animController.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _animController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.borderRadius ?? AppRadius.lgBorder;

    final bg = widget.backgroundColor ??
        (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard);

    final b = widget.border ??
        Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 1,
        );

    final shadows = widget.hasElevation
        ? (isDark ? AppElevation.darkCard : AppElevation.lightCard)
        : null;

    Widget card = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: b,
        boxShadow: shadows,
      ),
      padding: widget.padding,
      child: widget.child,
    );

    if (widget.onTap != null) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: () {
            HapticHelper.light();
            widget.onTap!();
          },
          child: card,
        ),
      );
    }

    return card;
  }
}
