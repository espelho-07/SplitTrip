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
import '../../../core/services/location_service.dart';
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
  final TextEditingController _locationController = TextEditingController();
  bool _isFetchingLocation = false;
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
        if (widget.existingExpense!.location != null) _locationController.text = widget.existingExpense!.location!;
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

  Future<void> _fetchCurrentLocation(AddExpenseViewModel addVm) async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    HapticHelper.selection();

    final place = await LocationService().getCurrentPlaceName();
    if (!mounted) return;

    setState(() => _isFetchingLocation = false);

    if (place != null && place.trim().isNotEmpty) {
      HapticHelper.medium();
      _locationController.text = place;
      addVm.setLocation(place);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('📍 $place', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF14B8A6),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      HapticHelper.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not fetch location. You can type manually.'),
          backgroundColor: Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _locationController.dispose();
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
          // Amount Section with Built-in Calculator Engine
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: KithAmountCalculatorField(
              controller: _amountController,
              currencyCode: currency,
              useInAppKeypad: false,
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
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    readOnly: false,
                    showCursor: true,
                    enableInteractiveSelection: true,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: KithInputDecoration.borderless(
                      hintText: 'Expense title',
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

          Divider(
            height: 1,
            thickness: 0.8,
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          ),

          // Where / Location Field (Manual Typing or Current GPS Location)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    readOnly: false,
                    showCursor: true,
                    enableInteractiveSelection: true,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: KithInputDecoration.borderless(
                      hintText: 'Location (optional)',
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontSize: 13.5,
                      ),
                    ),
                    onChanged: (val) => addVm.setLocation(val),
                  ),
                ),
                if (_locationController.text.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () {
                      HapticHelper.light();
                      _locationController.clear();
                      addVm.setLocation('');
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],

                // "Current Location" GPS Action Button
                Tooltip(
                  message: 'Use Current Location',
                  child: InkWell(
                    onTap: _isFetchingLocation ? null : () => _fetchCurrentLocation(addVm),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: _isFetchingLocation
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.my_location_rounded,
                                  size: 14,
                                  color: Color(0xFF14B8A6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'GPS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF14B8A6),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
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

  /// Clean Split Type and Participants section with Dropdown and (?) Explainer.
  Widget _buildSplitAndParticipantsSection(
    bool isDark,
    AddExpenseViewModel addVm,
    Trip trip,
    String currency,
    AppLocalizations l10n,
  ) {
    final count = addVm.selectedParticipantMemberIds.length;
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
          // Split Method Header with Dropdown & Question Mark Helper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.call_split_rounded,
                    size: 15,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SPLIT METHOD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Question mark icon button
                  InkWell(
                    onTap: () => _showSplitMethodsExplainer(context, isDark, addVm),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
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
              // Split Method Dropdown
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141A21) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    width: 0.8,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SplitType>(
                    value: addVm.splitType,
                    isDense: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    dropdownColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      DropdownMenuItem(
                        value: SplitType.equal,
                        child: Text(
                          '🟰 Split Equally',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: SplitType.exact,
                        child: Text(
                          '📊 Exact Amounts',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: SplitType.percentage,
                        child: Text(
                          '💯 By Percentage',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: SplitType.shares,
                        child: Text(
                          '⚖️ By Shares',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (SplitType? newType) {
                      if (newType != null) {
                        FocusScope.of(context).unfocus();
                        FocusManager.instance.primaryFocus?.unfocus();
                        HapticHelper.selection();
                        addVm.setSplitType(newType);
                      }
                    },
                  ),
                ),
              ),
            ],
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
                  if (count > 0) {
                    addVm.unselectAllParticipants();
                  } else {
                    addVm.selectAllParticipants(trip.members.map((m) => m.id).toList());
                  }
                },
                child: Text(
                  count > 0
                      ? (l10n.expenseDeselectAll.isNotEmpty ? l10n.expenseDeselectAll : 'Unselect All')
                      : (l10n.expenseSelectAll.isNotEmpty ? l10n.expenseSelectAll : 'Select All'),
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
                    description: 'Divides the entire amount evenly across all checked members. Remainder paise (e.g. ₹0.01) are automatically distributed deterministically.',
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
                    description: 'Enter custom specific amounts in Rupees for each individual. The sum of all members\' amounts must exactly equal the total expense amount.',
                    example: 'Example: Rahul ordered ₹600, Rohit ₹400, Priya ₹500 on a ₹1,500 food order.',
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
                    description: 'Assign each person a percentage share. Total percentage across all members must add up to exactly 100%.',
                    example: 'Example: Hotel stay: Master bedroom occupant pays 50%, other two rooms pay 25% each.',
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
                    description: 'Assign numerical units (e.g. 1, 2, 3 shares). Good when some friends brought family or consumed more.',
                    example: 'Example: A couple gets 2 shares, 2 single friends get 1 share each (Total 4 shares on ₹4,000 = ₹2,000 for couple, ₹1,000 each for singles).',
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
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
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
          InkWell(
            onTap: isChecked
                ? () => _showMemberSplitKeypad(context, isDark, member, addVm, false)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isChecked
                    ? (isDark ? const Color(0xFF182028) : const Color(0xFFF1F5F9))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isChecked
                      ? (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle)
                      : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.formatPaise(addVm.exactAmountsInPaise[member.id] ?? 0, currencyCode: currency),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isChecked
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_rounded,
                    size: 11,
                    color: isChecked
                        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          )
        else if (addVm.splitType == SplitType.percentage)
          InkWell(
            onTap: isChecked
                ? () => _showMemberSplitKeypad(context, isDark, member, addVm, true)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isChecked
                    ? (isDark ? const Color(0xFF182028) : const Color(0xFFF1F5F9))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isChecked
                      ? (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle)
                      : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(addVm.percentages[member.id] ?? 0.0).toStringAsFixed(1)} %',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isChecked
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_rounded,
                    size: 11,
                    color: isChecked
                        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                        : Colors.transparent,
                  ),
                ],
              ),
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

  void _showMemberSplitKeypad(
    BuildContext context,
    bool isDark,
    TripMember member,
    AddExpenseViewModel addVm,
    bool isPercentage,
  ) {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    HapticHelper.light();

    final currentVal = isPercentage
        ? (addVm.percentages[member.id] ?? 0.0)
        : ((addVm.exactAmountsInPaise[member.id] ?? 0) / 100.0);

    final initialText = currentVal > 0
        ? (currentVal % 1 == 0 ? currentVal.toInt().toString() : currentVal.toStringAsFixed(2))
        : '';

    final memberController = TextEditingController(text: initialText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F151C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final text = memberController.text;

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Handle & Header Bar with Down Arrow
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            MemberAvatar(name: member.displayName, size: 28),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.displayName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  isPercentage ? 'Set percentage share (%)' : 'Set exact amount (₹)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Down Arrow to close sheet
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Display Current Value
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161E28) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isPercentage ? 'Share' : 'Amount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        Text(
                          isPercentage
                              ? '${text.isEmpty ? '0' : text} %'
                              : '₹ ${text.isEmpty ? '0' : text}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Native Numeric Input Field & Action
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 8,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: memberController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: true,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: isPercentage ? 'Enter percentage' : 'Enter amount',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF161E28) : const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (val) {
                              setModalState(() {});
                              final v = double.tryParse(val) ?? 0.0;
                              if (isPercentage) {
                                addVm.setMemberPercentage(member.id, v);
                              } else {
                                addVm.setMemberExactAmount(member.id, (v * 100).round());
                              }
                            },
                            onSubmitted: (val) {
                              final v = double.tryParse(val) ?? 0.0;
                              if (isPercentage) {
                                addVm.setMemberPercentage(member.id, v);
                              } else {
                                addVm.setMemberExactAmount(member.id, (v * 100).round());
                              }
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            final v = double.tryParse(memberController.text) ?? 0.0;
                            if (isPercentage) {
                              addVm.setMemberPercentage(member.id, v);
                            } else {
                              addVm.setMemberExactAmount(member.id, (v * 100).round());
                            }
                            Navigator.pop(ctx);
                          },
                          child: const Icon(Icons.check_rounded, size: 22),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
