const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const WebSocket = require('ws');
const app = require('../src/app');
const { realtimeHub } = require('../src/realtime/websocket_hub');
const { db } = require('../src/db/database');

describe('Guest-First Architecture, Unlimited Multi-Trip & Sync Isolation Tests', () => {
  let server;
  const PORT = 10001;
  const BASE_URL = `http://127.0.0.1:${PORT}`;
  const WS_URL = `ws://127.0.0.1:${PORT}/ws`;

  before(async () => {
    db.clearAll();
    server = http.createServer(app);
    realtimeHub.attach(server);
    await new Promise((resolve) => server.listen(PORT, '0.0.0.0', resolve));
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

  let guestUserA, tokenA, recoveryKeyA;
  let guestUserB, tokenB;
  const createdTripIds = [];

  it('1. Automatic Guest Creation: Creates guest without email, password or phone number', async () => {
    const res = await api('/api/auth/guest', {
      method: 'POST',
      body: { displayName: 'Alex Rivera' },
    });

    assert.strictEqual(res.status, 201);
    const authData = res.data.data || res.data;
    assert.ok(authData.user.id.startsWith('usr_'));
    assert.ok(authData.user.recoveryKey.startsWith('KITH-'));
    assert.ok(authData.token.startsWith('kith_sess_'));
    assert.strictEqual(authData.user.displayName, 'Alex Rivera');

    guestUserA = authData.user;
    tokenA = authData.token;
    recoveryKeyA = authData.user.recoveryKey;
  });

  it('2. Unlimited Trip Creation: Single guest user can create 10+ distinct trips without artificial limits', async () => {
    const tripNames = [
      'Goa Beach Holiday',
      'Manali Trekking',
      'Weekend Dinner Club',
      'Co-living Rent & Wifi',
      'Diwali Party 2026',
      'Euro Summer Tour',
      'Concert Roadtrip',
      'Family Reunion',
      'Office Lunch Pool',
      'Camping Trip',
    ];

    for (let i = 0; i < tripNames.length; i++) {
      const res = await api('/api/trips', {
        method: 'POST',
        token: tokenA,
        body: {
          name: tripNames[i],
          emoji: '🏕️',
          currencyCode: 'INR',
          initialFriendNames: ['Friend 1', 'Friend 2'],
        },
      });

      assert.strictEqual(res.status, 201);
      const trip = res.data.data || res.data;
      assert.strictEqual(trip.name, tripNames[i]);
      assert.strictEqual(trip.creatorId, guestUserA.id);
      assert.strictEqual(trip.members.length, 3);
      createdTripIds.push(trip.id);
    }

    assert.strictEqual(createdTripIds.length, 10);

    // Verify all 10 trips are listed for user A
    const listRes = await api('/api/trips', { token: tokenA });
    assert.strictEqual(listRes.status, 200);
    const trips = listRes.data.data || listRes.data;
    assert.strictEqual(trips.length, 10);
  });

  it('3. Multi-Trip Switching & Data Isolation: Trip A expenses never leak into Trip B or Trip C', async () => {
    const tripAId = createdTripIds[0];
    const tripBId = createdTripIds[1];

    const tripARes = await api(`/api/trips/${tripAId}`, { token: tokenA });
    const tripBRes = await api(`/api/trips/${tripBId}`, { token: tokenA });

    const tripA = tripARes.data.data || tripARes.data;
    const memberA1 = tripA.members[0].id;
    const memberA2 = tripA.members[1].id;

    // Add ₹3,000 expense to Trip A
    const expARes = await api(`/api/trips/${tripAId}/expenses`, {
      method: 'POST',
      token: tokenA,
      body: {
        title: 'Goa Scuba Diving',
        amountInPaise: 300000,
        paidById: memberA1,
        category: 'activity',
        splitType: 'equal',
        splits: [
          { memberId: memberA1, amountInPaise: 150000 },
          { memberId: memberA2, amountInPaise: 150000 },
        ],
      },
    });
    assert.strictEqual(expARes.status, 201);

    // Verify Trip A has 1 expense and Trip B has 0 expenses
    const expensesA = await api(`/api/trips/${tripAId}/expenses`, { token: tokenA });
    const expensesB = await api(`/api/trips/${tripBId}/expenses`, { token: tokenA });

    const listA = expensesA.data.data || expensesA.data;
    const listB = expensesB.data.data || expensesB.data;

    assert.strictEqual(listA.length, 1);
    assert.strictEqual(listA[0].title, 'Goa Scuba Diving');
    assert.strictEqual(listB.length, 0);
  });

  it('4. Multi-Device Guest Recovery: Restoring recovery key on Device B returns exact same identity & trips', async () => {
    const recoverRes = await api('/api/auth/recover', {
      method: 'POST',
      body: { recoveryKey: recoveryKeyA },
    });

    assert.strictEqual(recoverRes.status, 200);
    const authData = recoverRes.data.data || recoverRes.data;
    assert.strictEqual(authData.user.id, guestUserA.id);
    assert.strictEqual(authData.user.displayName, guestUserA.displayName);

    const deviceBToken = authData.token;
    const deviceBTrips = await api('/api/trips', { token: deviceBToken });
    assert.strictEqual(deviceBTrips.status, 200);
    const trips = deviceBTrips.data.data || deviceBTrips.data;
    assert.strictEqual(trips.length, 10);
  });

  it('5. Realtime WebSocket Multi-Trip Room Isolation: Events in Trip A do not reach Trip B subscribers', async () => {
    const tripAId = createdTripIds[0];
    const tripBId = createdTripIds[1];

    const wsA = new WebSocket(`${WS_URL}?token=${tokenA}`);
    const wsB = new WebSocket(`${WS_URL}?token=${tokenA}`);

    await new Promise((resolve) => wsA.on('open', resolve));
    await new Promise((resolve) => wsB.on('open', resolve));

    // Client A subscribes to Trip A; Client B subscribes to Trip B
    wsA.send(JSON.stringify({ action: 'subscribe', tripId: tripAId }));
    wsB.send(JSON.stringify({ action: 'subscribe', tripId: tripBId }));

    await new Promise((resolve) => setTimeout(resolve, 50));

    const eventsReceivedByB = [];
    wsB.on('message', (raw) => {
      const parsed = JSON.parse(raw.toString());
      if (parsed.type === 'expense_added') {
        eventsReceivedByB.push(parsed);
      }
    });

    // Create an expense in Trip A
    const tripARes = await api(`/api/trips/${tripAId}`, { token: tokenA });
    const tripA = tripARes.data.data || tripARes.data;
    const memberA1 = tripA.members[0].id;
    const memberA2 = tripA.members[1].id;

    await api(`/api/trips/${tripAId}/expenses`, {
      method: 'POST',
      token: tokenA,
      body: {
        title: 'Shack Lunch',
        amountInPaise: 120000,
        paidById: memberA1,
        category: 'food',
        splitType: 'equal',
        splits: [
          { memberId: memberA1, amountInPaise: 60000 },
          { memberId: memberA2, amountInPaise: 60000 },
        ],
      },
    });

    await new Promise((resolve) => setTimeout(resolve, 100));

    // Verify WebSocket B subscribed to Trip B received ZERO events from Trip A
    assert.strictEqual(eventsReceivedByB.length, 0);

    wsA.close();
    wsB.close();
  });

  it('6. Offline Idempotency Across Multiple Trips: Retrying mutations does not create duplicates', async () => {
    const tripAId = createdTripIds[0];
    const tripARes = await api(`/api/trips/${tripAId}`, { token: tokenA });
    const tripA = tripARes.data.data || tripARes.data;
    const memberA1 = tripA.members[0].id;

    const customExpenseId = 'exp_client_offline_12345';
    const payload = {
      id: customExpenseId,
      title: 'Fuel Petrol Pump',
      amountInPaise: 200000,
      paidById: memberA1,
      category: 'fuel',
      splitType: 'equal',
      splits: [
        { memberId: memberA1, amountInPaise: 200000 },
      ],
    };

    // First attempt (online or replay)
    const firstRes = await api(`/api/trips/${tripAId}/expenses`, {
      method: 'POST',
      token: tokenA,
      body: payload,
    });
    assert.strictEqual(firstRes.status, 201);
    const exp1 = firstRes.data.data ? (firstRes.data.data.expense || firstRes.data.data) : firstRes.data;
    assert.strictEqual(exp1.id, customExpenseId);

    // Replay attempt (simulating client retry after network drop)
    const retryRes = await api(`/api/trips/${tripAId}/expenses`, {
      method: 'POST',
      token: tokenA,
      body: payload,
    });
    assert.strictEqual(retryRes.status, 201);
    const exp2 = retryRes.data.data ? (retryRes.data.data.expense || retryRes.data.data) : retryRes.data;
    assert.strictEqual(exp2.id, customExpenseId);

    // Verify only ONE record exists in the trip
    const allExpenses = await api(`/api/trips/${tripAId}/expenses`, { token: tokenA });
    const list = allExpenses.data.data || allExpenses.data;
    const matching = list.filter((e) => e.id === customExpenseId);
    assert.strictEqual(matching.length, 1);
  });

  it('7. IDOR Authorization: Guest User B cannot view or modify Guest User A trips without joining', async () => {
    // Create Guest User B
    const userBRes = await api('/api/auth/guest', {
      method: 'POST',
      body: { displayName: 'Unauthorized Stranger' },
    });
    const authDataB = userBRes.data.data || userBRes.data;
    tokenB = authDataB.token;
    guestUserB = authDataB.user;

    const privateTripAId = createdTripIds[0];

    // Attempt to access private trip details
    const unauthorizedGet = await api(`/api/trips/${privateTripAId}`, { token: tokenB });
    assert.strictEqual(unauthorizedGet.status, 403);

    // Attempt to add expense to private trip
    const unauthorizedPost = await api(`/api/trips/${privateTripAId}/expenses`, {
      method: 'POST',
      token: tokenB,
      body: { title: 'Hack Expense', amountInPaise: 50000 },
    });
    assert.strictEqual(unauthorizedPost.status, 403);
  });
});
