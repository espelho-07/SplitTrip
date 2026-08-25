import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/models/journey_stop.dart';
import '../../../../domain/models/trip.dart';

class AddJourneyStopSheet extends StatefulWidget {
  final Trip trip;
  final Function(JourneyStop) onAdd;

  const AddJourneyStopSheet({
    super.key,
    required this.trip,
    required this.onAdd,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required Function(JourneyStop) onAdd,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddJourneyStopSheet(trip: trip, onAdd: onAdd),
    );
  }

  @override
  State<AddJourneyStopSheet> createState() => _AddJourneyStopSheetState();
}

class _AddJourneyStopSheetState extends State<AddJourneyStopSheet> {
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();
  final _timeController = TextEditingController(text: '10:00 AM');
  int _dayNumber = 1;

  @override
  void dispose() {
    _locationController.dispose();
    _noteController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final location = _locationController.text.trim();
    if (location.isEmpty) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a place or stop name.')),
      );
      return;
    }

    final stop = JourneyStop(
      id: 'stop_${const Uuid().v4().substring(0, 8)}',
      tripId: widget.trip.id,
      dayNumber: _dayNumber,
      time: _timeController.text.trim().isEmpty ? '12:00 PM' : _timeController.text.trim(),
      locationName: location,
      notes: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      createdAt: DateTime.now(),
    );

    HapticHelper.success();
    widget.onAdd(stop);
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
            'Add Journey Stop',
            style: AppTypography.titleLarge(isDark: isDark),
          ),
          const SizedBox(height: 2),
          Text(
            'Add a landmark, viewpoint, or travel waypoint to this trip.',
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

          // Location
          TextField(
            controller: _locationController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: AppTypography.bodyMedium(isDark: isDark),
            decoration: const InputDecoration(
              labelText: 'Where did you go / Stop name?',
              hintText: 'e.g. Baga Beach, Cafe Alchemia, Rohtang Pass',
              prefixIcon: Icon(Icons.place_outlined, size: 20),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Time & Notes
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _timeController,
                  style: AppTypography.bodyMedium(isDark: isDark),
                  decoration: const InputDecoration(
                    labelText: 'Time',
                    hintText: '10:30 AM',
                    prefixIcon: Icon(Icons.access_time_rounded, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.bodyMedium(isDark: isDark),
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'Watched sunset',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          AppButton(
            text: 'Save Journey Stop',
            icon: Icons.check_circle_outline_rounded,
            isFullWidth: true,
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
