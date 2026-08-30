'use strict';

const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const settlementService = require('../src/services/settlement_service');
const operationSyncService = require('../src/services/operation_sync_service');
const { db } = require('../src/db/database');

describe('P2P Operation Exchange & Server Deduplication Reconciliation Suite', () => {
  let userA, userB, userC, userD;
  let testTrip;

  beforeEach(() => {
    db.clearAll();

    // 1. Create User A (Trip Creator)
    const resA = authService.createGuest({ displayName: 'Alice (Creator)' });
    userA = resA.user;

    // 2. Create User B (Member)
    const resB = authService.createGuest({ displayName: 'Bob (Member)' });
    userB = resB.user;

    // 3. Create User C (Member)
    const resC = authService.createGuest({ displayName: 'Charlie (Member)' });
    userC = resC.user;

    // 4. Create User D (Outsider / Non-member)
    const resD = authService.createGuest({ displayName: 'David (Attacker)' });
    userD = resD.user;

    // 5. User A creates a trip
    testTrip = tripService.createTrip(userA, {
      name: 'Goa Roadtrip 2026',
      emoji: '🏖️',
      currencyCode: 'INR',
    });

    // 6. User B & User C join the trip
    tripService.joinTripByCode(userB, testTrip.inviteCode);
    tripService.joinTripByCode(userC, testTrip.inviteCode);
  });

  afterEach(() => {
    db.clearAll();
  });

  it('1. Applies offline expense operation atomically and returns APPLIED', () => {
    const tripDetails = tripService.getTripById(testTrip.id, userA.id);
    const memberA = tripDetails.members.find((m) => m.userId === userA.id);
    const memberB = tripDetails.members.find((m) => m.userId === userB.id);

    const opPayload = {
      id: 'op_exp_dinner_1000',
      type: 'addExpense',
      payload: {
        id: 'exp_dinner_1000',
        title: 'Beachside Dinner',
        amountInPaise: 100000,
        category: 'food',
        paidById: memberA.id,
        splitType: 'equal',
        splits: [
          { memberId: memberA.id, amountInPaise: 50000 },
          { memberId: memberB.id, amountInPaise: 50000 },
        ],
      },
    };

    const res = operationSyncService.applyOperation(userA, testTrip.id, opPayload);

    assert.equal(res.status, 'APPLIED');
    assert.equal(res.operationId, 'op_exp_dinner_1000');

    // Verify exactly 1 expense exists in database
    const expenses = db.find('expenses', (e) => e.tripId === testTrip.id && !e.isDeleted);
    assert.equal(expenses.length, 1);
    assert.equal(expenses[0].id, 'exp_dinner_1000');
    assert.equal(expenses[0].amountInPaise, 100000);
  });

  it('2. 50 Rapid Replays of the same Operation ID produce EXACTLY ONE expense (Strict Idempotency)', () => {
    const tripDetails = tripService.getTripById(testTrip.id, userA.id);
    const memberA = tripDetails.members.find((m) => m.userId === userA.id);
    const memberB = tripDetails.members.find((m) => m.userId === userB.id);

    const opPayload = {
      id: 'op_idempotent_fuel_2400',
      type: 'addExpense',
      payload: {
        id: 'exp_fuel_2400',
        title: 'Highway Fuel',
        amountInPaise: 240000,
        category: 'transport',
        paidById: memberA.id,
        splitType: 'equal',
        splits: [
          { memberId: memberA.id, amountInPaise: 120000 },
          { memberId: memberB.id, amountInPaise: 120000 },
        ],
      },
    };

    // First call: APPLIED
    const firstRes = operationSyncService.applyOperation(userA, testTrip.id, opPayload);
    assert.equal(firstRes.status, 'APPLIED');

    // Next 49 calls: ALREADY_PROCESSED
    for (let i = 0; i < 49; i++) {
      const replayRes = operationSyncService.applyOperation(userA, testTrip.id, opPayload);
      assert.equal(replayRes.status, 'ALREADY_PROCESSED');
      assert.equal(replayRes.operationId, 'op_idempotent_fuel_2400');
    }

    // Ledger invariant: Exactly 1 expense in database, not 50
    const expenses = db.find('expenses', (e) => e.tripId === testTrip.id && !e.isDeleted);
    assert.equal(expenses.length, 1);
    assert.equal(expenses[0].id, 'exp_fuel_2400');
  });

  it('3. Relayed P2P Operation Simulation: User B uploads A\'s offline operation, then A uploads it -> Zero Duplication', () => {
    const tripDetails = tripService.getTripById(testTrip.id, userA.id);
    const memberA = tripDetails.members.find((m) => m.userId === userA.id);
    const memberB = tripDetails.members.find((m) => m.userId === userB.id);

    // Alice creates operation offline: op_relayed_123
    const relayedOp = {
      id: 'op_relayed_123',
      type: 'addExpense',
      payload: {
        id: 'exp_relayed_123',
        title: 'Boat Cruise Tickets',
        amountInPaise: 300000,
        category: 'entertainment',
        paidById: memberA.id,
        splitType: 'equal',
        splits: [
          { memberId: memberA.id, amountInPaise: 150000 },
          { memberId: memberB.id, amountInPaise: 150000 },
        ],
      },
    };

    // User B receives it via P2P and gets internet connection first
    const resB = operationSyncService.applyOperation(userB, testTrip.id, relayedOp);
    assert.equal(resB.status, 'APPLIED');

    // Later Alice gets internet connection and uploads the same op_relayed_123
    const resA = operationSyncService.applyOperation(userA, testTrip.id, relayedOp);
    assert.equal(resA.status, 'ALREADY_PROCESSED');

    // Exactly 1 expense exists
    const expenses = db.find('expenses', (e) => e.tripId === testTrip.id && !e.isDeleted);
    assert.equal(expenses.length, 1);
  });

  it('4. Batch Operations Sync reconciles multiple offline operations in order', () => {
    const tripDetails = tripService.getTripById(testTrip.id, userA.id);
    const memberA = tripDetails.members.find((m) => m.userId === userA.id);
    const memberB = tripDetails.members.find((m) => m.userId === userB.id);
    const memberC = tripDetails.members.find((m) => m.userId === userC.id);

    const batchOps = [
      {
        id: 'op_batch_exp_1',
        type: 'addExpense',
        payload: {
          id: 'exp_batch_1',
          title: 'Breakfast',
          amountInPaise: 60000,
          category: 'food',
          paidById: memberA.id,
          splitType: 'equal',
          splits: [
            { memberId: memberA.id, amountInPaise: 20000 },
            { memberId: memberB.id, amountInPaise: 20000 },
            { memberId: memberC.id, amountInPaise: 20000 },
          ],
        },
      },
      {
        id: 'op_batch_exp_2',
        type: 'addExpense',
        payload: {
          id: 'exp_batch_2',
          title: 'Lunch',
          amountInPaise: 90000,
          category: 'food',
          paidById: memberB.id,
          splitType: 'equal',
          splits: [
            { memberId: memberA.id, amountInPaise: 30000 },
            { memberId: memberB.id, amountInPaise: 30000 },
            { memberId: memberC.id, amountInPaise: 30000 },
          ],
        },
      },
    ];

    const res = operationSyncService.batchSyncOperations(userA, testTrip.id, batchOps);

    assert.equal(res.processedCount, 2);
    assert.equal(res.results[0].status, 'APPLIED');
    assert.equal(res.results[1].status, 'APPLIED');

    // Balance summary check: Total spending is 600 + 900 = 1500 (150000 paise)
    assert.equal(res.balanceSummary.totalTripSpendingInPaise, 150000);
  });

  it('5. Security / IDOR: Unauthorized user D cannot submit sync operations for Trip X', () => {
    assert.throws(
      () => {
        operationSyncService.applyOperation(userD, testTrip.id, {
          id: 'op_malicious_1',
          type: 'addExpense',
          payload: {
            title: 'Hacked Expense',
            amountInPaise: 999999,
          },
        });
      },
      (err) => err.statusCode === 403 || err.message.includes('not a member')
    );
  });

  it('6. P2P Watermark Negotiation: getOperationsSince retrieves delta operations', () => {
    const tripDetails = tripService.getTripById(testTrip.id, userA.id);
    const memberA = tripDetails.members.find((m) => m.userId === userA.id);
    const memberB = tripDetails.members.find((m) => m.userId === userB.id);

    // Apply 3 operations
    operationSyncService.applyOperation(userA, testTrip.id, {
      id: 'op_delta_1',
      type: 'addExpense',
      payload: {
        id: 'exp_delta_1',
        title: 'Item 1',
        amountInPaise: 10000,
        paidById: memberA.id,
        splits: [{ memberId: memberA.id, amountInPaise: 5000 }, { memberId: memberB.id, amountInPaise: 5000 }],
      },
    });

    operationSyncService.applyOperation(userA, testTrip.id, {
      id: 'op_delta_2',
      type: 'addExpense',
      payload: {
        id: 'exp_delta_2',
        title: 'Item 2',
        amountInPaise: 20000,
        paidById: memberA.id,
        splits: [{ memberId: memberA.id, amountInPaise: 10000 }, { memberId: memberB.id, amountInPaise: 10000 }],
      },
    });

    operationSyncService.applyOperation(userA, testTrip.id, {
      id: 'op_delta_3',
      type: 'addExpense',
      payload: {
        id: 'exp_delta_3',
        title: 'Item 3',
        amountInPaise: 30000,
        paidById: memberA.id,
        splits: [{ memberId: memberA.id, amountInPaise: 15000 }, { memberId: memberB.id, amountInPaise: 15000 }],
      },
    });

    // Peer knows op_delta_1, asks for remaining
    const delta = operationSyncService.getOperationsSince(testTrip.id, userB.id, {
      sinceRevision: 1,
      knownOperationIds: ['op_delta_1'],
    });

    assert.equal(delta.operations.length, 2);
    assert.equal(delta.operations[0].id, 'op_delta_2');
    assert.equal(delta.operations[1].id, 'op_delta_3');
  });
});
