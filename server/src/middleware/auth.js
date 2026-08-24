const { db } = require('../db/database');

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: {
        code: 'UNAUTHORIZED',
        message: 'Missing or invalid Authorization header. Expected Bearer token.',
      },
    });
  }

  const token = authHeader.substring(7).trim();
  const session = db.findOne('sessions', (s) => s.token === token);
  if (!session) {
    return res.status(401).json({
      error: {
        code: 'INVALID_SESSION',
        message: 'Session token is invalid.',
      },
    });
  }

  if (session.expiresAt && new Date(session.expiresAt) < new Date()) {
    return res.status(401).json({
      error: {
        code: 'SESSION_EXPIRED',
        message: 'Session has expired. Please sign in again.',
      },
    });
  }

  const user = db.get('users', session.userId);
  if (!user) {
    return res.status(401).json({
      error: {
        code: 'USER_NOT_FOUND',
        message: 'Authenticated user profile not found.',
      },
    });
  }

  // Attach authenticated user to request
  req.user = user;
  req.session = session;
  next();
}

module.exports = { authMiddleware };
