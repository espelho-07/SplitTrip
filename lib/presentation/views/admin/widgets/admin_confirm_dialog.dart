import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/kith_components.dart';

/// Modal dialog requiring explicit confirmation before executing privileged or destructive actions.
class AdminConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;
  final bool requireReason;
  final String reasonHint;

  const AdminConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.isDestructive = false,
    this.requireReason = false,
    this.reasonHint = 'Provide mandatory justification for this action...',
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDestructive = false,
    bool requireReason = false,
    String reasonHint = 'Provide mandatory justification for this action...',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
        requireReason: requireReason,
        reasonHint: reasonHint,
      ),
    );
  }

  @override
  State<AdminConfirmDialog> createState() => _AdminConfirmDialogState();
}

class _AdminConfirmDialogState extends State<AdminConfirmDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final text = _reasonController.text.trim();
    if (widget.requireReason && text.isEmpty) {
      setState(() {
        _errorText = 'A non-empty justification is strictly required.';
      });
      return;
    }
    Navigator.of(context).pop(text.isNotEmpty ? text : 'confirmed');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: (widget.isDestructive ? AppColors.negativeRedDark : AppColors.emeraldPrimary)
                          .withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: Icon(
                      widget.isDestructive ? Icons.warning_amber_rounded : Icons.shield_outlined,
                      color: widget.isDestructive ? AppColors.negativeRedDark : AppColors.emeraldPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.message,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              if (widget.requireReason) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: 13.5,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.reasonHint,
                    hintStyle: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 13,
                    ),
                    errorText: _errorText,
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: const BorderSide(color: AppColors.emeraldPrimary, width: 1.2),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KithButton(
                    label: 'Cancel',
                    variant: KithButtonVariant.tertiary,
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  KithButton(
                    label: widget.confirmLabel,
                    variant: widget.isDestructive ? KithButtonVariant.destructive : KithButtonVariant.primary,
                    onPressed: _onConfirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
