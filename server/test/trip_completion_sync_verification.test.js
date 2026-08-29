const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const { db } = require('../src/db/database');

describe('Smart Trip Completion & Multi-Participant Sync Verification Tests', () => {
  let userA;
  let userB;
  let userC;
  let trip;

  beforeEach(() => {
    db.clearAll();
    userA = authService.createGuest({ displayName: 'Alice' }).user;
    userB = authService.createGuest({ displayName: 'Bob' }).user;
    userC = authService.createGuest({ displayName: 'Charlie' }).user;

    trip = tripService.createTrip(userA, {
      name: 'Goa Holiday',
      currencyCode: 'INR',
    });
    trip = tripService.joinTripByCode(userB, trip.inviteCode);
    trip = tripService.joinTripByCode(userC, trip.inviteCode);
  });

  test('1. Sync Status: Accurately reports revision and participant states when fully synced', () => {
    // Both Alice, Bob, and Charlie acknowledge the current revision
    tripService.acknowledgeSync(trip.id, userA.id, { revision: trip.revision, pendingCount: 0 });
    tripService.acknowledgeSync(trip.id, userB.id, { revision: trip.revision, pendingCount: 0 });
    tripService.acknowledgeSync(trip.id, userC.id, { revision: trip.revision, pendingCount: 0 });

    const status = tripService.getTripSyncStatus(trip.id, userA.id);
    assert.equal(status.currentRevision, trip.revision);
    assert.equal(status.isFullySynced, true);
    assert.equal(status.canCompleteNormally, true);
    assert.equal(status.totalParticipants, 3);
    assert.equal(status.syncedParticipantsCount, 3);
    assert.equal(status.unsyncedParticipantsCount, 0);

    const me = status.participants.find((p) => p.userId === userA.id);
    assert.equal(me.isCurrentUser, true);
    assert.equal(me.syncStatus, 'synced');
  });

  test('2. Sync Status: Detects unsynced participant when an expense is added and unacknowledged', () => {
    const memberA = trip.members.find((m) => m.userId === userA.id);
    const memberB = trip.members.find((m) => m.userId === userB.id);

    // Alice adds an expense -> trip revision increments
    expenseService.createExpense(userA, trip.id, {
      title: 'Beach Shack Lunch',
      amountInPaise: 30000,
      paidById: memberA.id,
      splits: [
        { memberId: memberA.id, amountInPaise: 15000 },
        { memberId: memberB.id, amountInPaise: 15000 },
      ],
    });

    // Bob and Charlie haven't acknowledged the new revision yet
    const status = tripService.getTripSyncStatus(trip.id, userA.id);
    assert.equal(status.isFullySynced, false);
    assert.equal(status.canCompleteNormally, false);
    assert.ok(status.unsyncedParticipantsCount >= 1);

    const bob = status.participants.find((p) => p.userId === userB.id);
    assert.equal(bob.syncStatus, 'offline');
    assert.ok(bob.acknowledgedRevision < status.currentRevision);
  });

  test('3. Sync Acknowledgment: Re-acknowledging updates sync status to fully synced', () => {
    const memberA = trip.members.find((m) => m.userId === userA.id);
    const memberB = trip.members.find((m) => m.userId === userB.id);

    expenseService.createExpense(userA, trip.id, {
      title: 'Scuba Diving',
      amountInPaise: 60000,
      paidById: memberA.id,
      splits: [
        { memberId: memberA.id, amountInPaise: 30000 },
        { memberId: memberB.id, amountInPaise: 30000 },
      ],
    });

    const updatedTrip = db.get('trips', trip.id);

    // Bob and Charlie sync and acknowledge
    tripService.acknowledgeSync(trip.id, userB.id, { revision: updatedTrip.revision, pendingCount: 0 });
    tripService.acknowledgeSync(trip.id, userC.id, { revision: updatedTrip.revision, pendingCount: 0 });

    const status = tripService.getTripSyncStatus(trip.id, userA.id);
    assert.equal(status.isFullySynced, true);
    assert.equal(status.canCompleteNormally, true);
  });

  test('4. Complete Trip: Normal completion blocked if unsynced, succeeds when forced', () => {
    const memberA = trip.members.find((m) => m.userId === userA.id);
    const memberB = trip.members.find((m) => m.userId === userB.id);

    expenseService.createExpense(userA, trip.id, {
      title: 'Scooter Rental',
      amountInPaise: 20000,
      paidById: memberA.id,
      splits: [
        { memberId: memberA.id, amountInPaise: 10000 },
        { memberId: memberB.id, amountInPaise: 10000 },
      ],
    });

    // Attempt normal completion while Bob is un-synced -> should throw badRequest
    assert.throws(() => {
      tripService.completeTrip(trip.id, userA.id, { completionMode: 'NORMAL' });
    }, /Cannot complete trip normally/);

    // Explicit forced completion succeeds
    const completedTrip = tripService.completeTrip(trip.id, userA.id, { completionMode: 'FORCED_WITH_PENDING_SYNC' });
    assert.equal(completedTrip.lifecycleState, 'completed_with_pending_changes');
    assert.equal(completedTrip.completionMode, 'forced_with_pending_sync');
    assert.ok(completedTrip.completedAt);
    assert.equal(completedTrip.completedBy, userA.id);
  });

  test('5. Complete Trip: Idempotency & Conflict Check on Stale Revision', () => {
    // Acknowledge all members to allow normal completion
    const currentTrip = db.get('trips', trip.id);
    tripService.acknowledgeSync(trip.id, userA.id, { revision: currentTrip.revision, pendingCount: 0 });
    tripService.acknowledgeSync(trip.id, userB.id, { revision: currentTrip.revision, pendingCount: 0 });
    tripService.acknowledgeSync(trip.id, userC.id, { revision: currentTrip.revision, pendingCount: 0 });

    // Normal completion with matching expectedRevision
    const completedTrip1 = tripService.completeTrip(trip.id, userA.id, {
      completionMode: 'NORMAL',
      expectedRevision: currentTrip.revision,
    });
    assert.equal(completedTrip1.lifecycleState, 'completed');
    assert.equal(completedTrip1.completionMode, 'normal');

    // Idempotent duplicate call returns the same completed trip without error
    const completedTrip2 = tripService.completeTrip(trip.id, userA.id, {
      completionMode: 'NORMAL',
    });
    assert.equal(completedTrip2.lifecycleState, 'completed');

    // Reopen for conflict testing
    db.update('trips', trip.id, { lifecycleState: 'active', revision: 10 });
    // Calling with stale expectedRevision = 8 should throw conflict
    assert.throws(() => {
      tripService.completeTrip(trip.id, userA.id, {
        completionMode: 'FORCED_WITH_PENDING_SYNC',
        expectedRevision: 8,
      });
    }, /modified by another member/);
  });

  test('6. Late Offline Expense: Reconciled safely after trip completion without data loss', () => {
    const memberA = trip.members.find((m) => m.userId === userA.id);
    const memberB = trip.members.find((m) => m.userId === userB.id);

    // Complete trip
    const completed = tripService.completeTrip(trip.id, userA.id, { completionMode: 'FORCED_WITH_PENDING_SYNC' });
    assert.ok(completed.completedAt);

    // Offline device delivers expense created earlier
    const res = expenseService.createExpense(userB, trip.id, {
      id: 'exp_offline_b_1',
      title: 'Ice Cream on Beach',
      amountInPaise: 15000,
      paidById: memberB.id,
      splits: [
        { memberId: memberA.id, amountInPaise: 7500 },
        { memberId: memberB.id, amountInPaise: 7500 },
      ],
    });

    assert.equal(res.expense.id, 'exp_offline_b_1');
    assert.equal(res.expense.amountInPaise, 15000);

    // Verify balances reflect this late offline expense
    const balances = expenseService.getBalanceSummary(trip.id, userA.id);
    assert.equal(balances.totalTripSpendingInPaise, 15000);
  });
});
