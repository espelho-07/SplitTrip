const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const { db } = require('../src/db/database');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const settlementService = require('../src/services/settlement_service');
const operationSyncService = require('../src/services/operation_sync_service');
const { storageRetentionService } = require('../src/services/storage_retention_service');

describe('Concurrency, Scalability & Load Resilience Suite', () => {
  beforeEach(() => {
    db.clearAll();
  });

  it('1. 100 Simultaneous Concurrent Expense Creations on Same Trip with Exact Zero-Sum Conservation', async () => {
    const userA = authService.createGuest({ displayName: 'Creator Alice' }).user;
    const userB = authService.createGuest({ displayName: 'Member Bob' }).user;

    const trip = tripService.createTrip(userA, {
      name: 'Load Test Goa Trip',
      currencyCode: 'INR',
    });

    const joinedTrip = tripService.joinTripByCode(userB, trip.inviteCode);
    const memberA = joinedTrip.members.find((m) => m.userId === userA.id);
    const memberB = joinedTrip.members.find((m) => m.userId === userB.id);

    // Launch 100 concurrent expense creation promises
    const count = 100;
    const amountEach = 25000; // ₹250.00
    const promises = [];

    for (let i = 0; i < count; i++) {
      const payer = i % 2 === 0 ? userA : userB;
      const payerMemberId = i % 2 === 0 ? memberA.id : memberB.id;
      const expenseId = `exp_concurrent_load_${i}`;
      promises.push(
        Promise.resolve().then(() => {
          return expenseService.createExpense(payer, trip.id, {
            id: expenseId,
            title: `Concurrent Expense #${i}`,
            amountInPaise: amountEach,
            paidById: payerMemberId,
            splitType: 'EQUAL',
            splits: [
              { memberId: memberA.id, amountInPaise: 12500 },
              { memberId: memberB.id, amountInPaise: 12500 },
            ],
          });
        })
      );
    }

    const results = await Promise.all(promises);
    assert.strictEqual(results.length, 100);

    // Verify all 100 expenses exist in database
    const storedExpenses = expenseService.getExpenses(trip.id, userA.id);
    assert.strictEqual(storedExpenses.length, 100);

    // Verify financial ledger exact balance summary
    const summary = expenseService.getBalanceSummary(trip.id, userA.id);
    assert.strictEqual(summary.totalTripSpendingInPaise, 100 * 25000);

    // Since Alice paid 50 and Bob paid 50 equally, net balances must be exactly 0
    assert.strictEqual(summary.netBalancesInPaise[memberA.id], 0);
    assert.strictEqual(summary.netBalancesInPaise[memberB.id], 0);
  });

  it('2. 100 Simultaneous Concurrent Trip Reads under load without deadlocks or latency degradation', async () => {
    const user = authService.createGuest({ displayName: 'Reader User' }).user;
    const trip = tripService.createTrip(user, { name: 'Read Heavy Trip' });
    const member = trip.members[0];

    for (let i = 0; i < 20; i++) {
      expenseService.createExpense(user, trip.id, {
        id: `exp_read_seed_${i}`,
        title: `Seed #${i}`,
        amountInPaise: 1000,
        paidById: member.id,
        splits: [{ memberId: member.id, amountInPaise: 1000 }],
      });
    }

    const readPromises = [];
    const startTime = Date.now();
    for (let i = 0; i < 100; i++) {
      readPromises.push(Promise.resolve().then(() => tripService.getTripById(trip.id, user.id)));
    }

    const readResults = await Promise.all(readPromises);
    const totalDurationMs = Date.now() - startTime;

    assert.strictEqual(readResults.length, 100);
    assert.ok(totalDurationMs < 1500, `100 concurrent reads took ${totalDurationMs}ms (expected < 1500ms)`);
  });

  it('3. 100 Simultaneous Concurrent Sync Operations with Strict Global Idempotency', async () => {
    const user = authService.createGuest({ displayName: 'Sync Tester' }).user;
    const trip = tripService.createTrip(user, { name: 'Concurrent Sync Trip' });
    const member = trip.members[0];

    const operationId = 'op_concurrent_global_101';
    const rawOp = {
      id: operationId,
      type: 'addExpense',
      payload: {
        id: 'exp_sync_target_1',
        title: 'Single Unique Target Expense',
        amountInPaise: 50000,
        paidById: member.id,
        splits: [{ memberId: member.id, amountInPaise: 50000 }],
      },
      createdAt: new Date().toISOString(),
    };

    // 100 concurrent submissions of the same operation ID
    const promises = [];
    for (let i = 0; i < 100; i++) {
      promises.push(Promise.resolve().then(() => operationSyncService.applyOperation(user, trip.id, rawOp)));
    }

    const results = await Promise.all(promises);
    assert.strictEqual(results.length, 100);

    const appliedCount = results.filter((r) => r.status === 'APPLIED').length;
    const alreadyProcessedCount = results.filter((r) => r.status === 'ALREADY_PROCESSED').length;

    assert.strictEqual(appliedCount, 1, 'Exactly ONE operation must be APPLIED');
    assert.strictEqual(alreadyProcessedCount, 99, '99 operations must return ALREADY_PROCESSED');

    const expenses = expenseService.getExpenses(trip.id, user.id);
    assert.strictEqual(expenses.length, 1);
    assert.strictEqual(expenses[0].title, 'Single Unique Target Expense');
  });

  it('4. Storage Retention & Compaction Engine safely prunes expired data without touching active financial history', async () => {
    const user = authService.createGuest({ displayName: 'Active User' }).user;
    const trip = tripService.createTrip(user, { name: 'Preserved Active Trip' });
    const member = trip.members[0];

    // Add active expense
    expenseService.createExpense(user, trip.id, {
      id: 'exp_active_1',
      title: 'Active Dinner',
      amountInPaise: 10000,
      paidById: member.id,
      splits: [{ memberId: member.id, amountInPaise: 10000 }],
    });

    // Add old expired session (30 days ago)
    const oldDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    db.insert('sessions', {
      id: 'sess_old_expired',
      userId: user.id,
      token: 'tok_expired_123',
      expiresAt: oldDate,
      createdAt: oldDate,
    });

    // Add old deleted FCM token
    db.insert('user_fcm_tokens', {
      id: 'tok_old_deleted',
      userId: user.id,
      token: 'fcm_old_token',
      deleted: true,
      deletedAt: oldDate,
      createdAt: oldDate,
    });

    // Add old read notification
    db.insert('notifications', {
      id: 'notif_old_read',
      recipientUserId: user.id,
      status: 'READ',
      title: 'Old Notification',
      updatedAt: oldDate,
      createdAt: oldDate,
    });

    // Run retention cycle
    const summary = storageRetentionService.runRetentionCycle({
      sessionRetentionDays: 1,
      tokenRetentionDays: 1,
      notificationRetentionDays: 1,
    });

    assert.strictEqual(summary.prunedSessions, 1);
    assert.strictEqual(summary.prunedTokens, 1);
    assert.strictEqual(summary.prunedNotifications, 1);

    // Verify active financial records remain untouched
    const activeExpenses = expenseService.getExpenses(trip.id, user.id);
    assert.strictEqual(activeExpenses.length, 1);
    assert.strictEqual(activeExpenses[0].id, 'exp_active_1');

    const activeTrip = tripService.getTripById(trip.id, user.id);
    assert.ok(activeTrip);
  });
});
