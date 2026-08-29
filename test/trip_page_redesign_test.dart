import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/utils/date_formatter.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/domain/models/trip_member.dart';
import 'package:kith_app/presentation/views/trip/widgets/trip_filter_sheet.dart';

void main() {
  group('Kith Trips Page Redesign & Lifecycle Verification Suite', () {
    final t1Start = DateTime(2026, 8, 24, 10, 0);
    final t1End = DateTime(2026, 8, 27, 20, 30);
    final t2Start = DateTime(2026, 8, 24, 14, 0);
    final t2End = DateTime(2026, 8, 24, 22, 0); // same day

    final activeTrip = Trip(
      id: 'trip_active_1',
      name: 'Goa Trip',
      creatorId: 'user_1',
      emoji: '🏖️',
      members: [
        TripMember(
          id: 'mbr_1',
          userId: 'user_1',
          displayName: 'Darpan',
          role: 'creator',
          joinedAt: t1Start,
        ),
      ],
      inviteCode: 'GOA123',
      lifecycleState: TripLifecycle.active,
      startedAt: t1Start,
      createdAt: t1Start,
      updatedAt: t1Start,
    );

    final completedTrip1 = Trip(
      id: 'trip_comp_1',
      name: 'Manali Expedition',
      creatorId: 'user_1',
      emoji: '🏔️',
      members: [
        TripMember(
          id: 'mbr_1',
          userId: 'user_1',
          displayName: 'Darpan',
          role: 'creator',
          joinedAt: t1Start,
        ),
      ],
      inviteCode: 'MAN123',
      lifecycleState: TripLifecycle.completed,
      startedAt: t1Start,
      completedAt: t1End,
      createdAt: t1Start,
      updatedAt: t1End,
    );

    final completedTrip2 = Trip(
      id: 'trip_comp_2',
      name: 'Mumbai Day Trip',
      creatorId: 'user_1',
      emoji: '🏙️',
      members: [
        TripMember(
          id: 'mbr_1',
          userId: 'user_1',
          displayName: 'Darpan',
          role: 'creator',
          joinedAt: t2Start,
        ),
      ],
      inviteCode: 'MUM123',
      lifecycleState: TripLifecycle.completed,
      startedAt: t2Start,
      completedAt: t2End,
      createdAt: t2Start,
      updatedAt: t2End,
    );

    test('1. Trip domain model handles startedAt and completedAt accurately', () {
      final json = activeTrip.toJson();
      expect(json['startedAt'], t1Start.toIso8601String());
      expect(json['completedAt'], isNull);

      final fromJson = Trip.fromJson(json);
      expect(fromJson.startedAt, t1Start);
      expect(fromJson.completedAt, isNull);
      expect(fromJson.lifecycleState, TripLifecycle.active);

      final compJson = completedTrip1.toJson();
      expect(compJson['startedAt'], t1Start.toIso8601String());
      expect(compJson['completedAt'], t1End.toIso8601String());

      final fromCompJson = Trip.fromJson(compJson);
      expect(fromCompJson.startedAt, t1Start);
      expect(fromCompJson.completedAt, t1End);
      expect(fromCompJson.lifecycleState, TripLifecycle.completed);
    });

    test('2. DateFormatter handles active vs historical trip ranges cleanly', () {
      // Active trip
      final activeStr = DateFormatter.formatTripActiveDate(t1Start);
      expect(activeStr, startsWith('Started 24 Aug'));

      // Multi-day completed trip
      final multiDayStr = DateFormatter.formatTripHistoricalRange(t1Start, t1End);
      expect(multiDayStr, contains('24 Aug'));
      expect(multiDayStr, contains('27 Aug 2026'));
      expect(multiDayStr, contains('→'));

      // Same-day completed trip
      final sameDayStr = DateFormatter.formatTripHistoricalRange(t2Start, t2End);
      expect(sameDayStr, '24 Aug 2026');
    });

    test('3. TripFilterCriteria filters by status (All, Active, Completed)', () {
      final trips = [activeTrip, completedTrip1, completedTrip2];

      const allCriteria = TripFilterCriteria(status: TripStatusFilter.all);
      expect(allCriteria.filterAndSort(trips).length, 3);

      const activeCriteria = TripFilterCriteria(status: TripStatusFilter.active);
      final activeResults = activeCriteria.filterAndSort(trips);
      expect(activeResults.length, 1);
      expect(activeResults.first.id, 'trip_active_1');

      const completedCriteria = TripFilterCriteria(status: TripStatusFilter.completed);
      final completedResults = completedCriteria.filterAndSort(trips);
      expect(completedResults.length, 2);
      expect(completedResults.map((t) => t.id), containsAll(['trip_comp_1', 'trip_comp_2']));
    });

    test('4. TripFilterCriteria sorts by highest/lowest expenses and dates', () {
      final trips = [completedTrip1, completedTrip2];
      final totals = {
        'trip_comp_1': 1500000, // ₹15,000
        'trip_comp_2': 300000, // ₹3,000
      };

      const highestCriteria = TripFilterCriteria(sort: TripSortFilter.highestExpense);
      final highestResults = highestCriteria.filterAndSort(trips, tripTotalsPaise: totals);
      expect(highestResults.first.id, 'trip_comp_1');

      const lowestCriteria = TripFilterCriteria(sort: TripSortFilter.lowestExpense);
      final lowestResults = lowestCriteria.filterAndSort(trips, tripTotalsPaise: totals);
      expect(lowestResults.first.id, 'trip_comp_2');
    });

    test('5. TripFilterCriteria activeFilterCount and isFiltered state', () {
      const defaultCriteria = TripFilterCriteria();
      expect(defaultCriteria.activeFilterCount, 0);
      expect(defaultCriteria.isFiltered, isFalse);

      final filtered1 = defaultCriteria.copyWith(status: TripStatusFilter.completed);
      expect(filtered1.activeFilterCount, 1);
      expect(filtered1.isFiltered, isTrue);

      final filtered2 = filtered1.copyWith(
        date: TripDateFilter.thisMonth,
        sort: TripSortFilter.highestExpense,
      );
      expect(filtered2.activeFilterCount, 3);
      expect(filtered2.isFiltered, isTrue);
    });

    test('6. TripFilterCriteria date filter handles thisMonth and thisYear boundaries', () {
      final now = DateTime.now();
      final thisMonthTrip = Trip(
        id: 'trip_now',
        name: 'This Month Trip',
        creatorId: 'user_1',
        members: [],
        inviteCode: 'NOW123',
        lifecycleState: TripLifecycle.completed,
        startedAt: DateTime(now.year, now.month, 1),
        completedAt: DateTime(now.year, now.month, 2),
        createdAt: DateTime(now.year, now.month, 1),
        updatedAt: DateTime(now.year, now.month, 2),
      );

      final oldYearTrip = Trip(
        id: 'trip_old',
        name: 'Old Year Trip',
        creatorId: 'user_1',
        members: [],
        inviteCode: 'OLD123',
        lifecycleState: TripLifecycle.completed,
        startedAt: DateTime(now.year - 2, 1, 1),
        completedAt: DateTime(now.year - 2, 1, 5),
        createdAt: DateTime(now.year - 2, 1, 1),
        updatedAt: DateTime(now.year - 2, 1, 5),
      );

      final trips = [thisMonthTrip, oldYearTrip];

      const thisMonthCriteria = TripFilterCriteria(date: TripDateFilter.thisMonth);
      final thisMonthResults = thisMonthCriteria.filterAndSort(trips);
      expect(thisMonthResults.length, 1);
      expect(thisMonthResults.first.id, 'trip_now');

      const thisYearCriteria = TripFilterCriteria(date: TripDateFilter.thisYear);
      final thisYearResults = thisYearCriteria.filterAndSort(trips);
      expect(thisYearResults.length, 1);
      expect(thisYearResults.first.id, 'trip_now');

      const allTimeCriteria = TripFilterCriteria(date: TripDateFilter.allTime);
      final allTimeResults = allTimeCriteria.filterAndSort(trips);
      expect(allTimeResults.length, 2);
    });
  });
}
