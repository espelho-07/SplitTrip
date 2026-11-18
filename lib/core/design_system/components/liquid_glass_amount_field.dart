import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/glass_tokens.dart';
import 'liquid_glass_card.dart';

/// Ergonomic, high-legibility currency amount input field.
/// Guarantees tabular figures (zero numeral jitter), quick denomination chips,
/// haptic feedback on increments, and clear debit/credit semantics.
class LiquidGlassAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String currencySymbol;
  final String? label;
  final ValueChanged<String>? onChanged;
  final bool autoFocus;
  final bool isIncome;
  final List<int> quickPresets;

  const LiquidGlassAmountField({
    super.key,
    required this.controller,
    this.currencySymbol = '₹',
    this.label,
    this.onChanged,
    this.autoFocus = false,
    this.isIncome = false,
    this.quickPresets = const [100, 500, 1000, 2000],
  });

  void _addPreset(int amount) {
    HapticFeedback.lightImpact();
    final currentVal = double.tryParse(controller.text.replaceAll(',', '')) ?? 0.0;
    final newVal = currentVal + amount;
    controller.text = newVal % 1 == 0 ? newVal.toInt().toString() : newVal.toStringAsFixed(2);
    onChanged?.call(controller.text);
  }

  void _clear() {
    HapticFeedback.selectionClick();
    controller.clear();
    onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isIncome
        ? GlassColors.positive(isDark)
        : (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary);

    return LiquidGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
      borderRadius: GlassRadii.lgBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!.toUpperCase(),
              style: GlassTypography.labelCaps(isDark: isDark),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                currencySymbol,
                style: GlassTypography.moneyLarge(
                  isDark: isDark,
                  color: accentColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autoFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: GlassTypography.moneyHero(isDark: isDark, color: accentColor),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0',
                    hintStyle: GlassTypography.moneyHero(
                      isDark: isDark,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, val, _) {
                  if (val.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    onPressed: _clear,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Quick increment chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: quickPresets.map((preset) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () => _addPreset(preset),
                    borderRadius: GlassRadii.pillBorder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? GlassColors.darkSurfaceSubtle : GlassColors.lightSurfaceSubtle,
                        borderRadius: GlassRadii.pillBorder,
                        border: Border.all(
                          color: isDark ? GlassColors.darkBorderSubtle : GlassColors.lightBorderSubtle,
                        ),
                      ),
                      child: Text(
                        '+$currencySymbol$preset',
                        style: GlassTypography.bodySmall(isDark: isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
