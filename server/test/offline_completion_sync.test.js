const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const { db } = require('../src/db/database');

describe('Critical Offline Trip Completion & Expense Sync Backend Tests', () => {
  let userA;
  let userB;
  let trip;

  beforeEach(() => {
    db.clearAll();
    userA = authService.createGuest({ displayName: 'Alice' }).user;
    userB = authService.createGuest({ displayName: 'Bob' }).user;
    trip = tripService.createTrip(userA, {
      name: 'Himalayan Expedition',
      currencyCode: 'INR',
    });
    trip = tripService.joinTripByCode(userB, trip.inviteCode);
  });

  test('1. Offline Expense Sync: Preserves stable client-generated UUID idempotently', () => {
    const memberA = trip.members.find((m) => m.userId === userA.id);
    const memberB = trip.members.find((m) => m.userId === userB.id);
    const clientExpenseId = 'exp_client_uuid_12345';

    // First delivery of offline expense
    const res1 = expenseService.createExpense(userA, trip.id, {
      id: clientExpenseId,
      title: 'Trek Gear',
      amountInPaise: 50000,
      paidById: memberA.id,
      splits: [
        { memberId: memberA.id, amountInPaise: 25000 },
        { memberId: memberB.id, amountInPaise: 25000 },
      ],
    });

    assert.equal(res1.expense.id, clientExpenseId);
    assert.equal(res1.expense.title, 'Trek Gear');

    // Duplicate delivery due to network retry / reconnection
    const res2 = expenseService.createExpense(userA, trip.id, {
      id: clientExpenseId,
      title: 'Trek Gear',
      amountInPaise: 50000,
      paidById: memberA.id,
      splits: [
        { memberId: memberA.id, amountInPaise: 25000 },
        { memberId: memberB.id, amountInPaise: 25000 },
      ],
    });

    assert.equal(res2.expense.id, clientExpenseId);

    // Verify only 1 expense exists in database (zero duplicate insertion)
    const allExpenses = db.find('expenses', (e) => e.tripId === trip.id);
    assert.equal(allExpenses.length, 1);
  });

  test('2. Offline Trip Completion: Accepts completing state and transitions to completed', () => {
    // Client transitions to completing while syncing
    const completingTrip = tripService.updateLifecycle(trip.id, userA.id, 'completing');
    assert.equal(completingTrip.lifecycleState, 'completing');

    // Client promotes to completed once all pending changes have synced
    const completedTrip = tripService.updateLifecycle(trip.id, userA.id, 'completed');
    assert.equal(completedTrip.lifecycleState, 'completed');
  });

  test('3. Data Safety on Completed Trip: Late arriving offline expense is NEVER discarded', () => {
    const memberA = trip.members.find((m) => m.userId === userA.id);
    const memberB = trip.members.find((m) => m.userId === userB.id);

    // Trip is marked completed on server
    tripService.updateLifecycle(trip.id, userA.id, 'completed');
    assert.equal(db.get('trips', trip.id).lifecycleState, 'completed');

    // Offline device reconnects and delivers a previously created expense
    const lateExpense = expenseService.createExpense(userA, trip.id, {
      id: 'exp_late_offline_999',
      title: 'Late Camp Fee',
      amountInPaise: 30000,
      paidById: memberA.id,
      splits: [
        { memberId: memberA.id, amountInPaise: 15000 },
        { memberId: memberB.id, amountInPaise: 15000 },
      ],
    });

    assert.ok(lateExpense.expense);
    assert.equal(lateExpense.expense.id, 'exp_late_offline_999');

    // Verify trip is reopened or active to preserve financial reconciliation
    const currentTrip = db.get('trips', trip.id);
    assert.equal(currentTrip.lifecycleState, 'active');

    // And subsequent completion updates lifecycle cleanly
    const reCompleted = tripService.updateLifecycle(trip.id, userA.id, 'completed');
    assert.equal(reCompleted.lifecycleState, 'completed');
  });
});
