const crypto = require('crypto');
const { db } = require('../db/database');
const { AppError } = require('../middleware/error_handler');

class AuthService {
  _normalizeRecoveryKey(rawKey) {
    if (!rawKey) return '';
    const trimmed = String(rawKey).trim().toUpperCase();
    let clean = trimmed.replace(/[\s\-_:\r\n]/g, '');
    if (clean.startsWith('KITH')) {
      clean = clean.substring(4);
    }
    if (clean.length === 8) {
      return `KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}`;
    }
    return clean ? (clean.length > 8 ? `KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}` : clean) : '';
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
    if (!recoveryKey || !String(recoveryKey).trim()) {
      throw AppError.badRequest('Recovery key is required');
    }

    const normalizedKey = this._normalizeRecoveryKey(recoveryKey);
    const rawClean = String(recoveryKey).trim().toUpperCase();
    const noSpecial = rawClean.replace(/[\s\-_:\r\n]/g, '');
    const strippedKith = noSpecial.startsWith('KITH') ? noSpecial.substring(4) : noSpecial;

    const candidateHashes = new Set([
      this._hashKey(recoveryKey),
      this._hashKey(normalizedKey),
      crypto.createHash('sha256').update(rawClean).digest('hex'),
      crypto.createHash('sha256').update(noSpecial).digest('hex'),
      crypto.createHash('sha256').update(normalizedKey).digest('hex'),
      crypto.createHash('sha256').update(`KITH-${strippedKith}`).digest('hex'),
      crypto.createHash('sha256').update(strippedKith).digest('hex'),
    ]);

    const user = db.findOne('users', (u) => u.recoveryKeyHash && candidateHashes.has(u.recoveryKeyHash));

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
      if (recoveryKeyHash) {
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

  linkAccount(userId, { email, displayName }) {
    if (!userId) {
      throw AppError.unauthorized('User ID required');
    }
    if (!email || !email.includes('@')) {
      throw AppError.badRequest('A valid email address is required');
    }

    let user = db.get('users', userId);
    if (!user) {
      user = {
        id: userId,
        displayName: displayName ? displayName.trim() : 'Traveler',
        avatarUrl: null,
        recoveryKeyHash: null,
        isGuest: false,
        email: email.trim().toLowerCase(),
        createdAt: new Date().toISOString(),
        lastActiveAt: new Date().toISOString(),
      };
      db.insert('users', user);
    } else {
      const updates = {
        email: email.trim().toLowerCase(),
        isGuest: false,
        lastActiveAt: new Date().toISOString(),
      };
      if (displayName && displayName.trim()) {
        updates.displayName = displayName.trim();
      }
      db.update('users', userId, updates);
      user = db.get('users', userId);
    }

    return {
      user: {
        id: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        email: user.email,
        isGuest: user.isGuest,
        isLinkedToAccount: true,
        createdAt: user.createdAt,
      },
    };
  }

  loginWithGoogle({ email, displayName, photoUrl, googleId, supabaseUserId, currentGuestUserId }) {
    if (!email || !email.includes('@')) {
      throw AppError.badRequest('A valid Google email address is required');
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanGoogleId = googleId ? googleId.trim() : null;
    const cleanSupabaseUserId = supabaseUserId ? supabaseUserId.trim() : null;
    const now = new Date().toISOString();

    // 1. Check for existing canonical user by googleId, supabaseUserId, or email
    let user = db.findOne('users', (u) => {
      if (cleanGoogleId && u.googleId === cleanGoogleId) return true;
      if (cleanSupabaseUserId && (u.supabaseUserId === cleanSupabaseUserId || u.id === cleanSupabaseUserId)) return true;
      if (u.email && u.email.toLowerCase() === cleanEmail) return true;
      return false;
    });

    if (user) {
      // Existing canonical user found
      const updates = {
        lastActiveAt: now,
        isGuest: false,
        email: cleanEmail,
      };
      if (cleanGoogleId && !user.googleId) updates.googleId = cleanGoogleId;
      if (cleanSupabaseUserId && !user.supabaseUserId) updates.supabaseUserId = cleanSupabaseUserId;
      if (displayName && displayName.trim()) updates.displayName = displayName.trim();
      if (photoUrl && !user.avatarUrl) updates.avatarUrl = photoUrl;
      if (!user.recoveryKeyHash) {
        const generatedKey = this._generateRecoveryKey();
        updates.recoveryKeyHash = this._hashKey(generatedKey);
      }

      db.update('users', user.id, updates);
      user = db.get('users', user.id);

      // If guest session was passed and is distinct from canonical user, migrate local data
      if (currentGuestUserId && currentGuestUserId !== user.id) {
        this._migrateGuestData(currentGuestUserId, user.id);
      }
    } else {
      // 2. Check if we should upgrade the current active guest user
      const guestUser = currentGuestUserId ? db.get('users', currentGuestUserId) : null;
      if (guestUser && guestUser.isGuest) {
        const generatedKey = guestUser.recoveryKeyHash ? null : this._generateRecoveryKey();
        db.update('users', guestUser.id, {
          email: cleanEmail,
          googleId: cleanGoogleId,
          supabaseUserId: cleanSupabaseUserId,
          displayName: displayName && displayName.trim() ? displayName.trim() : guestUser.displayName,
          avatarUrl: photoUrl || guestUser.avatarUrl,
          recoveryKeyHash: guestUser.recoveryKeyHash || (generatedKey ? this._hashKey(generatedKey) : null),
          isGuest: false,
          lastActiveAt: now,
        });
        user = db.get('users', guestUser.id);
      } else {
        // Create new permanent canonical user with stable ID and recovery key
        const newId = cleanSupabaseUserId || (cleanGoogleId ? `usr_g_${cleanGoogleId}` : `usr_g_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`);
        const generatedKey = this._generateRecoveryKey();
        user = {
          id: newId,
          displayName: displayName && displayName.trim() ? displayName.trim() : cleanEmail.split('@')[0],
          avatarUrl: photoUrl || null,
          googleId: cleanGoogleId,
          supabaseUserId: cleanSupabaseUserId,
          recoveryKeyHash: this._hashKey(generatedKey),
          isGuest: false,
          email: cleanEmail,
          createdAt: now,
          lastActiveAt: now,
        };
        db.insert('users', user);
      }
    }

    const session = this._createSession(user.id);

    return {
      user: {
        id: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        email: user.email,
        googleId: user.googleId,
        supabaseUserId: user.supabaseUserId,
        isGuest: user.isGuest,
        isLinkedToAccount: true,
        anonymousToken: session.token,
        createdAt: user.createdAt,
      },
      token: session.token,
    };
  }

  _migrateGuestData(guestUserId, canonicalUserId) {
    try {
      // Migrate personal expenses
      const personalExpenses = db.find('personal_expenses', (e) => e.userId === guestUserId);
      for (const exp of personalExpenses) {
        db.update('personal_expenses', exp.id, { userId: canonicalUserId });
      }

      // Migrate personal debts
      const personalDebts = db.find('personal_debts', (d) => d.userId === guestUserId);
      for (const debt of personalDebts) {
        db.update('personal_debts', debt.id, { userId: canonicalUserId });
      }

      // Migrate personal repayments
      const personalRepayments = db.find('personal_repayments', (r) => r.userId === guestUserId);
      for (const rep of personalRepayments) {
        db.update('personal_repayments', rep.id, { userId: canonicalUserId });
      }

      // Migrate personal budgets
      const personalBudgets = db.find('personal_budgets', (b) => b.userId === guestUserId);
      for (const b of personalBudgets) {
        db.update('personal_budgets', b.id, { userId: canonicalUserId });
      }

      // Migrate trips created by guest
      const trips = db.find('trips', (t) => t.creatorId === guestUserId || t.createdBy === guestUserId);
      for (const t of trips) {
        db.update('trips', t.id, { creatorId: canonicalUserId, createdBy: canonicalUserId });
      }

      // Migrate trip members
      const members = db.find('trip_members', (m) => m.userId === guestUserId);
      for (const m of members) {
        db.update('trip_members', m.id, { userId: canonicalUserId });
      }

      // Migrate trip expenses paidById
      const expenses = db.find('expenses', (e) => e.paidById === guestUserId);
      for (const exp of expenses) {
        db.update('expenses', exp.id, { paidById: canonicalUserId });
      }

      // Migrate trip journey moments
      const moments = db.find('trip_journey_moments', (m) => m.userId === guestUserId || m.creatorId === guestUserId);
      for (const mom of moments) {
        db.update('trip_journey_moments', mom.id, { userId: canonicalUserId, creatorId: canonicalUserId });
      }

      // Migrate activity logs
      const logs = db.find('activity_logs', (l) => l.userId === guestUserId);
      for (const log of logs) {
        db.update('activity_logs', log.id, { userId: canonicalUserId });
      }
    } catch (e) {
      console.error('[AuthService] Guest data migration warning:', e.message);
    }
  }

  logout(token) {
    if (!token) return { success: true };
    const cleanToken = token.startsWith('Bearer ') ? token.substring(7).trim() : token.trim();
    const session = db.findOne('sessions', (s) => s.token === cleanToken);
    if (session) {
      db.delete('sessions', session.id);
    }
    return { success: true };
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
