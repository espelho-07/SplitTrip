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

class NotFoundException extends ApiException {
  const NotFoundException({super.message = 'The requested resource was not found.'})
      : super(code: 'NOT_FOUND', statusCode: 404);
}

class ConflictException extends ApiException {
  const ConflictException({super.message = 'A conflict occurred while processing the request.', super.details})
      : super(code: 'CONFLICT', statusCode: 409);
}

class ValidationException extends ApiException {
  const ValidationException({super.message = 'Validation error occurred.', super.details})
      : super(code: 'VALIDATION_ERROR', statusCode: 400);
}
