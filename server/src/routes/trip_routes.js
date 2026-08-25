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
    const { id, inviteCode, name, description, emoji, coverGradientIndex, currencyCode, initialFriendNames, tripMode } = req.body;
    const trip = tripService.createTrip(req.user, {
      id,
      inviteCode,
      name,
      description,
      emoji,
      coverGradientIndex,
      currencyCode,
      initialFriendNames,
      tripMode,
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

// POST /api/trips/:id/settlements - Record a settlement transfer
router.post('/:id/settlements', (req, res, next) => {
  try {
    const settlementService = require('../services/settlement_service');
    const { fromMemberId, toMemberId, amountInPaise, paymentReference, note } = req.body;
    const result = settlementService.recordSettlement(
      req.user,
      req.params.id,
      { fromMemberId, toMemberId, amountInPaise, paymentReference, note },
      realtimeHub
    );
    res.status(201).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// GET /api/trips/:id/settlements - Get all recorded settlements
router.get('/:id/settlements', (req, res, next) => {
  try {
    const settlementService = require('../services/settlement_service');
    const settlements = settlementService.getSettlementsForTrip(req.user, req.params.id);
    res.status(200).json({ data: settlements });
  } catch (e) {
    next(e);
  }
});

// GET /api/trips/:id/activity - Get chronological activity logs
router.get('/:id/activity', (req, res, next) => {
  try {
    const logs = tripService.getActivityLogs(req.params.id, req.user.id);
    res.status(200).json({ data: logs });
  } catch (e) {
    next(e);
  }
});

// Journey Moments Endpoints
// GET /api/trips/:id/moments - Get chronological journey moments
router.get('/:id/moments', (req, res, next) => {
  try {
    const journeyService = require('../services/journey_service');
    const moments = journeyService.getTripMoments(req.user, req.params.id);
    res.status(200).json({ data: moments });
  } catch (e) {
    next(e);
  }
});

// POST /api/trips/:id/moments - Create journey moment
router.post('/:id/moments', (req, res, next) => {
  try {
    const journeyService = require('../services/journey_service');
    const moment = journeyService.createMoment(req.user, req.params.id, req.body, realtimeHub);
    res.status(201).json({ data: moment });
  } catch (e) {
    next(e);
  }
});

// PUT /api/trips/:id/moments/:momentId - Update journey moment
router.put('/:id/moments/:momentId', (req, res, next) => {
  try {
    const journeyService = require('../services/journey_service');
    const moment = journeyService.updateMoment(req.user, req.params.id, req.params.momentId, req.body, realtimeHub);
    res.status(200).json({ data: moment });
  } catch (e) {
    next(e);
  }
});

// DELETE /api/trips/:id/moments/:momentId - Delete journey moment
router.delete('/:id/moments/:momentId', (req, res, next) => {
  try {
    const journeyService = require('../services/journey_service');
    const result = journeyService.deleteMoment(req.user, req.params.id, req.params.momentId, realtimeHub);
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
