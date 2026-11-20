const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const notificationService = require('../src/services/notification_service');
const { db } = require('../src/db/database');

describe('Smart Trip Completion & Member Consent Test Suite', () => {
  let userOwner;
  let userAlice;
  let userBob;
  let trip;

  beforeEach(() => {
    db.clearAll();
    userOwner = authService.createGuest({ displayName: 'Owner' }).user;
    userAlice = authService.createGuest({ displayName: 'Alice' }).user;
    userBob = authService.createGuest({ displayName: 'Bob' }).user;

    trip = tripService.createTrip(userOwner, {
      name: 'Goa Smart Trip',
      currencyCode: 'INR',
    });
    trip = tripService.joinTripByCode(userAlice, trip.inviteCode);
    trip = tripService.joinTripByCode(userBob, trip.inviteCode);
  });

  test('1. Authoritative Heartbeat & Presence Tracking', () => {
    // Record heartbeat for Alice
    const hb = tripService.recordHeartbeat(trip.id, userAlice.id);
    assert.equal(hb.tripId, trip.id);
    assert.equal(hb.userId, userAlice.id);
    assert.ok(hb.timestamp);

    const status = tripService.getTripSyncStatus(trip.id, userOwner.id);
    const aliceParticipant = status.participants.find((p) => p.userId === userAlice.id);
    assert.equal(aliceParticipant.presenceStatus, 'ONLINE');
    assert.ok(aliceParticipant.lastHeartbeatAt);

    // Simulate stale heartbeat for Bob (10 minutes ago)
    const bobMember = db.findOne('trip_members', (m) => m.tripId === trip.id && m.userId === userBob.id);
    const tenMinAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    db.update('trip_members', bobMember.id, { lastHeartbeatAt: tenMinAgo, lastSeenAt: tenMinAgo });

    const status2 = tripService.getTripSyncStatus(trip.id, userOwner.id);
    const bobParticipant = status2.participants.find((p) => p.userId === userBob.id);
    assert.equal(bobParticipant.presenceStatus, 'OFFLINE');
  });

  test('2. Owner Online Enforcement: Offline Owner Cannot Complete Trip', () => {
    // Attempt completion while owner is marked offline
    assert.throws(() => {
      tripService.completeTrip(trip.id, userOwner.id, { isOwnerOnline: false });
    }, (err) => {
      assert.match(err.message, /currently offline.*Connect to the internet/i);
      return true;
    });
  });

  test('3. Authorization Check: Non-Owner Cannot Request Consent or Complete Trip', () => {
    const memberAlice = trip.members.find((m) => m.userId === userAlice.id);
    const memberBob = trip.members.find((m) => m.userId === userBob.id);

    // Alice (regular member) attempts to request completion consent
    assert.throws(() => {
      tripService.requestCompletionConsent(trip.id, userAlice.id, memberBob.id);
    }, (err) => {
      assert.equal(err.statusCode, 403);
      return true;
    });

    // Alice attempts to complete trip
    assert.throws(() => {
      tripService.completeTrip(trip.id, userAlice.id);
    }, (err) => {
      assert.equal(err.statusCode, 403);
      return true;
    });
  });

  test('4. Consent Request: Owner Requests Consent, Trip Transitions to Completing', () => {
    const memberBob = trip.members.find((m) => m.userId === userBob.id);

    const req = tripService.requestCompletionConsent(trip.id, userOwner.id, memberBob.id);
    assert.equal(req.tripId, trip.id);
    assert.equal(req.memberId, memberBob.id);
    assert.equal(req.status, 'PENDING');
    assert.ok(req.expiresAt);

    // Verify trip state moved to 'completing'
    const updatedTrip = db.get('trips', trip.id);
    assert.equal(updatedTrip.lifecycleState, 'completing');

    // Verify notification was generated for Bob
    const notifs = notificationService.getNotificationsForUser(userBob.id);
    assert.ok(notifs.length >= 1);
    assert.equal(notifs[0].type, 'TRIP_COMPLETION_CONSENT_REQUESTED');

    // Normal completion should be blocked while consent is pending
    assert.throws(() => {
      tripService.completeTrip(trip.id, userOwner.id, { completionMode: 'NORMAL' });
    }, (err) => {
      assert.match(err.message, /Waiting for confirmation from Bob/i);
      return true;
    });
  });

  test('5. Member Responds YES (CONFIRMED_AVAILABLE) -> Unblocks Completion', () => {
    const memberAlice = trip.members.find((m) => m.userId === userAlice.id);
    const memberBob = trip.members.find((m) => m.userId === userBob.id);

    // Sync revisions so sync status is satisfied
    tripService.acknowledgeSync(trip.id, userOwner.id, { revision: trip.revision });
    tripService.acknowledgeSync(trip.id, userAlice.id, { revision: trip.revision });
    tripService.acknowledgeSync(trip.id, userBob.id, { revision: trip.revision });

    // Request consent from Bob
    const req = tripService.requestCompletionConsent(trip.id, userOwner.id, memberBob.id);

    // Bob responds YES
    const response = tripService.respondCompletionConsent(trip.id, req.id, userBob.id, {
      response: 'YES',
      note: 'All good on my side!',
    });
    assert.equal(response.status, 'CONFIRMED_AVAILABLE');
    assert.equal(response.response, 'YES');

    // Now Alice is online (recorded in beforeEach/acknowledgeSync) and Bob is CONFIRMED_AVAILABLE
    const compStatus = tripService.getTripCompletionStatus(trip.id, userOwner.id);
    assert.equal(compStatus.canCompleteNormally, true);

    // Completion succeeds
    const completed = tripService.completeTrip(trip.id, userOwner.id, { completionMode: 'NORMAL' });
    assert.equal(completed.lifecycleState, 'completed');
    assert.equal(completed.completionMode, 'normal');
  });

  test('6. Member Responds NO (UNAVAILABLE) -> Explicitly Blocks Completion & Reverts State', () => {
    const memberBob = trip.members.find((m) => m.userId === userBob.id);

    // Request consent from Bob
    const req = tripService.requestCompletionConsent(trip.id, userOwner.id, memberBob.id);
    assert.equal(db.get('trips', trip.id).lifecycleState, 'completing');

    // Bob responds NO because he has a missing bill
    const response = tripService.respondCompletionConsent(trip.id, req.id, userBob.id, {
      response: 'NO',
      note: 'I haven\'t added the dinner receipt yet',
    });
    assert.equal(response.status, 'UNAVAILABLE');

    // Trip lifecycle reverts to active
    assert.equal(db.get('trips', trip.id).lifecycleState, 'active');

    // Notification created for owner
    const ownerNotifs = notificationService.getNotificationsForUser(userOwner.id);
    const blockedNotif = ownerNotifs.find((n) => n.type === 'TRIP_COMPLETION_BLOCKED');
    assert.ok(blockedNotif);
    assert.match(blockedNotif.body, /Bob marked themselves unavailable/);

    // Attempting completion throws blocked error
    assert.throws(() => {
      tripService.completeTrip(trip.id, userOwner.id, { completionMode: 'NORMAL' });
    }, (err) => {
      assert.match(err.message, /Completion blocked: Bob/i);
      return true;
    });
  });

  test('7. Financial Integrity: Pending Local Mutations Block Normal Completion', () => {
    // Alice has pending offline mutations
    tripService.acknowledgeSync(trip.id, userAlice.id, { revision: trip.revision, pendingCount: 2 });

    assert.throws(() => {
      tripService.completeTrip(trip.id, userOwner.id, { completionMode: 'NORMAL' });
    }, (err) => {
      assert.match(err.message, /Some expenses are still waiting to sync/i);
      return true;
    });
  });

  test('8. Silence Is NOT Consent: Expired Request Blocks Completion', () => {
    const memberBob = trip.members.find((m) => m.userId === userBob.id);
    const req = tripService.requestCompletionConsent(trip.id, userOwner.id, memberBob.id);

    // Manually simulate expiration (25 hours ago)
    const yesterday = new Date(Date.now() - 25 * 60 * 60 * 1000).toISOString();
    db.update('trip_completion_requests', req.id, { expiresAt: yesterday });

    // Bob tries to respond to expired request -> fails
    assert.throws(() => {
      tripService.respondCompletionConsent(trip.id, req.id, userBob.id, { response: 'YES' });
    }, (err) => {
      assert.match(err.message, /expired/i);
      return true;
    });

    // Make Bob offline
    db.update('trip_members', memberBob.id, { lastHeartbeatAt: yesterday, lastSeenAt: yesterday });

    // Owner cannot complete normally
    assert.throws(() => {
      tripService.completeTrip(trip.id, userOwner.id, { completionMode: 'NORMAL' });
    }, (err) => {
      assert.equal(err.statusCode, 400);
      return true;
    });
  });

  test('9. Virtual Members Are System-Accounted', () => {
    // Add a virtual member to the trip
    tripService.addMember(trip.id, userOwner.id, {
      displayName: 'Virtual Traveler',
      isVirtual: true,
    });

    const status = tripService.getTripSyncStatus(trip.id, userOwner.id);
    const virtualP = status.participants.find((p) => p.displayName === 'Virtual Traveler');
    assert.equal(virtualP.presenceStatus, 'VIRTUAL_ACCOUNTED');
    assert.equal(virtualP.syncStatus, 'synced');
    assert.equal(virtualP.isVirtual, true);
  });

  test('10. Trip Reopening Workflow: Request and Owner Review', () => {
    // Fast-forward to completed state
    tripService.acknowledgeSync(trip.id, userOwner.id, { revision: trip.revision });
    tripService.acknowledgeSync(trip.id, userAlice.id, { revision: trip.revision });
    tripService.acknowledgeSync(trip.id, userBob.id, { revision: trip.revision });
    tripService.completeTrip(trip.id, userOwner.id, { completionMode: 'NORMAL' });

    assert.equal(db.get('trips', trip.id).lifecycleState, 'completed');

    // Alice requests reopening with MISSING_EXPENSE
    const reopenReq = tripService.requestTripReopening(trip.id, userAlice.id, {
      reasonCategory: 'MISSING_EXPENSE',
      note: 'Forgot the ferry tickets from Panaji',
    });
    assert.equal(reopenReq.status, 'PENDING');
    assert.equal(reopenReq.reasonCategory, 'MISSING_EXPENSE');

    // Owner notification created
    const ownerNotifs = notificationService.getNotificationsForUser(userOwner.id);
    const reopenNotif = ownerNotifs.find((n) => n.type === 'TRIP_REOPENING_REQUESTED');
    assert.ok(reopenNotif);

    // Owner reviews and approves
    const reviewResult = tripService.reviewTripReopening(trip.id, reopenReq.id, userOwner.id, {
      action: 'APPROVE',
      reviewNote: 'Approved, please add the receipt promptly',
    });
    assert.equal(reviewResult.request.status, 'APPROVED');
    assert.equal(reviewResult.trip.lifecycleState, 'active');

    // Verify lifecycle history contains audit log
    const history = tripService.getLifecycleHistory(trip.id, userOwner.id);
    assert.ok(history.length >= 2);
    const reopenHistory = history.find((h) => h.newStatus === 'active');
    assert.ok(reopenHistory);
    assert.match(reopenHistory.reason, /Reopening approved/);
  });
});
