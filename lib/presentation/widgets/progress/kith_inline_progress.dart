import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Lightweight, calm inline progress indicator for short operations (~300ms - 2s).
class KithInlineProgress extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final String? message;

  const KithInlineProgress({
    super.key,
    this.size = 18.0,
    this.strokeWidth = 2.2,
    this.color,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary);

    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
      ),
    );

    if (message == null || message!.isEmpty) {
      return indicator;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        indicator,
        const SizedBox(width: 10),
        Text(
          message!,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }
}
