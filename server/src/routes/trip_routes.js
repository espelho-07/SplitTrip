const express = require('express');
const tripService = require('../services/trip_service');
const { authMiddleware } = require('../middleware/auth');
const { realtimeHub } = require('../realtime/websocket_hub');

const router = express.Router();

// GET /api/trips/preview?code=... (Public preview)
router.get('/preview', (req, res, next) => {
  try {
    const { code } = req.query;
    const preview = tripService.getTripPreviewByCode(code);
    res.status(200).json({ data: preview });
  } catch (e) {
    next(e);
  }
});

// All subsequent routes require authentication
router.use(authMiddleware);

// GET /api/trips - List user's trips
router.get('/', (req, res, next) => {
  try {
    const trips = tripService.getUserTrips(req.user.id);
    res.status(200).json({ data: trips });
  } catch (e) {
    next(e);
  }
});

// POST /api/trips - Create new trip
router.post('/', (req, res, next) => {
  try {
    const { name, description, emoji, coverGradientIndex, currencyCode, initialFriendNames } = req.body;
    const trip = tripService.createTrip(req.user, {
      name,
      description,
      emoji,
      coverGradientIndex,
      currencyCode,
      initialFriendNames,
    });
    res.status(201).json({ data: trip });
  } catch (e) {
    next(e);
  }
});

// POST /api/trips/join - Join trip by invite code
router.post('/join', (req, res, next) => {
  try {
    const { inviteCode } = req.body;
    const trip = tripService.joinTripByCode(req.user, inviteCode, realtimeHub);
    res.status(200).json({ data: trip });
  } catch (e) {
    next(e);
  }
});

// GET /api/trips/:id - Get specific trip details
router.get('/:id', (req, res, next) => {
  try {
    const trip = tripService.getTripById(req.params.id, req.user.id);
    res.status(200).json({ data: trip });
  } catch (e) {
    next(e);
  }
});

// PATCH /api/trips/:id/lifecycle - Update trip lifecycle (e.g. complete trip)
router.patch('/:id/lifecycle', (req, res, next) => {
  try {
    const { lifecycleState } = req.body;
    const trip = tripService.updateLifecycle(req.params.id, req.user.id, lifecycleState, realtimeHub);
    res.status(200).json({ data: trip });
  } catch (e) {
    next(e);
  }
});

// POST /api/trips/:id/members - Add member to trip
router.post('/:id/members', (req, res, next) => {
  try {
    const { displayName } = req.body;
    const trip = tripService.addMember(req.params.id, req.user.id, { displayName }, realtimeHub);
    res.status(201).json({ data: trip });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
