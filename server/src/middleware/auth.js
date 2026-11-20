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
    const deletedSession = db.findOne('deleted_accounts', (d) => d.sessionToken === token || d.anonymousToken === token);
    if (deletedSession) {
      return res.status(403).json({
        error: {
          code: 'ACCOUNT_DELETED',
          message: 'This account has been permanently deleted.',
        },
      });
    }
    return res.status(401).json({
      error: {
        code: 'INVALID_SESSION',
        message: 'Session token is invalid.',
      },
    });
  }

  // Authoritative multi-device check: reject immediately if account was deleted globally
  const isDeleted = db.findOne('deleted_accounts', (d) => d.userId === session.userId || d.account_id === session.userId);
  if (isDeleted) {
    db.delete('sessions', session.id);
    return res.status(403).json({
      error: {
        code: 'ACCOUNT_DELETED',
        message: 'This account has been permanently deleted.',
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
    const isDeletedUser = db.findOne('deleted_accounts', (d) => d.userId === session.userId || d.account_id === session.userId);
    if (isDeletedUser) {
      db.delete('sessions', session.id);
      return res.status(403).json({
        error: {
          code: 'ACCOUNT_DELETED',
          message: 'This account has been permanently deleted.',
        },
      });
    }
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
