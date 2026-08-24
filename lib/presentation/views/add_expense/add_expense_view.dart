import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
import '../../../core/widgets/waveform_visualizer.dart';
import '../../../domain/enums/expense_category.dart';
import '../../../domain/enums/split_type.dart';
import '../../../domain/models/expense_draft.dart';
import '../../../domain/models/trip.dart';
import '../../../domain/models/trip_member.dart';
import '../../viewmodels/add_expense_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/trip_detail_viewmodel.dart';
import 'widgets/expense_draft_confirmation_sheet.dart';

class AddExpenseView extends StatefulWidget {
  final String tripId;

  const AddExpenseView({super.key, required this.tripId});

  @override
  State<AddExpenseView> createState() => _AddExpenseViewState();
}

class _AddExpenseViewState extends State<AddExpenseView> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  static const List<String> _sampleVoicePrompts = [
    'Maine 6000 train ke diye sabke liye',
    'I paid 850 for dinner for me and Rahul',
    'Rahul ne hotel ke 3000 diye sabke liye',
    '500 coffee aur chai',
    'Cab ride 1200',
  ];

  static const List<Map<String, String>> _sampleReceipts = [
    {
      'title': 'Cafe Coffee Day',
      'text': 'CAFE COFFEE DAY\nMG Road, Bangalore\nTAX INVOICE\n1x Cappuccino ₹220\n1x Croissant ₹180\n1x Cold Coffee ₹250\nSubtotal: ₹650\nCGST 2.5%: ₹16.25\nSGST 2.5%: ₹16.25\nTOTAL AMOUNT: ₹850.00\nThank you visit again!',
    },
    {
      'title': 'Taj Gateway Resort',
      'text': 'TAJ GATEWAY RESORT\nCalangute Beach, Goa\nROOM BILL\nRoom Charges: ₹5,000.00\nDining: ₹1,500.00\nService Charge: ₹500.00\nGRAND TOTAL: ₹7,000.00\nPaid via Card',
    },
    {
      'title': 'HP Petrol Pump',
      'text': 'HINDUSTAN PETROLEUM\nHighway Station #402\nPetrol 20.5L @ ₹102.50\nNET AMOUNT: ₹2,100.00\nCash Payment Received',
    },
  ];

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
      context.read<AddExpenseViewModel>().init(trip: trip, currentUserId: user.id);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _showDraftConfirmation(ExpenseDraft draft, Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExpenseDraftConfirmationSheet(
        draft: draft,
        trip: trip,
        onEditManual: () {
          final addVm = context.read<AddExpenseViewModel>();
          addVm.setTab(2); // Switch to Manual tab
          _titleController.text = addVm.title;
          _amountController.text = addVm.amountInPaise > 0
              ? CurrencyFormatter.toRupees(addVm.amountInPaise).toString()
              : '';
        },
        onConfirm: (confirmedDraft) async {
          final addVm = context.read<AddExpenseViewModel>();
          final expense = await addVm.saveConfirmedDraft(trip.id, confirmedDraft);
          if (expense != null && mounted) {
            context.pop(true);
          }
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    final addVm = context.read<AddExpenseViewModel>();
    final tripDetailVm = context.read<TripDetailViewModel>();
    final trip = tripDetailVm.trip;
    if (trip == null) return;

    final expense = await addVm.saveExpense(trip.id);
    if (expense != null && mounted) {
      HapticHelper.success();
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripDetailVm = context.watch<TripDetailViewModel>();
    final addVm = context.watch<AddExpenseViewModel>();
    final authVm = context.watch<AuthViewModel>();

    final trip = tripDetailVm.trip;
    final currentUserId = authVm.currentUser?.id ?? '';
    if (trip == null) {
      return const Scaffold(body: Center(child: Text('Trip not found')));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Add Expense'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Mode Tabs (Voice / Receipt Scan / Manual)
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
                    _buildModeTab('Voice', Icons.mic_rounded, 0, addVm.currentTab, isDark),
                    _buildModeTab('Receipt', Icons.receipt_long_rounded, 1, addVm.currentTab, isDark),
                    _buildModeTab('Manual', Icons.edit_note_rounded, 2, addVm.currentTab, isDark),
                  ],
                ),
              ),
            ),

            // Tab Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: addVm.currentTab == 0
                    ? _buildVoiceInputTab(addVm, trip, currentUserId, isDark)
                    : (addVm.currentTab == 1
                        ? _buildReceiptScanTab(addVm, trip, currentUserId, isDark)
                        : _buildManualInputTab(addVm, trip, isDark)),
              ),
            ),

            // Bottom Save Action Bar
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
                            const Text('Total Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            CurrencyDisplay(
                              amountInPaise: addVm.amountInPaise,
                              size: CurrencyDisplaySize.large,
                              currencyCode: trip.currencyCode,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: AppButton(
                          text: 'Save Expense',
                          icon: Icons.check_rounded,
                          isLoading: addVm.isSaving,
                          onPressed: addVm.amountInPaise > 0 && addVm.title.isNotEmpty
                              ? _handleSave
                              : null,
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

  Widget _buildVoiceInputTab(AddExpenseViewModel addVm, Trip trip, String currentUserId, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Speak Naturally',
          style: AppTypography.titleLarge(isDark: isDark),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Say who paid, what it was for, and how much.',
          style: AppTypography.bodyMedium(isDark: isDark),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.xl),

        // Waveform Visualizer & Live Mic Button
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            borderRadius: AppRadius.xlBorder,
            border: Border.all(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            ),
          ),
          child: Column(
            children: [
              WaveformVisualizer(
                isListening: addVm.isListening,
                height: 52,
              ),
              const SizedBox(height: AppSpacing.lg),

              GestureDetector(
                onTap: () {
                  HapticHelper.medium();
                  if (addVm.isListening) {
                    final draft = addVm.parseVoiceToDraft(
                      _sampleVoicePrompts[0],
                      trip.members,
                      currentUserId,
                    );
                    _showDraftConfirmation(draft, trip);
                  } else {
                    addVm.startVoiceListening();
                  }
                },
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: addVm.isListening
                        ? AppColors.roseAccent
                        : (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                    boxShadow: [
                      BoxShadow(
                        color: (addVm.isListening
                                ? AppColors.roseAccent
                                : (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary))
                            .withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    addVm.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              Text(
                addVm.isListening ? 'Listening... Tap to stop & confirm' : 'Tap microphone to speak',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Sample Voice Prompts
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Try saying (or tap to test):',
            style: AppTypography.titleSmall(isDark: isDark),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sampleVoicePrompts.map((prompt) {
            return ActionChip(
              label: Text(
                prompt,
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              onPressed: () {
                HapticHelper.light();
                final draft = addVm.parseVoiceToDraft(prompt, trip.members, currentUserId);
                _showDraftConfirmation(draft, trip);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildReceiptScanTab(AddExpenseViewModel addVm, Trip trip, String currentUserId, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Scan Receipt or Bill',
          style: AppTypography.titleLarge(isDark: isDark),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Capture or upload any receipt. Total and merchant are extracted automatically for your confirmation.',
          style: AppTypography.bodyMedium(isDark: isDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),

        // Camera / OCR Viewport
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            borderRadius: AppRadius.xlBorder,
            border: Border.all(
              color: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.document_scanner_rounded,
                size: 50,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
              const SizedBox(height: 12),
              Text(
                'Instant Receipt OCR',
                style: AppTypography.titleSmall(isDark: isDark),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap below to scan or select a sample bill',
                style: AppTypography.bodySmall(isDark: isDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Test with sample bills:',
            style: AppTypography.titleSmall(isDark: isDark),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._sampleReceipts.map((rcpt) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rcpt['title']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      const Text('Ready to extract', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      HapticHelper.light();
                      final draft = addVm.parseReceiptToDraft(rcpt['text']!, trip.members, currentUserId);
                      _showDraftConfirmation(draft, trip);
                    },
                    child: const Text('Parse & Confirm'),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildManualInputTab(AddExpenseViewModel addVm, Trip trip, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount Input Field (Hero sized)
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
        Text('What was this for?', style: AppTypography.titleSmall(isDark: isDark)),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Train tickets, Dinner, Groceries',
            prefixIcon: Icon(Icons.receipt_outlined, size: 20),
          ),
          onChanged: addVm.setTitle,
        ),

        const SizedBox(height: AppSpacing.lg),

        // Category Selector Chips
        Text('Category', style: AppTypography.titleSmall(isDark: isDark)),
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
        Text('Who Paid?', style: AppTypography.titleSmall(isDark: isDark)),
        const SizedBox(height: AppSpacing.xs),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: addVm.paidById.isNotEmpty ? addVm.paidById : null,
              isExpanded: true,
              hint: const Text('Select Payer'),
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

        // Split Type Mode Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Split Method', style: AppTypography.titleSmall(isDark: isDark)),
            DropdownButton<SplitType>(
              value: addVm.splitType,
              underline: const SizedBox.shrink(),
              items: SplitType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (type) {
                if (type != null) addVm.setSplitType(type);
              },
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xs),

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
    } else {
      return const Text('Custom split', style: TextStyle(fontSize: 12));
    }
  }
}
