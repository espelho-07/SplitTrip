const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const app = require('../src/app');
const { realtimeHub } = require('../src/realtime/websocket_hub');
const { db } = require('../src/db/database');

describe('Phase P0: Cross-Account & Cross-Device Trip Join Regression Suite', () => {
  let server;
  const PORT = 4098;
  const BASE_URL = `http://127.0.0.1:${PORT}`;

  let userA, userB;
  let tokenA, tokenB;
  let tripA, inviteCodeA;
  let memberA, memberB;

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

  it('1. User A authenticates via Google and creates a trip with invite code', async () => {
    // User A Google login
    const authResA = await api('/api/auth/google', {
      method: 'POST',
      body: {
        email: 'alice.creator@gmail.com',
        displayName: 'Alice Creator',
        photoUrl: 'https://lh3.googleusercontent.com/a/alice',
        googleId: 'google_sub_alice_1001',
      },
    });

    assert.strictEqual(authResA.status, 200);
    assert.ok(authResA.data.data.token);
    userA = authResA.data.data.user;
    tokenA = authResA.data.data.token;
    assert.strictEqual(userA.email, 'alice.creator@gmail.com');

    // User A creates Trip A
    const tripResA = await api('/api/trips', {
      method: 'POST',
      token: tokenA,
      body: {
        id: 'trip_alice_test_01',
        inviteCode: 'GOA2026',
        name: 'Goa Summer Escape',
        description: 'Beach holiday with friends',
        emoji: '🏖️',
        coverGradientIndex: 1,
        currencyCode: 'INR',
        initialFriendNames: ['Bob Traveler'],
      },
    });

    assert.strictEqual(tripResA.status, 201);
    tripA = tripResA.data.data;
    assert.strictEqual(tripA.id, 'trip_alice_test_01');
    assert.strictEqual(tripA.inviteCode, 'GOA2026');
    inviteCodeA = tripA.inviteCode;

    // Verify creator membership
    assert.strictEqual(tripA.creatorId, userA.id);
    const creatorMbr = tripA.members.find((m) => m.userId === userA.id);
    assert.ok(creatorMbr, 'Creator must be a member of the trip');
    assert.strictEqual(creatorMbr.role, 'creator');
    memberA = creatorMbr;
  });

  it('2. Public preview of trip by invite code returns safe metadata', async () => {
    const previewRes = await api(`/api/trips/preview?code=${inviteCodeA.toLowerCase()}`);
    assert.strictEqual(previewRes.status, 200);
    assert.strictEqual(previewRes.data.data.name, 'Goa Summer Escape');
    assert.strictEqual(previewRes.data.data.creatorName, 'Alice Creator');
    assert.strictEqual(previewRes.data.data.inviteCode, 'GOA2026');
  });

  it('3. User B authenticates on a separate Google account and joins Trip A', async () => {
    // User B Google login
    const authResB = await api('/api/auth/google', {
      method: 'POST',
      body: {
        email: 'bob.traveler@gmail.com',
        displayName: 'Bob Traveler',
        photoUrl: 'https://lh3.googleusercontent.com/a/bob',
        googleId: 'google_sub_bob_2002',
      },
    });

    assert.strictEqual(authResB.status, 200);
    assert.ok(authResB.data.data.token);
    userB = authResB.data.data.user;
    tokenB = authResB.data.data.token;

    // User A and User B must be separate identities
    assert.notStrictEqual(userA.id, userB.id);
    assert.notStrictEqual(tokenA, tokenB);

    // User B joins Trip A using invite code with lowercase and whitespace
    const joinResB = await api('/api/trips/join', {
      method: 'POST',
      token: tokenB,
      body: { inviteCode: '  goa2026  ' },
    });

    assert.strictEqual(joinResB.status, 200);
    const joinedTrip = joinResB.data.data;
    assert.strictEqual(joinedTrip.id, tripA.id);

    // Verify both User A and User B exist in trip members
    const mA = joinedTrip.members.find((m) => m.userId === userA.id);
    const mB = joinedTrip.members.find((m) => m.userId === userB.id);
    assert.ok(mA, 'User A must still be creator');
    assert.ok(mB, 'User B must be a member');
    assert.strictEqual(mA.role, 'creator');
    assert.strictEqual(mB.role, 'member');
    assert.strictEqual(mB.displayName, 'Bob Traveler');
    memberB = mB;
  });

  it('4. User B joining again is strictly idempotent (no duplicate rows)', async () => {
    const repeatJoinRes = await api('/api/trips/join', {
      method: 'POST',
      token: tokenB,
      body: { inviteCode: 'GOA2026' },
    });

    assert.strictEqual(repeatJoinRes.status, 200);

    // Verify database row count
    const allMembersInDb = db.find('trip_members', (m) => m.tripId === tripA.id && m.userId === userB.id);
    assert.strictEqual(allMembersInDb.length, 1, 'User B must have exactly 1 membership row');
  });

  it('5. Multiplayer: User B adds expense to Trip A; User A retrieves it', async () => {
    const expenseResB = await api(`/api/trips/${tripA.id}/expenses`, {
      method: 'POST',
      token: tokenB,
      body: {
        title: 'Seafood Beach Dinner',
        amountInPaise: 400000, // ₹4000
        category: 'food',
        paidById: memberB.id,
        splitType: 'equal',
        splits: [
          { memberId: memberA.id, amountInPaise: 200000 },
          { memberId: memberB.id, amountInPaise: 200000 },
        ],
      },
    });

    assert.strictEqual(expenseResB.status, 201);
    const createdExpense = expenseResB.data.data.expense;
    assert.strictEqual(createdExpense.title, 'Seafood Beach Dinner');

    // User A reads expenses from Trip A
    const listResA = await api(`/api/trips/${tripA.id}/expenses`, {
      method: 'GET',
      token: tokenA,
    });

    assert.strictEqual(listResA.status, 200);
    assert.strictEqual(listResA.data.data.length, 1);
    assert.strictEqual(listResA.data.data[0].title, 'Seafood Beach Dinner');
  });

  it('6. User A adds expense to Trip A; User B retrieves it', async () => {
    const expenseResA = await api(`/api/trips/${tripA.id}/expenses`, {
      method: 'POST',
      token: tokenA,
      body: {
        title: 'Scooter Rental',
        amountInPaise: 160000, // ₹1600
        category: 'transport',
        paidById: memberA.id,
        splitType: 'equal',
        splits: [
          { memberId: memberA.id, amountInPaise: 80000 },
          { memberId: memberB.id, amountInPaise: 80000 },
        ],
      },
    });

    assert.strictEqual(expenseResA.status, 201);

    // User B reads expenses from Trip A
    const listResB = await api(`/api/trips/${tripA.id}/expenses`, {
      method: 'GET',
      token: tokenB,
    });

    assert.strictEqual(listResB.status, 200);
    assert.strictEqual(listResB.data.data.length, 2);
  });

  it('7. Security & IDOR: User B cannot access User A private personal finance data', async () => {
    // User A creates personal expense
    const personalResA = await api('/api/personal/expenses', {
      method: 'POST',
      token: tokenA,
      body: {
        title: 'Personal Medicine',
        amountInPaise: 50000,
        category: 'medical',
      },
    });
    assert.strictEqual(personalResA.status, 201);
    const personalExpAId = personalResA.data.expense.id;

    // User B attempts to access User A personal expenses list
    const listResB = await api('/api/personal/expenses', {
      method: 'GET',
      token: tokenB,
    });
    assert.strictEqual(listResB.status, 200);
    assert.strictEqual(listResB.data.expenses.length, 0, 'User B must not see User A personal expenses');

    // User B attempts to delete User A personal expense
    const deleteResB = await api(`/api/personal/expenses/${personalExpAId}`, {
      method: 'DELETE',
      token: tokenB,
    });
    assert.strictEqual(deleteResB.status, 403, 'User B must be forbidden from mutating User A personal data');
  });

  it('8. Join with non-existent invite code returns clean 404', async () => {
    const notFoundRes = await api('/api/trips/join', {
      method: 'POST',
      token: tokenB,
      body: { inviteCode: 'NON999' },
    });

    assert.strictEqual(notFoundRes.status, 404);
    assert.ok(notFoundRes.data.error);
    assert.strictEqual(notFoundRes.data.error.code, 'NOT_FOUND');
  });
});
