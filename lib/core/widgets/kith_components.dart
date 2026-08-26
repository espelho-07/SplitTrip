import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/haptic_feedback_helper.dart';

/// Clean, elevated background surface container with subtle border.
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
          width: 1,
        ),
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

class KithButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final KithButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  const KithButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = KithButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case KithButtonVariant.primary:
        bg = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
        fg = isDark ? AppColors.darkBackground : Colors.white;
        break;
      case KithButtonVariant.secondary:
        bg = isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        break;
      case KithButtonVariant.tertiary:
        bg = Colors.transparent;
        fg = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
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
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return SizedBox(
      width: width,
      height: 48,
      child: Material(
        color: bg,
        borderRadius: AppRadius.mdBorder,
        child: InkWell(
          onTap: (isLoading || onPressed == null)
              ? null
              : () {
                  HapticHelper.light();
                  onPressed!();
                },
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
    );
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
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
          style: AppTypography.titleMedium(isDark: isDark),
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              title,
              style: AppTypography.titleMedium(isDark: isDark),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: AppTypography.bodySmall(isDark: isDark),
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
