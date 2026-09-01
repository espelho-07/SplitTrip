import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'widgets/add_journey_moment_sheet.dart';

class TripMemoriesView extends StatefulWidget {
  final String tripId;

  const TripMemoriesView({super.key, required this.tripId});

  @override
  State<TripMemoriesView> createState() => _TripMemoriesViewState();
}

class _TripMemoriesViewState extends State<TripMemoriesView> {
  String _selectedTab = 'Photos'; // 'All', 'Photos', 'Videos'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripRepo = context.watch<TripRepository>();
    final expenseRepo = context.watch<ExpenseRepository>();
    final authVm = context.watch<AuthViewModel>();
    final trip = tripRepo.getCachedTripById(widget.tripId);
    final user = authVm.currentUser;

    if (trip == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF14B8A6),
          ),
        ),
      );
    }

    final expenses = expenseRepo.getCachedExpenses(trip.id);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${trip.name} ${trip.emoji}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text(
              DateFormatter.formatTripDateRange(trip.createdAt, trip.updatedAt),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF14B8A6)),
            onPressed: () {
              HapticHelper.light();
              AddJourneyMomentSheet.show(
                context,
                trip: trip,
                expenses: expenses,
                currentUserId: user?.id ?? '',
                onAdd: (moment) {
                  final list = tripRepo.getCachedJourneyMoments(trip.id);
                  list.add(moment);
                  tripRepo.saveJourneyMoments(trip.id, list);
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs: [ All | Photos | Videos ]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Row(
              children: [
                _buildFilterPill('All', isDark),
                const SizedBox(width: 8),
                _buildFilterPill('Photos', isDark),
                const SizedBox(width: 8),
                _buildFilterPill('Videos', isDark),
              ],
            ),
          ),

          // Photo & Moment Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: 6,
              itemBuilder: (ctx, i) {
                final emojis = ['🏖️', '🌴', '⛵', '🏨', '🍽️', '🌅'];
                final titles = ['Beach Sunset', 'Palm Haven', 'Boat Ride', 'Resort Stay', 'Dinner Vibes', 'Golden Hour'];
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1418) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emojis[i % emojis.length], style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text(
                        titles[i % titles.length],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Day ${(i % 3) + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, bool isDark) {
    final isSelected = _selectedTab == label;
    return GestureDetector(
      onTap: () {
        HapticHelper.selection();
        setState(() => _selectedTab = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF14B8A6)
              : (isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}
