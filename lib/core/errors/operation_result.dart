import 'app_error.dart';

/// Explicit synchronization lifecycle status for any operation.
enum SyncStateStatus {
  pending,
  syncing,
  synced,
  failed,
  conflict,
  requiresReview,
}

/// Generic, robust result container for all domain and repository actions.
///
/// Distinguishes between:
/// 1. Operation completed & verified on server (`synced`)
/// 2. Operation safely persisted locally but pending background sync (`savedLocally`)
/// 3. Operation failed before local persistence (`failure`)
/// 4. Operation status ambiguous due to network drop during transit (`unknown`)
class OperationResult<T> {
  final bool isSuccess;
  final T? data;
  final ApplicationError? error;
  final SyncStateStatus syncStatus;
  final bool isSavedLocally;
  final bool isSynced;
  final bool isOutcomeUnknown;
  final String? correlationId;

  const OperationResult._({
    required this.isSuccess,
    this.data,
    this.error,
    required this.syncStatus,
    this.isSavedLocally = false,
    this.isSynced = false,
    this.isOutcomeUnknown = false,
    this.correlationId,
  });

  /// The operation succeeded and was verified on the cloud server.
  factory OperationResult.synced(T data, {String? correlationId}) {
    return OperationResult._(
      isSuccess: true,
      data: data,
      syncStatus: SyncStateStatus.synced,
      isSavedLocally: true,
      isSynced: true,
      correlationId: correlationId,
    );
  }

  /// The operation was safely committed to local SQLite storage, but has not yet synchronized.
  factory OperationResult.savedLocally(T data, {String? correlationId}) {
    return OperationResult._(
      isSuccess: true,
      data: data,
      syncStatus: SyncStateStatus.pending,
      isSavedLocally: true,
      isSynced: false,
      correlationId: correlationId,
    );
  }

  /// The operation failed completely (not saved locally and not synced).
  factory OperationResult.failure(ApplicationError error, {String? correlationId}) {
    return OperationResult._(
      isSuccess: false,
      error: error,
      syncStatus: SyncStateStatus.failed,
      isSavedLocally: error.isSavedLocally,
      isSynced: false,
      isOutcomeUnknown: error.isOutcomeUnknown,
      correlationId: correlationId,
    );
  }

  /// The operation encountered an update conflict or stale revision.
  factory OperationResult.conflict(ConflictError error, {T? latestData, String? correlationId}) {
    return OperationResult._(
      isSuccess: false,
      data: latestData,
      error: error,
      syncStatus: SyncStateStatus.conflict,
      isSavedLocally: true,
      isSynced: false,
      correlationId: correlationId,
    );
  }

  /// The operation network status is unknown (transmitted, but disconnected before ack).
  factory OperationResult.unknown(T data, {String? correlationId}) {
    return OperationResult._(
      isSuccess: true,
      data: data,
      syncStatus: SyncStateStatus.pending,
      isSavedLocally: true,
      isSynced: false,
      isOutcomeUnknown: true,
      correlationId: correlationId,
    );
  }

  /// Human-friendly display message for UI feedback.
  String get displayMessage {
    if (error != null) {
      return error!.userMessage;
    }
    if (isSynced) {
      return 'Changes saved and synced to cloud';
    }
    if (isSavedLocally) {
      return 'Saved locally. Will sync automatically when online';
    }
    return 'Operation completed';
  }
}
