const crypto = require('crypto');
const { db } = require('../db/database');
const { AppError } = require('../middleware/error_handler');

class AuthService {
  _normalizeRecoveryKey(rawKey) {
    if (!rawKey) return '';
    const trimmed = rawKey.trim().toUpperCase();
    let clean = trimmed.replace(/[\s\-_:]/g, '');
    if (clean.startsWith('KITH')) {
      clean = clean.substring(4);
    }
    if (clean.length === 8) {
      return `KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}`;
    }
    return trimmed;
  }

  _hashKey(key) {
    const normalized = this._normalizeRecoveryKey(key);
    return crypto.createHash('sha256').update(normalized).digest('hex');
  }

  _generateRecoveryKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let p1 = '';
    let p2 = '';
    for (let i = 0; i < 4; i++) {
      p1 += chars.charAt(crypto.randomInt(0, chars.length));
      p2 += chars.charAt(crypto.randomInt(0, chars.length));
    }
    return `KITH-${p1}-${p2}`;
  }

  _createSession(userId) {
    const token = `kith_sess_${crypto.randomBytes(24).toString('hex')}`;
    const session = {
      id: crypto.randomUUID(),
      token,
      userId,
      createdAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
    };
    db.insert('sessions', session);
    return session;
  }

  createGuest({ displayName, avatarUrl }) {
    if (!displayName || !displayName.trim()) {
      throw AppError.badRequest('Display name is required');
    }

    const trimmedName = displayName.trim();
    const recoveryKey = this._generateRecoveryKey();
    const recoveryKeyHash = this._hashKey(recoveryKey);
    const userId = `usr_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`;

    const user = {
      id: userId,
      displayName: trimmedName,
      avatarUrl: avatarUrl || null,
      recoveryKeyHash,
      isGuest: true,
      email: null,
      createdAt: new Date().toISOString(),
      lastActiveAt: new Date().toISOString(),
    };

    db.insert('users', user);
    const session = this._createSession(userId);

    return {
      user: {
        id: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        recoveryKey, // Only returned at creation time or recovery
        anonymousToken: session.token,
        isGuest: user.isGuest,
        createdAt: user.createdAt,
      },
      token: session.token,
    };
  }

  recoverGuest({ recoveryKey }) {
    if (!recoveryKey || !recoveryKey.trim()) {
      throw AppError.badRequest('Recovery key is required');
    }

    const normalizedKey = this._normalizeRecoveryKey(recoveryKey);
    const candidateHashes = new Set([
      this._hashKey(recoveryKey),
      this._hashKey(normalizedKey),
      crypto.createHash('sha256').update(recoveryKey.trim().toUpperCase()).digest('hex'),
      crypto.createHash('sha256').update(recoveryKey.trim().toUpperCase().replace(/[\s\-_:]/g, '')).digest('hex'),
    ]);

    const user = db.findOne('users', (u) => candidateHashes.has(u.recoveryKeyHash));

    if (!user) {
      throw AppError.unauthorized('Invalid recovery key. No account matches this key.');
    }

    const session = this._createSession(user.id);
    db.update('users', user.id, { lastActiveAt: new Date().toISOString() });

    return {
      user: {
        id: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        recoveryKey: normalizedKey,
        anonymousToken: session.token,
        isGuest: user.isGuest,
        createdAt: user.createdAt,
      },
      token: session.token,
    };
  }

  syncGuest({ id, displayName, recoveryKey, token, avatarUrl }) {
    if (!id || !displayName) {
      throw AppError.badRequest('User ID and display name are required');
    }

    const normalizedKey = recoveryKey ? this._normalizeRecoveryKey(recoveryKey) : null;
    const recoveryKeyHash = normalizedKey ? this._hashKey(normalizedKey) : null;
    const now = new Date().toISOString();

    let user = db.get('users', id);
    if (!user) {
      user = {
        id,
        displayName: displayName.trim(),
        avatarUrl: avatarUrl || null,
        recoveryKeyHash,
        isGuest: true,
        email: null,
        createdAt: now,
        lastActiveAt: now,
      };
      db.insert('users', user);
    } else {
      const updates = { lastActiveAt: now };
      if (recoveryKeyHash && !user.recoveryKeyHash) {
        updates.recoveryKeyHash = recoveryKeyHash;
      }
      if (displayName && displayName.trim()) {
        updates.displayName = displayName.trim();
      }
      db.update('users', id, updates);
      user = db.get('users', id);
    }

    if (token) {
      const existingSession = db.findOne('sessions', (s) => s.token === token);
      if (!existingSession) {
        db.insert('sessions', {
          id: crypto.randomUUID(),
          token,
          userId: id,
          createdAt: now,
          expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
        });
      }
    }

    return {
      success: true,
      user: {
        id: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        recoveryKey: normalizedKey,
        isGuest: user.isGuest,
        createdAt: user.createdAt,
      },
    };
  }

  getProfile(userId) {
    const user = db.get('users', userId);
    if (!user) {
      throw AppError.notFound('User not found');
    }
    return {
      id: user.id,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      isGuest: user.isGuest,
      email: user.email,
      createdAt: user.createdAt,
    };
  }
}

module.exports = new AuthService();
