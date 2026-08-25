import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/voice_speech_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../domain/engine/money_engine.dart';
import '../../../../domain/engine/voice_parser.dart';
import '../../../../domain/enums/expense_category.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/personal_debt.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/home_viewmodel.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';

enum PersonalEntryMode {
  expense,
  lent,
  borrowed;

  String get label {
    switch (this) {
      case PersonalEntryMode.expense:
        return 'Personal';
      case PersonalEntryMode.lent:
        return 'I Lent';
      case PersonalEntryMode.borrowed:
        return 'I Borrowed';
    }
  }
}

class AddPersonalExpenseSheet extends StatefulWidget {
  const AddPersonalExpenseSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddPersonalExpenseSheet(),
    );
  }

  @override
  State<AddPersonalExpenseSheet> createState() => _AddPersonalExpenseSheetState();
}

class _AddPersonalExpenseSheetState extends State<AddPersonalExpenseSheet> {
  PersonalEntryMode _mode = PersonalEntryMode.expense;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.food;
  DateTime _selectedDate = DateTime.now();

  bool _isSaving = false;
  bool _isListening = false;
  bool _syncToTrip = false;
  String? _selectedTripId;
  String? _voiceTranscript;

  final VoiceSpeechService _speechService = VoiceSpeechService();

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _personController.dispose();
    _notesController.dispose();
    _speechService.stopListening();
    super.dispose();
  }

  bool get _hasUnsavedData {
    return _amountController.text.trim().isNotEmpty ||
        _titleController.text.trim().isNotEmpty ||
        _personController.text.trim().isNotEmpty;
  }

  void _onCategorySelected(ExpenseCategory cat) {
    setState(() => _category = cat);
    HapticHelper.selection();
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isListening) {
      await _speechService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speechService.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone or Speech Recognition unavailable.')),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    HapticHelper.medium();

    await _speechService.startListening(
      onResult: (spokenText, isFinal) {
        if (!mounted) return;
        setState(() {
          _voiceTranscript = spokenText;
          if (isFinal) _isListening = false;
        });

        // Parse through VoiceIntentParser
        final draft = VoiceIntentParser.parsePersonalDraft(spokenText);
        if (draft.amountInPaise > 0) {
          _amountController.text = (draft.amountInPaise / 100).toStringAsFixed(
            draft.amountInPaise % 100 == 0 ? 0 : 2,
          );
        }

        if (draft.title.isNotEmpty) {
          _titleController.text = draft.title;
        }

        if (draft.personName != null && draft.personName!.isNotEmpty) {
          _personController.text = draft.personName!;
        }

        if (draft.type == PersonalVoiceIntentType.lend) {
          _mode = PersonalEntryMode.lent;
        } else if (draft.type == PersonalVoiceIntentType.borrow) {
          _mode = PersonalEntryMode.borrowed;
        } else {
          _category = draft.category;
        }

        HapticHelper.selection();
      },
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final amountText = _amountController.text.trim();
    final amountRupees = double.tryParse(amountText) ?? 0;
    final amountPaise = (amountRupees * 100).round();

    if (amountPaise <= 0) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (_mode == PersonalEntryMode.expense && title.isEmpty) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify what this expense was for.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final personName = _personController.text.trim();
    if ((_mode == PersonalEntryMode.lent || _mode == PersonalEntryMode.borrowed) && personName.isEmpty) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the person\'s name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authVm = context.read<AuthViewModel>();
    final user = authVm.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    final vm = context.read<PersonalExpenseViewModel>();

    if (_mode == PersonalEntryMode.expense) {
      final expense = await vm.addExpense(
        userId: user.id,
        title: title,
        amountInPaise: amountPaise,
        category: _category,
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        voiceTranscript: _voiceTranscript,
      );

      // Also sync to chosen Trip if enabled
      if (_syncToTrip && _selectedTripId != null && mounted) {
        final homeVm = context.read<HomeViewModel>();
        final targetTrip = homeVm.trips.where((t) => t.id == _selectedTripId).firstOrNull;
        if (targetTrip != null && targetTrip.members.isNotEmpty) {
          final expenseRepo = context.read<ExpenseRepository>();
          final payer = targetTrip.members.where((m) => m.userId == user.id).firstOrNull ?? targetTrip.members.first;
          final memberIds = targetTrip.members.map((m) => m.id).toList();
          final splits = MoneyEngine.calculateEqualSplits(
            totalPaise: amountPaise,
            participantMemberIds: memberIds,
            priorityMemberId: payer.id,
          );
          final tripExpense = Expense(
            id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
            tripId: targetTrip.id,
            title: title,
            amountInPaise: amountPaise,
            category: _category,
            paidById: payer.id,
            splits: splits,
            createdAt: _selectedDate,
            updatedAt: _selectedDate,
          );
          await expenseRepo.addExpense(tripExpense);
          homeVm.loadTrips(user.id);
        }
      }

      if (mounted) {
        setState(() => _isSaving = false);
        if (expense != null) {
          HapticHelper.success();
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_syncToTrip
                  ? 'Expense saved & added to trip ✓'
                  : 'Personal expense added ✓'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          HapticHelper.error();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save expense. Please try again.'),
              backgroundColor: AppColors.negativeRedDark,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      // Lending or Borrowing
      final debtType = _mode == PersonalEntryMode.lent ? PersonalDebtType.lent : PersonalDebtType.borrowed;
      final debt = await vm.addDebt(
        userId: user.id,
        personName: personName,
        debtType: debtType,
        amountInPaise: amountPaise,
        description: title.isEmpty ? null : title,
        date: _selectedDate,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (debt != null) {
          HapticHelper.success();
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _mode == PersonalEntryMode.lent
                    ? 'Lending record added for $personName ✓'
                    : 'Borrowing record added from $personName ✓',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          HapticHelper.error();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save debt record. Please try again.'),
              backgroundColor: AppColors.negativeRedDark,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<bool> _handlePopScope() async {
    if (!_hasUnsavedData || _isSaving) return true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        title: Text('Discard draft?', style: AppTypography.titleLarge(isDark: isDark)),
        content: Text(
          'You have entered details that haven\'t been saved yet.',
          style: AppTypography.bodyMedium(isDark: isDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negativeRedDark),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_hasUnsavedData,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handlePopScope();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          borderRadius: AppRadius.topSheetBorder,
        ),
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: AppSpacing.sm),

              // Context Badge: Personal Expense (Clearly distinguishing from trip expenses)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.emeraldPrimary),
                        SizedBox(width: 4),
                        Text(
                          'Personal · Private to you',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Mode Toggle + Mic
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: PersonalEntryMode.values.map((m) {
                          final isSelected = _mode == m;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _mode = m);
                                HapticHelper.selection();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  m.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening ? (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight) : AppColors.emeraldPrimary,
                    ),
                    onPressed: _toggleVoiceRecording,
                    tooltip: 'Voice entry',
                  ),
                ],
              ),

              if (_isListening) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.mdBorder,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _voiceTranscript?.isNotEmpty == true
                              ? 'Heard: "$_voiceTranscript"'
                              : 'Listening... (e.g. "Spent 500 on lunch")',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Amount Input
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                autofocus: true,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w400,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.mdBorder,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Person Name (For Lent / Borrowed)
              if (_mode == PersonalEntryMode.lent || _mode == PersonalEntryMode.borrowed) ...[
                TextField(
                  controller: _personController,
                  textCapitalization: TextCapitalization.words,
                  style: AppTypography.bodyLarge(isDark: isDark),
                  decoration: InputDecoration(
                    labelText: _mode == PersonalEntryMode.lent ? 'Who owes you?' : 'Who did you borrow from?',
                    hintText: 'Enter name (e.g. Rahul)',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    border: const OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Title / Description
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.bodyLarge(isDark: isDark),
                decoration: InputDecoration(
                  labelText: _mode == PersonalEntryMode.expense ? 'What was this for?' : 'Note (optional)',
                  hintText: _mode == PersonalEntryMode.expense ? 'e.g. Lunch with team' : 'e.g. Dinner share',
                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.mdBorder,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Categories (For Expense)
              if (_mode == PersonalEntryMode.expense) ...[
                Text('Category', style: AppTypography.titleSmall(isDark: isDark)),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ExpenseCategory.food,
                      ExpenseCategory.transport,
                      ExpenseCategory.groceries,
                      ExpenseCategory.shopping,
                      ExpenseCategory.stay,
                      ExpenseCategory.drinks,
                      ExpenseCategory.activities,
                      ExpenseCategory.general,
                    ].map((cat) {
                      final isSelected = _category == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${cat.emoji} ${cat.displayName}'),
                          selected: isSelected,
                          onSelected: (_) => _onCategorySelected(cat),
                          selectedColor: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Date Selection
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      DateFormatter.isToday(_selectedDate)
                          ? 'Today'
                          : DateFormatter.formatDate(_selectedDate),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),

              // Optional: Sync to Trip
              Builder(
                builder: (context) {
                  final availableTrips = context.watch<HomeViewModel>().trips.where((t) => t.lifecycleState.allowsExpenses).toList();
                  if (_mode != PersonalEntryMode.expense || availableTrips.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: SurfaceCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.sync_alt_rounded, size: 18, color: AppColors.emeraldPrimary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Sync / Add to a Trip',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch.adaptive(
                                value: _syncToTrip,
                                activeTrackColor: AppColors.emeraldPrimary,
                                onChanged: (val) {
                                  setState(() {
                                    _syncToTrip = val;
                                    if (val && (_selectedTripId == null || _selectedTripId!.isEmpty)) {
                                      _selectedTripId = availableTrips.first.id;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_syncToTrip) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: (_selectedTripId != null && availableTrips.any((t) => t.id == _selectedTripId))
                                  ? _selectedTripId
                                  : availableTrips.first.id,
                              decoration: InputDecoration(
                                labelText: 'Select Trip',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: availableTrips.map((t) {
                                return DropdownMenuItem(
                                  value: t.id,
                                  child: Text('${t.emoji} ${t.name}', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedTripId = val);
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Splits equally among trip members and shows up in the trip feed.',
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // Save Button
              AppButton(
                text: _mode == PersonalEntryMode.expense
                    ? 'Save Expense'
                    : (_mode == PersonalEntryMode.lent ? 'Record Lending' : 'Record Borrowing'),
                icon: Icons.check_rounded,
                isLoading: _isSaving,
                isFullWidth: true,
                onPressed: _isSaving ? null : _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
