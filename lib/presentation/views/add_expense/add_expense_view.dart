import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/kith_calculator_engine.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/kith_amount_calculator_field.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../domain/enums/expense_category.dart';
import '../../../domain/enums/split_type.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/trip.dart';
import '../../../domain/models/trip_member.dart';
import '../../viewmodels/add_expense_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/trip_detail_viewmodel.dart';
import '../../widgets/progress/kith_success_toast.dart';
import 'widgets/feature_crafting_hero.dart';

/// Clean, sleek, and intuitive Add/Edit Expense Experience for Kith.
///
/// Streamlined with a unified Amount + Title card, clean category chips,
/// tactile payer switcher, precision split matrix, and zero bulky/congested clutter.
class AddExpenseView extends StatefulWidget {
  final String tripId;
  final Expense? existingExpense;
  final int initialTab;
  final String? initialPersonName;
  final String? initialMemberId;
  final String? initialTitle;
  final int? initialAmountInPaise;

  const AddExpenseView({
    super.key,
    required this.tripId,
    this.existingExpense,
    this.initialTab = 2,
    this.initialPersonName,
    this.initialMemberId,
    this.initialTitle,
    this.initialAmountInPaise,
  });

  @override
  State<AddExpenseView> createState() => _AddExpenseViewState();
}

class _AddExpenseViewState extends State<AddExpenseView> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingTrip = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initViewModel();
    });
  }

  Future<void> _initViewModel() async {
    final tripDetailVm = context.read<TripDetailViewModel>();
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final user = authVm.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isLoadingTrip = false);
      return;
    }

    String resolvedTripId = widget.tripId;
    if (resolvedTripId.isEmpty) {
      if (homeVm.trips.isNotEmpty) {
        resolvedTripId = homeVm.trips.first.id;
      }
    }

    if (resolvedTripId.isNotEmpty) {
      if (tripDetailVm.trip?.id != resolvedTripId) {
        await tripDetailVm.loadTrip(resolvedTripId, user.id);
      }
    }

    if (!mounted) return;

    final trip = tripDetailVm.trip;
    if (trip != null) {
      final addVm = context.read<AddExpenseViewModel>();
      addVm.setTab(widget.initialTab);
      if (widget.existingExpense != null) {
        addVm.initForEdit(expense: widget.existingExpense!, trip: trip, currentUserId: user.id);
        _titleController.text = widget.existingExpense!.title;
        _amountController.text = (widget.existingExpense!.amountInPaise / 100.0).toStringAsFixed(
          widget.existingExpense!.amountInPaise % 100 == 0 ? 0 : 2,
        );
        _selectedDate = widget.existingExpense!.createdAt;
      } else if (widget.initialMemberId != null || widget.initialPersonName != null || widget.initialTitle != null || widget.initialAmountInPaise != null) {
        // Resolve member id from person name if not provided
        String? targetMemberId = widget.initialMemberId;
        if (targetMemberId == null && widget.initialPersonName != null) {
          final matched = trip.members.where((m) => m.displayName.toLowerCase() == widget.initialPersonName!.toLowerCase()).firstOrNull;
          targetMemberId = matched?.id;
        }

        addVm.initFromContext(
          trip: trip,
          currentUserId: user.id,
          preselectedMemberId: targetMemberId,
          initialTitle: widget.initialTitle,
          initialAmountInPaise: widget.initialAmountInPaise,
        );

        if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
          _titleController.text = widget.initialTitle!;
        }
        if (widget.initialAmountInPaise != null && widget.initialAmountInPaise! > 0) {
          final rupees = widget.initialAmountInPaise! / 100.0;
          _amountController.text = rupees % 1 == 0 ? rupees.toInt().toString() : rupees.toStringAsFixed(2);
        }
      } else {
        addVm.init(trip: trip, currentUserId: user.id);
      }
    }

    setState(() => _isLoadingTrip = false);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final addVm = context.read<AddExpenseViewModel>();
    final tripDetailVm = context.read<TripDetailViewModel>();
    final l10n = context.l10n;
    final trip = tripDetailVm.trip;
    if (trip == null || addVm.isSaving) return;

    // Resolve any pending expression in the calculator field
    final evaluatedPaise = KithCalculatorEngine.evaluateToPaise(_amountController.text);
    if (evaluatedPaise > 0 && addVm.amountInPaise != evaluatedPaise) {
      addVm.setAmountInPaise(evaluatedPaise);
    }

    if (addVm.title.trim().isEmpty || addVm.amountInPaise <= 0 || addVm.selectedParticipantMemberIds.isEmpty) {
      HapticHelper.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addVm.amountInPaise <= 0
                ? l10n.translate('add_expense_err_amount')
                : (addVm.title.trim().isEmpty
                    ? l10n.translate('add_expense_err_title')
                    : l10n.translate('add_expense_err_person')),
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
      KithSuccessToast.show(context, widget.existingExpense != null ? '${l10n.expenseUpdateBtn} ✓' : l10n.translate('add_expense_success'));
    } else if (mounted) {
      HapticHelper.error();
      final err = addVm.errorMessage ?? l10n.translate('error_generic');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.negativeRedDark,
          action: SnackBarAction(
            label: l10n.actionRetry,
            textColor: Colors.white,
            onPressed: _handleSave,
          ),
        ),
      );
    }
  }

  void _showSplitMethodsHelp() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF11161B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.topSheetBorder),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 24.0,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.emeraldPrimary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.expenseSplitOptionHeader,
                        style: AppTypography.titleLarge(isDark: isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildHelpRow('🟰 ${l10n.expenseSplitEqually}', l10n.translate('expense_split_equally_desc'), isDark),
                const SizedBox(height: 12),
                _buildHelpRow('📊 ${l10n.expenseSplitExact}', l10n.translate('expense_split_exact_desc'), isDark),
                const SizedBox(height: 12),
                _buildHelpRow('💯 ${l10n.expenseSplitPercentages}', l10n.translate('expense_split_percentages_desc'), isDark),
                const SizedBox(height: 12),
                _buildHelpRow('⚖️ ${l10n.expenseSplitShares}', l10n.translate('expense_split_shares_desc'), isDark),
                const SizedBox(height: 24),
                AppButton(
                  text: l10n.actionDone,
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

  Widget _buildHelpRow(String title, String desc, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : AppColors.lightTextPrimary)),
        const SizedBox(height: 2),
        Text(desc, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, height: 1.3)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripDetailVm = context.watch<TripDetailViewModel>();
    final addVm = context.watch<AddExpenseViewModel>();
    final trip = tripDetailVm.trip;

    final l10n = context.l10n;

    if (_isLoadingTrip || (tripDetailVm.isLoading && trip == null)) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(l10n.expenseAddTitle),
          backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.emeraldPrimary)),
      );
    }

    if (trip == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(l10n.expenseAddTitle),
          backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
          elevation: 0,
          leading: const BackButton(),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded, size: 40, color: AppColors.emeraldPrimary),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.tripsTabNoActiveTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tripsTabNoActiveDesc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: l10n.tripsCreate,
                  icon: Icons.add_rounded,
                  onPressed: () {
                    context.pop();
                    context.push('/create-trip');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currency = trip.currencyCode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: _buildTopAppBar(context, isDark, addVm, l10n),
      body: Column(
        children: [
          // Mode Tabs (Manual | Voice AI | Scan Receipt)
          _buildModeTabs(context, isDark, addVm, l10n),

          // Main Content
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
                    : _buildManualExpenseForm(context, isDark, addVm, trip, currency, l10n)),
          ),

          // Bottom Action Dock
          if (addVm.currentTab == 2)
            _buildBottomActionDock(context, isDark, addVm, trip, l10n),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context, bool isDark, AddExpenseViewModel addVm, AppLocalizations l10n) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Text(
        widget.existingExpense != null ? l10n.expenseEditTitle : l10n.expenseAddTitle,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, size: 20),
          tooltip: l10n.expenseSplitOptionHeader,
          onPressed: _showSplitMethodsHelp,
        ),
      ],
    );
  }

  Widget _buildModeTabs(BuildContext context, bool isDark, AddExpenseViewModel addVm, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141A21) : const Color(0xFFEDF2F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTabButton(title: l10n.expenseManualTab, icon: Icons.edit_rounded, index: 2, isDark: isDark, activeIndex: addVm.currentTab, onTap: () => addVm.setTab(2)),
            _buildTabButton(title: l10n.expenseVoiceTab, icon: Icons.mic_rounded, index: 0, isDark: isDark, activeIndex: addVm.currentTab, onTap: () => addVm.setTab(0)),
            _buildTabButton(title: l10n.expenseReceiptTab, icon: Icons.document_scanner_rounded, index: 1, isDark: isDark, activeIndex: addVm.currentTab, onTap: () => addVm.setTab(1)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required int index,
    required bool isDark,
    required int activeIndex,
    required VoidCallback onTap,
  }) {
    final isSelected = activeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticHelper.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF222B35) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualExpenseForm(
    BuildContext context,
    bool isDark,
    AddExpenseViewModel addVm,
    Trip trip,
    String currency,
    AppLocalizations l10n,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      children: [
        // 1. Unified Amount & Description Card
        _buildAmountAndTitleCard(context, isDark, addVm, currency, l10n),

        const SizedBox(height: 16),

        // 2. Category Selector (Horizontal Chips)
        _buildCategorySection(isDark, addVm, l10n),

        const SizedBox(height: 16),

        // 3. Paid By (Who Paid?)
        _buildPayerSection(isDark, addVm, trip, l10n),

        const SizedBox(height: 16),

        // 4. Split Type & Participants Matrix
        _buildSplitAndParticipantsSection(isDark, addVm, trip, currency, l10n),

        const SizedBox(height: 16),

        // 5. Date Selector Pill
        _buildDateSelectorPill(isDark, l10n),

        const SizedBox(height: 32),
      ],
    );
  }

  /// Single, sleek unified card for Amount & Expense Title.
  Widget _buildAmountAndTitleCard(
    BuildContext context,
    bool isDark,
    AddExpenseViewModel addVm,
    String currency,
    AppLocalizations l10n,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount Section with Built-in Calculator Engine & '+' Operator
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: KithAmountCalculatorField(
              controller: _amountController,
              currencyCode: currency,
              onAmountChanged: (evaluatedPaise) {
                addVm.setAmountInPaise(evaluatedPaise);
              },
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.8,
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          ),

          // Description / Title Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: KithInputDecoration.borderless(
                      hintText: l10n.translate('add_expense_title_hint'),
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontSize: 14,
                      ),
                    ),
                    onChanged: (val) => addVm.setTitle(val),
                  ),
                ),
                if (_titleController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      HapticHelper.light();
                      _titleController.clear();
                      addVm.setTitle('');
                    },
                    child: Icon(Icons.close_rounded, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact Horizontal Category Chips.
  Widget _buildCategorySection(bool isDark, AddExpenseViewModel addVm, AppLocalizations l10n) {
    const categories = ExpenseCategory.values;
    final activeColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.expenseCategoryHeader,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = addVm.category == cat;

              return InkWell(
                onTap: () {
                  HapticHelper.selection();
                  addVm.setCategory(cat);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: isDark ? 0.2 : 0.12)
                        : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? activeColor
                          : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                      width: isSelected ? 1.4 : 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        cat.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.white : activeColor)
                              : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Compact Payer Selector.
  Widget _buildPayerSection(bool isDark, AddExpenseViewModel addVm, Trip trip, AppLocalizations l10n) {
    final activeColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.expensePaidByHeader,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: trip.members.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final member = trip.members[index];
              final isSelected = addVm.paidById == member.id;

              return InkWell(
                onTap: () {
                  HapticHelper.selection();
                  addVm.setPayer(member.id);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: isDark ? 0.2 : 0.12)
                        : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? activeColor
                          : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                      width: isSelected ? 1.4 : 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MemberAvatar(name: member.displayName, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        member.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.white : activeColor)
                              : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Clean Split Type and Participants section.
  Widget _buildSplitAndParticipantsSection(
    bool isDark,
    AddExpenseViewModel addVm,
    Trip trip,
    String currency,
    AppLocalizations l10n,
  ) {
    final count = addVm.selectedParticipantMemberIds.length;
    final allSelected = count == trip.members.length;
    final activeColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Split Type Selector Bar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141A21) : const Color(0xFFEDF2F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildSplitTypeTab('🟰 ${l10n.expenseSplitEqually}', SplitType.equal, addVm.splitType, isDark, () => addVm.setSplitType(SplitType.equal)),
                _buildSplitTypeTab('📊 ${l10n.expenseSplitExact}', SplitType.exact, addVm.splitType, isDark, () => addVm.setSplitType(SplitType.exact)),
                _buildSplitTypeTab('💯 ${l10n.expenseSplitPercentages}', SplitType.percentage, addVm.splitType, isDark, () => addVm.setSplitType(SplitType.percentage)),
                _buildSplitTypeTab('⚖️ ${l10n.expenseSplitShares}', SplitType.shares, addVm.splitType, isDark, () => addVm.setSplitType(SplitType.shares)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Header Row: Count + Toggle All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.expenseSplitOptionHeader} ($count / ${trip.members.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticHelper.light();
                  if (allSelected) {
                    for (final m in trip.members.skip(1)) {
                      if (addVm.selectedParticipantMemberIds.contains(m.id)) {
                        addVm.toggleParticipant(m.id);
                      }
                    }
                  } else {
                    for (final m in trip.members) {
                      if (!addVm.selectedParticipantMemberIds.contains(m.id)) {
                        addVm.toggleParticipant(m.id);
                      }
                    }
                  }
                },
                child: Text(
                  allSelected ? l10n.translate('settlement_clear_all') : l10n.translate('settlement_select_all'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: activeColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Validation indicator for Exact or % splits
          if (addVm.splitType == SplitType.exact)
            _buildExactValidationBar(isDark, addVm, currency),
          if (addVm.splitType == SplitType.percentage)
            _buildPercentValidationBar(isDark, addVm),

          // Member item list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trip.members.length,
            separatorBuilder: (_, _) => Divider(
              height: 12,
              thickness: 0.5,
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            ),
            itemBuilder: (context, index) {
              final member = trip.members[index];
              final isChecked = addVm.selectedParticipantMemberIds.contains(member.id);

              return _buildMemberSplitRow(isDark, addVm, member, isChecked, currency, count);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSplitTypeTab(
    String label,
    SplitType type,
    SplitType activeType,
    bool isDark,
    VoidCallback onTap,
  ) {
    final isSelected = type == activeType;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticHelper.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 32,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF222B35) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                  : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExactValidationBar(bool isDark, AddExpenseViewModel addVm, String currency) {
    final remaining = addVm.exactRemainingPaise;
    final isBalanced = remaining == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isBalanced
            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isBalanced ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 14,
            color: isBalanced
                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                : Colors.amber,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isBalanced
                  ? 'Exact amounts match total bill ✓'
                  : 'Remaining: ${CurrencyFormatter.formatPaise(remaining.abs(), currencyCode: currency)} ${remaining > 0 ? "left" : "over"}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isBalanced
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                    : (isDark ? Colors.amberAccent : Colors.orange[800]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentValidationBar(bool isDark, AddExpenseViewModel addVm) {
    final total = addVm.totalAllocatedPercentage;
    final is100 = (total - 100.0).abs() < 0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: is100
            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            is100 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 14,
            color: is100
                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                : Colors.amber,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              is100
                  ? 'Percentages total 100% ✓'
                  : 'Total: ${total.toStringAsFixed(1)}% (Must be 100%)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: is100
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                    : (isDark ? Colors.amberAccent : Colors.orange[800]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSplitRow(
    bool isDark,
    AddExpenseViewModel addVm,
    TripMember member,
    bool isChecked,
    String currency,
    int selectedCount,
  ) {
    final perPersonPaise = (isChecked && selectedCount > 0)
        ? (addVm.amountInPaise / selectedCount).round()
        : 0;

    return Row(
      children: [
        // Checkbox
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: isChecked,
            activeColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onChanged: (_) {
              HapticHelper.selection();
              addVm.toggleParticipant(member.id);
            },
          ),
        ),
        const SizedBox(width: 6),
        MemberAvatar(name: member.displayName, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            member.displayName,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
              color: isChecked
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
          ),
        ),

        // Split Input depending on mode
        if (addVm.splitType == SplitType.equal)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isChecked
                  ? (isDark ? const Color(0xFF1A232C) : const Color(0xFFF1F5F9))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isChecked ? CurrencyFormatter.formatPaise(perPersonPaise, currencyCode: currency) : '₹0',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isChecked
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
            ),
          )
        else if (addVm.splitType == SplitType.exact)
          Container(
            width: 80,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182028) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: TextField(
              enabled: isChecked,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: KithInputDecoration.borderless(
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
              ),
              onChanged: (val) {
                final doubleVal = double.tryParse(val) ?? 0.0;
                addVm.setMemberExactAmount(member.id, (doubleVal * 100).round());
              },
            ),
          )
        else if (addVm.splitType == SplitType.percentage)
          Container(
            width: 70,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182028) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: TextField(
              enabled: isChecked,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: KithInputDecoration.borderless(
                suffixText: ' %',
                suffixStyle: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
              ),
              onChanged: (val) {
                final doubleVal = double.tryParse(val) ?? 0.0;
                addVm.setMemberPercentage(member.id, doubleVal);
              },
            ),
          )
        else if (addVm.splitType == SplitType.shares)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: isChecked && (addVm.shares[member.id] ?? 1) > 1
                    ? () => addVm.setMemberShare(member.id, (addVm.shares[member.id] ?? 1) - 1)
                    : null,
              ),
              const SizedBox(width: 4),
              Text(
                '${addVm.shares[member.id] ?? 1}x',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: isChecked
                    ? () => addVm.setMemberShare(member.id, (addVm.shares[member.id] ?? 1) + 1)
                    : null,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDateSelectorPill(bool isDark, AppLocalizations l10n) {
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              '${l10n.translate('add_expense_date_label')}: $dateStr',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 11,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionDock(
    BuildContext context,
    bool isDark,
    AddExpenseViewModel addVm,
    Trip trip,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            width: 0.8,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: addVm.isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emeraldPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: addVm.isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.existingExpense != null ? Icons.save_rounded : Icons.check_circle_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.existingExpense != null ? l10n.expenseUpdateBtn : l10n.expenseSaveBtn,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
