import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../../data/services/sync_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import 'widgets/active_trip_hero_card.dart';
import 'widgets/historical_trip_card.dart';
import 'widgets/trip_filter_sheet.dart';

/// Redesigned Master Kith Trips Page.
/// Focused strictly on 2 primary sections:
/// 1. CURRENT TRIP (Active & Ongoing)
/// 2. ALL TRIPS (Historical & Completed with Smart Filters & Search)
class TripsHomeTab extends StatefulWidget {
  const TripsHomeTab({super.key});

  @override
  State<TripsHomeTab> createState() => _TripsHomeTabState();
}

class _TripsHomeTabState extends State<TripsHomeTab> {
  TripFilterCriteria _filterCriteria = const TripFilterCriteria();
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVm = context.read<AuthViewModel>();
      final user = authVm.currentUser;
      if (user != null) {
        final homeVm = context.read<HomeViewModel>();
        homeVm.loadTrips(user.id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final homeVm = context.watch<HomeViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final syncService = Provider.of<SyncService?>(context);
    final user = authVm.currentUser;

    // Separate active vs completed trips
    final allTrips = homeVm.trips;
    final activeTrips = allTrips
        .where((t) => t.lifecycleState.isActive || t.lifecycleState.isCompleting)
        .toList();
    final completedTrips = allTrips
        .where((t) => t.lifecycleState.isCompleted)
        .toList();

    // Fast O(1) read from HomeViewModel pre-computed cache
    final tripTotalsPaise = homeVm.tripTotalsPaise;
    final tripExpenseCounts = homeVm.tripExpenseCounts;

    // Apply smart filters & search to ALL TRIPS section
    var displayedCompletedTrips = _filterCriteria.filterAndSort(
      completedTrips,
      tripTotalsPaise: tripTotalsPaise,
    );

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      displayedCompletedTrips = displayedCompletedTrips.where((t) {
        final matchName = t.name.toLowerCase().contains(q);
        final matchDesc = t.description?.toLowerCase().contains(q) ?? false;
        return matchName || matchDesc;
      }).toList();
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (user != null) {
          await homeVm.refresh(user.id);
        }
      },
      child: homeVm.isLoading && allTrips.isEmpty
          ? _buildLoadingSkeleton(isDark)
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              children: [
                // 1. Top Bar: [ Trips ]     [ + Create ] [ Join ]
                _buildTopBar(context, isDark, l10n),

                const SizedBox(height: 24),

                // 2. Section 1: CURRENT TRIP
                _buildSectionHeader(
                  title: l10n.tripsTabCurrentTrip.toUpperCase(),
                  count: activeTrips.isNotEmpty ? activeTrips.length : null,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                if (activeTrips.isNotEmpty)
                  ...activeTrips.map((trip) {
                    final balance = homeVm.tripBalances[trip.id];
                    final hasPending = syncService?.hasPendingMutationsForTrip(trip.id) ?? false;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ActiveTripHeroCard(
                        trip: trip,
                        balance: balance,
                        totalExpensesCount: tripExpenseCounts[trip.id] ?? 0,
                        totalExpensesPaise: tripTotalsPaise[trip.id] ?? 0,
                        hasPendingSync: hasPending,
                      ),
                    );
                  })
                else
                  _buildNoActiveTripCard(context, isDark, l10n),

                const SizedBox(height: 28),

                // 3. Section 2: ALL TRIPS
                _buildAllTripsHeader(context, isDark, completedTrips.length, l10n),

                if (_isSearchOpen) ...[
                  const SizedBox(height: 12),
                  _buildSearchBar(isDark, l10n),
                ],

                const SizedBox(height: 14),

                // Historical List or Filter Empty State
                if (displayedCompletedTrips.isNotEmpty)
                  ...displayedCompletedTrips.map((trip) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: HistoricalTripCard(
                        trip: trip,
                        totalExpensesPaise: tripTotalsPaise[trip.id] ?? 0,
                        totalExpensesCount: tripExpenseCounts[trip.id] ?? 0,
                      ),
                    );
                  })
                else if (completedTrips.isNotEmpty && _filterCriteria.isFiltered)
                  _buildFilteredEmptyState(isDark, l10n)
                else
                  _buildEmptyHistoryState(isDark, l10n),

                const SizedBox(height: 90),
              ],
            ),
    );
  }

  /// 1. Top Bar with title and quick Create/Join actions
  Widget _buildTopBar(BuildContext context, bool isDark, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.tripsTitle,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Join Trip Pill
            GestureDetector(
              onTap: () {
                HapticHelper.light();
                context.push('/join-trip');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 15,
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l10n.navJoin,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Create Trip Button
            GestureDetector(
              onTap: () {
                HapticHelper.medium();
                context.push('/create-trip');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.35 : 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      l10n.tripsCreate,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Section Header with title and optional count badge
  Widget _buildSectionHeader({
    required String title,
    int? count,
    required bool isDark,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
          ),
        ),
        if (count != null && count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Minimal clean card when there is no active trip
  Widget _buildNoActiveTripCard(BuildContext context, bool isDark, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('🏖️', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tripsTabNoActiveTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.tripsTabNoActiveSub,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ALL TRIPS header with Search & Filter controls
  Widget _buildAllTripsHeader(BuildContext context, bool isDark, int totalCount, AppLocalizations l10n) {
    final isFiltered = _filterCriteria.isFiltered;
    final filterCount = _filterCriteria.activeFilterCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Text(
              l10n.tripsTabAllTrips.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
              ),
            ),
            if (totalCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161D24) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search toggle icon
            IconButton(
              icon: Icon(
                _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                size: 20,
                color: _isSearchOpen
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                    : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
              ),
              onPressed: () {
                HapticHelper.light();
                setState(() {
                  _isSearchOpen = !_isSearchOpen;
                  if (!_isSearchOpen) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 6),

            // Filter button
            GestureDetector(
              onTap: () {
                HapticHelper.light();
                TripFilterSheet.show(
                  context,
                  initialCriteria: _filterCriteria,
                  onApply: (criteria) {
                    setState(() => _filterCriteria = criteria);
                  },
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: isFiltered
                      ? (isDark ? AppColors.emeraldPrimary.withValues(alpha: 0.2) : const Color(0xFFECFDF5))
                      : (isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFiltered
                        ? AppColors.emeraldPrimary
                        : (isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0)),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: isFiltered
                          ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                          : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isFiltered ? '${l10n.tripsTabFilter} • $filterCount' : l10n.tripsTabFilter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isFiltered
                            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                            : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Search Textfield
  Widget _buildSearchBar(bool isDark, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFCBD5E1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
        ),
        decoration: KithInputDecoration.borderless(
          icon: Icon(
            Icons.search_rounded,
            size: 18,
            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
          ),
          hintText: l10n.tripsTabSearchHint,
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.clear_rounded, size: 16),
                )
              : null,
        ),
        onChanged: (val) {
          setState(() => _searchQuery = val);
        },
      ),
    );
  }

  /// Filtered Empty State
  Widget _buildFilteredEmptyState(bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16.0),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.filter_list_off_rounded,
            size: 40,
            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.translate('search_empty_title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.translate('search_empty_desc'),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              HapticHelper.light();
              setState(() {
                _filterCriteria = const TripFilterCriteria();
                _searchQuery = '';
                _searchController.clear();
              });
            },
            child: Text(
              l10n.tripFilterClear,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty History State
  Widget _buildEmptyHistoryState(bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
            ),
            alignment: Alignment.center,
            child: const Text('✨', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.tripsTabNoCompletedTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.tripsTabNoCompletedSub,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      children: [
        ShimmerSkeleton(
          width: double.infinity,
          height: 180,
          borderRadius: BorderRadius.circular(24),
        ),
        const SizedBox(height: 28),
        ShimmerSkeleton(
          width: 140,
          height: 20,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 16),
        ShimmerSkeleton(
          width: double.infinity,
          height: 80,
          borderRadius: BorderRadius.circular(20),
        ),
        const SizedBox(height: 12),
        ShimmerSkeleton(
          width: double.infinity,
          height: 80,
          borderRadius: BorderRadius.circular(20),
        ),
      ],
    );
  }
}
