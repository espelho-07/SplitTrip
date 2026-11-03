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
  final ValueChanged<int>? onAmountChanged;
  final VoidCallback? onSubmitted;
  final bool autoFocus;
  final bool useInAppKeypad;
  final VoidCallback? onTap;

  const KithAmountCalculatorField({
    super.key,
    required this.controller,
    this.currencyCode = 'INR',
    this.onAmountChanged,
    this.onSubmitted,
    this.autoFocus = false,
    this.useInAppKeypad = false,
    this.onTap,
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

    widget.onAmountChanged?.call(evaluatedPaise);
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
                textInputAction: TextInputAction.next,
                readOnly: false,
                showCursor: true,
                onTap: widget.onTap,
                autofocus: widget.autoFocus,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: KithInputDecoration.borderless(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
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
      ],
    );
  }
}
