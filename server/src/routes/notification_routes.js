const express = require('express');
const notificationService = require('../services/notification_service');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// GET /api/notifications - Get all notifications for the authenticated user with optional pagination
router.get('/', authMiddleware, (req, res, next) => {
  try {
    const { limit, offset } = req.query;
    const notifications = notificationService.getNotificationsForUser(req.user.id, { limit, offset });
    const unreadCount = notificationService.getUnreadCount(req.user.id);
    res.status(200).json({ data: notifications, unreadCount });
  } catch (e) {
    next(e);
  }
});

// GET /api/notifications/unread-count - Get unread count only
router.get('/unread-count', authMiddleware, (req, res, next) => {
  try {
    const unreadCount = notificationService.getUnreadCount(req.user.id);
    res.status(200).json({ data: { unreadCount } });
  } catch (e) {
    next(e);
  }
});

// PATCH /api/notifications/:id/read - Mark single notification as read
router.patch('/:id/read', authMiddleware, (req, res, next) => {
  try {
    const result = notificationService.markAsRead(req.user.id, req.params.id);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/notifications/read-all - Mark all notifications read for user
router.post('/read-all', authMiddleware, (req, res, next) => {
  try {
    const result = notificationService.markAllAsRead(req.user.id);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
