import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../domain/models/trip.dart';

enum TripStatusFilter {
  all('All'),
  active('Active'),
  completed('Completed');

  final String label;
  const TripStatusFilter(this.label);
}

enum TripDateFilter {
  allTime('All time'),
  thisMonth('This month'),
  last3Months('Last 3 months'),
  thisYear('This year');

  final String label;
  const TripDateFilter(this.label);
}

enum TripSortFilter {
  newestFirst('Newest first'),
  oldestFirst('Oldest first'),
  highestExpense('Highest expense'),
  lowestExpense('Lowest expense');

  final String label;
  const TripSortFilter(this.label);
}

/// Immutable filter criteria model for Kith Trips page
class TripFilterCriteria {
  final TripStatusFilter status;
  final TripDateFilter date;
  final TripSortFilter sort;

  const TripFilterCriteria({
    this.status = TripStatusFilter.all,
    this.date = TripDateFilter.allTime,
    this.sort = TripSortFilter.newestFirst,
  });

  int get activeFilterCount {
    int count = 0;
    if (status != TripStatusFilter.all) count++;
    if (date != TripDateFilter.allTime) count++;
    if (sort != TripSortFilter.newestFirst) count++;
    return count;
  }

  bool get isFiltered => activeFilterCount > 0;

  TripFilterCriteria copyWith({
    TripStatusFilter? status,
    TripDateFilter? date,
    TripSortFilter? sort,
  }) {
    return TripFilterCriteria(
      status: status ?? this.status,
      date: date ?? this.date,
      sort: sort ?? this.sort,
    );
  }

  /// Filters and sorts a given list of trips based on this criteria
  List<Trip> filterAndSort(List<Trip> trips, {Map<String, int> tripTotalsPaise = const {}}) {
    final now = DateTime.now();
    var filtered = trips.where((trip) {
      // 1. Status filter
      if (status == TripStatusFilter.active) {
        if (!trip.lifecycleState.isActive && !trip.lifecycleState.isCompleting) {
          return false;
        }
      } else if (status == TripStatusFilter.completed) {
        if (!trip.lifecycleState.isCompleted) {
          return false;
        }
      }

      // 2. Date filter
      final tripDate = trip.completedAt ?? trip.startedAt;
      if (date == TripDateFilter.thisMonth) {
        if (tripDate.year != now.year || tripDate.month != now.month) {
          return false;
        }
      } else if (date == TripDateFilter.last3Months) {
        final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
        if (tripDate.isBefore(threeMonthsAgo)) {
          return false;
        }
      } else if (date == TripDateFilter.thisYear) {
        if (tripDate.year != now.year) {
          return false;
        }
      }

      return true;
    }).toList();

    // 3. Sort filter
    filtered.sort((a, b) {
      switch (sort) {
        case TripSortFilter.newestFirst:
          final aDate = a.completedAt ?? a.startedAt;
          final bDate = b.completedAt ?? b.startedAt;
          return bDate.compareTo(aDate);
        case TripSortFilter.oldestFirst:
          final aDate = a.completedAt ?? a.startedAt;
          final bDate = b.completedAt ?? b.startedAt;
          return aDate.compareTo(bDate);
        case TripSortFilter.highestExpense:
          final aTotal = tripTotalsPaise[a.id] ?? 0;
          final bTotal = tripTotalsPaise[b.id] ?? 0;
          return bTotal.compareTo(aTotal);
        case TripSortFilter.lowestExpense:
          final aTotal = tripTotalsPaise[a.id] ?? 0;
          final bTotal = tripTotalsPaise[b.id] ?? 0;
          return aTotal.compareTo(bTotal);
      }
    });

    return filtered;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripFilterCriteria &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          date == other.date &&
          sort == other.sort;

  @override
  int get hashCode => status.hashCode ^ date.hashCode ^ sort.hashCode;
}

/// Premium bottom sheet for filtering & sorting Kith trips
class TripFilterSheet extends StatefulWidget {
  final TripFilterCriteria initialCriteria;
  final ValueChanged<TripFilterCriteria> onApply;

  const TripFilterSheet({
    super.key,
    required this.initialCriteria,
    required this.onApply,
  });

  static Future<TripFilterCriteria?> show(
    BuildContext context, {
    required TripFilterCriteria initialCriteria,
    required ValueChanged<TripFilterCriteria> onApply,
  }) {
    return showModalBottomSheet<TripFilterCriteria>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripFilterSheet(
        initialCriteria: initialCriteria,
        onApply: onApply,
      ),
    );
  }

  @override
  State<TripFilterSheet> createState() => _TripFilterSheetState();
}

class _TripFilterSheetState extends State<TripFilterSheet> {
  late TripStatusFilter _status;
  late TripDateFilter _date;
  late TripSortFilter _sort;

  @override
  void initState() {
    super.initState();
    _status = widget.initialCriteria.status;
    _date = widget.initialCriteria.date;
    _sort = widget.initialCriteria.sort;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentCriteria = TripFilterCriteria(status: _status, date: _date, sort: _sort);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Filter Trips',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                ),
              ),
              if (currentCriteria.isFiltered)
                GestureDetector(
                  onTap: () {
                    HapticHelper.light();
                    setState(() {
                      _status = TripStatusFilter.all;
                      _date = TripDateFilter.allTime;
                      _sort = TripSortFilter.newestFirst;
                    });
                  },
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 22),

          // 1. Status Section
          _buildSectionTitle('STATUS', isDark),
          const SizedBox(height: 10),
          _buildChoiceRow<TripStatusFilter>(
            options: TripStatusFilter.values,
            selected: _status,
            labelOf: (val) => val.label,
            onSelected: (val) {
              HapticHelper.selection();
              setState(() => _status = val);
            },
            isDark: isDark,
          ),

          const SizedBox(height: 20),

          // 2. Date Section
          _buildSectionTitle('DATE', isDark),
          const SizedBox(height: 10),
          _buildChoiceWrap<TripDateFilter>(
            options: TripDateFilter.values,
            selected: _date,
            labelOf: (val) => val.label,
            onSelected: (val) {
              HapticHelper.selection();
              setState(() => _date = val);
            },
            isDark: isDark,
          ),

          const SizedBox(height: 20),

          // 3. Sort Section
          _buildSectionTitle('SORT BY', isDark),
          const SizedBox(height: 10),
          _buildChoiceWrap<TripSortFilter>(
            options: TripSortFilter.values,
            selected: _sort,
            labelOf: (val) => val.label,
            onSelected: (val) {
              HapticHelper.selection();
              setState(() => _sort = val);
            },
            isDark: isDark,
          ),

          const SizedBox(height: 28),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticHelper.light();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticHelper.medium();
                    final criteria = TripFilterCriteria(
                      status: _status,
                      date: _date,
                      sort: _sort,
                    );
                    widget.onApply(criteria);
                    Navigator.of(context).pop(criteria);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    currentCriteria.isFiltered
                        ? 'Apply (${currentCriteria.activeFilterCount})'
                        : 'Apply Filters',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
      ),
    );
  }

  Widget _buildChoiceRow<T>({
    required List<T> options,
    required T selected,
    required String Function(T) labelOf,
    required ValueChanged<T> onSelected,
    required bool isDark,
  }) {
    return Row(
      children: options.map((opt) {
        final isSelected = opt == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () => onSelected(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.emeraldPrimary.withValues(alpha: 0.22) : const Color(0xFFECFDF5))
                      : (isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.emeraldPrimary
                        : (isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0)),
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  labelOf(opt),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                        : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChoiceWrap<T>({
    required List<T> options,
    required T selected,
    required String Function(T) labelOf,
    required ValueChanged<T> onSelected,
    required bool isDark,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onSelected(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.emeraldPrimary.withValues(alpha: 0.22) : const Color(0xFFECFDF5))
                  : (isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.emeraldPrimary
                    : (isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Text(
              labelOf(opt),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                    : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
