import 'package:flutter/material.dart';
import '../engine/liquid_glass_engine.dart';
import '../navigation/liquid_glass_navigation.dart';
import '../tokens/glass_tokens.dart';

/// Standardized Liquid Glass modal bottom sheet.
/// Features a tactile drag handle, pinned header with an explicit 48dp Close button,
/// keyboard insets avoidance, and adaptive glass surface background.
class LiquidGlassModalSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool isScrollControlled;

  const LiquidGlassModalSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.isScrollControlled = true,
  });

  /// Displays the modal sheet using standardized elevation and backdrop parameters.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget child,
    Widget? trailing,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => LiquidGlassModalSheet(
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = LiquidGlassEngine.getSurfaceColor(
      context,
      isDark: isDark,
      isModal: true,
    );
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: GlassRadii.modalBorder,
        border: Border.all(
          color: isDark ? GlassColors.darkBorderSubtle : GlassColors.lightBorderSubtle,
          width: 0.75,
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Tactile Centered Drag Handle
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // 2. Header Row: Title + Subtitle + Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GlassTypography.titleMedium(isDark: isDark),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: GlassTypography.bodySmall(isDark: isDark),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    trailing!,
                    const SizedBox(width: 8),
                  ],
                  LiquidGlassNavigation.closeButton(context: context),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 3. Sheet Body Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: child,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
