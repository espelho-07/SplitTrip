import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Clean member avatar with initials, deterministic color harmony, and creator indicator.
class MemberAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;
  final bool isCreator;
  final bool showBorder;

  const MemberAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 36.0,
    this.isCreator = false,
    this.showBorder = true,
  });

  static const List<Color> _avatarColors = [
    Color(0xFF0D9488), // Teal
    Color(0xFF6366F1), // Indigo
    Color(0xFFD97706), // Amber
    Color(0xFFE11D48), // Rose
    Color(0xFF8B5CF6), // Violet
    Color(0xFF059669), // Emerald
    Color(0xFF0284C7), // Sky
    Color(0xFFD946EF), // Fuchsia
  ];

  Color _getDeterministicColor(String input) {
    if (input.isEmpty) return _avatarColors[0];
    final code = input.codeUnits.fold(0, (sum, c) => sum + c);
    return _avatarColors[code % _avatarColors.length];
  }

  String _getInitials(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = _getInitials(name);
    final bgColor = _getDeterministicColor(name);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor.withValues(alpha: isDark ? 0.25 : 0.15),
            border: showBorder
                ? Border.all(
                    color: isDark ? AppColors.darkBorderStrong : Colors.white,
                    width: 1.5,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              color: isDark ? Colors.white : bgColor,
              fontSize: size * 0.40,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        if (isCreator)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.star_rounded,
                size: size * 0.35,
                color: AppColors.amberAccent,
              ),
            ),
          ),
      ],
    );
  }
}
