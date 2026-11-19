import 'dart:async';
import 'app_events.dart';

/// A lightweight broadcast event bus for cross-ViewModel reactive sync.
///
/// Usage:
/// ```dart
/// // Emit
/// eventBus.emit(ExpenseCreatedEvent(tripId: id, expense: exp));
///
/// // Subscribe (in ViewModel)
/// _sub = eventBus.on<ExpenseCreatedEvent>().listen((e) { ... });
/// ```
class AppEventBus {
  final StreamController<AppEvent> _controller =
      StreamController<AppEvent>.broadcast();

  /// Returns a filtered stream that only emits events of type [T].
  Stream<T> on<T extends AppEvent>() =>
      _controller.stream.where((e) => e is T).cast<T>();

  /// Emits an [event] to all current listeners.
  /// Safe to call from any isolate; no-ops if the bus is closed.
  void emit(AppEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Closes the stream. Call only on app shutdown or in tests.
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
