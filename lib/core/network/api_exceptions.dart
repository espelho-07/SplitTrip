class ApiException implements Exception {
  final String message;
  final String code;
  final int statusCode;
  final dynamic details;

  const ApiException({
    required this.message,
    required this.code,
    required this.statusCode,
    this.details,
  });

  String get userFriendlyMessage {
    if (message.isNotEmpty &&
        !message.startsWith('ApiException') &&
        !message.startsWith('Exception:')) {
      return message;
    }
    switch (code) {
      case 'NOT_FOUND':
        return 'No trip or item found. Please verify and try again.';
      case 'NETWORK_ERROR':
        return 'Unable to connect to the server. Please check your internet connection.';
      case 'UNAUTHORIZED':
        return 'Session expired or invalid. Please sign in again.';
      case 'FORBIDDEN':
        return 'You do not have permission to perform this action.';
      case 'CONFLICT':
        return 'This action has already been performed or has conflicts.';
      case 'VALIDATION_ERROR':
        return 'Invalid input provided. Please verify and try again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  @override
  String toString() => message.isNotEmpty ? message : 'ApiException [$code] ($statusCode)';
}

class NetworkException extends ApiException {
  const NetworkException({super.message = 'Unable to connect to the server. Please check your internet connection.'})
      : super(code: 'NETWORK_ERROR', statusCode: 0);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({super.message = 'Session expired or invalid. Please sign in again.'})
      : super(code: 'UNAUTHORIZED', statusCode: 401);
}

class ForbiddenException extends ApiException {
  const ForbiddenException({super.message = 'You do not have permission to perform this action.'})
      : super(code: 'FORBIDDEN', statusCode: 403);
}

class AccountDeletedException extends ApiException {
  const AccountDeletedException({
    super.message = 'This account has been permanently deleted.',
    super.details,
  }) : super(code: 'ACCOUNT_DELETED', statusCode: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException({super.message = 'No trip found with this code. Please check and try again.'})
      : super(code: 'NOT_FOUND', statusCode: 404);
}

class ConflictException extends ApiException {
  const ConflictException({super.message = 'A conflict occurred while processing the request.', super.details})
      : super(code: 'CONFLICT', statusCode: 409);
}

class ValidationException extends ApiException {
  const ValidationException({super.message = 'Validation error occurred. Please check your input.', super.details})
      : super(code: 'VALIDATION_ERROR', statusCode: 400);
}
