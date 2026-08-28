import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
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

/// Master Redesigned Add & Edit Expense Experience for Kith.
///
/// Features a hero amount card, quick preset chips, 8-category carousel,
/// 1-tap payer switcher, 4 precision split engines (Equal, Exact, %, Shares),
/// and seamless Voice & Receipt scanning workflows.
class AddExpenseView extends StatefulWidget {
  final String tripId;
  final Expense? existingExpense;
  final int initialTab;

  const AddExpenseView({
    super.key,
    required this.tripId,
    this.existingExpense,
    this.initialTab = 2,
  });

  @override
  State<AddExpenseView> createState() => _AddExpenseViewState();
}

class _AddExpenseViewState extends State<AddExpenseView> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingTrip = true;

  static const List<Map<String, dynamic>> _quickPresets = [
    {'title': 'Dinner', 'icon': '🍔', 'category': ExpenseCategory.food},
    {'title': 'Cab / Taxi', 'icon': '🚕', 'category': ExpenseCategory.transport},
    {'title': 'Fuel', 'icon': '⛽', 'category': ExpenseCategory.transport},
    {'title': 'Groceries', 'icon': '🛒', 'category': ExpenseCategory.groceries},
    {'title': 'Hotel / Stay', 'icon': '🏨', 'category': ExpenseCategory.stay},
    {'title': 'Coffee & Cafe', 'icon': '☕', 'category': ExpenseCategory.drinks},
    {'title': 'Drinks & Bar', 'icon': '🍹', 'category': ExpenseCategory.drinks},
    {'title': 'Tickets & Entry', 'icon': '🎟️', 'category': ExpenseCategory.activities},
    {'title': 'Shopping', 'icon': '🛍️', 'category': ExpenseCategory.shopping},
  ];

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
    final trip = tripDetailVm.trip;
    if (trip == null || addVm.isSaving) return;

    if (addVm.title.trim().isEmpty || addVm.amountInPaise <= 0 || addVm.selectedParticipantMemberIds.isEmpty) {
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
      KithSuccessToast.show(context, widget.existingExpense != null ? 'Expense updated ✓' : 'Expense added ✓');
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
                        'Split Methods Explained',
                        style: AppTypography.titleLarge(isDark: isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildHelpRow('🟰 Split Equally', 'Evenly divides the bill across all checked participants.', isDark),
                const SizedBox(height: 12),
                _buildHelpRow('📊 Exact Amounts', 'Assign custom ₹ amounts per person. Kith ensures the exact sum matches.', isDark),
                const SizedBox(height: 12),
                _buildHelpRow('💯 Percentages', 'Assign percentage shares (e.g. 50%, 25%, 25%). Must equal 100%.', isDark),
                const SizedBox(height: 12),
                _buildHelpRow('⚖️ By Shares', 'Split by ratios (e.g. 2 shares for couples, 1 share for singles).', isDark),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Got it',
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

    if (_isLoadingTrip || (tripDetailVm.isLoading && trip == null)) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Add Expense'),
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
          title: const Text('Add Expense'),
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
                  'No Active Trip Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please select or create a trip first to start splitting expenses with friends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Create a Trip',
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
      appBar: _buildTopAppBar(context, isDark, addVm),
      body: Column(
        children: [
          // Mode Tabs (Manual | Voice AI | Scan Receipt)
          _buildModeTabs(context, isDark, addVm),

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
                    : _buildManualExpenseForm(context, isDark, addVm, trip, currency)),
          ),

          // Bottom Action Dock
          if (addVm.currentTab == 2)
            _buildBottomActionDock(context, isDark, addVm, trip),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context, bool isDark, AddExpenseViewModel addVm) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      title: Text(
        widget.existingExpense != null ? 'Edit Expense' : 'Add Expense',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, size: 22),
          tooltip: 'Split Help',
          onPressed: _showSplitMethodsHelp,
        ),
      ],
    );
  }

  Widget _buildModeTabs(BuildContext context, bool isDark, AddExpenseViewModel addVm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141A21) : const Color(0xFFEDF2F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            _buildTabButton(title: 'Manual', icon: Icons.edit_rounded, index: 2, isDark: isDark, activeIndex: addVm.currentTab, onTap: () => addVm.setTab(2)),
            _buildTabButton(title: 'Voice AI', icon: Icons.mic_rounded, index: 0, isDark: isDark, activeIndex: addVm.currentTab, onTap: () => addVm.setTab(0)),
            _buildTabButton(title: 'Scan Receipt', icon: Icons.document_scanner_rounded, index: 1, isDark: isDark, activeIndex: addVm.currentTab, onTap: () => addVm.setTab(1)),
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
          duration: const Duration(milliseconds: 200),
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF222B35) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
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
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      children: [
        // 1. Hero Amount Card
        _buildHeroAmountCard(context, isDark, addVm, currency),

        const SizedBox(height: 14),

        // 2. Quick Merchant Presets
        _buildQuickPresetsRow(isDark, addVm),

        const SizedBox(height: 18),

        // 3. Expense Description Field
        _buildDescriptionField(isDark, addVm),

        const SizedBox(height: 18),

        // 4. Category Selector Carousel
        _buildCategoryCarousel(isDark, addVm),

        const SizedBox(height: 20),

        // 5. Payer Selector Deck
        _buildPayerSelector(isDark, addVm, trip),

        const SizedBox(height: 20),

        // 6. Split Type Selector (Equal, Exact, %, Shares)
        _buildSplitTypeSelector(isDark, addVm),

        const SizedBox(height: 16),

        // 7. Participants Matrix
        _buildParticipantsSection(isDark, addVm, trip, currency),

        const SizedBox(height: 20),

        // 8. Date Selector Pill
        _buildDateSelectorPill(isDark),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeroAmountCard(
    BuildContext context,
    bool isDark,
    AddExpenseViewModel addVm,
    String currency,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11161B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: isDark ? 0.25 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: isDark ? 0.06 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AMOUNT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              // Category tag inside hero
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(addVm.category.emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      addVm.category.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                currency == 'INR' ? '₹' : currency,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    final doubleVal = double.tryParse(val) ?? 0.0;
                    addVm.setAmountInPaise((doubleVal * 100).round());
                  },
                ),
              ),
              if (_amountController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    _amountController.clear();
                    addVm.setAmountInPaise(0);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresetsRow(bool isDark, AddExpenseViewModel addVm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK SUGGESTIONS',
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
            itemCount: _quickPresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = _quickPresets[index];
              return InkWell(
                onTap: () {
                  HapticHelper.selection();
                  _titleController.text = preset['title'];
                  addVm.setTitle(preset['title']);
                  addVm.setCategory(preset['category']);
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141A21) : const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(preset['icon'], style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        preset['title'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
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

  Widget _buildDescriptionField(bool isDark, AddExpenseViewModel addVm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11161B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note_rounded,
            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'What was this expense for?',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (val) => addVm.setTitle(val),
            ),
          ),
          if (_titleController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _titleController.clear();
                addVm.setTitle('');
              },
              child: Icon(Icons.close_rounded, size: 18, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryCarousel(bool isDark, AddExpenseViewModel addVm) {
    const categories = ExpenseCategory.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
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
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.18)
                        : (isDark ? const Color(0xFF141A21) : const Color(0xFFEDF2F7)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                          : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        cat.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
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

  Widget _buildPayerSelector(bool isDark, AddExpenseViewModel addVm, Trip trip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11161B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PAID BY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '1 Payer',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Horizontal Member Selector Chips
          SizedBox(
            height: 42,
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
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.2)
                          : (isDark ? const Color(0xFF182028) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MemberAvatar(name: member.displayName, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          member.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? (isDark ? Colors.white : AppColors.emeraldPrimary)
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
      ),
    );
  }

  Widget _buildSplitTypeSelector(bool isDark, AddExpenseViewModel addVm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SPLIT TYPE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A21) : const Color(0xFFEDF2F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _buildSplitTypeTab('🟰 Equally', SplitType.equal, addVm.splitType, isDark, () => addVm.setSplitType(SplitType.equal)),
              _buildSplitTypeTab('📊 Exact', SplitType.exact, addVm.splitType, isDark, () => addVm.setSplitType(SplitType.exact)),
              _buildSplitTypeTab('💯 %', SplitType.percentage, addVm.splitType, isDark, () => addVm.setSplitType(SplitType.percentage)),
              _buildSplitTypeTab('⚖️ Shares', SplitType.shares, addVm.splitType, isDark, () => addVm.setSplitType(SplitType.shares)),
            ],
          ),
        ),
      ],
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
          duration: const Duration(milliseconds: 200),
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF222B35) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
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

  Widget _buildParticipantsSection(
    bool isDark,
    AddExpenseViewModel addVm,
    Trip trip,
    String currency,
  ) {
    final count = addVm.selectedParticipantMemberIds.length;
    final allSelected = count == trip.members.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11161B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SPLIT BETWEEN ($count / ${trip.members.length})',
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
                    // Deselect down to first member
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
                  allSelected ? 'Clear Others' : 'Select All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

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
              height: 16,
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

  Widget _buildExactValidationBar(bool isDark, AddExpenseViewModel addVm, String currency) {
    final remaining = addVm.exactRemainingPaise;
    final isBalanced = remaining == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isBalanced
            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isBalanced ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 16,
            color: isBalanced
                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                : Colors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isBalanced
                  ? 'Exact amounts match total bill perfectly ✓'
                  : 'Remaining to assign: ${CurrencyFormatter.formatPaise(remaining.abs(), currencyCode: currency)} ${remaining > 0 ? "left" : "over"}',
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: is100
            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            is100 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 16,
            color: is100
                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                : Colors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              is100
                  ? 'Percentages total 100% ✓'
                  : 'Current total: ${total.toStringAsFixed(1)}% (Must be 100%)',
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
        Checkbox(
          value: isChecked,
          activeColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          onChanged: (_) {
            HapticHelper.selection();
            addVm.toggleParticipant(member.id);
          },
        ),
        MemberAvatar(name: member.displayName, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            member.displayName,
            style: TextStyle(
              fontSize: 13,
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isChecked
                  ? (isDark ? const Color(0xFF1A232C) : const Color(0xFFF1F5F9))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
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
          SizedBox(
            width: 85,
            height: 32,
            child: TextField(
              enabled: isChecked,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: isDark ? const Color(0xFF182028) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                final doubleVal = double.tryParse(val) ?? 0.0;
                addVm.setMemberExactAmount(member.id, (doubleVal * 100).round());
              },
            ),
          )
        else if (addVm.splitType == SplitType.percentage)
          SizedBox(
            width: 75,
            height: 32,
            child: TextField(
              enabled: isChecked,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                suffixText: ' %',
                suffixStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: isDark ? const Color(0xFF182028) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
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
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                onPressed: isChecked && (addVm.shares[member.id] ?? 1) > 1
                    ? () => addVm.setMemberShare(member.id, (addVm.shares[member.id] ?? 1) - 1)
                    : null,
              ),
              Text(
                '${addVm.shares[member.id] ?? 1}x',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                onPressed: isChecked
                    ? () => addVm.setMemberShare(member.id, (addVm.shares[member.id] ?? 1) + 1)
                    : null,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDateSelectorPill(bool isDark) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF11161B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
            ),
            const SizedBox(width: 10),
            Text(
              'Date: $dateStr',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
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
  ) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1217) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: AppButton(
        text: widget.existingExpense != null ? 'Update Expense' : 'Save Expense',
        icon: Icons.check_circle_rounded,
        isLoading: addVm.isSaving,
        isFullWidth: true,
        onPressed: _handleSave,
      ),
    );
  }
}
