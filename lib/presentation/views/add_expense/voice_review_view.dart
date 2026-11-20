import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../domain/enums/expense_category.dart';
import '../../../domain/models/expense_draft.dart';
import '../../../domain/models/trip.dart';
import '../../../domain/models/trip_member.dart';
import '../../viewmodels/voice_review_viewmodel.dart';

/// Production-grade Voice AI Multi-Expense Review Screen.
/// Displays parsed expense drafts from speech input, allowing users to inspect,
/// edit, correct, add, remove, and batch-confirm expenses with full paise precision.
class VoiceReviewView extends StatefulWidget {
  final String initialTranscript;
  final List<ExpenseDraft> initialDrafts;
  final Trip? trip;
  final List<TripMember> members;
  final String? currentUserId;
  final ValueChanged<List<ExpenseDraft>> onConfirmed;
  final VoidCallback? onReRecord;

  const VoiceReviewView({
    super.key,
    required this.initialTranscript,
    this.initialDrafts = const [],
    this.trip,
    this.members = const [],
    this.currentUserId,
    required this.onConfirmed,
    this.onReRecord,
  });

  @override
  State<VoiceReviewView> createState() => _VoiceReviewViewState();
}

class _VoiceReviewViewState extends State<VoiceReviewView> {
  late final VoiceReviewViewModel _viewModel;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _viewModel = VoiceReviewViewModel(
      initialTranscript: widget.initialTranscript,
      initialDrafts: widget.initialDrafts,
      trip: widget.trip,
      members: widget.members,
      currentUserId: widget.currentUserId,
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _editTranscript(BuildContext context) {
    HapticHelper.medium();
    final controller = TextEditingController(text: _viewModel.transcript);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2630) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Spoken Transcript',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter expense transcript...',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF141A21) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    HapticHelper.selection();
                    _viewModel.reparse(controller.text);
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Re-parse Expenses', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditItemDialog(BuildContext context, VoiceReviewItem item) {
    HapticHelper.medium();
    final titleCtrl = TextEditingController(text: item.title);
    final amountRupees = item.amountInPaise / 100.0;
    final amountCtrl = TextEditingController(
      text: amountRupees > 0
          ? (amountRupees % 1 == 0 ? amountRupees.toInt().toString() : amountRupees.toStringAsFixed(2))
          : '',
    );
    ExpenseCategory selectedCat = item.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isDark = Theme.of(modalCtx).brightness == Brightness.dark;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2630) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Expense',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description / Title',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF141A21) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF141A21) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ExpenseCategory.values.map((cat) {
                        final isSelected = cat == selectedCat;
                        return ChoiceChip(
                          label: Text('${cat.emoji} ${cat.displayName}'),
                          selected: isSelected,
                          onSelected: (_) {
                            setModalState(() {
                              selectedCat = cat;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        final parsedRupees = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        final newPaise = (parsedRupees * 100).round();
                        final newTitle = titleCtrl.text.trim().isEmpty ? 'Expense' : titleCtrl.text.trim();

                        _viewModel.updateTitle(item.id, newTitle);
                        _viewModel.updateAmount(item.id, newPaise);
                        _viewModel.updateCategory(item.id, selectedCat);

                        HapticHelper.selection();
                        Navigator.of(modalCtx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Update Expense', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPayerPicker(BuildContext context, VoiceReviewItem item) {
    if (widget.members.isEmpty) return;
    HapticHelper.medium();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2630) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Payer',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              ...widget.members.map((mbr) {
                final isSelected = mbr.id == item.payerMemberId;
                return ListTile(
                  title: Text(mbr.displayName),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                      : null,
                  onTap: () {
                    HapticHelper.selection();
                    _viewModel.updatePayer(item.id, mbr.id, mbr.displayName);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showAddItemDialog(BuildContext context) {
    HapticHelper.medium();
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    ExpenseCategory selectedCat = ExpenseCategory.general;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isDark = Theme.of(modalCtx).brightness == Brightness.dark;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2630) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Expense',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Title / Description',
                        hintText: 'e.g. Taxi to Airport',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF141A21) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        hintText: 'e.g. 500',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF141A21) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ExpenseCategory.values.map((cat) {
                        final isSelected = cat == selectedCat;
                        return ChoiceChip(
                          label: Text('${cat.emoji} ${cat.displayName}'),
                          selected: isSelected,
                          onSelected: (_) {
                            setModalState(() {
                              selectedCat = cat;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        final parsedRupees = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        final paise = (parsedRupees * 100).round();
                        final title = titleCtrl.text.trim().isEmpty ? 'Expense' : titleCtrl.text.trim();

                        _viewModel.addItem(
                          title: title,
                          amountInPaise: paise,
                          category: selectedCat,
                        );

                        HapticHelper.selection();
                        Navigator.of(modalCtx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateChip(DateTime? date) {
    if (date == null) return 'Today';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == 2) return '2 days ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mName = (date.month >= 1 && date.month <= 12) ? months[date.month - 1] : '';
    return '${date.day} $mName';
  }

  Future<void> _pickDateForItem(BuildContext context, VoiceReviewItem item) async {
    final now = DateTime.now();
    final initialDate = item.expenseDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      HapticHelper.light();
      _viewModel.updateDate(item.id, picked);
    }
  }

  void _handleConfirm() {
    if (!_viewModel.isValid) {
      HapticHelper.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please resolve invalid amounts or payers before confirming.'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    HapticHelper.success();
    setState(() => _isSaving = true);
    final drafts = _viewModel.toExpenseDrafts();
    widget.onConfirmed(drafts);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyCode = widget.trip?.currencyCode ?? 'INR';

    return ChangeNotifierProvider<VoiceReviewViewModel>.value(
      value: _viewModel,
      child: Consumer<VoiceReviewViewModel>(
        builder: (ctx, vm, _) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Review Spoken Expenses',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 22),
                  tooltip: 'Add Expense',
                  onPressed: () => _showAddItemDialog(context),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // Transcript Banner Card
                      _buildTranscriptCard(context, isDark, vm),
                      const SizedBox(height: 16),

                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DETECTED EXPENSES (${vm.count})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showAddItemDialog(context),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Draft Cards List
                      if (vm.items.isEmpty)
                        _buildEmptyState(isDark)
                      else
                        ...vm.items.map((item) => _buildDraftCard(context, isDark, item, currencyCode)),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Bottom Sticky Summary & Action Dock
                _buildBottomDock(context, isDark, vm, currencyCode),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTranscriptCard(BuildContext context, bool isDark, VoiceReviewViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 14,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Spoken Transcript',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const Spacer(),
              if (widget.onReRecord != null)
                InkWell(
                  onTap: widget.onReRecord,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'Re-record',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _editTranscript(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            vm.transcript.isNotEmpty ? '"${vm.transcript}"' : '(No speech detected)',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(
    BuildContext context,
    bool isDark,
    VoiceReviewItem item,
    String currencyCode,
  ) {
    final hasWarning = !item.isReady;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A21) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasWarning
              ? const Color(0xFFF43F5E)
              : (isDark ? const Color(0xFF222B35) : const Color(0xFFE2E8F0)),
          width: hasWarning ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category Emoji Avatar
              GestureDetector(
                onTap: () => _showEditItemDialog(context, item),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(item.category.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Category Name
              Expanded(
                child: GestureDetector(
                  onTap: () => _showEditItemDialog(context, item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.isNotEmpty ? item.title : 'Untitled Expense',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Amount
              GestureDetector(
                onTap: () => _showEditItemDialog(context, item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    CurrencyFormatter.formatPaise(item.amountInPaise, currencyCode: currencyCode),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    ),
                  ),
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                tooltip: 'Remove',
                onPressed: () {
                  HapticHelper.light();
                  _viewModel.removeItem(item.id);
                },
              ),
            ],
          ),

          // Payer & Date Info Row
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              GestureDetector(
                onTap: () => _showPayerPicker(context, item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2630) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      const SizedBox(width: 5),
                      Text(
                        'Paid by ${item.payerName ?? "You"} • Split equally',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down_rounded, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _pickDateForItem(context, item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2630) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      const SizedBox(width: 5),
                      Text(
                        _formatDateChip(item.expenseDate),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_calendar_rounded, size: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Interactive Candidate Payer Disambiguation Chips
          if (item.candidatePayers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.candidatePayers.map((m) {
                return ActionChip(
                  avatar: const Icon(Icons.check_circle_outline_rounded, size: 14),
                  label: Text('Select ${m.displayName}', style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    HapticHelper.selection();
                    _viewModel.updatePayer(item.id, m.id, m.displayName);
                  },
                );
              }).toList(),
            ),
          ],

          // Ambiguity or Error Warning
          if (hasWarning) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF43F5E)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.ambiguityMessage ??
                          (item.amountInPaise <= 0 ? 'Amount is missing. Tap to enter amount.' : 'Needs verification'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF43F5E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            const SizedBox(height: 12),
            Text(
              'No expenses detected',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "+ Add Item" or re-record your voice.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDock(
    BuildContext context,
    bool isDark,
    VoiceReviewViewModel vm,
    String currencyCode,
  ) {
    final totalFormatted = CurrencyFormatter.formatPaise(vm.totalInPaise, currencyCode: currencyCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E2630) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vm.count} EXPENSE${vm.count == 1 ? "" : "S"}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
                ElevatedButton(
                  onPressed: _isSaving || !vm.isValid ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    disabledBackgroundColor: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.3),
                    disabledForegroundColor: isDark ? Colors.white38 : Colors.white54,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : Text(
                          'Confirm & Save (${vm.count})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
