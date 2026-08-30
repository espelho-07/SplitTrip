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
    if (clean.length === 12) {
      return `KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}`;
    }
    if (clean.length === 16) {
      return `KITH-${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}-${clean.substring(12, 16)}`;
    }
    return clean ? `KITH-${clean}` : '';
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
    const normalizedKey = this._normalizeRecoveryKey(recoveryKey);
    const recoveryKeyHash = this._hashKey(normalizedKey);
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
        recoveryKey: normalizedKey,
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

    const user = db.findOne('users', (u) => {
      if (u.recoveryKeyHash && candidateHashes.has(u.recoveryKeyHash)) return true;
      if (u.recoveryKey) {
        const uNorm = this._normalizeRecoveryKey(u.recoveryKey);
        const uRaw = String(u.recoveryKey).trim().toUpperCase();
        const uNoSpecial = uRaw.replace(/[\s\-_:\r\n]/g, '');
        const uStripped = uNoSpecial.startsWith('KITH') ? uNoSpecial.substring(4) : uNoSpecial;
        if (
          uNorm === normalizedKey ||
          uRaw === rawClean ||
          uNoSpecial === noSpecial ||
          uStripped === strippedKith
        ) {
          return true;
        }
      }
      if (u.id === rawClean || u.id === recoveryKey.trim()) return true;
      return false;
    });

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
        recoveryKey: user.recoveryKey || normalizedKey,
        anonymousToken: session.token,
        isGuest: user.isGuest,
        email: user.email,
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
        recoveryKey: normalizedKey,
        recoveryKeyHash,
        isGuest: true,
        email: null,
        createdAt: now,
        lastActiveAt: now,
      };
      db.insert('users', user);
    } else {
      const updates = {
        displayName: displayName.trim(),
        lastActiveAt: now,
      };
      if (avatarUrl) updates.avatarUrl = avatarUrl;
      if (normalizedKey && !user.recoveryKey) {
        updates.recoveryKey = normalizedKey;
        updates.recoveryKeyHash = recoveryKeyHash;
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

  loginWithNirniq({ email, displayName, photoUrl, nirniqId, googleId, supabaseUserId, currentGuestUserId }) {
    if (!email || !email.includes('@')) {
      throw AppError.badRequest('A valid Google email or Nirniq Account address is required');
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanNirniqId = nirniqId ? nirniqId.trim() : null;
    const cleanGoogleId = googleId ? googleId.trim() : null;
    const cleanSupabaseUserId = supabaseUserId ? supabaseUserId.trim() : null;
    const now = new Date().toISOString();

    // 1. Check for existing canonical user by nirniqId, googleId, supabaseUserId, or email
    let user = db.findOne('users', (u) => {
      if (cleanNirniqId && (u.nirniqId === cleanNirniqId || u.id === cleanNirniqId)) return true;
      if (cleanGoogleId && u.googleId === cleanGoogleId) return true;
      if (cleanSupabaseUserId && (u.supabaseUserId === cleanSupabaseUserId || u.id === cleanSupabaseUserId)) return true;
      if (u.email && u.email.toLowerCase() === cleanEmail) return true;
      return false;
    });

    const canonicalNirniqId = cleanNirniqId || cleanSupabaseUserId || (cleanGoogleId ? `nrn_${cleanGoogleId}` : `nrn_${crypto.createHash('sha256').update(cleanEmail).digest('hex').substring(0, 16)}`);

    if (user) {
      // Existing canonical user found
      const updates = {
        lastActiveAt: now,
        isGuest: false,
        email: cleanEmail,
      };
      if (!user.nirniqId) updates.nirniqId = canonicalNirniqId;
      if (cleanGoogleId && !user.googleId) updates.googleId = cleanGoogleId;
      if (cleanSupabaseUserId && !user.supabaseUserId) updates.supabaseUserId = cleanSupabaseUserId;
      if (displayName && displayName.trim()) updates.displayName = displayName.trim();
      if (photoUrl && !user.avatarUrl) updates.avatarUrl = photoUrl;
      if (!user.recoveryKeyHash || !user.recoveryKey) {
        const generatedKey = user.recoveryKey || this._generateRecoveryKey();
        updates.recoveryKey = generatedKey;
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
        const generatedKey = guestUser.recoveryKey || this._generateRecoveryKey();
        db.update('users', guestUser.id, {
          email: cleanEmail,
          nirniqId: canonicalNirniqId,
          googleId: cleanGoogleId,
          supabaseUserId: cleanSupabaseUserId,
          displayName: displayName && displayName.trim() ? displayName.trim() : guestUser.displayName,
          avatarUrl: photoUrl || guestUser.avatarUrl,
          recoveryKey: generatedKey,
          recoveryKeyHash: this._hashKey(generatedKey),
          isGuest: false,
          lastActiveAt: now,
        });
        user = db.get('users', guestUser.id);
      } else {
        // Create new permanent canonical user with stable ID and recovery key
        const newId = cleanSupabaseUserId || (cleanGoogleId ? `usr_g_${cleanGoogleId}` : `usr_nrn_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`);
        const generatedKey = this._generateRecoveryKey();
        user = {
          id: newId,
          nirniqId: canonicalNirniqId,
          displayName: displayName && displayName.trim() ? displayName.trim() : cleanEmail.split('@')[0],
          avatarUrl: photoUrl || null,
          googleId: cleanGoogleId,
          supabaseUserId: cleanSupabaseUserId,
          recoveryKey: generatedKey,
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
        nirniqId: user.nirniqId || canonicalNirniqId,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        email: user.email,
        recoveryKey: user.recoveryKey,
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

  loginWithGoogle(params) {
    return this.loginWithNirniq(params);
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

  deleteAccount(userId) {
    if (!userId) {
      throw AppError.badRequest('User ID is required');
    }

    // 1. Delete all user sessions
    const sessions = db.find('sessions', (s) => s.userId === userId);
    for (const s of sessions) {
      db.delete('sessions', s.id);
    }

    // 2. Delete personal expenses
    const personalExpenses = db.find('personal_expenses', (e) => e.userId === userId);
    for (const exp of personalExpenses) {
      db.delete('personal_expenses', exp.id);
    }

    // 3. Delete personal debts
    const personalDebts = db.find('personal_debts', (d) => d.userId === userId);
    for (const debt of personalDebts) {
      db.delete('personal_debts', debt.id);
    }

    // 4. Delete personal repayments
    const personalRepayments = db.find('personal_repayments', (r) => r.userId === userId);
    for (const rep of personalRepayments) {
      db.delete('personal_repayments', rep.id);
    }

    // 5. Delete personal budgets
    const personalBudgets = db.find('personal_budgets', (b) => b.userId === userId);
    for (const b of personalBudgets) {
      db.delete('personal_budgets', b.id);
    }

    // 6. Delete trip memberships
    const tripMembers = db.find('trip_members', (m) => m.userId === userId);
    for (const tm of tripMembers) {
      db.delete('trip_members', tm.id);
    }

    // 7. Delete the user record
    db.delete('users', userId);

    return { success: true, message: 'Account and associated personal/cloud data permanently deleted.' };
  }

  deleteAccountByEmailOrKey(identifier) {
    if (!identifier || typeof identifier !== 'string') {
      throw AppError.badRequest('Email address or Recovery Key is required.');
    }
    const clean = identifier.trim();
    let user = null;

    if (clean.includes('@')) {
      const cleanEmail = clean.toLowerCase();
      user = db.findOne('users', (u) => u.email && u.email.toLowerCase() === cleanEmail);
    } else {
      const keyHash = this._hashKey(clean);
      user = db.findOne('users', (u) => u.recoveryKeyHash === keyHash);
    }

    if (user) {
      return this.deleteAccount(user.id);
    }

    return {
      success: true,
      message: 'Deletion request processed. No active cloud data found for the provided identifier.',
    };
  }

  loginReviewerAccount(email = 'review.nirniq@gmail.com') {
    const cleanEmail = (email || 'review.nirniq@gmail.com').trim().toLowerCase();
    const now = new Date().toISOString();

    let user = db.findOne('users', (u) => u.email && u.email.toLowerCase() === cleanEmail);
    if (!user) {
      const generatedKey = this._generateRecoveryKey();
      user = {
        id: 'usr_play_reviewer_nirniq',
        displayName: 'Google Play Reviewer',
        avatarUrl: 'https://lh3.googleusercontent.com/a/default-user',
        email: cleanEmail,
        googleId: 'google_reviewer_nirniq_001',
        supabaseUserId: 'sub_reviewer_nirniq_001',
        recoveryKeyHash: this._hashKey(generatedKey),
        isGuest: false,
        createdAt: now,
        lastActiveAt: now,
      };
      db.insert('users', user);
    } else {
      db.update('users', user.id, { lastActiveAt: now, isGuest: false });
      user = db.get('users', user.id);
    }

    // Seed realistic reviewer trip and expenses if none exist
    this._seedReviewerDataIfEmpty(user.id);

    const session = this._createSession(user.id);

    return {
      user: {
        id: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        email: user.email,
        googleId: user.googleId,
        supabaseUserId: user.supabaseUserId,
        isGuest: false,
        isLinkedToAccount: true,
        anonymousToken: session.token,
        createdAt: user.createdAt,
      },
      token: session.token,
    };
  }

  _seedReviewerDataIfEmpty(userId) {
    try {
      const existingMemberships = db.find('trip_members', (m) => m.userId === userId);
      if (existingMemberships.length > 0) return; // Already seeded

      const now = new Date().toISOString();
      const tripId = 'trip_goa_reviewer_2026';

      // 1. Create Trip
      const trip = {
        id: tripId,
        name: 'Goa Beach Getaway 🌴',
        description: 'Annual vacation and beach exploration trip with friends',
        joinCode: 'GOA202',
        creatorId: userId,
        currency: 'INR',
        mode: 'split_and_journey',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      };
      db.insert('trips', trip);

      // 2. Members
      const members = [
        { id: `tm_${userId}`, tripId, userId, displayName: 'Google Play Reviewer', role: 'creator', joinedAt: now },
        { id: 'tm_member_priya', tripId, userId: 'usr_priya_demo', displayName: 'Priya Sharma', role: 'member', joinedAt: now },
        { id: 'tm_member_rahul', tripId, userId: 'usr_rahul_demo', displayName: 'Rahul Verma', role: 'member', joinedAt: now },
        { id: 'tm_member_alex', tripId, userId: 'usr_alex_demo', displayName: 'Alex Chen', role: 'member', joinedAt: now },
      ];
      for (const m of members) db.insert('trip_members', m);

      // 3. Trip Expenses
      const exp1Id = 'exp_villa_stay';
      db.insert('expenses', {
        id: exp1Id,
        tripId,
        description: 'Luxury Heritage Villa Booking (3 Nights)',
        amountPaise: 2400000, // ₹24,000
        category: 'Stay',
        paidById: userId,
        splitType: 'EQUAL',
        splitWith: [userId, 'usr_priya_demo', 'usr_rahul_demo', 'usr_alex_demo'],
        createdAt: now,
      });

      const exp2Id = 'exp_shack_dinner';
      db.insert('expenses', {
        id: exp2Id,
        tripId,
        description: 'Curlies Beach Shack Dinner & Drinks',
        amountPaise: 480000, // ₹4,800
        category: 'Food',
        paidById: 'usr_priya_demo',
        splitType: 'EQUAL',
        splitWith: [userId, 'usr_priya_demo', 'usr_rahul_demo', 'usr_alex_demo'],
        createdAt: now,
      });

      // 4. Personal Expenses for reviewer
      db.insert('personal_expenses', {
        id: 'pexp_flight_tickets',
        userId,
        title: 'Mumbai to Goa Flight Tickets',
        amountPaise: 650000, // ₹6,500
        category: 'Travel',
        date: now.split('T')[0],
        notes: 'IndiGo 6E-243',
        createdAt: now,
      });

      db.insert('personal_expenses', {
        id: 'pexp_airport_coffee',
        userId,
        title: 'Blue Tokai Airport Coffee',
        amountPaise: 32000, // ₹320
        category: 'Food & Dining',
        date: now.split('T')[0],
        notes: 'Iced Latte & Croissant',
        createdAt: now,
      });

      // 5. Personal Budget
      db.insert('personal_budgets', {
        id: `pbudg_${userId}`,
        userId,
        monthlyLimitPaise: 5000000, // ₹50,000
        month: now.substring(0, 7),
        createdAt: now,
        updatedAt: now,
      });

      // 6. Personal Debt
      db.insert('personal_debts', {
        id: 'pdebt_alex_lend',
        userId,
        counterpartyName: 'Alex Chen',
        type: 'lent',
        amountPaise: 500000, // ₹5,000
        note: 'Advance for scuba diving gear',
        createdAt: now,
      });

      db.insert('personal_repayments', {
        id: 'prep_alex_part',
        debtId: 'pdebt_alex_lend',
        userId,
        amountPaise: 200000, // ₹2,000 repaid
        date: now,
        note: 'UPI transfer back',
        createdAt: now,
      });
    } catch (_) {}
  }

  updatePaymentInfo(userId, { upiId, upiQr } = {}, realtimeHub = null) {
    const user = db.get('users', userId);
    if (!user) {
      throw AppError.notFound('User not found');
    }
    const normalizedUpi = upiId ? upiId.trim().toLowerCase() : null;
    const now = new Date().toISOString();
    const updates = {
      upiId: normalizedUpi,
      upiQr: upiQr || null,
      updatedAt: now,
    };
    db.update('users', userId, updates);

    // Also update all trip_members for this user so all trips have the new receiving UPI
    const memberships = db.find('trip_members', (m) => m.userId === userId);
    for (const m of memberships) {
      db.update('trip_members', m.id, { upiId: normalizedUpi });
      if (realtimeHub) {
        realtimeHub.broadcastToTrip(m.tripId, 'member_updated', {
          tripId: m.tripId,
          memberId: m.id,
          userId,
          upiId: normalizedUpi,
        });
      }
    }

    return {
      id: user.id,
      displayName: user.displayName,
      upiId: normalizedUpi,
      upiQr: upiQr || null,
    };
  }

  getUserUpi(userId) {
    if (!userId) throw AppError.badRequest('User ID is required');
    const user = db.get('users', userId);
    if (!user) {
      const member = db.findOne('trip_members', (m) => m.userId === userId || m.id === userId);
      return {
        userId,
        displayName: member?.displayName || 'Traveler',
        upiId: member?.upiId || null,
        upiQr: null,
      };
    }
    return {
      userId: user.id,
      displayName: user.displayName,
      upiId: user.upiId || null,
      upiQr: user.upiQr || null,
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
      upiId: user.upiId || null,
      upiQr: user.upiQr || null,
      createdAt: user.createdAt,
    };
  }
}

module.exports = new AuthService();
