/// Authoritative, strongly-typed application error hierarchy for SplitTrip (KITH).
///
/// Ensures every error has specific, understandable, user-facing titles and explanations,
/// clear operational status (saved locally vs reached server vs outcome unknown),
/// and actionable recovery steps without leaking raw stack traces or internal implementation details.
abstract class ApplicationError implements Exception {
  final String userTitle;
  final String userMessage;
  final String? actionLabel;
  final bool isSavedLocally;
  final bool isReachedServer;
  final bool isOutcomeUnknown;
  final bool isRetrySafe;
  final bool isUserActionRequired;
  final String? recoveryAction;
  final String? correlationId;
  final String code;
  final dynamic originalError;

  const ApplicationError({
    required this.userTitle,
    required this.userMessage,
    this.actionLabel,
    this.isSavedLocally = false,
    this.isReachedServer = false,
    this.isOutcomeUnknown = false,
    this.isRetrySafe = true,
    this.isUserActionRequired = false,
    this.recoveryAction,
    this.correlationId,
    required this.code,
    this.originalError,
  });

  @override
  String toString() => '$userTitle: $userMessage [code=$code, savedLocally=$isSavedLocally, reachedServer=$isReachedServer]';
}

/// Network connectivity, socket, host resolution, or transport timeouts.
class NetworkError extends ApplicationError {
  const NetworkError({
    super.userTitle = "You're offline",
    super.userMessage = "An internet connection is required to complete this online operation. Check your connection and try again.",
    super.actionLabel = "Retry",
    super.isSavedLocally = false,
    super.isReachedServer = false,
    super.isOutcomeUnknown = false,
    super.isRetrySafe = true,
    super.isUserActionRequired = true,
    super.recoveryAction = "Verify your Wi-Fi or mobile data connection and tap Retry.",
    super.correlationId,
    super.code = "NETWORK_ERROR",
    super.originalError,
  });
}

/// Authentication failures, invalid tokens, or expired sessions.
class AuthenticationError extends ApplicationError {
  const AuthenticationError({
    super.userTitle = "Session expired",
    super.userMessage = "Your security session has expired. Please sign in or use your recovery key to continue syncing.",
    super.actionLabel = "Sign In",
    super.isSavedLocally = true,
    super.isReachedServer = false,
    super.isOutcomeUnknown = false,
    super.isRetrySafe = false,
    super.isUserActionRequired = true,
    super.recoveryAction = "Authenticate with Google or enter your 16-character recovery key.",
    super.correlationId,
    super.code = "AUTH_ERROR",
    super.originalError,
  });
}

/// Permission denied, non-member trip access, or unauthorized mutations.
class AuthorizationError extends ApplicationError {
  const AuthorizationError({
    super.userTitle = "Access unavailable",
    super.userMessage = "You don't have permission to perform this action on this trip.",
    super.actionLabel = "Back to Trips",
    super.isSavedLocally = false,
    super.isReachedServer = true,
    super.isOutcomeUnknown = false,
    super.isRetrySafe = false,
    super.isUserActionRequired = true,
    super.recoveryAction = "Ask the trip host to verify your membership or send a fresh invitation.",
    super.correlationId,
    super.code = "FORBIDDEN",
    super.originalError,
  });
}

/// Client-side or server-side input validation failures (e.g., zero splits, invalid amounts).
class ValidationError extends ApplicationError {
  const ValidationError({
    super.userTitle = "Check your details",
    super.userMessage = "Some information is missing or invalid. Please review the highlighted fields.",
    super.actionLabel = "Review Fields",
    super.isSavedLocally = false,
    super.isReachedServer = false,
    super.isOutcomeUnknown = false,
    super.isRetrySafe = true,
    super.isUserActionRequired = true,
    super.recoveryAction = "Correct the input values and submit again.",
    super.correlationId,
    super.code = "VALIDATION_ERROR",
    super.originalError,
  });
}

/// SQLite or database schema, transaction, or constraint failures.
class DatabaseError extends ApplicationError {
  const DatabaseError({
    super.userTitle = "Database storage error",
    super.userMessage = "We couldn't write your changes to local storage. Your previous records remain safe.",
    super.actionLabel = "Try Again",
    super.isSavedLocally = false,
    super.isReachedServer = false,
    super.isOutcomeUnknown = false,
    super.isRetrySafe = true,
    super.isUserActionRequired = false,
    super.recoveryAction = "Restart the app or free up device storage.",
    super.correlationId,
    super.code = "DATABASE_ERROR",
    super.originalError,
  });
}

/// Outbox mutation queue, delta ingestion, or peer-to-peer sync failures.
class SynchronizationError extends ApplicationError {
  const SynchronizationError({
    super.userTitle = "Sync temporarily unavailable",
    super.userMessage = "Your changes are safe on this device, but haven't reached the server yet.",
    super.actionLabel = "Retry Sync",
    super.isSavedLocally = true,
    super.isReachedServer = false,
    super.isOutcomeUnknown = false,
    super.isRetrySafe = true,
    super.isUserActionRequired = false,
    super.recoveryAction = "Kith will automatically retry syncing when a stable connection is restored.",
    super.correlationId,
    super.code = "SYNC_ERROR",
    super.originalError,
  });
}

/// Stale revisions, version mismatches, or concurrent conflicting edits.
class ConflictError extends ApplicationError {
  const ConflictError({
    super.userTitle = "Update conflict detected",
    super.userMessage = "Another trip member updated this record while you were editing. We have refreshed with the latest information.",
    super.actionLabel = "Review Changes",
    super.isSavedLocally = true,
    super.isReachedServer = true,
    super.isOutcomeUnknown = false,
    super.isRetrySafe = false,
    super.isUserActionRequired = true,
    super.recoveryAction = "Review the latest values and re-apply your changes if needed.",
    super.correlationId,
    super.code = "CONFLICT",
    super.originalError,
  });
}

/// Disk full, SharedPreferences failure, or keystore access denial.
class StorageError extends ApplicationError {
  const StorageError({
    super.userTitle = "Storage unavailable",
    super.userMessage = "Unable to access secure device storage. Please check device permissions.",
    super.actionLabel = "Retry",
    super.isSavedLocally = false,
    super.isReachedServer = false,
    super.isOutcomeUnknown = false,
    super.isRetrySafe = true,
    super.isUserActionRequired = true,
    super.recoveryAction = "Check that your device has available storage space.",
    super.correlationId,
    super.code = "STORAGE_ERROR",
    super.originalError,
  });
}

/// Backend 5xx errors, database connectivity drops, or maintenance windows.
class ServerError extends ApplicationError {
  const ServerError({
    super.userTitle = "Server temporarily unavailable",
    super.userMessage = "We couldn't reach the server right now. Your locally saved changes remain available.",
    super.actionLabel = "Retry",
    super.isSavedLocally = false,
    super.isReachedServer = false,
    super.isOutcomeUnknown = false,
    super.isRetrySafe = true,
    super.isUserActionRequired = false,
    super.recoveryAction = "Our team has been notified. Try again in a few minutes.",
    super.correlationId,
    super.code = "SERVER_ERROR",
    super.originalError,
  });
}

/// Ambiguous state where request was transmitted but connection dropped before response ack was received.
class UnknownOutcomeError extends ApplicationError {
  const UnknownOutcomeError({
    super.userTitle = "Checking operation status",
    super.userMessage = "We couldn't confirm whether this action reached the server. Checking before attempting it again.",
    super.actionLabel = "Check Status",
    super.isSavedLocally = true,
    super.isReachedServer = false,
    super.isOutcomeUnknown = true,
    super.isRetrySafe = true,
    super.isUserActionRequired = false,
    super.recoveryAction = "Kith is verifying whether the operation completed on the server to prevent duplicates.",
    super.correlationId,
    super.code = "UNKNOWN_OUTCOME",
    super.originalError,
  });
}
