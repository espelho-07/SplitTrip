/// Base exception for administrative operations.
abstract class AdminException implements Exception {
  final String message;
  final String? code;

  const AdminException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Thrown when the caller does not possess administrative privileges.
class AdminUnauthorizedException extends AdminException {
  const AdminUnauthorizedException([super.message = 'Access denied. You do not possess the required administrative role.'])
      : super(code: 'UNAUTHORIZED');
}

/// Thrown when the required backend table or RPC is not yet deployed or available.
class AdminBackendUnavailableException extends AdminException {
  final String resource;

  const AdminBackendUnavailableException(this.resource, [String? message])
      : super(message ?? 'Backend resource "$resource" is currently unavailable or migration is pending.', code: 'BACKEND_UNAVAILABLE');
}

/// Thrown when an administrative action fails validation (e.g. missing suspension reason).
class AdminValidationException extends AdminException {
  const AdminValidationException(super.message) : super(code: 'VALIDATION_FAILED');
}
