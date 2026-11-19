import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/haptic_feedback_helper.dart';
import '../utils/kith_calculator_engine.dart';
import 'kith_components.dart';

/// Tactile, smart amount input field with inline mathematical expression calculator.
///
/// Features:
/// - Smart Numeric Keyboard configuration by default (`TextInputType.numberWithOptions`)
/// - Operator Toolbar with tactile keys: `+`, `-`, `×`, `÷`, `(`, `)`, `=`, `⌫`, `C`
/// - Safe inline mathematical expression engine with BODMAS precedence & parentheses
/// - Live calculated preview pill (e.g. `= ₹123.00` or validation warning)
/// - One-tap resolution: tapping preview applies computed result
/// - Optional expandable in-app calculator keypad
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
  late CalculatorEvaluationResult _evalResult;
  late bool _showKeypad;

  @override
  void initState() {
    super.initState();
    _showKeypad = widget.useInAppKeypad;
    _evalResult = KithCalculatorEngine.evaluateExpression(
      widget.controller.text,
      currencyCode: widget.currencyCode,
    );
    if (widget.controller.text.isNotEmpty && _evalResult.amountInPaise > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onAmountChanged?.call(_evalResult.amountInPaise);
        }
      });
    }
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant KithAmountCalculatorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currencyCode != widget.currencyCode) {
      _recalculate();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleTextChange() {
    _recalculate();
  }

  void _recalculate() {
    final text = widget.controller.text;
    final res = KithCalculatorEngine.evaluateExpression(
      text,
      currencyCode: widget.currencyCode,
    );

    if (mounted) {
      setState(() {
        _evalResult = res;
      });
    }

    widget.onAmountChanged?.call(res.amountInPaise);
  }

  void _clear() {
    HapticHelper.light();
    widget.controller.clear();
    widget.controller.selection = const TextSelection.collapsed(offset: 0);
  }

  void _insertAtCursor(String char) {
    HapticHelper.selection();
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, char);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + char.length),
    );
  }

  void _backspace() {
    HapticHelper.light();
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    if (start != end) {
      final newText = text.replaceRange(start, end, '');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
    } else if (start > 0) {
      final newText = text.replaceRange(start - 1, start, '');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start - 1),
      );
    }
  }

  void _applyEvaluatedAmount() {
    HapticHelper.medium();
    if (_evalResult.amountInPaise > 0) {
      final rupees = _evalResult.amountInPaise / 100.0;
      final text = rupees % 1 == 0 ? rupees.toInt().toString() : rupees.toStringAsFixed(2);
      widget.controller.text = text;
      widget.controller.selection = TextSelection.collapsed(offset: text.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = widget.currencyCode == 'INR' ? '₹' : widget.currencyCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Amount Input Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              symbol,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controller,
                // Default to numeric keyboard on Android for fast numeric entry
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textInputAction: TextInputAction.next,
                readOnly: false,
                showCursor: true,
                onTap: widget.onTap,
                autofocus: widget.autoFocus,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: KithInputDecoration.borderless(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                onSubmitted: (_) => widget.onSubmitted?.call(),
              ),
            ),
            // Keypad toggle button
            IconButton(
              icon: Icon(
                _showKeypad ? Icons.keyboard_rounded : Icons.dialpad_rounded,
                size: 20,
                color: _showKeypad
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
              tooltip: _showKeypad ? 'Switch to native keyboard' : 'Open in-app calculator keypad',
              onPressed: () {
                HapticHelper.light();
                setState(() => _showKeypad = !_showKeypad);
              },
            ),
            if (widget.controller.text.isNotEmpty)
              GestureDetector(
                onTap: _clear,
                behavior: HitTestBehavior.opaque,
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

        // Live calculation preview pill (or error validation)
        if (_evalResult.hasOperators) ...[
          const SizedBox(height: 6),
          if (_evalResult.isError)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFE11D48)),
                  const SizedBox(width: 6),
                  Text(
                    _evalResult.errorMessage ?? 'Invalid expression',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            )
          else if (_evalResult.previewText != null)
            GestureDetector(
              onTap: _applyEvaluatedAmount,
              child: Container(
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
                      _evalResult.previewText!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Tap to apply',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],

        const SizedBox(height: 10),

        // Accessible Operator Toolbar
        _buildOperatorToolbar(isDark),

        // Optional Expanded In-App Keypad
        if (_showKeypad) ...[
          const SizedBox(height: 12),
          _buildInAppKeypad(isDark),
        ],
      ],
    );
  }

  /// Compact, tactile operator toolbar allowing single-tap entry of mathematical symbols.
  Widget _buildOperatorToolbar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildOperatorChip('+', () => _insertAtCursor('+'), isDark, isPrimary: true),
          const SizedBox(width: 6),
          _buildOperatorChip('-', () => _insertAtCursor('-'), isDark, isPrimary: true),
          const SizedBox(width: 6),
          _buildOperatorChip('×', () => _insertAtCursor('×'), isDark, isPrimary: true),
          const SizedBox(width: 6),
          _buildOperatorChip('÷', () => _insertAtCursor('÷'), isDark, isPrimary: true),
          const SizedBox(width: 6),
          _buildOperatorChip('(', () => _insertAtCursor('('), isDark),
          const SizedBox(width: 6),
          _buildOperatorChip(')', () => _insertAtCursor(')'), isDark),
          const SizedBox(width: 6),
          _buildOperatorChip('=', _applyEvaluatedAmount, isDark, isAccent: true),
          const SizedBox(width: 6),
          _buildOperatorChip('⌫', _backspace, isDark),
        ],
      ),
    );
  }

  Widget _buildOperatorChip(
    String label,
    VoidCallback onTap,
    bool isDark, {
    bool isPrimary = false,
    bool isAccent = false,
  }) {
    Color bg;
    Color fg;
    Color border;

    if (isAccent) {
      bg = (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.2);
      fg = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
      border = (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.4);
    } else if (isPrimary) {
      bg = isDark ? const Color(0xFF1E2832) : const Color(0xFFE2E8F0);
      fg = isDark ? Colors.white : const Color(0xFF0F172A);
      border = isDark ? const Color(0xFF2D3C4B) : const Color(0xFFCBD5E1);
    } else {
      bg = isDark ? const Color(0xFF141A21) : const Color(0xFFF1F5F9);
      fg = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
      border = isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 0.8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  /// In-app tactile calculator keypad (0-9, ., +, -, ×, ÷, (, ), C, ⌫, =).
  Widget _buildInAppKeypad(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10171F) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildKeypadBtn('C', _clear, isDark, isDanger: true),
              _buildKeypadBtn('(', () => _insertAtCursor('('), isDark),
              _buildKeypadBtn(')', () => _insertAtCursor(')'), isDark),
              _buildKeypadBtn('÷', () => _insertAtCursor('÷'), isDark, isOp: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildKeypadBtn('7', () => _insertAtCursor('7'), isDark),
              _buildKeypadBtn('8', () => _insertAtCursor('8'), isDark),
              _buildKeypadBtn('9', () => _insertAtCursor('9'), isDark),
              _buildKeypadBtn('×', () => _insertAtCursor('×'), isDark, isOp: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildKeypadBtn('4', () => _insertAtCursor('4'), isDark),
              _buildKeypadBtn('5', () => _insertAtCursor('5'), isDark),
              _buildKeypadBtn('6', () => _insertAtCursor('6'), isDark),
              _buildKeypadBtn('-', () => _insertAtCursor('-'), isDark, isOp: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildKeypadBtn('1', () => _insertAtCursor('1'), isDark),
              _buildKeypadBtn('2', () => _insertAtCursor('2'), isDark),
              _buildKeypadBtn('3', () => _insertAtCursor('3'), isDark),
              _buildKeypadBtn('+', () => _insertAtCursor('+'), isDark, isOp: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildKeypadBtn('0', () => _insertAtCursor('0'), isDark),
              _buildKeypadBtn('.', () => _insertAtCursor('.'), isDark),
              _buildKeypadBtn('⌫', _backspace, isDark),
              _buildKeypadBtn('=', _applyEvaluatedAmount, isDark, isOp: true, isAction: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadBtn(
    String label,
    VoidCallback onTap,
    bool isDark, {
    bool isOp = false,
    bool isDanger = false,
    bool isAction = false,
  }) {
    Color bg;
    Color fg;

    if (isAction) {
      bg = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
      fg = isDark ? Colors.black : Colors.white;
    } else if (isDanger) {
      bg = Colors.red.withValues(alpha: isDark ? 0.2 : 0.1);
      fg = Colors.red;
    } else if (isOp) {
      bg = (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15);
      fg = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
    } else {
      bg = isDark ? const Color(0xFF1E2832) : Colors.white;
      fg = isDark ? Colors.white : const Color(0xFF0F172A);
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
