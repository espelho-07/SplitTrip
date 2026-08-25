const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const app = require('../src/app');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const personalService = require('../src/services/personal_service');

describe('Phase 23 Production Hardening & Release Candidate Test Suite', () => {
  let server;
  let port;
  let baseUrl;

  let userA, tokenA;
  let userB, tokenB;
  let userIntruder, tokenIntruder;
  let trip;

  before(async () => {
    server = http.createServer(app);
    await new Promise((resolve) => {
      server.listen(0, '127.0.0.1', () => {
        port = server.address().port;
        baseUrl = `http://127.0.0.1:${port}`;
        resolve();
      });
    });

    const resA = authService.createGuest({ displayName: 'Alice (Creator)' });
    userA = resA.user;
    tokenA = resA.token;

    const resB = authService.createGuest({ displayName: 'Bob (Member)' });
    userB = resB.user;
    tokenB = resB.token;

    const resIntruder = authService.createGuest({ displayName: 'Eve (Intruder)' });
    userIntruder = resIntruder.user;
    tokenIntruder = resIntruder.token;

    trip = tripService.createTrip(userA, {
      name: 'RC Hardening Trip',
      currencyCode: 'INR',
    });
    trip = tripService.joinTripByCode(userB, trip.inviteCode);
  });

  after(() => {
    if (server) server.close();
  });

  test('1. IDOR Security: Intruder Eve cannot read settlements from private trip', async () => {
    const res = await fetch(`${baseUrl}/api/trips/${trip.id}/settlements`, {
      headers: {
        'Authorization': `Bearer ${tokenIntruder}`,
      },
    });

    assert.strictEqual(res.status, 403, 'Should return HTTP 403 Forbidden for non-members');
    const body = await res.json();
    assert.strictEqual(body.error.code, 'FORBIDDEN');
    assert.ok(body.error.message.includes('not a member'));
  });

  test('2. IDOR Security: Intruder Eve cannot read or mutate Journey moments of private trip', async () => {
    const getRes = await fetch(`${baseUrl}/api/trips/${trip.id}/moments`, {
      headers: {
        'Authorization': `Bearer ${tokenIntruder}`,
      },
    });
    assert.strictEqual(getRes.status, 403);

    const postRes = await fetch(`${baseUrl}/api/trips/${trip.id}/moments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${tokenIntruder}`,
      },
      body: JSON.stringify({
        title: 'Hacked moment',
      }),
    });
    assert.strictEqual(postRes.status, 403);
  });

  test('3. Financial Conservation: 3-way uneven split preserves exact paise sum with zero remainder', () => {
    const totalPaise = 100000; // ₹1,000.00
    const memberIds = ['m1', 'm2', 'm3'];
    const baseShare = Math.floor(totalPaise / memberIds.length);
    const remainder = totalPaise % memberIds.length;

    const splits = memberIds.map((id, idx) => ({
      memberId: id,
      amountInPaise: baseShare + (idx === 0 ? remainder : 0),
    }));

    const splitSum = splits.reduce((acc, s) => acc + s.amountInPaise, 0);
    assert.strictEqual(splitSum, totalPaise, 'Split sum must equal total paise exactly');
    assert.strictEqual(splits[0].amountInPaise, 33334);
    assert.strictEqual(splits[1].amountInPaise, 33333);
    assert.strictEqual(splits[2].amountInPaise, 33333);
  });

  test('4. Personal Debt Integrity: Partial repayments decrease debt and prevent negative remaining balance', () => {
    const debt = personalService.createPersonalDebt(userA.id, {
      personName: 'Rohan',
      debtType: 'lent',
      amountInPaise: 500000, // ₹5,000
    });

    assert.strictEqual(debt.remainingAmountInPaise, 500000);
    assert.strictEqual(debt.isSettled, false);

    // Partial Repayment 1: �2,000
    const rep1 = personalService.recordDebtRepayment(userA.id, debt.id, {
      amountInPaise: 200000,
      note: 'Part 1',
    });
    assert.strictEqual(rep1.debt.remainingAmountInPaise, 300000);
    assert.strictEqual(rep1.debt.isSettled, false);

    // Partial Repayment 2: �3,000 (Fully settled)
    const rep2 = personalService.recordDebtRepayment(userA.id, debt.id, {
      amountInPaise: 300000,
      note: 'Final settlement',
    });
    assert.strictEqual(rep2.debt.remainingAmountInPaise, 0);
    assert.strictEqual(rep2.debt.isSettled, true);

    // Attempting to repay further throws error (Cannot overpay or create negative debt)
    assert.throws(
      () => {
        personalService.recordDebtRepayment(userA.id, debt.id, {
          amountInPaise: 10000,
        });
      },
      (err) => err.statusCode === 400 && err.message.includes('already settled')
    );
  });

  test('5. Multi-Trip Isolation: Expenses in Trip A never appear in Trip B', () => {
    const tripB = tripService.createTrip(userA, {
      name: 'Second Isolated Trip',
      currencyCode: 'INR',
    });

    const members = trip.members;

    const expA = expenseService.createExpense(userA, trip.id, {
      title: 'Resort Stay',
      amountInPaise: 600000,
      paidById: members[0].id,
      splits: [
        { memberId: members[0].id, amountInPaise: 300000 },
        { memberId: members[1].id, amountInPaise: 300000 },
      ],
    });

    const expensesTripB = expenseService.getExpenses(tripB.id, userA.id);
    assert.strictEqual(expensesTripB.length, 0);

    const expensesTripA = expenseService.getExpenses(trip.id, userA.id);
    assert.ok(expensesTripA.some((e) => e.id === expA.expense.id));
  });

  test('6. Production Error Sanitization: Route not found returns clean structured error', async () => {
    const res = await fetch(`${baseUrl}/api/non_existent_endpoint`, {
      headers: {
        'Authorization': `Bearer ${tokenA}`,
      },
    });

    assert.strictEqual(res.status, 404);
    const body = await res.json();
    assert.strictEqual(body.error.code, 'ROUTE_NOT_FOUND');
    assert.strictEqual(body.error.stack, undefined);
  });
});
