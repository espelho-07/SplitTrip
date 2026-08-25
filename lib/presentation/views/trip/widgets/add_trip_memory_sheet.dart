import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/models/trip_memory.dart';
import '../../../../domain/models/trip.dart';

class AddTripMemorySheet extends StatefulWidget {
  final Trip trip;
  final Function(TripMemory) onAdd;

  const AddTripMemorySheet({
    super.key,
    required this.trip,
    required this.onAdd,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required Function(TripMemory) onAdd,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTripMemorySheet(trip: trip, onAdd: onAdd),
    );
  }

  @override
  State<AddTripMemorySheet> createState() => _AddTripMemorySheetState();
}

class _AddTripMemorySheetState extends State<AddTripMemorySheet> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedEmoji = '✨';
  int _dayNumber = 1;

  static const List<String> _emojiOptions = ['✨', '🌊', '🌄', '🍕', '🎉', '🛵', '☕', '🏕️', '📸', '🎵'];

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for this memory.')),
      );
      return;
    }

    final memory = TripMemory(
      id: 'mem_${const Uuid().v4().substring(0, 8)}',
      tripId: widget.trip.id,
      title: title,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      emoji: _selectedEmoji,
      dayNumber: _dayNumber,
      createdAt: DateTime.now(),
    );

    HapticHelper.success();
    widget.onAdd(memory);
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
            'Save a Trip Memory',
            style: AppTypography.titleLarge(isDark: isDark),
          ),
          const SizedBox(height: 2),
          Text(
            'Capture a highlight, funny story, or moment to remember from this trip.',
            style: AppTypography.bodySmall(isDark: isDark),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Day selector
          Row(
            children: [
              Text('Day:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              const SizedBox(width: 12),
              ...List.generate(5, (index) {
                final day = index + 1;
                final isSelected = _dayNumber == day;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      HapticHelper.selection();
                      setState(() => _dayNumber = day);
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
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Emoji selector
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _emojiOptions.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final emoji = _emojiOptions[i];
                final isSelected = _selectedEmoji == emoji;
                return InkWell(
                  onTap: () {
                    HapticHelper.selection();
                    setState(() => _selectedEmoji = emoji);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.2)
                          : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary, width: 1.5)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Title
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.bodyMedium(isDark: isDark),
            decoration: const InputDecoration(
              labelText: 'What made this moment memorable?',
              hintText: 'e.g. Spontaneous beach scooter ride, Stargazing at camp',
              prefixIcon: Icon(Icons.auto_awesome_rounded, size: 20),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Reflection / Note
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            style: AppTypography.bodyMedium(isDark: isDark),
            decoration: const InputDecoration(
              labelText: 'Story / Reflection (optional)',
              hintText: 'Everyone agreed this was the best meal of the entire vacation...',
              prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          AppButton(
            text: 'Save Memory to Trip',
            icon: Icons.bookmark_added_rounded,
            isFullWidth: true,
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
