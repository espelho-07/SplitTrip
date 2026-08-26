import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/currency_display.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/enums/expense_category.dart';
import '../../../domain/enums/split_type.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/trip.dart';
import '../../../domain/models/trip_member.dart';
import '../../viewmodels/add_expense_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/trip_detail_viewmodel.dart';
import '../../widgets/progress/kith_success_toast.dart';
import 'widgets/feature_crafting_hero.dart';

class AddExpenseView extends StatefulWidget {
  final String tripId;
  final Expense? existingExpense;

  const AddExpenseView({
    super.key,
    required this.tripId,
    this.existingExpense,
  });

  @override
  State<AddExpenseView> createState() => _AddExpenseViewState();
}

class _AddExpenseViewState extends State<AddExpenseView> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final Map<String, TextEditingController> _exactControllers = {};
  final Map<String, TextEditingController> _percentControllers = {};
  bool _hasAttemptedSave = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initViewModel();
    });
  }

  void _initViewModel() {
    final tripDetailVm = context.read<TripDetailViewModel>();
    final authVm = context.read<AuthViewModel>();
    final trip = tripDetailVm.trip;
    final user = authVm.currentUser;

    if (trip != null && user != null) {
      final addVm = context.read<AddExpenseViewModel>();
      if (widget.existingExpense != null) {
        addVm.initForEdit(expense: widget.existingExpense!, trip: trip, currentUserId: user.id);
        _titleController.text = widget.existingExpense!.title;
        _amountController.text = (widget.existingExpense!.amountInPaise / 100.0).toStringAsFixed(
          widget.existingExpense!.amountInPaise % 100 == 0 ? 0 : 2,
        );
      } else {
        addVm.init(trip: trip, currentUserId: user.id);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    final addVm = context.read<AddExpenseViewModel>();
    final tripDetailVm = context.read<TripDetailViewModel>();
    final trip = tripDetailVm.trip;
    if (trip == null || addVm.isSaving) return;

    if (addVm.title.trim().isEmpty || addVm.amountInPaise <= 0 || addVm.selectedParticipantMemberIds.isEmpty) {
      setState(() {
        _hasAttemptedSave = true;
      });
      HapticHelper.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addVm.amountInPaise <= 0
                ? 'Please enter an expense amount'
                : (addVm.title.trim().isEmpty
                    ? 'Please specify what this expense was for'
                    : 'Please select at least one participant'),
          ),
          backgroundColor: AppColors.negativeRedDark,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticHelper.light();
    final expense = await addVm.saveExpense(trip.id);
    if (expense != null && mounted) {
      context.pop(true);
      KithSuccessToast.show(context, 'Expense added ✓');
    } else if (mounted) {
      HapticHelper.error();
      final err = addVm.errorMessage ?? 'Could not save the expense. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.negativeRedDark,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _handleSave,
          ),
        ),
      );
    }
  }

  void _showSplitMethodsHelp() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.topSheetBorder),
      builder: (ctx) {
        return Padding(
          padding: AppSpacing.bottomSheetPadding,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.emeraldPrimary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Split Methods Explained',
                      style: AppTypography.titleLarge(isDark: isDark),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildHelpMethodItem(
                  title: '1. Equal Split',
                  subtitle: 'Evenly divides the bill across all selected friends. Any 1-paise difference is automatically handled without penny loss.',
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildHelpMethodItem(
                  title: '2. Exact Amount',
                  subtitle: 'Enter the exact rupee amount each person owes (e.g. for specific food items ordered). Sum must equal the total amount.',
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildHelpMethodItem(
                  title: '3. Percentage (% Split)',
                  subtitle: 'Assign custom percentages to members (e.g. 60% / 40%). Percentages must sum to 100%.',
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildHelpMethodItem(
                  title: '4. Shares (Proportional)',
                  subtitle: 'Assign ratio shares to members (e.g. 2 shares for couples/families, 1 share for individuals).',
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  text: 'Got It',
                  isFullWidth: true,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpMethodItem({required String title, required String subtitle, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: AppRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTypography.bodySmall(isDark: isDark)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripDetailVm = context.watch<TripDetailViewModel>();
    final addVm = context.watch<AddExpenseViewModel>();
    final l10n = context.l10n;

    final trip = tripDetailVm.trip;
    if (trip == null) {
      return const Scaffold(body: Center(child: Text('Trip not found')));
    }

    final hasUnsavedData = addVm.amountInPaise > 0 || addVm.title.trim().isNotEmpty;

    return PopScope(
      canPop: !hasUnsavedData,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            title: Text(l10n.createTripDiscardTitle, style: AppTypography.titleLarge(isDark: isDark)),
            content: Text(
              l10n.createTripDiscardDesc,
              style: AppTypography.bodyMedium(isDark: isDark),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.createTripDiscardKeep),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.negativeRedDark),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.createTripDiscardConfirm),
              ),
            ],
          ),
        );
        if ((shouldPop ?? false) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                addVm.isEditMode ? l10n.expenseEditTitle : l10n.expenseAddTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '${trip.emoji} ${trip.name} · ${l10n.tripsHomeMembersCount(trip.members.length)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (hasUnsavedData) {
                final shouldPop = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
                    backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    title: Text(l10n.createTripDiscardTitle, style: AppTypography.titleLarge(isDark: isDark)),
                    content: Text(
                      l10n.createTripDiscardDesc,
                      style: AppTypography.bodyMedium(isDark: isDark),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.createTripDiscardKeep),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.negativeRedDark),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.createTripDiscardConfirm),
                      ),
                    ],
                  ),
                );
                if ((shouldPop ?? false) && context.mounted) {
                  context.pop();
                }
              } else {
                context.pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top Mode Tabs (Voice / Receipt Scan / Manual) - Hidden in Edit Mode for simplicity
              if (!addVm.isEditMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    borderRadius: AppRadius.mdBorder,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _buildModeTab(l10n.expenseVoiceTab, Icons.mic_rounded, 0, addVm.currentTab, isDark),
                      _buildModeTab(l10n.expenseReceiptTab, Icons.receipt_long_rounded, 1, addVm.currentTab, isDark),
                      _buildModeTab(l10n.expenseManualTab, Icons.edit_note_rounded, 2, addVm.currentTab, isDark),
                    ],
                  ),
                ),
              ),

            // Tab Body
            Expanded(
              child: addVm.currentTab == 0
                  ? FeatureCraftingHero(
                      type: FeatureCraftingType.voice,
                      onSwitchToManual: () => addVm.setTab(2),
                    )
                  : (addVm.currentTab == 1
                      ? FeatureCraftingHero(
                          type: FeatureCraftingType.receipt,
                          onSwitchToManual: () => addVm.setTab(2),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                          child: _buildManualInputTab(addVm, trip, isDark, l10n),
                        )),
            ),

            // Bottom Save Action Bar (Shown on Manual Tab or Edit Mode)
            if (addVm.currentTab == 2 || addVm.isEditMode)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (addVm.errorMessage != null) ...[
                      Text(
                        addVm.errorMessage!,
                        style: TextStyle(
                          color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.expenseAmountLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              CurrencyDisplay(
                                amountInPaise: addVm.amountInPaise,
                                size: CurrencyDisplaySize.large,
                                currencyCode: trip.currencyCode,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            text: addVm.isEditMode ? l10n.actionEdit : l10n.expenseSaveBtn,
                            icon: Icons.check_rounded,
                            isLoading: addVm.isSaving,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onPressed: _handleSave,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildModeTab(String label, IconData icon, int index, int currentTab, bool isDark) {
    final isSelected = currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticHelper.selection();
          context.read<AddExpenseViewModel>().setTab(index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard)
                : Colors.transparent,
            borderRadius: AppRadius.smBorder,
            boxShadow: isSelected
                ? (isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)] : null)
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isSelected
                      ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSplitTypeDisplayName(SplitType type, AppLocalizations l10n) {
    switch (type) {
      case SplitType.equal: return l10n.expenseSplitEqually;
      case SplitType.exact: return l10n.expenseSplitExact;
      case SplitType.percentage: return l10n.expenseSplitPercentages;
      case SplitType.shares: return l10n.expenseSplitShares;
    }
  }

  Widget _buildManualInputTab(AddExpenseViewModel addVm, Trip trip, bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount Input Field (Hero sized)
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.expenseAmountLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    trip.currencyCode == 'USD' ? '\$' : '₹',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emeraldPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        fillColor: Colors.transparent,
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null) {
                          addVm.setAmountInPaise(CurrencyFormatter.toPaise(parsed));
                        } else {
                          addVm.setAmountInPaise(0);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Expense Title
        Text(l10n.expenseWhatForLabel, style: AppTypography.titleSmall(isDark: isDark)),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l10n.expenseWhatForHint,
            prefixIcon: const Icon(Icons.receipt_outlined, size: 20),
            errorText: _hasAttemptedSave && addVm.title.trim().isEmpty
                ? l10n.expenseWhatForHint
                : null,
          ),
          onChanged: (val) {
            addVm.setTitle(val);
            if (_hasAttemptedSave && val.trim().isNotEmpty) {
              setState(() {});
            }
          },
        ),

        const SizedBox(height: AppSpacing.lg),

        // Category Selector Chips
        Text(l10n.tripDetailTabCategories, style: AppTypography.titleSmall(isDark: isDark)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ExpenseCategory.values.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = ExpenseCategory.values[index];
              final isSelected = addVm.category == cat;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(cat.displayName),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) {
                  HapticHelper.selection();
                  addVm.setCategory(cat);
                },
                selectedColor: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.2),
                backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBorder),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Payer Selector
        Text(l10n.expensePaidByLabel, style: AppTypography.titleSmall(isDark: isDark)),
        const SizedBox(height: AppSpacing.xs),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: addVm.paidById.isNotEmpty ? addVm.paidById : null,
              isExpanded: true,
              hint: Text(l10n.expensePaidByLabel),
              items: trip.members.map((m) {
                return DropdownMenuItem<String>(
                  value: m.id,
                  child: Row(
                    children: [
                      MemberAvatar(name: m.displayName, size: 26),
                      const SizedBox(width: 10),
                      Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) addVm.setPayer(val);
              },
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Split Type Mode Selector + Help Info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(l10n.expenseSplitHowLabel, style: AppTypography.titleSmall(isDark: isDark)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.emeraldPrimary),
                  tooltip: 'Explain split methods',
                  visualDensity: VisualDensity.compact,
                  onPressed: _showSplitMethodsHelp,
                ),
              ],
            ),
            DropdownButton<SplitType>(
              value: addVm.splitType,
              underline: const SizedBox.shrink(),
              items: SplitType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getSplitTypeDisplayName(type, l10n), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (type) {
                if (type != null) addVm.setSplitType(type);
              },
            ),
          ],
        ),

        // Live Allocation Status Indicator for Exact and Percentage splits
        if (addVm.splitType == SplitType.exact) ...[
          const SizedBox(height: 4),
          _buildExactAllocationBanner(addVm, trip.currencyCode, isDark),
        ] else if (addVm.splitType == SplitType.percentage) ...[
          const SizedBox(height: 4),
          _buildPercentageAllocationBanner(addVm, isDark),
        ],

        const SizedBox(height: AppSpacing.xs),

        // Participant Split List

        // Participant Split List
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trip.members.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            ),
            itemBuilder: (context, index) {
              final member = trip.members[index];
              final isSelected = addVm.selectedParticipantMemberIds.contains(member.id);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (_) {
                  HapticHelper.selection();
                  addVm.toggleParticipant(member.id);
                },
                activeColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                title: Row(
                  children: [
                    MemberAvatar(name: member.displayName, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        member.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                secondary: _buildSplitAllocationWidget(addVm, member, isSelected, trip.currencyCode, isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExactAllocationBanner(AddExpenseViewModel addVm, String currencyCode, bool isDark) {
    final remaining = addVm.exactRemainingPaise;
    final isMatched = remaining == 0 && addVm.amountInPaise > 0;
    final isOver = remaining < 0;

    final Color bannerColor = isMatched
        ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
        : (isOver
            ? (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight)
            : AppColors.amberAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.12),
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isMatched ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
            size: 16,
            color: bannerColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMatched
                  ? 'Exact split matches total ${CurrencyFormatter.formatPaise(addVm.amountInPaise, currencyCode: currencyCode)}'
                  : (isOver
                      ? 'Exceeds total by ${CurrencyFormatter.formatPaise(remaining.abs(), currencyCode: currencyCode)}'
                      : '${CurrencyFormatter.formatPaise(remaining, currencyCode: currencyCode)} remaining to allocate'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: bannerColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageAllocationBanner(AddExpenseViewModel addVm, bool isDark) {
    final totalPct = addVm.totalAllocatedPercentage;
    final isMatched = (totalPct - 100.0).abs() < 0.01;

    final Color bannerColor = isMatched
        ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
        : AppColors.amberAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.12),
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isMatched ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
            size: 16,
            color: bannerColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMatched
                  ? 'Percentages sum to 100.0%'
                  : 'Total: ${totalPct.toStringAsFixed(1)}% (must equal 100%)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: bannerColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitAllocationWidget(
    AddExpenseViewModel addVm,
    TripMember member,
    bool isSelected,
    String currencyCode,
    bool isDark,
  ) {
    if (!isSelected) {
      return const Text(
        'Excluded',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    if (addVm.splitType == SplitType.equal) {
      final activeSplits = addVm.computeFinalSplits();
      final split = activeSplits.where((s) => s.memberId == member.id).firstOrNull;
      final amount = split?.amountInPaise ?? 0;

      return Text(
        CurrencyFormatter.formatPaise(amount, currencyCode: currencyCode),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      );
    } else if (addVm.splitType == SplitType.shares) {
      final currentShare = addVm.shares[member.id] ?? 1;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            onPressed: () => addVm.setMemberShare(member.id, currentShare - 1),
          ),
          Text(
            '$currentShare ${currentShare == 1 ? 'share' : 'shares'}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 18),
            onPressed: () => addVm.setMemberShare(member.id, currentShare + 1),
          ),
        ],
      );
    } else if (addVm.splitType == SplitType.exact) {
      final currentPaise = addVm.exactAmountsInPaise[member.id] ?? 0;
      if (!_exactControllers.containsKey(member.id)) {
        _exactControllers[member.id] = TextEditingController(
          text: currentPaise > 0 ? (currentPaise / 100.0).toStringAsFixed(currentPaise % 100 == 0 ? 0 : 2) : '',
        );
      }

      return SizedBox(
        width: 86,
        height: 38,
        child: TextField(
          controller: _exactControllers[member.id],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          decoration: InputDecoration(
            prefixText: currencyCode == 'USD' ? '\$' : '₹',
            hintText: '0',
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            isDense: true,
          ),
          onChanged: (val) {
            final amt = double.tryParse(val) ?? 0;
            addVm.setMemberExactAmount(member.id, CurrencyFormatter.toPaise(amt));
          },
        ),
      );
    } else if (addVm.splitType == SplitType.percentage) {
      final currentPct = addVm.percentages[member.id] ?? 0.0;
      if (!_percentControllers.containsKey(member.id)) {
        _percentControllers[member.id] = TextEditingController(
          text: currentPct > 0 ? currentPct.toStringAsFixed(1) : '',
        );
      }

      return SizedBox(
        width: 72,
        height: 38,
        child: TextField(
          controller: _percentControllers[member.id],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          decoration: const InputDecoration(
            suffixText: '%',
            hintText: '0',
            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            isDense: true,
          ),
          onChanged: (val) {
            final pct = double.tryParse(val) ?? 0.0;
            addVm.setMemberPercentage(member.id, pct);
          },
        ),
      );
    } else {
      return const Text('Custom split', style: TextStyle(fontSize: 12));
    }
  }
}
