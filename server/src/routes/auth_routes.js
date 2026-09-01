const express = require('express');
const authService = require('../services/auth_service');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// In-memory rate limiting map for recovery endpoint
const recoveryAttempts = new Map();

function recoveryRateLimiter(req, res, next) {
  const ip = req.ip || req.connection.remoteAddress || 'unknown';
  const now = Date.now();
  const windowMs = 15 * 60 * 1000; // 15 minutes
  const maxAttempts = 10;

  const record = recoveryAttempts.get(ip) || { count: 0, resetTime: now + windowMs };

  if (now > record.resetTime) {
    record.count = 0;
    record.resetTime = now + windowMs;
  }

  if (record.count >= maxAttempts) {
    const retryAfterSec = Math.ceil((record.resetTime - now) / 1000);
    return res.status(429).json({
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: `Too many recovery attempts. Please try again after ${retryAfterSec} seconds.`,
      },
    });
  }

  record.count += 1;
  recoveryAttempts.set(ip, record);
  next();
}

// POST /api/auth/guest - Create anonymous guest session
router.post('/guest', (req, res, next) => {
  try {
    const { displayName, avatarUrl } = req.body;
    const result = authService.createGuest({ displayName, avatarUrl });
    res.status(201).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/recover - Recover session across devices via recovery key with rate limiter
router.post('/recover', recoveryRateLimiter, (req, res, next) => {
  try {
    const { recoveryKey } = req.body;
    const result = authService.recoverGuest({ recoveryKey });
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/sync-guest - Sync local guest registration & recovery key to server
router.post('/sync-guest', (req, res, next) => {
  try {
    const result = authService.syncGuest(req.body);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/link - Link guest account to email and permanent credentials
router.post('/link', authMiddleware, (req, res, next) => {
  try {
    const { email, displayName } = req.body;
    const result = authService.linkAccount(req.user.id, { email, displayName });
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/nirniq - Authenticate or canonicalize Nirniq Account identity
router.post('/nirniq', (req, res, next) => {
  try {
    const { email, displayName, photoUrl, nirniqId, googleId, supabaseUserId, currentGuestUserId } = req.body;
    const result = authService.loginWithNirniq({
      email,
      displayName,
      photoUrl,
      nirniqId,
      googleId,
      supabaseUserId,
      currentGuestUserId,
    });
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/google - Backward compatible alias for Google identity provider
router.post('/google', (req, res, next) => {
  try {
    const { email, displayName, photoUrl, nirniqId, googleId, supabaseUserId, currentGuestUserId } = req.body;
    const result = authService.loginWithNirniq({
      email,
      displayName,
      photoUrl,
      nirniqId,
      googleId,
      supabaseUserId,
      currentGuestUserId,
    });
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/logout - Invalidate session token
router.post('/logout', (req, res, next) => {
  try {
    const token = req.headers.authorization;
    const result = authService.logout(token);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// DELETE /api/auth/account - Permanently delete account and associated cloud data
router.delete('/account', authMiddleware, (req, res, next) => {
  try {
    const result = authService.deleteAccount(req.user.id);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/delete-account - Fallback endpoint for account deletion
router.post('/delete-account', authMiddleware, (req, res, next) => {
  try {
    const result = authService.deleteAccount(req.user.id);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/reviewer-login - Pre-authenticated Play Store Reviewer Login with seeded environment
router.post('/reviewer-login', (req, res, next) => {
  try {
    const { email } = req.body || {};
    const result = authService.loginReviewerAccount(email || 'review.nirniq@gmail.com');
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/web-delete-request - Public Web Data Deletion Request Endpoint (Email or Recovery Key)
router.post('/web-delete-request', (req, res, next) => {
  try {
    const { identifier } = req.body || {};
    const result = authService.deleteAccountByEmailOrKey(identifier);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// GET /api/auth/me - Current authenticated user profile
router.get('/me', authMiddleware, (req, res, next) => {
  try {
    const profile = authService.getProfile(req.user.id);
    res.status(200).json({ data: profile });
  } catch (e) {
    next(e);
  }
});

// PUT & POST /api/auth/payment - Update user's receiving UPI ID and QR code
function handleUpdatePayment(req, res, next) {
  try {
    const { upiId, upiQr } = req.body || {};
    const { realtimeHub } = require('../realtime/websocket_hub');
    const result = authService.updatePaymentInfo(req.user.id, { upiId, upiQr }, realtimeHub);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
}

router.put('/payment', authMiddleware, handleUpdatePayment);
router.post('/payment', authMiddleware, handleUpdatePayment);

// GET /api/auth/users/:userId/upi - Lookup a trip member's configured receiving UPI ID
router.get('/users/:userId/upi', authMiddleware, (req, res, next) => {
  try {
    const result = authService.getUserUpi(req.params.userId);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

router.get('/upi/:userId', authMiddleware, (req, res, next) => {
  try {
    const result = authService.getUserUpi(req.params.userId);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/fcm-token — Register/update FCM token for push notifications
router.post('/fcm-token', (req, res, next) => {
  try {
    const { token, deviceId, platform, userId: bodyUserId } = req.body || {};
    if (!token) return res.status(400).json({ error: { code: 'MISSING_TOKEN', message: 'FCM token required' } });

    const authHeader = req.headers.authorization;
    let userId = bodyUserId;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const tokenVal = authHeader.substring(7).trim();
      const session = require('../db/database').db.findOne('sessions', (s) => s.token === tokenVal);
      if (session) {
        userId = session.userId;
      }
    }

    if (!userId) {
      return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'User identification required' } });
    }

    const db = require('../db/database').db;
    const now = new Date().toISOString();

    // Account Switching / Isolation: Unbind this device / token from any other previous user accounts
    const staleTokens = db.find('user_fcm_tokens', (r) => (r.token === token || (deviceId && r.deviceId === deviceId)) && r.userId !== userId && !r.deleted);
    for (const stale of staleTokens) {
      db.update('user_fcm_tokens', stale.id, { deleted: true, deletedAt: now });
    }

    // Upsert: update existing token for this device or insert new one for the current user
    const existing = db.findOne('user_fcm_tokens', (r) => r.userId === userId && (r.deviceId === deviceId || r.token === token));
    if (existing) {
      db.update('user_fcm_tokens', existing.id, { token, deviceId: deviceId || existing.deviceId, platform: platform || existing.platform, updatedAt: now, deleted: false, deletedAt: null });
    } else {
      const { v4: uuidv4 } = require('uuid');
      db.insert('user_fcm_tokens', {
        id: uuidv4(),
        userId,
        token,
        deviceId: deviceId || `device_${Date.now()}`,
        platform: platform || 'android',
        createdAt: now,
        updatedAt: now,
        deleted: false,
      });
    }

    res.status(200).json({ data: { registered: true } });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/fcm-token/delete — Unregister FCM token (on logout)
router.post('/fcm-token/delete', authMiddleware, (req, res, next) => {
  try {
    const { token } = req.body;
    const db = require('../db/database').db;
    const userId = req.user.id;

    if (token) {
      const record = db.findOne('user_fcm_tokens', (r) => r.userId === userId && r.token === token);
      if (record) {
        db.update('user_fcm_tokens', record.id, { deleted: true, deletedAt: new Date().toISOString() });
      }
    } else {
      // Remove all tokens for this user on explicit logout
      const records = db.find('user_fcm_tokens', (r) => r.userId === userId && !r.deleted);
      const now = new Date().toISOString();
      for (const record of records) {
        db.update('user_fcm_tokens', record.id, { deleted: true, deletedAt: now });
      }
    }

    res.status(200).json({ data: { unregistered: true } });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
