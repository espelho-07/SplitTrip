import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

enum CurrencyDisplaySize { hero, large, medium, small }
enum CurrencyColorMode { auto, positive, negative, neutral, custom }

class CurrencyDisplay extends StatelessWidget {
  final int amountInPaise;
  final CurrencyDisplaySize size;
  final CurrencyColorMode colorMode;
  final Color? customColor;
  final String currencyCode;
  final bool showPlusSign;
  final bool forceDecimals;

  const CurrencyDisplay({
    super.key,
    required this.amountInPaise,
    this.size = CurrencyDisplaySize.medium,
    this.colorMode = CurrencyColorMode.neutral,
    this.customColor,
    this.currencyCode = 'INR',
    this.showPlusSign = false,
    this.forceDecimals = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    switch (colorMode) {
      case CurrencyColorMode.auto:
        if (amountInPaise > 0) {
          color = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
        } else if (amountInPaise < 0) {
          color = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
        } else {
          color = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        }
        break;
      case CurrencyColorMode.positive:
        color = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
        break;
      case CurrencyColorMode.negative:
        color = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
        break;
      case CurrencyColorMode.neutral:
        color = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        break;
      case CurrencyColorMode.custom:
        color = customColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
        break;
    }

    final formatted = CurrencyFormatter.formatPaise(
      amountInPaise,
      currencyCode: currencyCode,
      showSign: showPlusSign,
      forceDecimals: forceDecimals,
    );

    TextStyle style;
    switch (size) {
      case CurrencyDisplaySize.hero:
        style = AppTypography.moneyHero(isDark: isDark, overrideColor: color);
        break;
      case CurrencyDisplaySize.large:
        style = AppTypography.moneyLarge(isDark: isDark, overrideColor: color);
        break;
      case CurrencyDisplaySize.medium:
        style = AppTypography.moneyMedium(isDark: isDark, overrideColor: color);
        break;
      case CurrencyDisplaySize.small:
        style = AppTypography.moneySmall(isDark: isDark, overrideColor: color);
        break;
    }

    return Text(
      formatted,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
