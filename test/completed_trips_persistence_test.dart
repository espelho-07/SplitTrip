import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/utils/date_formatter.dart';
import 'package:kith_app/domain/enums/trip_lifecycle.dart';
import 'package:kith_app/domain/models/trip.dart';
import 'package:kith_app/presentation/views/trip/widgets/trip_filter_sheet.dart';

void main() {
  group('Completed Trips Persistence & Discovery Test Suite', () {
    final tStart = DateTime(2026, 8, 24, 10, 0);
    final tEnd = DateTime(2026, 8, 30, 18, 0);

    test('1. Trip.fromJson robustly deserializes snake_case lifecycle_state, completed_at, and completed_by', () {
      final jsonSnake = {
        'id': 'trip_goa_123',
        'name': 'Goa Trip',
        'description': 'Fun beach trip',
        'emoji': '🏖️',
        'cover_gradient_index': 2,
        'currency_code': 'INR',
        'creator_id': 'usr_darpan',
        'lifecycle_state': 'completed',
        'invite_code': 'GOA999',
        'trip_mode': 'split_and_journey',
        'revision': 5,
        'completion_mode': 'normal',
        'started_at': tStart.toIso8601String(),
        'completed_at': tEnd.toIso8601String(),
        'completed_by': 'usr_darpan',
        'created_at': tStart.toIso8601String(),
        'updated_at': tEnd.toIso8601String(),
        'members': [
          {
            'id': 'mbr_1',
            'tripId': 'trip_goa_123',
            'userId': 'usr_darpan',
            'displayName': 'Darpan',
            'role': 'creator',
            'isClaimed': true,
            'joinedAt': tStart.toIso8601String(),
          }
        ]
      };

      final trip = Trip.fromJson(jsonSnake);
      expect(trip.id, equals('trip_goa_123'));
      expect(trip.name, equals('Goa Trip'));
      expect(trip.lifecycleState, equals(TripLifecycle.completed));
      expect(trip.lifecycleState.isCompleted, isTrue);
      expect(trip.lifecycleState.isActive, isFalse);
      expect(trip.completedAt, isNotNull);
      expect(trip.completedAt?.year, equals(2026));
      expect(trip.completedAt?.day, equals(30));
      expect(trip.completedBy, equals('usr_darpan'));
      expect(trip.tripMode, equals('split_and_journey'));
    });

    test('2. TripLifecycle.isCompleted correctly recognizes completed, completedWithPendingChanges, and settled', () {
      expect(TripLifecycle.completed.isCompleted, isTrue);
      expect(TripLifecycle.completedWithPendingChanges.isCompleted, isTrue);
      expect(TripLifecycle.settled.isCompleted, isTrue);
      expect(TripLifecycle.settling.isCompleted, isTrue);

      expect(TripLifecycle.active.isCompleted, isFalse);
      expect(TripLifecycle.active.isActive, isTrue);
      expect(TripLifecycle.completing.isActive, isFalse);
      expect(TripLifecycle.completing.isCompleting, isTrue);
      expect(TripLifecycle.draft.isCompleted, isFalse);
    });

    test('3. TripLifecycle.fromString cleanly parses various status strings', () {
      expect(TripLifecycle.fromString('completed'), equals(TripLifecycle.completed));
      expect(TripLifecycle.fromString('COMPLETED'), equals(TripLifecycle.completed));
      expect(TripLifecycle.fromString('complete'), equals(TripLifecycle.completed));
      expect(TripLifecycle.fromString('completed_with_pending_changes'), equals(TripLifecycle.completedWithPendingChanges));
      expect(TripLifecycle.fromString('settled'), equals(TripLifecycle.settled));
      expect(TripLifecycle.fromString('settling'), equals(TripLifecycle.settling));
      expect(TripLifecycle.fromString('active'), equals(TripLifecycle.active));
      expect(TripLifecycle.fromString('ACTIVE'), equals(TripLifecycle.active));
    });

    test('4. DateFormatter formats completed trip range correctly', () {
      final formatted = DateFormatter.formatTripHistoricalRange(tStart, tEnd);
      expect(formatted, contains('24 Aug → 30 Aug 2026'));

      // Same day completed trip
      final sameDayStart = DateTime(2026, 8, 24, 10, 0);
      final sameDayEnd = DateTime(2026, 8, 24, 20, 0);
      final formattedSameDay = DateFormatter.formatTripHistoricalRange(sameDayStart, sameDayEnd);
      expect(formattedSameDay, equals('24 Aug 2026'));
    });

    test('5. TripFilterCriteria preserves completed trips and sorts by completedAt newest first', () {
      final trip1 = Trip(
        id: 'trip_1',
        name: 'Goa Trip',
        creatorId: 'usr_1',
        members: [],
        inviteCode: 'GOA1',
        lifecycleState: TripLifecycle.completed,
        startedAt: DateTime(2026, 8, 20),
        completedAt: DateTime(2026, 8, 30),
        createdAt: DateTime(2026, 8, 20),
        updatedAt: DateTime(2026, 8, 30),
      );

      final trip2 = Trip(
        id: 'trip_2',
        name: 'Mumbai Trip',
        creatorId: 'usr_1',
        members: [],
        inviteCode: 'MUM1',
        lifecycleState: TripLifecycle.completed,
        startedAt: DateTime(2026, 8, 10),
        completedAt: DateTime(2026, 8, 21),
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 21),
      );

      final criteria = const TripFilterCriteria();
      final sorted = criteria.filterAndSort([trip2, trip1]);

      expect(sorted.length, equals(2));
      expect(sorted[0].name, equals('Goa Trip')); // Aug 30 is newer than Aug 21
      expect(sorted[1].name, equals('Mumbai Trip'));
    });
  });
}
