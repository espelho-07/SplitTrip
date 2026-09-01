import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/kith_calculator_engine.dart';
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
/// Streamlined matching the requested simple UI:
/// - Sticky bottom dock with live Total Amount & Save Button
/// - Large amount card with active cursor
/// - Clean Category selector with active checkmark
/// - Direct "Who Paid?" dropdown card
/// - Header Split Method (?) guide + Dropdown
/// - Clean per-participant split cards with checkboxes
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
  final TextEditingController _locationController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingTrip = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initViewModel();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
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
        if (widget.existingExpense!.location != null) _locationController.text = widget.existingExpense!.location!;
      } else if (widget.initialMemberId != null || widget.initialPersonName != null || widget.initialTitle != null || widget.initialAmountInPaise != null) {
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

  Future<void> _handleSave() async {
    final addVm = context.read<AddExpenseViewModel>();
    final tripDetailVm = context.read<TripDetailViewModel>();
    final trip = tripDetailVm.trip;

    if (trip == null) return;

    if (addVm.amountInPaise <= 0) {
      HapticHelper.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid expense amount'),
          backgroundColor: AppColors.negativeRedLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (addVm.title.trim().isEmpty) {
      HapticHelper.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an expense description'),
          backgroundColor: AppColors.negativeRedLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (addVm.selectedParticipantMemberIds.isEmpty) {
      HapticHelper.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one participant to split with'),
          backgroundColor: AppColors.negativeRedLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticHelper.medium();
    final isEditing = widget.existingExpense != null;

    final saved = await addVm.saveExpense(trip.id);

    if (!mounted) return;

    if (saved != null) {
      HapticHelper.success();
      final authVm = context.read<AuthViewModel>();
      if (authVm.currentUser != null) {
        tripDetailVm.loadTrip(trip.id, authVm.currentUser!.id);
      }

      KithSuccessToast.show(
        context,
        isEditing ? 'Expense updated successfully!' : 'Expense saved successfully!',
      );

      context.pop();
    } else if (addVm.errorMessage != null) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(addVm.errorMessage!),
          backgroundColor: AppColors.negativeRedLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                ElevatedButton.icon(
                  onPressed: () {
                    context.pop();
                    context.push('/create-trip');
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.tripsCreate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
      appBar: _buildTopAppBar(context, isDark, addVm, trip, l10n),
      body: Column(
        children: [
          // Mode Tabs (Voice | Receipt | Manual)
          _buildModeTabs(context, isDark, addVm, l10n),

          // Main Scrollable Content
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
        ],
      ),
      bottomNavigationBar: addVm.currentTab == 2
          ? _buildBottomActionDock(context, isDark, addVm, trip, currency, l10n)
          : null,
    );
  }

  PreferredSizeWidget _buildTopAppBar(
    BuildContext context,
    bool isDark,
    AddExpenseViewModel addVm,
    Trip trip,
    AppLocalizations l10n,
  ) {
    final tripEmoji = trip.emoji.isNotEmpty ? trip.emoji : '✈️';
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, size: 24),
        onPressed: () => context.pop(),
      ),
      title: Column(
        children: [
          Text(
            widget.existingExpense != null ? 'Edit Group Expense' : 'Add Group Expense',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$tripEmoji ${trip.name} • Split with ${trip.members.length} members',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs(BuildContext context, bool isDark, AddExpenseViewModel addVm, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141A21) : const Color(0xFFEDF2F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _buildTabButton(title: 'Voice', icon: Icons.mic_rounded, index: 0, isDark: isDark, activeIndex: addVm.currentTab, onTap: () => addVm.setTab(0)),
            _buildTabButton(title: 'Receipt', icon: Icons.receipt_long_rounded, index: 1, isDark: isDark, activeIndex: addVm.currentTab, onTap: () => addVm.setTab(1)),
            _buildTabButton(title: 'Manual', icon: Icons.edit_note_rounded, index: 2, isDark: isDark, activeIndex: addVm.currentTab, onTap: () => addVm.setTab(2)),
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
            borderRadius: BorderRadius.circular(10),
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
                size: 15,
                color: isSelected
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                    : (isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
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
        // 1. Amount Card
        _buildAmountCard(context, isDark, addVm, currency),

        const SizedBox(height: 16),

        // 2. What was this for?
        _buildTitleSection(isDark, addVm),

        const SizedBox(height: 16),

        // 3. Category Selector
        _buildCategorySection(isDark, addVm),

        const SizedBox(height: 16),

        // 4. Who Paid?
        _buildPayerSection(isDark, addVm, trip),

        const SizedBox(height: 16),

        // 5. Split Method & Participants Matrix
        _buildSplitAndParticipantsSection(isDark, addVm, trip, currency),

        const SizedBox(height: 16),

        // 6. Date Selector Pill
        _buildDateSelectorPill(isDark, l10n),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAmountCard(BuildContext context, bool isDark, AddExpenseViewModel addVm, String currency) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          Text(
            'Amount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '₹',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  cursorColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 32, fontWeight: FontWeight.w800),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    final evaluated = KithCalculatorEngine.evaluateToPaise(val);
                    addVm.setAmountInPaise(evaluated);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(bool isDark, AddExpenseViewModel addVm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What was this for?',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A21) : const Color(0xFFEFF3F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorderSubtle : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 20,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Train tickets, Dinner, Groceries',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) => addVm.setTitle(val),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(bool isDark, AddExpenseViewModel addVm) {
    const categories = ExpenseCategory.values;
    final activeColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = addVm.category == cat;

              return InkWell(
                onTap: () {
                  HapticHelper.selection();
                  addVm.setCategory(cat);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF132A22) : const Color(0xFFE2F3ED))
                        : (isDark ? const Color(0xFF141A21) : const Color(0xFFEFF3F0)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? activeColor : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        cat.displayName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.white : activeColor)
                              : (isDark ? AppColors.darkTextSecondary : const Color(0xFF334155)),
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

  Widget _buildPayerSection(bool isDark, AddExpenseViewModel addVm, Trip trip) {
    final payer = trip.members.firstWhere(
      (m) => m.id == addVm.paidById,
      orElse: () => trip.members.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who Paid?',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
              width: 0.8,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: payer.id,
              isDense: true,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                size: 24,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              ),
              dropdownColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              items: trip.members.map((m) {
                return DropdownMenuItem<String>(
                  value: m.id,
                  child: Row(
                    children: [
                      _buildInitialsAvatar(m.displayName, isDark),
                      const SizedBox(width: 12),
                      Text(
                        m.displayName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newPayerId) {
                if (newPayerId != null) {
                  HapticHelper.selection();
                  addVm.setPayer(newPayerId);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitAndParticipantsSection(
    bool isDark,
    AddExpenseViewModel addVm,
    Trip trip,
    String currency,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row: Split Method + (?) + Dropdown
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Split Method',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _showSplitMethodsExplainer(context, isDark, addVm),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.question_mark_rounded,
                      size: 13,
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    ),
                  ),
                ),
              ],
            ),
            // Dropdown
            DropdownButtonHideUnderline(
              child: DropdownButton<SplitType>(
                value: addVm.splitType,
                isDense: true,
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 20,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                ),
                dropdownColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                items: const [
                  DropdownMenuItem(value: SplitType.equal, child: Text('Equally', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: SplitType.exact, child: Text('Exact Amounts', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: SplitType.percentage, child: Text('By Percentage', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: SplitType.shares, child: Text('By Shares', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                ],
                onChanged: (newType) {
                  if (newType != null) {
                    HapticHelper.selection();
                    addVm.setSplitType(newType);
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Member list cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trip.members.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final member = trip.members[index];
            final isChecked = addVm.selectedParticipantMemberIds.contains(member.id);

            return _buildCleanMemberRow(isDark, addVm, member, isChecked, currency);
          },
        ),
      ],
    );
  }

  Widget _buildCleanMemberRow(
    bool isDark,
    AddExpenseViewModel addVm,
    TripMember member,
    bool isChecked,
    String currency,
  ) {
    final activeColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
    int sharePaise = 0;
    if (isChecked) {
      final splits = addVm.computeFinalSplits();
      final match = splits.where((s) => s.memberId == member.id).firstOrNull;
      sharePaise = match?.amountInPaise ?? 0;
    }
    final formattedShare = CurrencyFormatter.formatPaise(sharePaise, currencyCode: currency);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isChecked
              ? (isDark ? activeColor.withValues(alpha: 0.3) : const Color(0xFFD1FAE5))
              : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Amount for this member
          SizedBox(
            width: 75,
            child: Text(
              formattedShare,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isChecked
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Avatar & Name
          _buildInitialsAvatar(member.displayName, isDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isChecked
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
              ),
            ),
          ),

          // If Exact Split -> show rupee edit field
          if (addVm.splitType == SplitType.exact)
            SizedBox(
              width: 75,
              height: 32,
              child: TextFormField(
                initialValue: ((addVm.exactAmountsInPaise[member.id] ?? 0) / 100).toStringAsFixed(0),
                enabled: isChecked,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '₹',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  isDense: true,
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val) ?? 0.0;
                  addVm.setMemberExactAmount(member.id, (parsed * 100).round());
                },
              ),
            )
          else if (addVm.splitType == SplitType.percentage)
            SizedBox(
              width: 65,
              height: 32,
              child: TextFormField(
                initialValue: (addVm.percentages[member.id] ?? 0.0).toStringAsFixed(0),
                enabled: isChecked,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  suffixText: '%',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  isDense: true,
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val) ?? 0.0;
                  addVm.setMemberPercentage(member.id, parsed);
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
                Text('${addVm.shares[member.id] ?? 1}x', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
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

          const SizedBox(width: 8),

          // Checkbox
          InkWell(
            onTap: () {
              HapticHelper.selection();
              addVm.toggleParticipant(member.id);
            },
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked ? activeColor : (isDark ? Colors.white38 : const Color(0xFFCBD5E1)),
                  width: 1.8,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(String name, bool isDark) {
    final initials = name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join('').toUpperCase();
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFFBAE6FD),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : 'DA',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0284C7),
        ),
      ),
    );
  }

  void _showSplitMethodsExplainer(
    BuildContext context,
    bool isDark,
    AddExpenseViewModel addVm,
  ) {
    HapticHelper.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.call_split_rounded,
                              size: 20,
                              color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Split Methods Explained',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'How Kith divides trip expenses',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Equal Split
                  _buildExplainerMethodCard(
                    isDark: isDark,
                    emoji: '🟰',
                    title: 'Split Equally',
                    badge: 'Default • Most Common',
                    description: 'Divides the entire amount evenly across all checked members. Remainder paise are automatically distributed deterministically.',
                    example: 'Example: ₹1,500 dinner bill split among 3 friends = ₹500 each.',
                    isSelected: addVm.splitType == SplitType.equal,
                    onSelect: () {
                      addVm.setSplitType(SplitType.equal);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 10),

                  // 2. Exact Amounts
                  _buildExplainerMethodCard(
                    isDark: isDark,
                    emoji: '📊',
                    title: 'Exact Amounts (₹)',
                    badge: 'Itemized Bills',
                    description: 'Enter custom specific amounts in Rupees for each individual. The sum must exactly equal total amount.',
                    example: 'Example: Rahul ordered ₹600, Rohit ₹400, Priya ₹500 on a ₹1,500 bill.',
                    isSelected: addVm.splitType == SplitType.exact,
                    onSelect: () {
                      addVm.setSplitType(SplitType.exact);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 10),

                  // 3. By Percentage
                  _buildExplainerMethodCard(
                    isDark: isDark,
                    emoji: '💯',
                    title: 'By Percentage (%)',
                    badge: 'Proportional Shares',
                    description: 'Assign each person a percentage share. Total percentage across all members must add up to 100%.',
                    example: 'Example: Master bedroom occupant pays 50%, other rooms pay 25% each.',
                    isSelected: addVm.splitType == SplitType.percentage,
                    onSelect: () {
                      addVm.setSplitType(SplitType.percentage);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 10),

                  // 4. By Shares / Ratios
                  _buildExplainerMethodCard(
                    isDark: isDark,
                    emoji: '⚖️',
                    title: 'By Shares / Ratios',
                    badge: 'Families & Couples',
                    description: 'Assign numerical units (e.g. 1, 2, 3 shares). Ideal when friends bring family or consume more.',
                    example: 'Example: Couple gets 2 shares, 2 singles get 1 share each (Total 4 shares on ₹4,000 = ₹2,000 for couple, ₹1,000 each).',
                    isSelected: addVm.splitType == SplitType.shares,
                    onSelect: () {
                      addVm.setSplitType(SplitType.shares);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExplainerMethodCard({
    required bool isDark,
    required String emoji,
    required String title,
    required String badge,
    required String description,
    required String example,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    final activeColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticHelper.selection();
          onSelect();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF132A22) : const Color(0xFFECFDF5))
                : (isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
              width: isSelected ? 1.5 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor.withValues(alpha: 0.2)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSelected ? 'ACTIVE' : badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? activeColor
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 14,
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        example,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
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
    String currency,
    AppLocalizations l10n,
  ) {
    final totalFormatted = CurrencyFormatter.formatPaise(addVm.amountInPaise, currencyCode: currency);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF080C0E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Total Amount + Live Rupees
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                totalFormatted,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          // Right: Save Expense Button
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: addVm.isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                elevation: 0,
              ),
              child: addVm.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.existingExpense != null ? 'Update Expense' : 'Save Expense',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
