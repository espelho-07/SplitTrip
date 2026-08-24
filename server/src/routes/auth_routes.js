const express = require('express');
const authService = require('../services/auth_service');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

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

// POST /api/auth/recover - Recover session across devices via recovery key
router.post('/recover', (req, res, next) => {
  try {
    const { recoveryKey } = req.body;
    const result = authService.recoverGuest({ recoveryKey });
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
