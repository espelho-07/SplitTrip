function errorHandler(err, req, res, next) {
  // Never log sensitive tokens or full stack traces with secrets
  const isAppError = err instanceof AppError;
  const status = err.statusCode || 500;
  const code = err.code || (status === 500 ? 'INTERNAL_SERVER_ERROR' : 'API_ERROR');
  
  // Sanitize internal server errors in production to avoid leaking SQL or internal details
  const isProduction = process.env.NODE_ENV === 'production';
  const message = (status >= 500 && isProduction && !isAppError)
    ? 'An unexpected internal server error occurred. Please try again later.'
    : (err.message || 'An unexpected error occurred');

  if (status >= 500) {
    console.error(`[Internal Server Error] ${req.method} ${req.originalUrl}:`, err.message);
  }

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
