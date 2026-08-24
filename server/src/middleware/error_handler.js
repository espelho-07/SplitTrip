function errorHandler(err, req, res, next) {
  console.error('[Error]', err);

  const status = err.statusCode || 500;
  const code = err.code || 'INTERNAL_SERVER_ERROR';
  const message = err.message || 'An unexpected error occurred';

  res.status(status).json({
    error: {
      code,
      message,
      details: err.details || undefined,
    },
  });
}

class AppError extends Error {
  constructor(statusCode, code, message, details) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }

  static badRequest(message, details) {
    return new AppError(400, 'BAD_REQUEST', message, details);
  }

  static unauthorized(message) {
    return new AppError(401, 'UNAUTHORIZED', message);
  }

  static forbidden(message) {
    return new AppError(403, 'FORBIDDEN', message);
  }

  static notFound(message) {
    return new AppError(404, 'NOT_FOUND', message);
  }

  static conflict(message, details) {
    return new AppError(409, 'CONFLICT', message, details);
  }

  static unprocessable(message, details) {
    return new AppError(422, 'UNPROCESSABLE_ENTITY', message, details);
  }
}

module.exports = { errorHandler, AppError };
