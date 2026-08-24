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

// GET /api/auth/me - Current authenticated user profile
router.get('/me', authMiddleware, (req, res, next) => {
  try {
    const profile = authService.getProfile(req.user.id);
    res.status(200).json({ data: profile });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
