import 'dart:io';
import '../network/api_exceptions.dart';
import '../errors/app_error.dart';
import '../errors/error_mapper.dart';

/// Centralized utility to format raw exceptions and API error strings
/// into clear, polite, and user-friendly messages for the UI.
class KithErrorFormatter {
  KithErrorFormatter._();

  /// Converts any exception or error object into a clean, user-facing explanation.
  /// Maps an error to a strongly-typed ApplicationError with userTitle, recoveryAction, and retry guidance.
  static ApplicationError mapToApplicationError(
    dynamic error, {
    UserActivity? activity,
    bool isSavedLocally = false,
    String? correlationId,
  }) {
    return ErrorMapper.map(
      error,
      activity: activity,
      isSavedLocally: isSavedLocally,
      correlationId: correlationId,
    );
  }

  /// Converts any exception or error object into a clean, user-facing explanation.
  static String format(dynamic error, {String? context}) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    if (error is ApiException) {
      return _formatApiException(error, context: context);
    }

    if (error is SocketException) {
      if (context == 'join' || context == 'trip_join') {
        return "You're offline. Reconnect to the internet to see and join this trip.";
      }
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    final raw = error.toString().trim();

    // Clean Exception prefixes
    String cleaned = raw;
    if (cleaned.startsWith('Exception: ')) {
      cleaned = cleaned.substring(11).trim();
    } else if (cleaned.startsWith('StateError: ')) {
      cleaned = cleaned.substring(12).trim();
    } else if (cleaned.startsWith('ArgumentError: ')) {
      cleaned = cleaned.substring(15).trim();
    }

    final lower = cleaned.toLowerCase();

    // Handle Network / Socket / Offline patterns
    if (cleaned.contains('SocketException') ||
        cleaned.contains('Failed host lookup') ||
        cleaned.contains('Network connection failed') ||
        cleaned.contains('NETWORK_ERROR') ||
        cleaned.contains('ClientException') ||
        lower.contains('offline') ||
        lower.contains('unable to reach server')) {
      if (context == 'join' || context == 'trip_join' || lower.contains('join')) {
        return "You're offline. Reconnect to the internet to see and join this trip.";
      }
      return "You're offline. Please check your internet connection and try again.";
    }

    // Handle NotFound / Not found patterns
    if (cleaned.contains('NOT_FOUND') ||
        lower.contains('trip not found') ||
        lower.contains('not found') ||
        cleaned.contains('404')) {
      if (context == 'join' || context == 'trip_join') {
        return 'This trip does not exist. Check the code and try again.';
      }
      if (lower.contains('trip') || lower.contains('code')) {
        return 'No trip found for this invite code. Please check the code and try again.';
      }
      return 'The requested item was not found. Please try again.';
    }

    // Strip technical brackets like ApiException [XXX] (YYY):
    final apiRegex = RegExp(r'ApiException\s*\[[^\]]+\]\s*\(\d+\):\s*(.*)');
    final match = apiRegex.firstMatch(cleaned);
    if (match != null && match.group(1) != null) {
      final inner = match.group(1)!.trim();
      if (inner.isNotEmpty && !inner.toLowerCase().contains('validation error') && !inner.toLowerCase().contains('not found')) {
        return inner;
      }
      cleaned = inner.isNotEmpty ? inner : cleaned;
    }

    // Handle Validation / Conflict
    if (cleaned.contains('VALIDATION_ERROR') || lower.contains('validation error')) {
      return 'Invalid details entered. Please verify and try again.';
    }
    if (cleaned.contains('CONFLICT') || lower.contains('already a member')) {
      return 'You are already a member of this trip.';
    }

    if (cleaned.isNotEmpty && !cleaned.contains('ApiException')) {
      return cleaned;
    }

    return 'Something went wrong. Please try again.';
  }

  static String _formatApiException(ApiException e, {String? context}) {
    if (e is NotFoundException || e.code == 'NOT_FOUND' || e.statusCode == 404) {
      if (e.message.isNotEmpty &&
          e.message != 'The requested resource was not found.' &&
          e.message != 'Trip not found' &&
          !e.message.contains('ApiException')) {
        return e.message;
      }
      if (context == 'join' || context == 'trip_join') {
        return 'This trip does not exist. Check the code and try again.';
      }
      return 'No trip found for this invite code. Please check the code and try again.';
    }

    if (e is NetworkException || e.code == 'NETWORK_ERROR' || e.statusCode == 0) {
      if (context == 'join' || context == 'trip_join' || e.message.toLowerCase().contains('join')) {
        return "You're offline. Reconnect to the internet to see and join this trip.";
      }
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    if (e is UnauthorizedException || e.code == 'UNAUTHORIZED' || e.statusCode == 401) {
      return 'Session expired or invalid. Please sign in again.';
    }

    if (e is ForbiddenException || e.code == 'FORBIDDEN' || e.statusCode == 403) {
      return 'You do not have permission to perform this action.';
    }

    if (e is ConflictException || e.code == 'CONFLICT' || e.statusCode == 409) {
      if (e.message.isNotEmpty && !e.message.contains('ApiException')) {
        return e.message;
      }
      return 'This action has already been processed or is in conflict.';
    }

    if (e is ValidationException || e.code == 'VALIDATION_ERROR' || e.statusCode == 400) {
      if (e.message.isNotEmpty && !e.message.contains('ApiException')) {
        return e.message;
      }
      return 'Invalid request details. Please check your input.';
    }

    if (e.message.isNotEmpty && !e.message.contains('ApiException')) {
      return e.message;
    }

    return 'An error occurred while connecting to the server. Please try again.';
  }
}
