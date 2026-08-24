const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const { db } = require('../src/db/database');

describe('Trip Service Tests', () => {
  let creator;
  let member;

  beforeEach(() => {
    db.clearAll();
    const cRes = authService.createGuest({ displayName: 'Creator User' });
    creator = cRes.user;
    const mRes = authService.createGuest({ displayName: 'Member User' });
    member = mRes.user;
  });

  test('Creates a trip with unique 6-character alphanumeric join code', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Manali Trek',
      description: 'Mountain adventure',
      emoji: '🏔️',
      currencyCode: 'INR',
    });

    assert.ok(trip.id.startsWith('trip_'));
    assert.equal(trip.name, 'Manali Trek');
    assert.equal(trip.emoji, '🏔️');
    assert.equal(trip.inviteCode.length, 6);
    assert.equal(trip.members.length, 1);
    assert.equal(trip.members[0].userId, creator.id);
    assert.equal(trip.members[0].role, 'creator');
    assert.equal(trip.lifecycleState, 'active');
  });

  test('Generates safe public trip preview by join code without sensitive data', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Goa Holiday',
      emoji: '🏖️',
      coverGradientIndex: 2,
    });

    const preview = tripService.getTripPreviewByCode(trip.inviteCode);
    assert.equal(preview.tripId, trip.id);
    assert.equal(preview.name, 'Goa Holiday');
    assert.equal(preview.emoji, '🏖️');
    assert.equal(preview.creatorName, 'Creator User');
    assert.equal(preview.memberCount, 1);
    assert.equal(preview.inviteCode, trip.inviteCode);
  });

  test('Allows another authenticated guest to join via invite code', () => {
    const trip = tripService.createTrip(creator, { name: 'Kashmir Trip' });
    const joined = tripService.joinTripByCode(member, trip.inviteCode);

    assert.equal(joined.members.length, 2);
    assert.ok(joined.members.some((m) => m.userId === member.id));

    // Verify user can now fetch trip
    const userTrips = tripService.getUserTrips(member.id);
    assert.equal(userTrips.length, 1);
    assert.equal(userTrips[0].id, trip.id);
  });

  test('Rejects non-creator from completing trip', () => {
    const trip = tripService.createTrip(creator, { name: 'Ladakh' });
    tripService.joinTripByCode(member, trip.inviteCode);

    assert.throws(
      () => tripService.updateLifecycle(trip.id, member.id, 'completed'),
      (err) => err.statusCode === 403
    );
  });

  test('Allows creator to complete trip', () => {
    const trip = tripService.createTrip(creator, { name: 'Ladakh' });
    const completed = tripService.updateLifecycle(trip.id, creator.id, 'completed');
    assert.equal(completed.lifecycleState, 'completed');
  });
});
