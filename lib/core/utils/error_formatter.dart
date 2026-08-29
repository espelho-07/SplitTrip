import 'dart:io';
import '../network/api_exceptions.dart';

/// Centralized utility to format raw exceptions and API error strings
/// into clear, polite, and user-friendly messages for the UI.
class KithErrorFormatter {
  KithErrorFormatter._();

  /// Converts any exception or error object into a clean, user-facing explanation.
  static String format(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    if (error is ApiException) {
      return _formatApiException(error);
    }

    if (error is SocketException) {
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

    // Handle NotFound / Not found patterns
    if (cleaned.contains('NOT_FOUND') ||
        cleaned.toLowerCase().contains('trip not found') ||
        cleaned.toLowerCase().contains('not found') ||
        cleaned.contains('404')) {
      return 'No trip found for this invite code. Please check the code and try again.';
    }

    // Handle Network / Socket / Offline patterns
    if (cleaned.contains('SocketException') ||
        cleaned.contains('Failed host lookup') ||
        cleaned.contains('Network connection failed') ||
        cleaned.contains('NETWORK_ERROR') ||
        cleaned.contains('ClientException')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }

    // Handle Validation / Conflict
    if (cleaned.contains('VALIDATION_ERROR') || cleaned.contains('Validation error')) {
      return 'Invalid details entered. Please verify and try again.';
    }
    if (cleaned.contains('CONFLICT') || cleaned.contains('already a member')) {
      return 'You are already a member of this trip.';
    }

    // Strip technical brackets like ApiException [XXX] (YYY):
    final apiRegex = RegExp(r'ApiException\s*\[[^\]]+\]\s*\(\d+\):\s*(.*)');
    final match = apiRegex.firstMatch(cleaned);
    if (match != null && match.group(1) != null) {
      final inner = match.group(1)!.trim();
      if (inner.isNotEmpty) return inner;
    }

    if (cleaned.isNotEmpty && !cleaned.contains('ApiException')) {
      return cleaned;
    }

    return 'Something went wrong. Please try again.';
  }

  static String _formatApiException(ApiException e) {
    if (e is NotFoundException || e.code == 'NOT_FOUND' || e.statusCode == 404) {
      if (e.message.isNotEmpty &&
          e.message != 'The requested resource was not found.' &&
          e.message != 'Trip not found' &&
          !e.message.contains('ApiException')) {
        return e.message;
      }
      return 'No trip found for this invite code. Please check the code and try again.';
    }

    if (e is NetworkException || e.code == 'NETWORK_ERROR' || e.statusCode == 0) {
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
