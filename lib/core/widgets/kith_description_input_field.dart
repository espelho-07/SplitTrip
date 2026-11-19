import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/haptic_feedback_helper.dart';

/// Modern, tactile expense description input component.
///
/// Features:
/// - Clear section label & icon
/// - Subtle animated focus state with Emerald highlight
/// - Comfortable multiline support (1-4 lines)
/// - Modern rounded container matching Kith design system
/// - Inline clear button
/// - Optional quick contextual suggestion chips
class KithDescriptionInputField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final String? label;
  final String hintText;
  final List<String>? suggestions;
  final ValueChanged<String>? onSuggestionSelected;

  const KithDescriptionInputField({
    super.key,
    required this.controller,
    this.onChanged,
    this.focusNode,
    this.label = 'DESCRIPTION',
    this.hintText = 'What was this expense for?',
    this.suggestions,
    this.onSuggestionSelected,
  });

  @override
  State<KithDescriptionInputField> createState() => _KithDescriptionInputFieldState();
}

class _KithDescriptionInputFieldState extends State<KithDescriptionInputField> {
  late final FocusNode _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  void _handleTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleClear() {
    HapticHelper.light();
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = _isFocused
        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
        : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle);

    final bgColor = isDark
        ? (_isFocused ? const Color(0xFF131B22) : const Color(0xFF0F151B))
        : (_isFocused ? Colors.white : const Color(0xFFF8FAFC));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.notes_rounded,
                size: 15,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Input Container with animated focus border
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: _isFocused ? 1.5 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _effectiveFocusNode,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
              if (widget.controller.text.isNotEmpty)
                GestureDetector(
                  onTap: _handleClear,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Quick Suggestion Chips (if provided)
        if (widget.suggestions != null && widget.suggestions!.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.suggestions!.map((suggestion) {
                final isSelected = widget.controller.text.trim().toLowerCase() == suggestion.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      HapticHelper.selection();
                      widget.controller.text = suggestion;
                      widget.controller.selection = TextSelection.collapsed(offset: suggestion.length);
                      widget.onChanged?.call(suggestion);
                      widget.onSuggestionSelected?.call(suggestion);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.2)
                            : (isDark ? const Color(0xFF141A21) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                              : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
