import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/haptic_feedback_helper.dart';

/// Tactile, responsive in-app QWERTY text keyboard for Kith.
/// Provides letter typing, shift/caps, numbers & symbol modes, space,
/// backspace, and done/next navigation without opening the system keyboard.
class KithTextKeypad extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onDone;
  final VoidCallback? onNext;
  final ValueChanged<String>? onChanged;
  final String actionLabel;
  final IconData actionIcon;

  const KithTextKeypad({
    super.key,
    required this.controller,
    this.onDone,
    this.onNext,
    this.onChanged,
    this.actionLabel = 'Done',
    this.actionIcon = Icons.check_rounded,
  });

  @override
  State<KithTextKeypad> createState() => _KithTextKeypadState();
}

class _KithTextKeypadState extends State<KithTextKeypad> {
  bool _isCaps = true;
  bool _isSymbolMode = false;

  static const List<String> _row1Letters = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
  static const List<String> _row2Letters = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
  static const List<String> _row3Letters = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];

  static const List<String> _row1Symbols = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
  static const List<String> _row2Symbols = ['@', '#', '₹', r'$', '&', '*', '-', '+', '(', ')'];
  static const List<String> _row3Symbols = ['!', '"', "'", ':', ';', '/', '?', '%'];

  void _insertText(String char) {
    HapticHelper.selection();
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    final charToInsert = _isSymbolMode
        ? char
        : (_isCaps ? char.toUpperCase() : char.toLowerCase());

    String newText;
    int newOffset;

    if (selection.isValid && selection.start >= 0 && selection.end >= selection.start) {
      newText = text.replaceRange(selection.start, selection.end, charToInsert);
      newOffset = selection.start + charToInsert.length;
    } else {
      newText = '$text$charToInsert';
      newOffset = newText.length;
    }

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );

    widget.onChanged?.call(newText);
  }

  void _handleBackspace() {
    HapticHelper.light();
    final text = widget.controller.text;
    if (text.isEmpty) return;

    final selection = widget.controller.selection;
    String newText;
    int newOffset;

    if (selection.isValid && selection.start >= 0 && selection.end > selection.start) {
      newText = text.replaceRange(selection.start, selection.end, '');
      newOffset = selection.start;
    } else if (selection.isValid && selection.start > 0) {
      newText = text.replaceRange(selection.start - 1, selection.start, '');
      newOffset = selection.start - 1;
    } else {
      newText = text.substring(0, text.length - 1);
      newOffset = newText.length;
    }

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );

    widget.onChanged?.call(newText);
  }

  void _handleClear() {
    HapticHelper.medium();
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  void _handleSpace() {
    _insertText(' ');
  }

  void _toggleCaps() {
    HapticHelper.light();
    setState(() {
      _isCaps = !_isCaps;
    });
  }

  void _toggleSymbolMode() {
    HapticHelper.light();
    setState(() {
      _isSymbolMode = !_isSymbolMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final keyBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final specialKeyBg = isDark ? const Color(0xFF131C26) : const Color(0xFFE2E8F0);
    final keyBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final row1 = _isSymbolMode ? _row1Symbols : _row1Letters;
    final row2 = _isSymbolMode ? _row2Symbols : _row2Letters;
    final row3 = _isSymbolMode ? _row3Symbols : _row3Letters;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
          // Row 1
          Row(
            children: row1.map((char) {
              final display = _isSymbolMode ? char : (_isCaps ? char.toUpperCase() : char.toLowerCase());
              return _buildKey(
                label: display,
                keyBg: keyBg,
                borderColor: keyBorder,
                textColor: textPrimary,
                onTap: () => _insertText(display),
              );
            }).toList(),
          ),
          const SizedBox(height: 5),

          // Row 2 (Padded on sides for staggered keyboard appearance)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: row2.map((char) {
                final display = _isSymbolMode ? char : (_isCaps ? char.toUpperCase() : char.toLowerCase());
                return _buildKey(
                  label: display,
                  keyBg: keyBg,
                  borderColor: keyBorder,
                  textColor: textPrimary,
                  onTap: () => _insertText(display),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 5),

          // Row 3: Shift / Mode, Characters, Backspace
          Row(
            children: [
              // Shift / Mode Key
              Expanded(
                flex: 3,
                child: _buildSpecialKey(
                  icon: _isSymbolMode ? null : (_isCaps ? Icons.keyboard_capslock_rounded : Icons.keyboard_arrow_up_rounded),
                  label: _isSymbolMode ? 'ABC' : null,
                  keyBg: _isCaps && !_isSymbolMode
                      ? (isDark ? AppColors.emeraldLight.withValues(alpha: 0.25) : AppColors.emeraldPrimary.withValues(alpha: 0.15))
                      : specialKeyBg,
                  borderColor: _isCaps && !_isSymbolMode ? AppColors.emeraldPrimary : keyBorder,
                  iconColor: _isCaps && !_isSymbolMode ? AppColors.emeraldPrimary : textMuted,
                  textColor: _isCaps && !_isSymbolMode ? AppColors.emeraldPrimary : textMuted,
                  onTap: _isSymbolMode ? _toggleSymbolMode : _toggleCaps,
                ),
              ),

              // Middle letters / symbols
              ...row3.map((char) {
                final display = _isSymbolMode ? char : (_isCaps ? char.toUpperCase() : char.toLowerCase());
                return _buildKey(
                  label: display,
                  keyBg: keyBg,
                  borderColor: keyBorder,
                  textColor: textPrimary,
                  onTap: () => _insertText(display),
                );
              }),

              // Backspace Key
              Expanded(
                flex: 3,
                child: _buildSpecialKey(
                  icon: Icons.backspace_outlined,
                  keyBg: specialKeyBg,
                  borderColor: keyBorder,
                  iconColor: textMuted,
                  onTap: _handleBackspace,
                  onLongPress: _handleClear,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Row 4: ?123, Space, Clear / Done
          Row(
            children: [
              // Toggle Symbols (?123)
              Expanded(
                flex: 3,
                child: _buildSpecialKey(
                  label: _isSymbolMode ? 'ABC' : '?123',
                  keyBg: specialKeyBg,
                  borderColor: keyBorder,
                  textColor: textPrimary,
                  onTap: _toggleSymbolMode,
                ),
              ),

              // Space Bar
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Material(
                    color: keyBg,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: _handleSpace,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: keyBorder, width: 0.8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'space',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Action (Next / Done)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Material(
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    borderRadius: BorderRadius.circular(10),
                    elevation: 1,
                    child: InkWell(
                      onTap: () {
                        HapticHelper.medium();
                        if (widget.onNext != null) {
                          widget.onNext?.call();
                        } else {
                          widget.onDone?.call();
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.actionLabel,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(widget.actionIcon, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: keyBg,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            splashColor: textColor.withValues(alpha: 0.15),
            highlightColor: textColor.withValues(alpha: 0.08),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    String? label,
    IconData? icon,
    required Color keyBg,
    required Color borderColor,
    Color? textColor,
    Color? iconColor,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: keyBg,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 18, color: iconColor ?? textColor)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
