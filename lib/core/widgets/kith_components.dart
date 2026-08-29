import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/haptic_feedback_helper.dart';

/// Clean, elevated background surface container with subtle border and ambient shadow.
class KithSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final Color? color;
  final VoidCallback? onTap;

  const KithSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.borderRadius,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = color ?? (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard);
    final radius = borderRadius ?? AppRadius.lgBorder;

    final content = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: radius,
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticHelper.light();
            onTap!();
          },
          borderRadius: radius as BorderRadius?,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Unified button system enforcing strong visual hierarchy:
/// Primary, Secondary, Tertiary, Destructive.
enum KithButtonVariant { primary, secondary, tertiary, destructive }

class KithButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final KithButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;

  const KithButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = KithButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 50,
  });

  @override
  State<KithButton> createState() => _KithButtonState();
}

class _KithButtonState extends State<KithButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (widget.variant) {
      case KithButtonVariant.primary:
        bg = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
        fg = isDark ? AppColors.darkBackground : Colors.white;
        break;
      case KithButtonVariant.secondary:
        bg = isDark ? const Color(0xFF1E242B) : const Color(0xFFF1F5F9);
        fg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        border = BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        );
        break;
      case KithButtonVariant.tertiary:
        bg = Colors.transparent;
        fg = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
        break;
      case KithButtonVariant.destructive:
        bg = isDark ? AppColors.negativeRedDark.withValues(alpha: 0.15) : AppColors.negativeRedLight.withValues(alpha: 0.1);
        fg = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
        break;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: fg,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Material(
          color: bg,
          borderRadius: AppRadius.mdBorder,
          child: InkWell(
            onTapDown: (widget.isLoading || widget.onPressed == null) ? null : (_) => setState(() => _isPressed = true),
            onTapUp: (widget.isLoading || widget.onPressed == null)
                ? null
                : (_) {
                    setState(() => _isPressed = false);
                    HapticHelper.light();
                    widget.onPressed!();
                  },
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: AppRadius.mdBorder,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdBorder,
                border: border != BorderSide.none ? Border.fromBorderSide(border) : null,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Standardized, high-end list tile for transactions, categories, debts, and settings.
class KithListItem extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? trailingAmount;
  final String? trailingSubtext;
  final Color? trailingAmountColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  const KithListItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailingAmount,
    this.trailingSubtext,
    this.trailingAmountColor,
    this.trailing,
    this.onTap,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tile = Container(
      padding: contentPadding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailingAmount != null) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingAmount!,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: trailingAmountColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    letterSpacing: -0.3,
                  ),
                ),
                if (trailingSubtext != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    trailingSubtext!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ] else if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticHelper.light();
            onTap!();
          },
          borderRadius: AppRadius.mdBorder,
          child: tile,
        ),
      );
    }

    return tile;
  }
}

/// Compact segmented filter / selection chip.
class KithChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const KithChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
          : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
      borderRadius: AppRadius.fullBorder,
      child: InkWell(
        onTap: () {
          HapticHelper.selection();
          onTap();
        },
        borderRadius: AppRadius.fullBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? (isDark ? AppColors.darkBackground : Colors.white)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? AppColors.darkBackground : Colors.white)
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clean section header with optional trailing action button.
class KithSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const KithSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: AppTypography.titleMedium(isDark: isDark).copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              onAction!();
            },
            behavior: HitTestBehavior.opaque,
            child: Text(
              actionLabel!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Short, calm, and actionable empty state.
class KithEmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const KithEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              title,
              style: AppTypography.titleMedium(isDark: isDark).copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: AppTypography.bodySmall(isDark: isDark).copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              KithButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: KithButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Helper for completely borderless, un-boxed input decorations.
/// Prevents harsh 4-sided black/colored outline boxes when inputs are focused.
class KithInputDecoration {
  KithInputDecoration._();

  static InputDecoration borderless({
    String? hintText,
    TextStyle? hintStyle,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Widget? icon,
    String? prefixText,
    TextStyle? prefixStyle,
    String? suffixText,
    TextStyle? suffixStyle,
    EdgeInsetsGeometry? contentPadding = EdgeInsets.zero,
    bool isDense = true,
    Color? fillColor,
    bool filled = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      icon: icon,
      prefixText: prefixText,
      prefixStyle: prefixStyle,
      suffixText: suffixText,
      suffixStyle: suffixStyle,
      contentPadding: contentPadding,
      isDense: isDense,
      fillColor: fillColor,
      filled: filled,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );
  }
}

