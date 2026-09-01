import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/haptic_feedback_helper.dart';

/// Custom, tactile, in-app numeric keyboard with arithmetic (+, -) support,
/// quick decimal/double zero (00), backspace, and evaluation for Kith expenses.
class KithNumericKeypad extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onDone;
  final VoidCallback? onNext;
  final ValueChanged<String>? onExpressionChanged;
  final IconData actionIcon;

  const KithNumericKeypad({
    super.key,
    required this.controller,
    this.onDone,
    this.onNext,
    this.onExpressionChanged,
    this.actionIcon = Icons.arrow_forward_rounded,
  });

  void _handleNumberPress(String digit) {
    HapticHelper.selection();
    final text = controller.text;

    // Prevent excessive leading zeros
    if (text == '0' && digit != '.') {
      controller.text = digit;
    } else {
      controller.text = '$text$digit';
    }

    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    onExpressionChanged?.call(controller.text);
  }

  void _handleOperatorPress(String op) {
    HapticHelper.light();
    final text = controller.text.trim();
    if (text.isEmpty) return;

    // Replace trailing operator if already present
    if (text.endsWith('+') || text.endsWith('-') || text.endsWith('*') || text.endsWith('/')) {
      controller.text = '${text.substring(0, text.length - 1)} $op ';
    } else {
      controller.text = '$text $op ';
    }

    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    onExpressionChanged?.call(controller.text);
  }

  void _handleBackspace() {
    HapticHelper.light();
    final text = controller.text;
    if (text.isEmpty) return;

    if (text.endsWith(' ')) {
      // Operator space trimmed
      final trimmed = text.trimRight();
      if (trimmed.isNotEmpty) {
        controller.text = trimmed.substring(0, trimmed.length - 1).trimRight();
      } else {
        controller.text = '';
      }
    } else {
      controller.text = text.substring(0, text.length - 1);
    }

    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    onExpressionChanged?.call(controller.text);
  }

  void _handleClear() {
    HapticHelper.medium();
    controller.clear();
    onExpressionChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final keyBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final keyBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final opBg = isDark
        ? AppColors.emeraldLight.withValues(alpha: 0.18)
        : AppColors.emeraldPrimary.withValues(alpha: 0.12);
    final opColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1117) : const Color(0xFFF1F5F9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: 1, 2, 3, +
          Row(
            children: [
              _buildKey(label: '1', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('1')),
              _buildKey(label: '2', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('2')),
              _buildKey(label: '3', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('3')),
              _buildKey(label: '+', keyBg: opBg, borderColor: opColor.withValues(alpha: 0.3), textColor: opColor, isOperator: true, onTap: () => _handleOperatorPress('+')),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: 4, 5, 6, -
          Row(
            children: [
              _buildKey(label: '4', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('4')),
              _buildKey(label: '5', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('5')),
              _buildKey(label: '6', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('6')),
              _buildKey(label: '−', keyBg: opBg, borderColor: opColor.withValues(alpha: 0.3), textColor: opColor, isOperator: true, onTap: () => _handleOperatorPress('-')),
            ],
          ),
          const SizedBox(height: 6),

          // Row 3: 7, 8, 9, Backspace
          Row(
            children: [
              _buildKey(label: '7', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('7')),
              _buildKey(label: '8', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('8')),
              _buildKey(label: '9', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('9')),
              _buildIconKey(
                icon: Icons.backspace_outlined,
                keyBg: isDark ? const Color(0xFF1E2833) : const Color(0xFFE2E8F0),
                borderColor: keyBorder,
                iconColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                onTap: _handleBackspace,
                onLongPress: _handleClear,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 4: ., 0, 00, Done / Evaluate (=)
          Row(
            children: [
              _buildKey(label: '.', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('.')),
              _buildKey(label: '0', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('0')),
              _buildKey(label: '00', keyBg: keyBg, borderColor: keyBorder, textColor: textPrimary, onTap: () => _handleNumberPress('00')),
              _buildDoneKey(isDark: isDark, onTap: onDone),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey({
    required String label,
    required Color keyBg,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
    bool isOperator = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.5),
        child: Material(
          color: keyBg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: textColor.withValues(alpha: 0.15),
            highlightColor: textColor.withValues(alpha: 0.08),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isOperator ? 22 : 19,
                  fontWeight: isOperator ? FontWeight.w900 : FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconKey({
    required IconData icon,
    required Color keyBg,
    required Color borderColor,
    required Color iconColor,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.5),
        child: Material(
          color: keyBg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoneKey({
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    final bg = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.5),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          elevation: 1,
          child: InkWell(
            onTap: () {
              HapticHelper.medium();
              (onNext ?? onTap)?.call();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(actionIcon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
