import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/haptic_feedback_helper.dart';
import '../utils/kith_calculator_engine.dart';
import 'kith_components.dart';

/// Tactile amount input field with built-in arithmetic calculator ('+' operator,
/// live evaluation preview, quick increments, and thousand comma formatting support).
class KithAmountCalculatorField extends StatefulWidget {
  final TextEditingController controller;
  final String currencyCode;
  final ValueChanged<int> onAmountChanged;
  final VoidCallback? onSubmitted;
  final bool autoFocus;

  const KithAmountCalculatorField({
    super.key,
    required this.controller,
    this.currencyCode = 'INR',
    required this.onAmountChanged,
    this.onSubmitted,
    this.autoFocus = false,
  });

  @override
  State<KithAmountCalculatorField> createState() => _KithAmountCalculatorFieldState();
}

class _KithAmountCalculatorFieldState extends State<KithAmountCalculatorField> {
  String? _livePreview;

  @override
  void initState() {
    super.initState();
    _livePreview = KithCalculatorEngine.getLivePreview(widget.controller.text, currencyCode: widget.currencyCode);
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleTextChange() {
    final text = widget.controller.text;
    final evaluatedPaise = KithCalculatorEngine.evaluateToPaise(text);
    final preview = KithCalculatorEngine.getLivePreview(text, currencyCode: widget.currencyCode);

    if (mounted) {
      setState(() {
        _livePreview = preview;
      });
    }

    widget.onAmountChanged(evaluatedPaise);
  }

  void _insertOperator(String op) {
    HapticHelper.light();
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    if (text.endsWith('+') || text.endsWith('-') || text.endsWith('*') || text.endsWith('/')) {
      widget.controller.text = '${text.substring(0, text.length - 1)} $op ';
    } else {
      widget.controller.text = '$text $op ';
    }
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
  }

  void _addQuickAmount(int amountInRupees) {
    HapticHelper.selection();
    final currentPaise = KithCalculatorEngine.evaluateToPaise(widget.controller.text);
    final newPaise = currentPaise + (amountInRupees * 100);
    final rupees = newPaise / 100.0;
    widget.controller.text = rupees % 1 == 0 ? rupees.toInt().toString() : rupees.toStringAsFixed(2);
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
  }

  void _clear() {
    HapticHelper.light();
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = widget.currencyCode == 'INR' ? '₹' : widget.currencyCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main input container
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              symbol,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controller,
                keyboardType: TextInputType.text,
                autofocus: widget.autoFocus,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: KithInputDecoration.borderless(
                  hintText: '0.00 or 30,000 + 742',
                  hintStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                onSubmitted: (_) => widget.onSubmitted?.call(),
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              GestureDetector(
                onTap: _clear,
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(
                    Icons.cancel_rounded,
                    size: 20,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
          ],
        ),

        // Live calculation preview pill (if user typed arithmetic operations)
        if (_livePreview != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calculate_rounded,
                  size: 14,
                  color: AppColors.emeraldPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  _livePreview!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Calculator Accessory Strip (+ operator, quick amounts)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // '+' button
              _buildKeypadPill(
                label: '+ Add',
                icon: Icons.add_rounded,
                isDark: isDark,
                isHighlight: true,
                onTap: () => _insertOperator('+'),
              ),
              const SizedBox(width: 8),
              // '-' button
              _buildKeypadPill(
                label: '-',
                isDark: isDark,
                onTap: () => _insertOperator('-'),
              ),
              const SizedBox(width: 8),
              // Quick +100
              _buildKeypadPill(
                label: '+100',
                isDark: isDark,
                onTap: () => _addQuickAmount(100),
              ),
              const SizedBox(width: 8),
              // Quick +500
              _buildKeypadPill(
                label: '+500',
                isDark: isDark,
                onTap: () => _addQuickAmount(500),
              ),
              const SizedBox(width: 8),
              // Quick +1000
              _buildKeypadPill(
                label: '+1,000',
                isDark: isDark,
                onTap: () => _addQuickAmount(1000),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadPill({
    required String label,
    IconData? icon,
    required bool isDark,
    bool isHighlight = false,
    required VoidCallback onTap,
  }) {
    final bgColor = isHighlight
        ? (isDark ? AppColors.emeraldLight.withValues(alpha: 0.18) : AppColors.emeraldPrimary.withValues(alpha: 0.12))
        : (isDark ? const Color(0xFF1E2630) : const Color(0xFFF1F5F9));

    final textColor = isHighlight
        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHighlight
                  ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.3)
                  : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: textColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
