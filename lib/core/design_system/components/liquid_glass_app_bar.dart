import 'dart:ui';
import 'package:flutter/material.dart';
import '../engine/liquid_glass_engine.dart';
import '../navigation/liquid_glass_navigation.dart';
import '../tokens/glass_tokens.dart';

/// Frosted optical glass AppBar conforming to WCAG 2.2 AA and Material Design 3.
/// Guarantees 48x48dp interactive touch targets and automatic Back/Close navigation buttons.
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? titleText;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final bool isModal;
  final double height;
  final VoidCallback? onLeadingPressed;

  const LiquidGlassAppBar({
    super.key,
    this.title,
    this.titleText,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.isModal = false,
    this.height = 56.0,
    this.onLeadingPressed,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBlur = LiquidGlassEngine.getEffectiveBlur(context, GlassTokens.blurStandard);
    final surfaceColor = LiquidGlassEngine.getSurfaceColor(context, isDark: isDark, isCard: false);

    Widget? leadingWidget = leading;
    if (leadingWidget == null && automaticallyImplyLeading) {
      final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
      final canPop = parentRoute?.canPop ?? false;
      if (canPop) {
        leadingWidget = isModal
            ? LiquidGlassNavigation.closeButton(context: context, onPressed: onLeadingPressed)
            : LiquidGlassNavigation.backButton(context: context, onPressed: onLeadingPressed);
      }
    }

    Widget content = SafeArea(
      bottom: false,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            bottom: BorderSide(
              color: isDark ? GlassColors.darkBorderSubtle : GlassColors.lightBorderSubtle,
              width: 0.75,
            ),
          ),
        ),
        child: Row(
          children: [
            if (leadingWidget != null)
              ConstrainedBox(
                constraints: GlassSpacing.touchTargetConstraints,
                child: leadingWidget,
              )
            else
              const SizedBox(width: 8),
            const SizedBox(width: 4),
            Expanded(
              child: title ??
                  Text(
                    titleText ?? '',
                    style: GlassTypography.titleMedium(isDark: isDark),
                    overflow: TextOverflow.ellipsis,
                  ),
            ),
            if (actions != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!.map((action) {
                  return ConstrainedBox(
                    constraints: GlassSpacing.touchTargetConstraints,
                    child: action,
                  );
                }).toList(),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );

    if (effectiveBlur > 0.0) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: content,
        ),
      );
    }

    return content;
  }
}
