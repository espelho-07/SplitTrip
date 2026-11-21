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
      clipBehavior: Clip.antiAlias,
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
  final bool isFullWidth;
  final EdgeInsetsGeometry? padding;

  const KithButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = KithButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 48,
    this.isFullWidth = false,
    this.padding,
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
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );

    final effectiveWidth = widget.isFullWidth ? double.infinity : widget.width;

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: effectiveWidth,
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
              padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
    String? labelText,
    TextStyle? labelStyle,
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
    bool? isDark,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      labelText: labelText,
      labelStyle: labelStyle,
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
      filled: filled || fillColor != null,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );
  }
}

/// Tactile, modern card surface container.
/// Features a subtle border, ambient elevation shadow, and a gentle micro-scale press interaction.
class KithCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final bool hasShadow;
  final bool enableScale;
  final bool isSelected;

  const KithCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.onTap,
    this.borderRadius = AppRadius.lgBorder,
    this.backgroundColor,
    this.border,
    this.hasShadow = true,
    this.enableScale = true,
    this.isSelected = false,
  });

  @override
  State<KithCard> createState() => _KithCardState();
}

class _KithCardState extends State<KithCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = widget.backgroundColor ??
        (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard);
    final effectiveBorder = widget.border ??
        Border.all(
          color: widget.isSelected
              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
              : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          width: widget.isSelected ? 1.5 : 1.0,
        );

    final cardContent = Container(
      clipBehavior: Clip.antiAlias,
      padding: widget.padding,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: widget.borderRadius,
        border: effectiveBorder,
        boxShadow: widget.hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: widget.child,
    );

    if (widget.onTap == null) {
      return cardContent;
    }

    return AnimatedScale(
      scale: (_isPressed && widget.enableScale) ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          HapticHelper.light();
          widget.onTap!();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        behavior: HitTestBehavior.opaque,
        child: cardContent,
      ),
    );
  }
}

/// Animated, Airbnb-level segmented control.
/// Adheres strictly to the nested radius formula: outer radius = 16, padding = 4, inner radius = 12.
class KithSegmentedControl<T> extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final String Function(T item) labelBuilder;
  final IconData? Function(T item)? iconBuilder;
  final int? Function(T item)? badgeBuilder;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  const KithSegmentedControl({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.labelBuilder,
    required this.onSelected,
    this.iconBuilder,
    this.badgeBuilder,
    this.padding = const EdgeInsets.all(4.0),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 0.8,
        ),
      ),
      child: Row(
        children: items.map((item) {
          final isSelected = item == selectedItem;
          final icon = iconBuilder != null ? iconBuilder!(item) : null;
          final badge = badgeBuilder != null ? badgeBuilder!(item) : null;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  HapticHelper.selection();
                  onSelected(item);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.darkSurfaceElevated : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderSubtle,
                          width: 0.8,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 15,
                        color: isSelected
                            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      labelBuilder(item),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: -0.2,
                        color: isSelected
                            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                    if (badge != null && badge > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.emeraldLight.withValues(alpha: 0.2) : AppColors.emeraldPrimary.withValues(alpha: 0.12))
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Reusable pill badge for categories, statuses, filters, and counter tags.
class KithPill extends StatelessWidget {
  final String label;
  final Widget? leading;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? textColor;
  final BorderSide? border;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isSelected;

  const KithPill({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    this.backgroundColor,
    this.textColor,
    this.border,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = backgroundColor ??
        (isSelected
            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
            : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle));

    final fg = textColor ??
        (isSelected
            ? (isDark ? AppColors.darkBackground : Colors.white)
            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary));

    final effectiveBorder = border ??
        BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          width: 0.8,
        );

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.fullBorder,
        border: Border.fromBorderSide(effectiveBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: fg,
              letterSpacing: -0.1,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 5),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticHelper.selection();
          onTap!();
        },
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}

/// High-precision tabular financial amount display with currency formatting.
class KithMoneyDisplay extends StatelessWidget {
  final int amountInPaise;
  final String currencyCode;
  final TextStyle? style;
  final bool isNetBalance;
  final bool isHero;

  const KithMoneyDisplay({
    super.key,
    required this.amountInPaise,
    this.currencyCode = 'INR',
    this.style,
    this.isNetBalance = false,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final absPaise = amountInPaise.abs();
    final rupees = absPaise / 100.0;
    final formattedNum = absPaise % 100 == 0
        ? rupees.toInt().toString()
        : rupees.toStringAsFixed(2);
    final prefix = isNetBalance
        ? (amountInPaise > 0 ? '+₹' : (amountInPaise < 0 ? '-₹' : '₹'))
        : '₹';
    final fullText = '$prefix$formattedNum';

    Color textColor;
    if (isNetBalance) {
      if (amountInPaise > 0) {
        textColor = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
      } else if (amountInPaise < 0) {
        textColor = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
      } else {
        textColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
      }
    } else {
      textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    }

    final effectiveStyle = style ??
        (isHero
            ? AppTypography.moneyHero(isDark: isDark, overrideColor: textColor)
            : AppTypography.moneyLarge(isDark: isDark, overrideColor: textColor));

    return Text(
      fullText,
      style: effectiveStyle,
    );
  }
}

/// Airbnb-inspired header with circular back button, bold title, and trailing actions.
class KithAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const KithAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: showBackButton ? 56 : 0,
      leading: showBackButton
          ? Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    HapticHelper.light();
                    if (onBackPressed != null) {
                      onBackPressed!();
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
        ],
      ),
      actions: actions != null
          ? [
              ...actions!,
              const SizedBox(width: 12),
            ]
          : null,
    );
  }
}

/// Standardized bottom sheet container with rounded top corners, centered drag handle,
/// and optional pinned action button.
class KithBottomSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? bottomAction;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;

  const KithBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.bottomAction,
    this.onClose,
    this.padding = AppSpacing.bottomSheetPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
        ),
      ),
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Centered drag handle pill
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header row with title and close icon button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticHelper.light();
                  if (onClose != null) {
                    onClose!();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Body content
          Flexible(child: child),

          // Pinned bottom action
          if (bottomAction != null) ...[
            const SizedBox(height: 16),
            bottomAction!,
          ],
        ],
      ),
    );
  }
}

/// Overlapping member avatar stack.
class KithAvatarGroup extends StatelessWidget {
  final List<String> names;
  final double avatarSize;
  final int maxVisible;

  const KithAvatarGroup({
    super.key,
    required this.names,
    this.avatarSize = 30.0,
    this.maxVisible = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visibleNames = names.take(maxVisible).toList();
    final extraCount = names.length - maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < visibleNames.length; i++)
          Align(
            widthFactor: 0.76,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                border: Border.all(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  width: 1.8,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                visibleNames[i].isNotEmpty ? visibleNames[i][0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: avatarSize * 0.42,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
              ),
            ),
          ),
        if (extraCount > 0)
          Align(
            widthFactor: 0.76,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFE2E8F0),
                border: Border.all(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  width: 1.8,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '+$extraCount',
                style: TextStyle(
                  fontSize: avatarSize * 0.35,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Airbnb-grade bottom navigation bar with refined typography, micro-scale animations,
/// subtle active dot indicator, and zero chunky background blobs.
class KithNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const KithNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class KithBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<KithNavItem> items;

  const KithBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
    final inactiveColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E2630) : const Color(0xFFE2E8F0),
            width: 0.75,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (selectedIndex != i) {
                        HapticHelper.selection();
                        onDestinationSelected(i);
                      }
                    },
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    child: _KithNavItemWidget(
                      item: items[i],
                      isSelected: selectedIndex == i,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KithNavItemWidget extends StatelessWidget {
  final KithNavItem item;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;

  const _KithNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSelected ? item.activeIcon : item.icon,
              key: ValueKey(isSelected),
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? activeColor : inactiveColor,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 4 : 0,
            height: isSelected ? 4 : 0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeColor,
            ),
          ),
        ],
      ),
    );
  }
}

