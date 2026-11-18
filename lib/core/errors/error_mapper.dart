import 'dart:async';
import 'dart:io';

import '../network/api_exceptions.dart';
import 'app_error.dart';

/// Comprehensive classification of every user activity across SplitTrip.
enum UserActivity {
  // Authentication
  login,
  registration,
  logout,
  passwordReset,
  sessionExpiration,

  // Trip Management
  createTrip,
  joinTrip,
  acceptInvitation,
  rejectInvitation,
  leaveTrip,
  deleteTrip,
  editTrip,
  completeTrip,
  reopenTrip,

  // Participant Management
  addParticipant,
  removeParticipant,
  changeParticipantDetails,
  assignRoles,

  // Expense Management
  addExpense,
  editExpense,
  deleteExpense,
  splitExpense,
  changePayer,
  changeParticipants,
  uploadReceipt,

  // Settlements
  recordPayment,
  confirmPayment,
  editSettlement,
  deleteSettlement,

  // Synchronization
  initialSync,
  backgroundSync,
  manualSync,
  retrySync,
  conflictResolution,
  offlineRecovery,
}

/// Centralized mapper translating raw exceptions into actionable, polite ApplicationError models.
class ErrorMapper {
  ErrorMapper._();

  /// Maps any exception and user activity context into a strongly-typed ApplicationError.
  static ApplicationError map(
    dynamic error, {
    UserActivity? activity,
    bool isSavedLocally = false,
    String? correlationId,
  }) {
    if (error == null) {
      return ServerError(
        userTitle: 'Unexpected response',
        userMessage: 'The application received an empty response. Please try again.',
        isSavedLocally: isSavedLocally,
        correlationId: correlationId,
      );
    }

    if (error is ApplicationError) {
      return error;
    }

    // 1. Network & Timeout Exceptions
    if (error is SocketException ||
        error is NetworkException ||
        error is TimeoutException ||
        _isNetworkPattern(error.toString())) {
      return _mapNetworkError(error, activity, isSavedLocally, correlationId);
    }

    // 2. HTTP / API Exceptions
    if (error is ApiException) {
      return _mapApiException(error, activity, isSavedLocally, correlationId);
    }

    // 3. Validation / Format / Argument Errors
    if (error is ArgumentError || error is FormatException) {
      return ValidationError(
        userTitle: 'Check your details',
        userMessage: error is ArgumentError ? error.message.toString() : 'Some fields contain invalid formatting. Please verify.',
        actionLabel: 'Review Fields',
        isSavedLocally: isSavedLocally,
        isReachedServer: false,
        isRetrySafe: true,
        isUserActionRequired: true,
        recoveryAction: 'Correct the invalid values and try again.',
        correlationId: correlationId,
        originalError: error,
      );
    }

    // 4. Default Fallback
    return ServerError(
      userTitle: 'Action could not be completed',
      userMessage: isSavedLocally
          ? 'Your changes are safe on this device. We will update the server when possible.'
          : 'We encountered an unexpected issue completing this request. Please try again.',
      actionLabel: 'Retry',
      isSavedLocally: isSavedLocally,
      isReachedServer: false,
      isOutcomeUnknown: false,
      isRetrySafe: true,
      correlationId: correlationId,
      originalError: error,
    );
  }

  static bool _isNetworkPattern(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network connection failed') ||
        lower.contains('network_error') ||
        lower.contains('clientexception') ||
        lower.contains('unable to reach server') ||
        lower.contains('connection refused') ||
        lower.contains('connection timed out');
  }

  static ApplicationError _mapNetworkError(
    dynamic error,
    UserActivity? activity,
    bool isSavedLocally,
    String? correlationId,
  ) {
    switch (activity) {
      case UserActivity.joinTrip:
      case UserActivity.acceptInvitation:
        return NetworkError(
          userTitle: "You're offline",
          userMessage: "An internet connection is required to verify and join this trip. Connect to the internet and try again.",
          actionLabel: "Retry Join",
          isSavedLocally: false,
          isReachedServer: false,
          isRetrySafe: true,
          isUserActionRequired: true,
          recoveryAction: "Turn on Wi-Fi or mobile data, then tap Retry Join.",
          correlationId: correlationId,
          originalError: error,
        );

      case UserActivity.addExpense:
      case UserActivity.editExpense:
      case UserActivity.deleteExpense:
      case UserActivity.createTrip:
        return SynchronizationError(
          userTitle: "Saved on device",
          userMessage: "Your changes were saved locally. They will automatically sync to the group when you're back online.",
          actionLabel: "Got It",
          isSavedLocally: true,
          isReachedServer: false,
          isRetrySafe: true,
          isUserActionRequired: false,
          recoveryAction: "No action required. Kith will automatically sync in the background.",
          correlationId: correlationId,
          originalError: error,
        );

      case UserActivity.recordPayment:
      case UserActivity.confirmPayment:
        return UnknownOutcomeError(
          userTitle: "Checking payment status",
          userMessage: "Network connection was interrupted while recording payment. Checking payment status before retrying.",
          actionLabel: "Check Status",
          isSavedLocally: true,
          isReachedServer: false,
          isOutcomeUnknown: true,
          isRetrySafe: true,
          isUserActionRequired: false,
          recoveryAction: "Kith is checking whether the payment reached the group to avoid duplicate records.",
          correlationId: correlationId,
          originalError: error,
        );

      default:
        return NetworkError(
          userTitle: "You're offline",
          userMessage: isSavedLocally
              ? "Your changes are safe on this device. They will sync automatically when you're back online."
              : "Unable to reach the server. Please check your internet connection and try again.",
          actionLabel: "Retry",
          isSavedLocally: isSavedLocally,
          isReachedServer: false,
          isRetrySafe: true,
          isUserActionRequired: !isSavedLocally,
          recoveryAction: "Check your internet connection and retry.",
          correlationId: correlationId,
          originalError: error,
        );
    }
  }

  static ApplicationError _mapApiException(
    ApiException error,
    UserActivity? activity,
    bool isSavedLocally,
    String? correlationId,
  ) {
    if (error is UnauthorizedException || error.statusCode == 401) {
      return AuthenticationError(
        userTitle: "Session expired",
        userMessage: "Your security session has expired. Please sign in or use your recovery key to continue syncing.",
        actionLabel: "Sign In",
        isSavedLocally: isSavedLocally,
        isReachedServer: true,
        correlationId: correlationId,
        originalError: error,
      );
    }

    if (error is ForbiddenException || error.statusCode == 403) {
      return AuthorizationError(
        userTitle: "Access unavailable",
        userMessage: activity == UserActivity.joinTrip
            ? "You cannot access this trip. The invitation code may be invalid or restricted."
            : "You don't have permission to perform this action on this trip.",
        actionLabel: "Back to Trips",
        isSavedLocally: false,
        isReachedServer: true,
        correlationId: correlationId,
        originalError: error,
      );
    }

    if (error is NotFoundException || error.statusCode == 404) {
      return ValidationError(
        userTitle: activity == UserActivity.joinTrip ? "Trip not found" : "Record not found",
        userMessage: activity == UserActivity.joinTrip
            ? "No trip was found matching this invite code. Please check the code with your host."
            : "The requested trip record or expense is no longer available.",
        actionLabel: activity == UserActivity.joinTrip ? "Check Code" : "Refresh",
        isSavedLocally: false,
        isReachedServer: true,
        isRetrySafe: false,
        isUserActionRequired: true,
        recoveryAction: "Verify the code or ID and try again.",
        correlationId: correlationId,
        originalError: error,
      );
    }

    if (error.statusCode == 409 || error.code == 'CONFLICT') {
      return ConflictError(
        userTitle: "Update conflict detected",
        userMessage: "Another trip member modified this record while you were making changes. We have updated your view.",
        actionLabel: "Review Latest",
        isSavedLocally: isSavedLocally,
        isReachedServer: true,
        isRetrySafe: false,
        isUserActionRequired: true,
        recoveryAction: "Review the updated data and re-apply your changes if needed.",
        correlationId: correlationId,
        originalError: error,
      );
    }

    return ServerError(
      userTitle: "Server temporarily unavailable",
      userMessage: isSavedLocally
          ? "We couldn't reach the server right now. Your locally saved changes remain available."
          : "The server encountered an issue processing your request. Please try again shortly.",
      actionLabel: "Retry",
      isSavedLocally: isSavedLocally,
      isReachedServer: false,
      correlationId: correlationId,
      originalError: error,
    );
  }
}
