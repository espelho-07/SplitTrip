import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/journey_moment.dart';
import '../../../../domain/models/trip.dart';

class AddJourneyMomentSheet extends StatefulWidget {
  final Trip trip;
  final List<Expense> expenses;
  final String currentUserId;
  final Function(JourneyMoment) onAdd;

  const AddJourneyMomentSheet({
    super.key,
    required this.trip,
    required this.expenses,
    required this.currentUserId,
    required this.onAdd,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required List<Expense> expenses,
    required String currentUserId,
    required Function(JourneyMoment) onAdd,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddJourneyMomentSheet(
        trip: trip,
        expenses: expenses,
        currentUserId: currentUserId,
        onAdd: onAdd,
      ),
    );
  }

  @override
  State<AddJourneyMomentSheet> createState() => _AddJourneyMomentSheetState();
}

class _AddJourneyMomentSheetState extends State<AddJourneyMomentSheet> {
  final _titleController = TextEditingController();
  final _placeController = TextEditingController();
  final _noteController = TextEditingController();
  int _dayIndex = 1;
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _selectedExpenseId;

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give this moment a title.')),
      );
      return;
    }

    final now = DateTime.now();
    final occurredAt = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final moment = JourneyMoment(
      id: 'moment_${const Uuid().v4().substring(0, 8)}',
      tripId: widget.trip.id,
      createdBy: widget.currentUserId,
      title: title,
      placeName: _placeController.text.trim().isEmpty ? null : _placeController.text.trim(),
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      occurredAt: occurredAt,
      dayIndex: _dayIndex,
      expenseId: _selectedExpenseId,
      createdAt: now,
      updatedAt: now,
    );

    HapticHelper.success();
    widget.onAdd(moment);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.xl + bottomInset + MediaQuery.of(context).padding.bottom,
      ),
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
            const SizedBox(height: AppSpacing.md),
            Text(
              'Add Journey Moment',
              style: AppTypography.titleLarge(isDark: isDark),
            ),
            const SizedBox(height: 2),
            Text(
              'Capture where you were, what happened, and highlights from "${widget.trip.name}".',
              style: AppTypography.bodySmall(isDark: isDark),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Day Selector
            Row(
              children: [
                Text(
                  'Day:',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(7, (index) {
                        final day = index + 1;
                        final isSelected = _dayIndex == day;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              HapticHelper.selection();
                              setState(() => _dayIndex = day);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                                    : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Day $day',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? (isDark ? Colors.black : Colors.white)
                                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Time Selector
            Row(
              children: [
                Text(
                  'Time:',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () async {
                    HapticHelper.light();
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (time != null) {
                      setState(() => _selectedTime = time);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded, size: 14, color: AppColors.emeraldPrimary),
                        const SizedBox(width: 6),
                        Text(
                          _selectedTime.format(context),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Title
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.bodyMedium(isDark: isDark),
              decoration: const InputDecoration(
                labelText: 'What happened?',
                hintText: 'e.g. Sunset drinks, Surfing lesson, Checked into villa',
                prefixIcon: Icon(Icons.auto_awesome_rounded, size: 20),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Place / Location
            TextField(
              controller: _placeController,
              textCapitalization: TextCapitalization.words,
              style: AppTypography.bodyMedium(isDark: isDark),
              decoration: const InputDecoration(
                labelText: 'Place / Landmark (Optional)',
                hintText: 'e.g. Vagator Beach, Old Goa Church',
                prefixIcon: Icon(Icons.place_rounded, size: 20),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Notes / Story
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              style: AppTypography.bodyMedium(isDark: isDark),
              decoration: const InputDecoration(
                labelText: 'Reflection / Note (Optional)',
                hintText: 'e.g. Best calamari we had, played acoustic songs by the shore',
                prefixIcon: Icon(Icons.notes_rounded, size: 20),
              ),
            ),

            if (widget.expenses.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Link an Expense (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        HapticHelper.selection();
                        setState(() => _selectedExpenseId = null);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _selectedExpenseId == null
                              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                              : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'None',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _selectedExpenseId == null
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                        ),
                      ),
                    ),
                    ...widget.expenses.take(8).map((exp) {
                      final isSelected = _selectedExpenseId == exp.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            HapticHelper.selection();
                            setState(() => _selectedExpenseId = exp.id);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                                  : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${exp.title} (₹${(exp.amountInPaise / 100).toStringAsFixed(0)})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            AppButton(
              text: 'Save Moment',
              icon: Icons.check_circle_outline_rounded,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
