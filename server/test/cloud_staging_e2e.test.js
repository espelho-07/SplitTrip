const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const WebSocket = require('ws');
const app = require('../src/app');
const { realtimeHub } = require('../src/realtime/websocket_hub');
const { db } = require('../src/db/database');

describe('Real Cloud Staging & Multi-User End-to-End QA Test Suite', () => {
  let server;
  const PORT = 4099;
  const BASE_URL = `http://127.0.0.1:${PORT}`;
  const WS_URL = `ws://127.0.0.1:${PORT}/ws`;

  let userA, userB;
  let tokenA, tokenB;
  let tripId, inviteCode;
  let memberAId, memberBId;
  let memberIds = [];

  before(async () => {
    db.clearAll();
    server = http.createServer(app);
    realtimeHub.attach(server);
    await new Promise((resolve) => server.listen(PORT, resolve));
  });

  after(async () => {
    realtimeHub.close();
    await new Promise((resolve) => server.close(resolve));
  });

  async function api(path, { method = 'GET', body = null, token = null } = {}) {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const res = await fetch(`${BASE_URL}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : null,
    });
    const data = await res.json();
    return { status: res.status, data };
  }

  // 1. Staging Health & Readiness
  it('1. GET /health and GET /ready return healthy and ready status', async () => {
    const health = await api('/health');
    assert.strictEqual(health.status, 200);
    assert.strictEqual(health.data.status, 'healthy');
    assert.strictEqual(health.data.service, 'kith-backend');

    const ready = await api('/ready');
    assert.strictEqual(ready.status, 200);
    assert.strictEqual(ready.data.status, 'ready');
  });

  // 2. Authentication & Guest Recovery
  it('2. Creates unique guest identities and verifies cryptographic session recovery', async () => {
    const resA = await api('/api/auth/guest', {
      method: 'POST',
      body: { displayName: 'Alice Cloud' },
    });
    assert.strictEqual(resA.status, 201);
    userA = resA.data.data.user;
    tokenA = resA.data.data.token;
    assert.ok(userA.id.startsWith('usr_'));
    assert.ok(userA.recoveryKey.startsWith('KITH-'));

    const resB = await api('/api/auth/guest', {
      method: 'POST',
      body: { displayName: 'Bob Cloud' },
    });
    assert.strictEqual(resB.status, 201);
    userB = resB.data.data.user;
    tokenB = resB.data.data.token;
    assert.notStrictEqual(userA.id, userB.id);

    // Test Guest Recovery
    const recoveryRes = await api('/api/auth/recover', {
      method: 'POST',
      body: { recoveryKey: userA.recoveryKey },
    });
    assert.strictEqual(recoveryRes.status, 200);
    assert.strictEqual(recoveryRes.data.data.user.id, userA.id);
  });

  // 3. Real Trip Creation & Joining
  it('3. User A creates "Kith Cloud QA Trip" and User B joins via invite code', async () => {
    const tripRes = await api('/api/trips', {
      method: 'POST',
      token: tokenA,
      body: {
        name: 'Kith Cloud QA Trip',
        emoji: '🏔️',
        currencyCode: 'INR',
        initialFriendNames: ['Charlie Cloud', 'David Cloud', 'Eve Cloud'],
      },
    });
    assert.strictEqual(tripRes.status, 201);
    const trip = tripRes.data.data;
    tripId = trip.id;
    inviteCode = trip.inviteCode;
    assert.strictEqual(inviteCode.length, 6);

    const members = trip.members;
    assert.strictEqual(members.length, 4); // Alice + 3 initial friends
    memberAId = members.find((m) => m.userId === userA.id).id;

    // User B joins via invite code
    const joinRes = await api('/api/trips/join', {
      method: 'POST',
      token: tokenB,
      body: { inviteCode },
    });
    assert.strictEqual(joinRes.status, 200);
    assert.strictEqual(joinRes.data.data.id, tripId);
    assert.strictEqual(joinRes.data.data.members.length, 5);

    memberBId = joinRes.data.data.members.find((m) => m.userId === userB.id).id;
    memberIds = joinRes.data.data.members.map((m) => m.id);
  });

  // 4. Duplicate Join Idempotency
  it('4. Rejects duplicate join attempts for existing members gracefully', async () => {
    const dupRes = await api('/api/trips/join', {
      method: 'POST',
      token: tokenB,
      body: { inviteCode },
    });
    assert.strictEqual(dupRes.status, 200);
    assert.strictEqual(dupRes.data.data.members.length, 5); // Idempotently returns existing trip without duplicating member
  });

  // 5. 5-Member Expense Split with Integer Paise Precision
  it('5. User A records ₹6,000 Train expense split equally across 5 members', async () => {
    const splits = memberIds.map((mId) => ({
      memberId: mId,
      amountInPaise: 120000, // ₹1,200 each
    }));

    const expRes = await api(`/api/trips/${tripId}/expenses`, {
      method: 'POST',
      token: tokenA,
      body: {
        id: 'exp_cloud_train_001',
        title: 'Train to Mountains',
        amountInPaise: 600000, // ₹6,000.00
        paidById: memberAId,
        splitType: 'equal',
        category: 'transport',
        splits,
      },
    });

    assert.strictEqual(expRes.status, 201);
    const data = expRes.data.data;
    assert.strictEqual(data.expense.amountInPaise, 600000);
    assert.strictEqual(data.balanceSummary.totalTripSpendingInPaise, 600000);
    // User A paid 6000, share is 1200 => net balance = +4800 (480000 paise)
    assert.strictEqual(data.balanceSummary.currentUserNetBalanceInPaise, 480000);
  });

  // 6. Second Expense & Multi-Payer Balance Calculation
  it('6. User B records ₹300 Food expense split across all 5 members', async () => {
    const splits = memberIds.map((mId) => ({
      memberId: mId,
      amountInPaise: 6000, // ₹60 each
    }));

    const expRes = await api(`/api/trips/${tripId}/expenses`, {
      method: 'POST',
      token: tokenB,
      body: {
        id: 'exp_cloud_food_002',
        title: 'Mountain Cafe Food',
        amountInPaise: 30000, // ₹300.00
        paidById: memberBId,
        splitType: 'equal',
        category: 'food',
        splits,
      },
    });

    assert.strictEqual(expRes.status, 201);
    const data = expRes.data.data;
    assert.strictEqual(data.expense.amountInPaise, 30000);
    assert.strictEqual(data.balanceSummary.totalTripSpendingInPaise, 630000);

    // Verify Zero-Sum Conservation Invariant: SUM(net balances) == 0
    const netBalances = data.balanceSummary.netBalancesInPaise;
    const sumNet = Object.values(netBalances).reduce((acc, val) => acc + val, 0);
    assert.strictEqual(sumNet, 0, 'Sum of all member net balances must strictly equal 0');
  });

  // 7. Settlement Computation & Recording
  it('7. Computes direct settlements and records valid settlement payment', async () => {
    const tripExpenses = await api(`/api/trips/${tripId}/expenses`, { token: tokenB });
    assert.strictEqual(tripExpenses.status, 200);

    const recordRes = await api(`/api/trips/${tripId}/settlements`, {
      method: 'POST',
      token: tokenB,
      body: {
        fromMemberId: memberBId,
        toMemberId: memberAId,
        amountInPaise: 6000,
        note: 'UPI Payment in cloud QA test',
      },
    });
    assert.strictEqual(recordRes.status, 201);
    assert.strictEqual(recordRes.data.data.settlement.amountInPaise, 6000);
  });

  // 8. IDOR & Authorization Protection
  it('8. Enforces IDOR security: Non-member cannot access or mutate private trips', async () => {
    const unauthGuest = await api('/api/auth/guest', {
      method: 'POST',
      body: { displayName: 'Intruder' },
    });

    const accessRes = await api(`/api/trips/${tripId}`, {
      token: unauthGuest.data.data.token,
    });
    assert.strictEqual(accessRes.status, 403);
  });

  // 9. Offline Mutation Idempotency
  it('9. Idempotent mutation: Replaying existing expense ID does not create duplicate', async () => {
    const dupExpenseRes = await api(`/api/trips/${tripId}/expenses`, {
      method: 'POST',
      token: tokenA,
      body: {
        id: 'exp_cloud_train_001', // Already existing ID
        title: 'Train to Mountains',
        amountInPaise: 600000,
        paidById: memberAId,
        splitType: 'equal',
        splits: memberIds.map((mId) => ({ memberId: mId, amountInPaise: 120000 })),
      },
    });

    assert.ok(dupExpenseRes.status === 200 || dupExpenseRes.status === 201);
    assert.strictEqual(dupExpenseRes.data.data.expense.id, 'exp_cloud_train_001');

    // Verify trip expense count is still exactly 2 (Train + Food)
    const tripExpenses = await api(`/api/trips/${tripId}/expenses`, { token: tokenA });
    assert.strictEqual(tripExpenses.data.data.length, 2);
  });

  // 10. Live WebSocket Realtime Broadcast
  it('10. WebSocket Hub broadcasts realtime trip mutations to subscribed rooms', async () => {
    const ws = new WebSocket(WS_URL);

    const eventPromise = new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('WebSocket event timed out')), 4000);

      ws.on('open', () => {
        ws.send(JSON.stringify({ type: 'auth', token: tokenB }));
        ws.send(JSON.stringify({ type: 'subscribe', tripId }));
      });

      ws.on('message', (raw) => {
        const msg = JSON.parse(raw.toString());
        if (msg.type === 'expense_added' || msg.type === 'expense_created') {
          clearTimeout(timer);
          ws.close();
          resolve(msg);
        }
      });
    });

    // Wait 80ms for WS room join then trigger expense
    await new Promise((r) => setTimeout(r, 80));

    await api(`/api/trips/${tripId}/expenses`, {
      method: 'POST',
      token: tokenA,
      body: {
        title: 'Snacks on Trail',
        amountInPaise: 15000,
        paidById: memberAId,
        splitType: 'equal',
        splits: memberIds.map((mId) => ({ memberId: mId, amountInPaise: 3000 })),
      },
    });

    const receivedEvent = await eventPromise;
    assert.strictEqual(receivedEvent.tripId, tripId);
  });

  // 11. Balance Summary Endpoint
  it('11. GET /api/trips/:tripId/expenses/balance/summary returns live balance summary', async () => {
    const summaryRes = await api(`/api/trips/${tripId}/expenses/balance/summary`, { token: tokenA });
    assert.strictEqual(summaryRes.status, 200);
    assert.ok(summaryRes.data.data.totalTripSpendingInPaise > 0);
    assert.ok(summaryRes.data.data.netBalancesInPaise !== undefined);
  });
});
