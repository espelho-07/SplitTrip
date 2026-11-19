/// Typed application-level event hierarchy for cross-ViewModel reactive state sync.
///
/// Emitted by repositories after successful local mutations so ViewModels
/// can refresh without polling or tight coupling.
library;

import '../../domain/models/expense.dart';
import '../../domain/models/trip.dart';

/// Base event class — all events carry a creation timestamp.
abstract class AppEvent {
  final DateTime timestamp;
  AppEvent() : timestamp = DateTime.now();
}

/// Emitted after a new expense is successfully persisted locally.
class ExpenseCreatedEvent extends AppEvent {
  final String tripId;
  final Expense expense;
  ExpenseCreatedEvent({required this.tripId, required this.expense});
}

/// Emitted after an existing expense is updated locally.
class ExpenseUpdatedEvent extends AppEvent {
  final String tripId;
  final Expense expense;
  ExpenseUpdatedEvent({required this.tripId, required this.expense});
}

/// Emitted after an expense is soft-deleted locally.
class ExpenseDeletedEvent extends AppEvent {
  final String tripId;
  final String expenseId;
  ExpenseDeletedEvent({required this.tripId, required this.expenseId});
}

/// Emitted after a new trip is created and locally persisted.
class TripCreatedEvent extends AppEvent {
  final Trip trip;
  TripCreatedEvent({required this.trip});
}

/// Emitted after a trip is successfully joined and locally persisted.
class TripJoinedEvent extends AppEvent {
  final Trip trip;
  TripJoinedEvent({required this.trip});
}

/// Emitted after a settlement is recorded locally.
class SettlementRecordedEvent extends AppEvent {
  final String tripId;
  SettlementRecordedEvent({required this.tripId});
}
