const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const journeyService = require('../src/services/journey_service');
const { db } = require('../src/db/database');

describe('Journey Moments & Travel Timeline Service Tests', () => {
  let creator;
  let member;
  let outsider;
  let trip;

  beforeEach(() => {
    db.clearAll();
    const cRes = authService.createGuest({ displayName: 'Creator User' });
    creator = cRes.user;
    const mRes = authService.createGuest({ displayName: 'Member User' });
    member = mRes.user;
    const oRes = authService.createGuest({ displayName: 'Outsider User' });
    outsider = oRes.user;

    trip = tripService.createTrip(creator, {
      name: 'Goa Road Trip',
      emoji: '🏖️',
      currencyCode: 'INR',
    });

    tripService.joinTripByCode(member, trip.inviteCode);
  });

  test('1. Creates a journey moment with location, day index, and note', () => {
    const moment = journeyService.createMoment(creator, trip.id, {
      title: 'Arrived at Vagator Beach',
      placeName: 'Vagator Beach, North Goa',
      note: 'Watched the sunset from the cliffside cafe',
      dayIndex: 1,
      latitude: 15.6030,
      longitude: 73.7336,
      photoUrls: ['https://storage.kith.app/trips/goa/sunset.jpg'],
    });

    assert.ok(moment.id.startsWith('moment_'));
    assert.equal(moment.tripId, trip.id);
    assert.equal(moment.createdBy, creator.id);
    assert.equal(moment.title, 'Arrived at Vagator Beach');
    assert.equal(moment.placeName, 'Vagator Beach, North Goa');
    assert.equal(moment.dayIndex, 1);
    assert.equal(moment.photoUrls.length, 1);
  });

  test('2. Retrieves moments ordered chronologically by day index and timestamp', () => {
    const t0 = new Date('2026-08-25T10:00:00Z').toISOString();
    const t1 = new Date('2026-08-25T14:00:00Z').toISOString();
    const t2 = new Date('2026-08-26T09:00:00Z').toISOString();

    journeyService.createMoment(member, trip.id, {
      title: 'Day 2 Breakfast at Cafe Chocolatti',
      dayIndex: 2,
      occurredAt: t2,
    });

    journeyService.createMoment(creator, trip.id, {
      title: 'Day 1 Check-in',
      dayIndex: 1,
      occurredAt: t0,
    });

    journeyService.createMoment(creator, trip.id, {
      title: 'Day 1 Afternoon Swim',
      dayIndex: 1,
      occurredAt: t1,
    });

    const moments = journeyService.getTripMoments(creator, trip.id);
    assert.equal(moments.length, 3);
    assert.equal(moments[0].title, 'Day 1 Check-in');
    assert.equal(moments[1].title, 'Day 1 Afternoon Swim');
    assert.equal(moments[2].title, 'Day 2 Breakfast at Cafe Chocolatti');
  });

  test('3. Updates and deletes journey moments with authorization enforcement', () => {
    const moment = journeyService.createMoment(member, trip.id, {
      title: 'Scooter Ride to Chapora',
      dayIndex: 1,
    });

    const updated = journeyService.updateMoment(member, trip.id, moment.id, {
      title: 'Scooter Ride to Chapora Fort (Sunset)',
      placeName: 'Chapora Fort',
    });

    assert.equal(updated.title, 'Scooter Ride to Chapora Fort (Sunset)');
    assert.equal(updated.placeName, 'Chapora Fort');

    const delRes = journeyService.deleteMoment(member, trip.id, moment.id);
    assert.equal(delRes.success, true);

    const remaining = journeyService.getTripMoments(member, trip.id);
    assert.equal(remaining.length, 0);
  });

  test('4. IDOR Protection: Non-member cannot view or create moments', () => {
    assert.throws(() => {
      journeyService.getTripMoments(outsider, trip.id);
    }, /not a member of this trip/);

    assert.throws(() => {
      journeyService.createMoment(outsider, trip.id, {
        title: 'Hacked Moment',
      });
    }, /not a member of this trip/);
  });

  test('5. Idempotent moment creation with predetermined client ID', () => {
    const fixedId = 'moment_fixed_client_001';
    const m1 = journeyService.createMoment(creator, trip.id, {
      id: fixedId,
      title: 'Airport Landing',
      dayIndex: 1,
    });

    const m2 = journeyService.createMoment(creator, trip.id, {
      id: fixedId,
      title: 'Airport Landing (Duplicate Retry)',
      dayIndex: 1,
    });

    assert.equal(m1.id, fixedId);
    assert.equal(m2.id, fixedId);
    assert.equal(m2.title, 'Airport Landing'); // Kept first insert

    const moments = journeyService.getTripMoments(creator, trip.id);
    assert.equal(moments.length, 1);
  });
});
