import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/currency_display.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../domain/models/expense_draft.dart';
import '../../../../domain/models/trip.dart';
import '../../../../domain/models/trip_member.dart';

class ExpenseDraftConfirmationSheet extends StatefulWidget {
  final ExpenseDraft draft;
  final Trip trip;
  final VoidCallback onEditManual;
  final Future<void> Function(ExpenseDraft confirmedDraft) onConfirm;

  const ExpenseDraftConfirmationSheet({
    super.key,
    required this.draft,
    required this.trip,
    required this.onEditManual,
    required this.onConfirm,
  });

  @override
  State<ExpenseDraftConfirmationSheet> createState() => _ExpenseDraftConfirmationSheetState();
}

class _ExpenseDraftConfirmationSheetState extends State<ExpenseDraftConfirmationSheet> {
  late ExpenseDraft _currentDraft;
  bool _isConfirming = false;
  final TextEditingController _amountEditController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentDraft = widget.draft;
    if (_currentDraft.amountInPaise > 0) {
      _amountEditController.text = CurrencyFormatter.toRupees(_currentDraft.amountInPaise).toString();
    }
  }

  @override
  void dispose() {
    _amountEditController.dispose();
    super.dispose();
  }

  TripMember? get _selectedPayer {
    return widget.trip.members.where((m) => m.id == _currentDraft.payerMemberId).firstOrNull ??
        widget.trip.members.firstOrNull;
  }

  int get _perPersonAmount {
    if (_currentDraft.amountInPaise <= 0 || _currentDraft.participantMemberIds.isEmpty) return 0;
    return (_currentDraft.amountInPaise / _currentDraft.participantMemberIds.length).round();
  }

  Future<void> _handleConfirm() async {
    if (_currentDraft.amountInPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a valid expense amount')),
      );
      return;
    }

    setState(() => _isConfirming = true);
    HapticHelper.medium();

    try {
      await widget.onConfirm(_currentDraft);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: AppSpacing.bottomSheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header with source badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Confirm Expense',
                style: AppTypography.titleLarge(isDark: isDark),
              ),
              PillBadge(
                label: _currentDraft.source == ExpenseDraftSource.voice ? 'Voice Intent' : 'Receipt OCR',
                icon: _currentDraft.source == ExpenseDraftSource.voice ? Icons.mic_rounded : Icons.receipt_long_rounded,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Is this information correct?',
            style: AppTypography.bodySmall(isDark: isDark),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Ambiguity warning if any
          if (_currentDraft.ambiguityMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amberAccent.withValues(alpha: 0.12),
                borderRadius: AppRadius.mdBorder,
                border: Border.all(color: AppColors.amberAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.amberAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentDraft.ambiguityMessage!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Ambiguous Payer Resolution Selector (if multiple matching candidates)
          if (_currentDraft.candidatePayers.isNotEmpty) ...[
            Text('Select Payer:', style: AppTypography.titleSmall(isDark: isDark)),
            const SizedBox(height: 6),
            ..._currentDraft.candidatePayers.map((candidate) {
              final isSelected = _currentDraft.payerMemberId == candidate.id;
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
                tileColor: isSelected
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12)
                    : null,
                leading: MemberAvatar(name: candidate.displayName, size: 28),
                title: Text(candidate.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.emeraldPrimary) : null,
                onTap: () {
                  HapticHelper.selection();
                  setState(() {
                    _currentDraft = _currentDraft.copyWith(
                      payerMemberId: candidate.id,
                      payerName: candidate.displayName,
                      unresolvedFields: _currentDraft.unresolvedFields.where((f) => f != 'payer_ambiguity').toList(),
                      ambiguityMessage: null,
                    );
                  });
                },
              );
            }),
            const SizedBox(height: AppSpacing.md),
          ],

          // Main Expense Card Overview
          SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                        borderRadius: AppRadius.mdBorder,
                      ),
                      alignment: Alignment.center,
                      child: Text(_currentDraft.category.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentDraft.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentDraft.category.displayName,
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                        ],
                      ),
                    ),
                    CurrencyDisplay(
                      amountInPaise: _currentDraft.amountInPaise,
                      size: CurrencyDisplaySize.large,
                      currencyCode: widget.trip.currencyCode,
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('Paid by', style: AppTypography.bodySmall(isDark: isDark)),
                      ],
                    ),
                    Text(
                      _selectedPayer?.displayName ?? 'You',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          'For ${_currentDraft.participantMemberIds.length} people',
                          style: AppTypography.bodySmall(isDark: isDark),
                        ),
                      ],
                    ),
                    Text(
                      '${CurrencyFormatter.formatPaise(_perPersonAmount, currencyCode: widget.trip.currencyCode)} each',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Edit',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    HapticHelper.light();
                    Navigator.of(context).pop();
                    widget.onEditManual();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  text: 'Add Expense',
                  icon: Icons.check_rounded,
                  isLoading: _isConfirming,
                  onPressed: _currentDraft.amountInPaise > 0 && _currentDraft.payerMemberId != null
                      ? _handleConfirm
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
