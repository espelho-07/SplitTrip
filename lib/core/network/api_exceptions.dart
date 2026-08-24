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

  @override
  String toString() => 'ApiException [$code] ($statusCode): $message';
}

class NetworkException extends ApiException {
  const NetworkException({String message = 'Unable to connect to the server. Please check your internet connection.'})
      : super(message: message, code: 'NETWORK_ERROR', statusCode: 0);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({String message = 'Session expired or invalid. Please sign in again.'})
      : super(message: message, code: 'UNAUTHORIZED', statusCode: 401);
}

class ForbiddenException extends ApiException {
  const ForbiddenException({String message = 'You do not have permission to perform this action.'})
      : super(message: message, code: 'FORBIDDEN', statusCode: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException({String message = 'The requested resource was not found.'})
      : super(message: message, code: 'NOT_FOUND', statusCode: 404);
}

class ConflictException extends ApiException {
  const ConflictException({String message = 'A conflict occurred while processing the request.', dynamic details})
      : super(message: message, code: 'CONFLICT', statusCode: 409, details: details);
}

class ValidationException extends ApiException {
  const ValidationException({String message = 'Validation error occurred.', dynamic details})
      : super(message: message, code: 'VALIDATION_ERROR', statusCode: 400, details: details);
}
