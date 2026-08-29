import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../widgets/progress/kith_success_toast.dart';
import '../../viewmodels/locale_viewmodel.dart';

/// Modal bottom sheet for changing language anywhere in the app.
class LanguageSelectSheet extends StatefulWidget {
  const LanguageSelectSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LanguageSelectSheet(),
    );
  }

  @override
  State<LanguageSelectSheet> createState() => _LanguageSelectSheetState();
}

class _LanguageSelectSheetState extends State<LanguageSelectSheet> {
  late AppLanguage _selectedLanguage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedLanguage = context.read<LocaleViewModel>().currentLanguage;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onLanguageSelected(AppLanguage lang) {
    HapticHelper.selection();
    setState(() {
      _selectedLanguage = lang;
    });
    // Update active locale live
    context.read<LocaleViewModel>().setLanguage(lang);
  }

  Future<void> _handleDone() async {
    HapticHelper.medium();
    final localeVm = context.read<LocaleViewModel>();
    await localeVm.setLanguage(_selectedLanguage);

    if (mounted) {
      Navigator.of(context).pop();
      KithSuccessToast.show(context, context.l10n.languageChangeSuccess);
    }
  }

  Widget _buildLanguageItem(AppLanguage lang, bool isDark) {
    final isSelected = _selectedLanguage == lang;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _onLanguageSelected(lang),
        borderRadius: AppRadius.mdBorder,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.emeraldPrimary.withValues(alpha: 0.15)
                    : AppColors.emeraldPrimary.withValues(alpha: 0.08))
                : (isDark
                    ? AppColors.darkSurfaceSubtle
                    : AppColors.lightSurfaceSubtle),
            borderRadius: AppRadius.mdBorder,
            border: Border.all(
              color: isSelected
                  ? AppColors.emeraldPrimary
                  : (isDark ? Colors.white10 : Colors.black12),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.emeraldPrimary.withValues(alpha: 0.15)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.translate_rounded,
                  size: 18,
                  color: isSelected
                      ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                      : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.nativeName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                    Text(
                      lang.englishName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.emeraldPrimary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    final indicList = AppLanguage.indicLanguages
        .where((l) => l.matchesQuery(_searchQuery))
        .toList();
    final eastAsianList = AppLanguage.eastAsianLanguages
        .where((l) => l.matchesQuery(_searchQuery))
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Title
          Text(
            l10n.languageSelectTitle,
            style: AppTypography.titleLarge(isDark: isDark).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.languageSelectSubtitle,
            style: AppTypography.bodySmall(isDark: isDark),
          ),

          const SizedBox(height: AppSpacing.md),

          // Search Field
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              borderRadius: AppRadius.smBorder,
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: AppTypography.bodyMedium(isDark: isDark),
                    decoration: InputDecoration(
                      hintText: l10n.langSearchHint,
                      hintStyle: AppTypography.bodySmall(isDark: isDark).copyWith(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Scrollable Languages List
          Flexible(
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: [
                if (indicList.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      l10n.langCategoryIndic,
                      style: AppTypography.badgeText(
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...indicList.map((lang) => _buildLanguageItem(lang, isDark)),
                ],

                if (eastAsianList.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      l10n.langCategoryEastAsian,
                      style: AppTypography.badgeText(
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...eastAsianList.map((lang) => _buildLanguageItem(lang, isDark)),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          AppButton(
            text: l10n.actionDone,
            isFullWidth: true,
            variant: AppButtonVariant.primary,
            onPressed: _handleDone,
          ),
        ],
      ),
    );
  }
}
