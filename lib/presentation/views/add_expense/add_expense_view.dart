import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/receipt_scanner_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/kith_calculator_engine.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/voice_speech_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/kith_amount_calculator_field.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../core/widgets/kith_description_input_field.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/waveform_visualizer.dart';
import '../../../domain/engine/multi_expense_voice_parser.dart';
import '../../../domain/enums/expense_category.dart';
import '../../../domain/enums/split_type.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/expense_draft.dart';
import '../../../domain/models/receipt_data.dart';
import '../../../domain/models/trip.dart';
import '../../../domain/models/trip_member.dart';
import '../../../data/services/sync_service.dart';
import '../../viewmodels/add_expense_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/trip_detail_viewmodel.dart';
import '../../widgets/progress/kith_success_toast.dart';
import 'receipt_review_view.dart';
import 'voice_review_view.dart';

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
  final Map<String, TextEditingController> _payerControllers = {};
  AddExpenseViewModel? _addVm;
  bool _isFetchingLocation = false;
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingTrip = true;
  bool _isProcessingReceipt = false;
  String _receiptProcessingStatus = '';
  final ReceiptScannerService _receiptScannerService = ReceiptScannerService();
  bool _isProcessingVoice = false;
  bool _isVoiceListening = false;
  final TextEditingController _voiceTranscriptController = TextEditingController();
  final VoiceSpeechService _voiceSpeechService = VoiceSpeechService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _addVm = context.read<AddExpenseViewModel>();
  }

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

      if (widget.existingExpense == null) {
        _selectedDate = DateTime.now();
        addVm.setDate(_selectedDate);
        addVm.setTab(widget.initialTab);
        _fetchCurrentLocation(addVm, silent: true);
      }
    }

    setState(() => _isLoadingTrip = false);
  }

  Future<void> _fetchCurrentLocation(AddExpenseViewModel addVm, {bool silent = false}) async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    if (!silent) HapticHelper.selection();

    try {
      final place = await LocationService().getCurrentPlaceName().timeout(const Duration(seconds: 2));
      if (!mounted) return;

      if (place != null && place.trim().isNotEmpty) {
        if (!silent) HapticHelper.medium();
        _locationController.text = place;
        addVm.setLocation(place);
        if (!silent) {
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
        }
      } else if (!silent) {
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
    } catch (_) {
      // Safe fallback when location service is offline, denied, or in tests
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  TextEditingController _getPayerController(String memberId, int paise) {
    final ctrl = _payerControllers.putIfAbsent(memberId, () {
      final rupees = paise / 100.0;
      final text = paise % 100 == 0 ? rupees.toInt().toString() : rupees.toStringAsFixed(2);
      return TextEditingController(text: text);
    });

    final currentPaise = ((double.tryParse(ctrl.text) ?? 0.0) * 100).round();
    if (currentPaise != paise) {
      final rupees = paise / 100.0;
      final text = paise % 100 == 0 ? rupees.toInt().toString() : rupees.toStringAsFixed(2);
      ctrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return ctrl;
  }

  @override
  void dispose() {
    _voiceSpeechService.cancelListening().ignore();
    _voiceTranscriptController.dispose();
    _addVm?.cancelVoice();
    _amountController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    for (final ctrl in _payerControllers.values) {
      ctrl.dispose();
    }
    _payerControllers.clear();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final addVm = context.read<AddExpenseViewModel>();
    final tripDetailVm = context.read<TripDetailViewModel>();
    final l10n = context.l10n;
    final trip = tripDetailVm.trip;
    if (trip == null || addVm.isSaving) return;

    // Resolve and validate any mathematical expression in the calculator field
    final evalResult = KithCalculatorEngine.evaluateExpression(
      _amountController.text,
      currencyCode: trip.currencyCode,
    );

    if (evalResult.isError) {
      HapticHelper.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(evalResult.errorMessage ?? 'Please enter a valid expense amount expression'),
          backgroundColor: AppColors.negativeRedDark,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (evalResult.amountInPaise > 0 && addVm.amountInPaise != evalResult.amountInPaise) {
      addVm.setAmountInPaise(evalResult.amountInPaise);
    }

    // If title is empty, auto-fill with category or 'Expense' (description is optional)
    if (addVm.title.trim().isEmpty) {
      final fallbackTitle = addVm.category.displayName.isNotEmpty
          ? addVm.category.displayName
          : 'Expense';
      addVm.setTitle(fallbackTitle);
      _titleController.text = fallbackTitle;
    }

    if (addVm.amountInPaise <= 0 || addVm.selectedParticipantMemberIds.isEmpty) {
      HapticHelper.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addVm.amountInPaise <= 0
                ? l10n.translate('add_expense_err_amount')
                : l10n.translate('add_expense_err_person'),
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
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        try {
          context.pop(true);
        } catch (_) {
          // No enclosing GoRouter in test harnesses
        }
      }
      final syncService = Provider.of<SyncService?>(context, listen: false);
      if (syncService?.currentStatus == SyncStatus.offline ||
          syncService?.currentStatus == SyncStatus.pending) {
        KithSuccessToast.show(
          context,
          "Expense saved on this device. It will sync when you're online. ✓",
        );
      } else {
        KithSuccessToast.show(
          context,
          widget.existingExpense != null
              ? '${l10n.expenseUpdateBtn} ✓'
              : l10n.translate('add_expense_success'),
        );
      }
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
                _buildHelpRow('🟰 ${l10n.expenseSplitEqually}', l10n.expenseSplitEquallyDesc, isDark),
                const SizedBox(height: 12),
                _buildHelpRow('📊 ${l10n.expenseSplitExact}', l10n.expenseSplitExactDesc, isDark),
                const SizedBox(height: 12),
                _buildHelpRow('💯 ${l10n.expenseSplitPercentages}', l10n.expenseSplitPercentagesDesc, isDark),
                const SizedBox(height: 12),
                _buildHelpRow('⚖️ ${l10n.expenseSplitShares}', l10n.expenseSplitSharesDesc, isDark),
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
          _buildModeTabs(context, isDark, addVm, l10n),
          Expanded(
            child: addVm.currentTab == 1
                ? _buildReceiptScannerTab(context, isDark, addVm, trip, l10n)
                : (addVm.currentTab == 0
                    ? _buildVoiceTab(context, isDark, addVm, trip, l10n)
                    : _buildManualExpenseForm(context, isDark, addVm, trip, currency, l10n)),
          ),
        ],
      ),
      bottomNavigationBar: addVm.currentTab == 2
          ? _buildBottomActionDock(context, isDark, addVm, trip, l10n)
          : null,
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
    final tabs = [
      {'label': l10n.expenseManualTab, 'icon': Icons.edit_rounded, 'index': 2},
      {'label': l10n.expenseVoiceTab, 'icon': Icons.mic_rounded, 'index': 0},
      {'label': l10n.expenseReceiptTab, 'icon': Icons.document_scanner_rounded, 'index': 1},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: KithSegmentedControl<int>(
        items: const [2, 0, 1],
        selectedItem: addVm.currentTab,
        labelBuilder: (idx) => tabs.firstWhere((t) => t['index'] == idx)['label'] as String,
        iconBuilder: (idx) => tabs.firstWhere((t) => t['index'] == idx)['icon'] as IconData,
        onSelected: (idx) => addVm.setTab(idx),
      ),
    );
  }

  Future<void> _handleCaptureReceiptCamera(AddExpenseViewModel addVm, Trip trip) async {
    HapticHelper.medium();
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        HapticHelper.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera permission is required to scan receipts.'),
            backgroundColor: const Color(0xFFE11D48),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    try {
      final imagePath = await _receiptScannerService.captureFromCamera();
      if (imagePath == null || !mounted) return;

      await _processScannedReceipt(imagePath, addVm, trip);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture receipt: ${e.toString()}'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  Future<void> _handleImportReceiptGallery(AddExpenseViewModel addVm, Trip trip) async {
    HapticHelper.medium();
    try {
      final imagePath = await _receiptScannerService.importFromGallery();
      if (imagePath == null || !mounted) return;

      await _processScannedReceipt(imagePath, addVm, trip);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import receipt: ${e.toString()}'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  Future<void> _processScannedReceipt(String imagePath, AddExpenseViewModel addVm, Trip trip) async {
    setState(() {
      _isProcessingReceipt = true;
      _receiptProcessingStatus = 'Extracting receipt text on-device...';
    });

    try {
      final receiptData = await _receiptScannerService.processReceiptImage(
        imagePath,
        tripCurrencyCode: trip.currencyCode,
      );

      if (!mounted) return;

      setState(() {
        _isProcessingReceipt = false;
      });

      final tripExpenses = context.read<TripDetailViewModel>().expenses;
      final currentUserId = context.read<AuthViewModel>().currentUser?.id;
      final confirmedReceipt = await Navigator.of(context).push<ReceiptData>(
        MaterialPageRoute(
          builder: (ctx) => ReceiptReviewView(
            initialReceipt: receiptData,
            existingTripExpenses: tripExpenses,
            tripMembers: trip.members,
            currentUserId: currentUserId,
            onConfirmed: (confirmed) {
              Navigator.of(ctx).pop(confirmed);
            },
          ),
        ),
      );

      if (confirmedReceipt != null && mounted) {
        _onReceiptConfirmed(confirmedReceipt, addVm);
      } else {
        // User cancelled without confirming. Delete the temporary receipt file to avoid storage leakage.
        _receiptScannerService.deleteReceiptFile(imagePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingReceipt = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR error: ${e.toString()}'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  void _onReceiptConfirmed(ReceiptData confirmedReceipt, AddExpenseViewModel addVm) {
    addVm.applyReceiptData(confirmedReceipt);
    if (confirmedReceipt.selectedPayerId != null) {
      addVm.setPayer(confirmedReceipt.selectedPayerId!);
    }
    if (confirmedReceipt.merchant.name != null && confirmedReceipt.merchant.name!.trim().isNotEmpty) {
      _titleController.text = confirmedReceipt.merchant.name!.trim();
    }
    final total = confirmedReceipt.summary.totalInPaise ?? confirmedReceipt.calculatedTotalInPaise;
    if (total > 0) {
      final rupees = total / 100.0;
      _amountController.text = rupees % 1 == 0 ? rupees.toInt().toString() : rupees.toStringAsFixed(2);
    }
    if (confirmedReceipt.receipt.date != null) {
      setState(() {
        _selectedDate = confirmedReceipt.receipt.date!;
      });
    }
    if (confirmedReceipt.merchant.address != null && confirmedReceipt.merchant.address!.trim().isNotEmpty) {
      _locationController.text = confirmedReceipt.merchant.address!.trim();
    }
    HapticHelper.medium();
    KithSuccessToast.show(context, 'Receipt details applied! Choose split & save. ✓');
  }

  Widget _buildReceiptScannerTab(
    BuildContext context,
    bool isDark,
    AddExpenseViewModel addVm,
    Trip trip,
    AppLocalizations l10n,
  ) {
    if (_isProcessingReceipt) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
            ),
            const SizedBox(height: 20),
            Text(
              _receiptProcessingStatus.isNotEmpty
                  ? _receiptProcessingStatus
                  : 'Processing receipt...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Running 100% on-device OCR for maximum privacy',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A21) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF222B35) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  color: Color(0xFF14B8A6),
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Scan Any Receipt or Bill',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Extract merchant, line items, taxes, and totals instantly without manual typing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt_rounded, size: 20),
            label: const Text(
              'Scan with Camera',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            onPressed: () => _handleCaptureReceiptCamera(addVm, trip),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_rounded, size: 20),
            label: const Text(
              'Import from Gallery',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
              side: BorderSide(
                color: isDark ? const Color(0xFF2D3748) : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _handleImportReceiptGallery(addVm, trip),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF11171E) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Text(
                    'TIPS FOR BEST ACCURACY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTipItem('Keep receipt flat on a contrasting surface', isDark),
              _buildTipItem('Ensure good lighting and avoid camera glare', isDark),
              _buildTipItem('Capture the whole bill including the grand total', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVoiceMicToggle(AddExpenseViewModel addVm, Trip trip) async {
    if (_isVoiceListening) {
      await _stopVoiceListening();
    } else {
      await _startVoiceListening(addVm, trip);
    }
  }

  Future<void> _startVoiceListening(AddExpenseViewModel addVm, Trip trip) async {
    HapticHelper.selection();
    setState(() {
      _isVoiceListening = true;
    });

    final ok = await _voiceSpeechService.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _voiceTranscriptController.text = words;
        });

        if (isFinal && words.trim().isNotEmpty) {
          setState(() {
            _isVoiceListening = false;
          });
        }
      },
    );

    if (!ok && mounted) {
      setState(() => _isVoiceListening = false);
      final error = _voiceSpeechService.userFacingError ?? 'Microphone permission or speech recognition unavailable.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    }
  }

  Future<void> _stopVoiceListening() async {
    HapticHelper.light();
    await _voiceSpeechService.stopListening();
    if (mounted) {
      setState(() {
        _isVoiceListening = false;
      });
    }
  }

  Future<void> _processVoiceTranscript(AddExpenseViewModel addVm, Trip trip) async {
    final transcript = _voiceTranscriptController.text.trim();
    if (transcript.isEmpty) return;

    if (_isVoiceListening) {
      await _stopVoiceListening();
    }
    if (!mounted) return;

    HapticHelper.medium();
    setState(() => _isProcessingVoice = true);

    try {
      final authVm = context.read<AuthViewModel>();
      final currentUserId = authVm.currentUser?.id ?? '';

      final drafts = MultiExpenseVoiceParser.parse(
        transcript,
        members: trip.members,
        currentUserId: currentUserId,
      );

      if (!mounted) return;
      setState(() => _isProcessingVoice = false);

      if (drafts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect any expenses from transcript. Please try again.'),
            backgroundColor: Color(0xFFE11D48),
          ),
        );
        return;
      }

      final confirmedDrafts = await Navigator.of(context).push<List<ExpenseDraft>>(
        MaterialPageRoute(
          builder: (ctx) => VoiceReviewView(
            initialTranscript: transcript,
            initialDrafts: drafts,
            trip: trip,
            members: trip.members,
            currentUserId: currentUserId,
            onConfirmed: (confirmed) {
              Navigator.of(ctx).pop(confirmed);
            },
            onReRecord: () {
              Navigator.of(ctx).pop();
              _voiceTranscriptController.clear();
              _startVoiceListening(addVm, trip);
            },
          ),
        ),
      );

      if (confirmedDrafts != null && confirmedDrafts.isNotEmpty && mounted) {
        await _onVoiceExpensesConfirmed(confirmedDrafts, addVm, trip);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingVoice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice parsing error: ${e.toString()}'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  Future<void> _onVoiceExpensesConfirmed(
    List<ExpenseDraft> confirmedDrafts,
    AddExpenseViewModel addVm,
    Trip trip,
  ) async {
    if (confirmedDrafts.isEmpty) return;

    setState(() => _isProcessingVoice = true);

    try {
      final savedExpenses = await addVm.saveMultipleConfirmedDrafts(trip.id, confirmedDrafts);

      if (!mounted) return;
      setState(() => _isProcessingVoice = false);

      if (savedExpenses.isNotEmpty) {
        if (!mounted) return;
        final tripDetailVm = context.read<TripDetailViewModel>();
        final authVm = context.read<AuthViewModel>();
        if (authVm.currentUser != null) {
          await tripDetailVm.loadTrip(trip.id, authVm.currentUser!.id);
        }
        if (!mounted) return;

        HapticHelper.success();
        final count = savedExpenses.length;
        KithSuccessToast.show(
          context,
          count == 1 ? 'Expense saved successfully! ✓' : '$count expenses saved successfully! ✓',
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          try {
            context.pop(true);
          } catch (_) {}
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(addVm.errorMessage ?? 'Failed to save expenses. Please try again.'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingVoice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expenses: ${e.toString()}'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  Widget _buildVoiceTab(
    BuildContext context,
    bool isDark,
    AddExpenseViewModel addVm,
    Trip trip,
    AppLocalizations l10n,
  ) {
    if (_isProcessingVoice) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Parsing voice expenses...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Extracting multiple expenses with 100% integer precision',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final hasTranscript = _voiceTranscriptController.text.trim().isNotEmpty;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      children: [
        // Hero Header Card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A21) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF222B35) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              // Animated / Pulsing Microphone Button
              GestureDetector(
                onTap: () => _handleVoiceMicToggle(addVm, trip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isVoiceListening
                        ? const Color(0xFFE11D48).withValues(alpha: 0.15)
                        : (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isVoiceListening
                          ? const Color(0xFFE11D48)
                          : (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                      width: _isVoiceListening ? 3 : 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _isVoiceListening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 40,
                      color: _isVoiceListening
                          ? const Color(0xFFE11D48)
                          : (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isVoiceListening ? 'Listening... Speak Now' : 'Voice Multi-Expense Entry',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isVoiceListening
                    ? 'Say amounts and items (e.g. 4k train, 5k club, 800 food)'
                    : 'Speak naturally in English, Hindi, or Hinglish. Single or multiple expenses are supported.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              if (_isVoiceListening) ...[
                const SizedBox(height: 14),
                WaveformVisualizer(
                  isListening: _isVoiceListening,
                  height: 38,
                  color: const Color(0xFFE11D48),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Live Recognized / Editable Transcript Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A21) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF222B35) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SPOKEN TRANSCRIPT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  if (hasTranscript)
                    InkWell(
                      onTap: () {
                        HapticHelper.light();
                        setState(() {
                          _voiceTranscriptController.clear();
                        });
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _voiceTranscriptController,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Recognized voice text will appear here. You can also type or edit directly.',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E2630) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Process Action Button
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text(
              'Process Spoken Expenses',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              foregroundColor: isDark ? Colors.black : Colors.white,
              disabledBackgroundColor: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.3),
              disabledForegroundColor: isDark ? Colors.white38 : Colors.white54,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            onPressed: hasTranscript ? () => _processVoiceTranscript(addVm, trip) : null,
          ),
        ),
        const SizedBox(height: 24),

        // Quick Examples Section
        Text(
          'TRY SAYING',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 10),
        _buildVoiceExampleChip(
          context,
          isDark,
          'Maine 4k train ke, 5k club ke aur 800 food ke diye',
          '3 Expenses: Train ₹4,000, Club ₹5,000, Food ₹800',
        ),
        _buildVoiceExampleChip(
          context,
          isDark,
          'Train 4000, hotel 5000, food 800',
          '3 Expenses: Transport, Hotel, Food',
        ),
        _buildVoiceExampleChip(
          context,
          isDark,
          'Yesterday I paid 2500 for hotel and 450 for taxi',
          '2 Expenses: Hotel ₹2,500, Taxi ₹450',
        ),
        _buildVoiceExampleChip(
          context,
          isDark,
          '2.5k taxi and 700 snacks',
          '2 Expenses: Taxi ₹2,500, Snacks ₹700',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildVoiceExampleChip(
    BuildContext context,
    bool isDark,
    String phrase,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          HapticHelper.selection();
          setState(() {
            _voiceTranscriptController.text = phrase;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A21) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF222B35) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.record_voice_over_rounded,
                size: 16,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phrase,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachedReceiptCard(BuildContext context, bool isDark, AddExpenseViewModel addVm) {
    final path = addVm.receiptUrl!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 56,
              color: isDark ? Colors.black26 : Colors.grey[200],
              child: File(path).existsSync()
                  ? Image.file(File(path), fit: BoxFit.cover)
                  : const Icon(Icons.receipt_long_rounded, color: Color(0xFF14B8A6)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF14B8A6), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Receipt Attached',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF14B8A6)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Stored locally and will sync with this expense.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Remove receipt',
            onPressed: () {
              HapticHelper.light();
              final currentPath = addVm.receiptUrl;
              addVm.setReceiptUrl(null);
              if (currentPath != null) {
                _receiptScannerService.deleteReceiptFile(currentPath);
              }
            },
          ),
        ],
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
        // 0. Attached Receipt Banner (if present)
        if (addVm.receiptUrl != null && addVm.receiptUrl!.isNotEmpty) ...[
          _buildAttachedReceiptCard(context, isDark, addVm),
          const SizedBox(height: 14),
        ],

        // 1. Core Amount & Title with Quick Ideas
        _buildAmountAndTitleCard(context, isDark, addVm, currency, l10n),

        const SizedBox(height: 14),

        // 2. Category Selector (Horizontal Chips)
        _buildCategorySection(isDark, addVm, l10n),

        const SizedBox(height: 14),

        // 3. Paid By (Who Paid?)
        _buildPayerSection(isDark, addVm, trip, l10n),

        const SizedBox(height: 14),

        // 4. Split with Whom?
        _buildSplitAndParticipantsSection(isDark, addVm, trip, currency, l10n),

        const SizedBox(height: 14),

        // 5. Date & Location Selector
        _buildDateAndLocationSection(isDark, addVm, l10n),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildQuickAddChip(String label, int amount, bool isDark, AddExpenseViewModel addVm) {
    return GestureDetector(
      onTap: () {
        HapticHelper.light();
        final currentRupees = (addVm.amountInPaise / 100.0).round();
        final nextRupees = currentRupees + amount;
        _amountController.text = nextRupees.toString();
        addVm.setAmountInPaise(nextRupees * 100);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18222C) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
          ),
        ),
      ),
    );
  }

  /// Single, sleek unified card for Amount & Expense Title with 1-tap quick ideas.
  Widget _buildAmountAndTitleCard(
    BuildContext context,
    bool isDark,
    AddExpenseViewModel addVm,
    String currency,
    AppLocalizations l10n,
  ) {
    final quickIdeas = [
      {'emoji': '🍽️', 'title': 'Dinner', 'cat': ExpenseCategory.food},
      {'emoji': '☕', 'title': 'Coffee', 'cat': ExpenseCategory.food},
      {'emoji': '🚕', 'title': 'Cab', 'cat': ExpenseCategory.transport},
      {'emoji': '🛒', 'title': 'Groceries', 'cat': ExpenseCategory.groceries},
      {'emoji': '🏨', 'title': 'Stay', 'cat': ExpenseCategory.stay},
      {'emoji': '⛽', 'title': 'Fuel', 'cat': ExpenseCategory.transport},
      {'emoji': '🎟️', 'title': 'Tickets', 'cat': ExpenseCategory.activities},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
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
            'HOW MUCH & WHAT FOR?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          // Amount field with calculator
          KithAmountCalculatorField(
            controller: _amountController,
            currencyCode: currency,
            useInAppKeypad: false,
            onAmountChanged: (evaluatedPaise) {
              addVm.setAmountInPaise(evaluatedPaise);
            },
          ),

          const SizedBox(height: 8),

          // Quick increment chips (+100, +200, +500, +1000)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickAddChip('+100', 100, isDark, addVm),
                const SizedBox(width: 6),
                _buildQuickAddChip('+200', 200, isDark, addVm),
                const SizedBox(width: 6),
                _buildQuickAddChip('+500', 500, isDark, addVm),
                const SizedBox(width: 6),
                _buildQuickAddChip('+1,000', 1000, isDark, addVm),
                const SizedBox(width: 8),
                if (_amountController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      HapticHelper.light();
                      _amountController.clear();
                      addVm.setAmountInPaise(0);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red)),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          const SizedBox(height: 14),

          // Redesigned Description Input UI with multiline comfort, animated focus, and quick idea chips
          KithDescriptionInputField(
            controller: _titleController,
            label: 'DESCRIPTION',
            hintText: 'What was this expense for? (e.g. Dinner, Fuel, Groceries)',
            suggestions: quickIdeas.map((idea) => '${idea['emoji']} ${idea['title']}').toList(),
            onChanged: (val) {
              addVm.setTitle(val);
              setState(() {});
            },
            onSuggestionSelected: (fullSuggestion) {
              final matchingIdea = quickIdeas.firstWhere(
                (i) => '${i['emoji']} ${i['title']}' == fullSuggestion,
                orElse: () => quickIdeas.first,
              );
              _titleController.text = matchingIdea['title'] as String;
              _titleController.selection = TextSelection.collapsed(offset: (matchingIdea['title'] as String).length);
              addVm.setTitle(matchingIdea['title'] as String);
              addVm.setCategory(matchingIdea['cat'] as ExpenseCategory);
              setState(() {});
            },
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

  /// Clean Payer Selector Card with Multi-Payer & Custom Split Amounts support.
  Widget _buildPayerSection(bool isDark, AddExpenseViewModel addVm, Trip trip, AppLocalizations l10n) {
    final activeColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
    final activeMembers = trip.members.where((m) => !m.isMerged).toList();
    final isMultiple = addVm.isMultiplePayers;

    final totalPaidPaise = isMultiple
        ? addVm.totalPayerAllocatedPaise
        : addVm.amountInPaise;
    final remainingPaise = addVm.amountInPaise - totalPaidPaise;
    final isMatching = remainingPaise == 0;

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.expensePaidByHeader,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                ),
              ),
              InkWell(
                onTap: () {
                  HapticHelper.selection();
                  addVm.toggleMultiplePayers(!isMultiple);
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMultiple ? Icons.people_alt_rounded : Icons.person_rounded,
                        size: 13,
                        color: isMultiple ? activeColor : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMultiple ? 'Multiple Payers' : 'Single Payer',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isMultiple ? activeColor : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.swap_horiz_rounded, size: 13, color: isMultiple ? activeColor : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: activeMembers.map((member) {
                final isSelected = isMultiple
                    ? addVm.payerAmountsInPaise.containsKey(member.id)
                    : addVm.paidById == member.id;
                return Padding(
                  key: ValueKey('payer_chip_${member.id}'),
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      HapticHelper.selection();
                      addVm.togglePayerSelection(member.id);
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                            : (isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? activeColor
                              : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          width: isSelected ? 1.5 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MemberAvatar(name: member.displayName, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            member.displayName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? Colors.white : activeColor)
                                  : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.check_circle_rounded, size: 14, color: activeColor),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (isMultiple) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PAID AMOUNTS (${addVm.payerAmountsInPaise.length} PAYERS)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticHelper.light();
                    addVm.distributeEqualAmongPayers();
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Split Paid Equally',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: activeColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final member in activeMembers.where((m) => addVm.payerAmountsInPaise.containsKey(m.id)))
              Padding(
                key: ValueKey('payer_row_${member.id}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    children: [
                      MemberAvatar(name: member.displayName, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          member.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        trip.currencyCode == 'INR' ? '₹' : trip.currencyCode,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 90,
                        height: 34,
                        child: TextFormField(
                          key: ValueKey('payer_input_${member.id}'),
                          controller: _getPayerController(member.id, addVm.payerAmountsInPaise[member.id] ?? 0),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: activeColor, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final doubleVal = double.tryParse(val) ?? 0.0;
                            final paise = (doubleVal * 100).round();
                            addVm.setPayerAmount(member.id, paise);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Paid: ${CurrencyFormatter.formatPaise(totalPaidPaise, currencyCode: trip.currencyCode)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isMatching ? AppColors.positiveGreenLight : Colors.orange,
                  ),
                ),
                Text(
                  isMatching
                      ? '✓ Matches Total'
                      : (remainingPaise > 0
                          ? 'Remaining: ${CurrencyFormatter.formatPaise(remainingPaise, currencyCode: trip.currencyCode)} left'
                          : 'Exceeds: ${CurrencyFormatter.formatPaise(-remainingPaise, currencyCode: trip.currencyCode)} over'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isMatching ? AppColors.positiveGreenLight : (remainingPaise > 0 ? Colors.orange : AppColors.negativeRedDark),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
    final activeSplitMembers = trip.members.where((m) => !m.isMerged).toList();

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
            itemCount: activeSplitMembers.length,
            separatorBuilder: (_, _) => Divider(
              height: 12,
              thickness: 0.5,
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            ),
            itemBuilder: (context, index) {
              final member = activeSplitMembers[index];
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
        // Tappable Checkbox & Member Identity
        Expanded(
          child: InkWell(
            onTap: () {
              HapticHelper.selection();
              addVm.toggleParticipant(member.id);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
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
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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

  Widget _buildLocationField(bool isDark, AddExpenseViewModel addVm) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 0.8,
        ),
      ),
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
              textCapitalization: TextCapitalization.words,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: const InputDecoration(
                hintText: 'Location (e.g. Cafe, Airport)',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) => addVm.setLocation(val),
            ),
          ),
          if (_locationController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                HapticHelper.light();
                _locationController.clear();
                addVm.setLocation('');
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.close_rounded, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
            ),
          InkWell(
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
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location_rounded, size: 13, color: Color(0xFF14B8A6)),
                        SizedBox(width: 4),
                        Text(
                          'GPS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF14B8A6)),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateAndLocationSection(bool isDark, AddExpenseViewModel addVm, AppLocalizations l10n) {
    return Column(
      children: [
        _buildDateSelectorPill(isDark, l10n),
        const SizedBox(height: 10),
        _buildLocationField(isDark, addVm),
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
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
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
    final hasAmount = addVm.amountInPaise > 0;
    final formatted = CurrencyFormatter.formatPaise(addVm.amountInPaise, currencyCode: trip.currencyCode);
    final buttonText = widget.existingExpense != null
        ? (hasAmount ? 'Update • $formatted' : 'Update Expense')
        : (hasAmount ? 'Save Expense • $formatted' : 'Save Expense');

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF080C0E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: addVm.isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF14B8A6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
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
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      buttonText,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
