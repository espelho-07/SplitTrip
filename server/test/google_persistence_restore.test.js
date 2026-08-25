const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const app = require('../src/app');
const { realtimeHub } = require('../src/realtime/websocket_hub');
const { db } = require('../src/db/database');

describe('Phase P0 Critical: Google Account Data Persistence & Cross-Device Restore Suite', () => {
  let server;
  const PORT = 4099;
  const BASE_URL = `http://127.0.0.1:${PORT}`;

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

  let guestUserId, guestToken;
  let canonicalUserA, tokenA;
  let trip1Id, trip1Invite;

  it('1. User uses Kith as a Guest: creates personal expense, budget, debt, trip and trip expense', async () => {
    // Guest creation
    const guestRes = await api('/api/auth/guest', {
      method: 'POST',
      body: { displayName: 'Guest Darpan' },
    });
    assert.strictEqual(guestRes.status, 201);
    guestUserId = guestRes.data.data.user.id;
    guestToken = guestRes.data.data.token;
    assert.ok(guestUserId.startsWith('usr_'));

    // 1. Create personal expense as guest
    const pexpRes = await api('/api/personal/expenses', {
      method: 'POST',
      token: guestToken,
      body: {
        title: 'Morning Coffee',
        amountInPaise: 25000,
        category: 'food',
      },
    });
    assert.strictEqual(pexpRes.status, 201);
    assert.strictEqual(pexpRes.data.expense.userId, guestUserId);

    // 2. Create personal budget as guest
    const budgetRes = await api('/api/personal/budget', {
      method: 'PUT',
      token: guestToken,
      body: {
        monthYear: '2026-08',
        monthlyLimitInPaise: 5000000,
      },
    });
    assert.strictEqual(budgetRes.status, 200);

    // 3. Create personal debt (Lending) as guest
    const debtRes = await api('/api/personal/debts', {
      method: 'POST',
      token: guestToken,
      body: {
        personName: 'Rohan',
        debtType: 'lent',
        amountInPaise: 150000,
      },
    });
    assert.strictEqual(debtRes.status, 201);

    // 4. Create Trip as guest
    const tripRes = await api('/api/trips', {
      method: 'POST',
      token: guestToken,
      body: {
        id: 'trip_guest_goa_01',
        inviteCode: 'GOA777',
        name: 'Goa Weekend',
        emoji: '🏖️',
        currencyCode: 'INR',
        initialFriendNames: ['Amit'],
      },
    });
    assert.strictEqual(tripRes.status, 201);
    trip1Id = tripRes.data.data.id;
    trip1Invite = tripRes.data.data.inviteCode;
    assert.strictEqual(tripRes.data.data.creatorId, guestUserId);

    const guestMember = tripRes.data.data.members.find((m) => m.userId === guestUserId);
    assert.ok(guestMember);

    // 5. Add Trip Expense as guest
    const expRes = await api(`/api/trips/${trip1Id}/expenses`, {
      method: 'POST',
      token: guestToken,
      body: {
        title: 'Resort Booking',
        amountInPaise: 1000000,
        paidById: guestMember.id,
        splitType: 'equal',
        splits: [
          { memberId: guestMember.id, amountInPaise: 500000 },
          { memberId: tripRes.data.data.members[1].id, amountInPaise: 500000 },
        ],
      },
    });
    assert.strictEqual(expRes.status, 201);
  });

  it('2. Guest signs in with Google: Account is linked & all data atomically migrated', async () => {
    const googleRes = await api('/api/auth/google', {
      method: 'POST',
      body: {
        email: 'darpan.traveler@gmail.com',
        displayName: 'Darpan Cloud',
        googleId: 'google_oauth_sub_998877',
        supabaseUserId: 'supabase_uid_darpan_123',
        currentGuestUserId: guestUserId,
      },
    });

    assert.strictEqual(googleRes.status, 200);
    canonicalUserA = googleRes.data.data.user;
    tokenA = googleRes.data.data.token;
    assert.strictEqual(canonicalUserA.email, 'darpan.traveler@gmail.com');
    assert.strictEqual(canonicalUserA.isGuest, false);

    // Verify all records were migrated to canonical user ID
    const personalExpenses = await api('/api/personal/expenses', { token: tokenA });
    assert.strictEqual(personalExpenses.status, 200);
    assert.strictEqual(personalExpenses.data.expenses.length, 1);
    assert.strictEqual(personalExpenses.data.expenses[0].title, 'Morning Coffee');

    const personalDebts = await api('/api/personal/debts', { token: tokenA });
    assert.strictEqual(personalDebts.status, 200);
    assert.strictEqual(personalDebts.data.debts.length, 1);
    assert.strictEqual(personalDebts.data.debts[0].personName, 'Rohan');

    const trips = await api('/api/trips', { token: tokenA });
    assert.strictEqual(trips.status, 200);
    assert.strictEqual(trips.data.data.length, 1);
    assert.strictEqual(trips.data.data[0].id, trip1Id);
    assert.strictEqual(trips.data.data[0].creatorId, canonicalUserA.id);
  });

  it('3. Idempotent login: Same Google account logs in again -> resolves exact SAME Kith user', async () => {
    const loginAgainRes = await api('/api/auth/google', {
      method: 'POST',
      body: {
        email: 'darpan.traveler@gmail.com',
        displayName: 'Darpan Cloud',
        googleId: 'google_oauth_sub_998877',
        supabaseUserId: 'supabase_uid_darpan_123',
      },
    });

    assert.strictEqual(loginAgainRes.status, 200);
    const userAgain = loginAgainRes.data.data.user;
    assert.strictEqual(userAgain.id, canonicalUserA.id, 'User ID must be strictly identical');
    assert.strictEqual(userAgain.email, canonicalUserA.email);
  });

  it('4. FRESH INSTALL / DEVICE B SIMULATION: Logging in with Google Account A restores full cloud state', async () => {
    // Device B signs in with the same Google account
    const deviceBAuth = await api('/api/auth/google', {
      method: 'POST',
      body: {
        email: 'darpan.traveler@gmail.com',
        displayName: 'Darpan Cloud',
        googleId: 'google_oauth_sub_998877',
        supabaseUserId: 'supabase_uid_darpan_123',
      },
    });

    assert.strictEqual(deviceBAuth.status, 200);
    const tokenB = deviceBAuth.data.data.token;
    const userB = deviceBAuth.data.data.user;
    assert.strictEqual(userB.id, canonicalUserA.id);

    // 1. Device B fetches personal expenses -> returns 1
    const pexpB = await api('/api/personal/expenses', { token: tokenB });
    assert.strictEqual(pexpB.status, 200);
    assert.strictEqual(pexpB.data.expenses.length, 1);
    assert.strictEqual(pexpB.data.expenses[0].title, 'Morning Coffee');

    // 2. Device B fetches debts -> returns 1
    const debtsB = await api('/api/personal/debts', { token: tokenB });
    assert.strictEqual(debtsB.status, 200);
    assert.strictEqual(debtsB.data.debts.length, 1);

    // 3. Device B fetches budget -> returns 5000000 limit
    const budgetB = await api('/api/personal/budget?month=2026-08', { token: tokenB });
    assert.strictEqual(budgetB.status, 200);
    assert.strictEqual(budgetB.data.monthlyLimitInPaise, 5000000);

    // 4. Device B fetches trips -> returns 1
    const tripsB = await api('/api/trips', { token: tokenB });
    assert.strictEqual(tripsB.status, 200);
    assert.strictEqual(tripsB.data.data.length, 1);
    assert.strictEqual(tripsB.data.data[0].id, trip1Id);

    // 5. Device B fetches trip expenses -> returns 1
    const tripExpensesB = await api(`/api/trips/${trip1Id}/expenses`, { token: tokenB });
    assert.strictEqual(tripExpensesB.status, 200);
    assert.strictEqual(tripExpensesB.data.data.length, 1);
    assert.strictEqual(tripExpensesB.data.data[0].title, 'Resort Booking');
  });

  it('5. Cross-Device Sync: Device B adds an expense; Device A queries and receives it', async () => {
    // Device B adds an expense to personal ledger
    const newPersonalRes = await api('/api/personal/expenses', {
      method: 'POST',
      token: tokenA,
      body: {
        title: 'Airport Taxi',
        amountInPaise: 65000,
        category: 'transport',
      },
    });
    assert.strictEqual(newPersonalRes.status, 201);

    // Device A lists personal expenses -> now has 2
    const listResA = await api('/api/personal/expenses', { token: tokenA });
    assert.strictEqual(listResA.status, 200);
    assert.strictEqual(listResA.data.expenses.length, 2);
    assert.ok(listResA.data.expenses.some((e) => e.title === 'Airport Taxi'));
  });

  it('6. Account Isolation: Google Account B logs in -> receives ZERO data from Account A', async () => {
    const authResAccountB = await api('/api/auth/google', {
      method: 'POST',
      body: {
        email: 'stranger.danger@gmail.com',
        displayName: 'Stranger',
        googleId: 'google_sub_stranger_555',
        supabaseUserId: 'supabase_uid_stranger_555',
      },
    });

    assert.strictEqual(authResAccountB.status, 200);
    const tokenStranger = authResAccountB.data.data.token;
    const userStranger = authResAccountB.data.data.user;
    assert.notStrictEqual(userStranger.id, canonicalUserA.id);

    // Stranger queries personal expenses
    const pexpStranger = await api('/api/personal/expenses', { token: tokenStranger });
    assert.strictEqual(pexpStranger.status, 200);
    assert.strictEqual(pexpStranger.data.expenses.length, 0, 'Stranger must see 0 personal expenses');

    // Stranger queries personal debts
    const debtsStranger = await api('/api/personal/debts', { token: tokenStranger });
    assert.strictEqual(debtsStranger.status, 200);
    assert.strictEqual(debtsStranger.data.debts.length, 0, 'Stranger must see 0 debts');

    // Stranger queries trips
    const tripsStranger = await api('/api/trips', { token: tokenStranger });
    assert.strictEqual(tripsStranger.status, 200);
    assert.strictEqual(tripsStranger.data.data.length, 0, 'Stranger must see 0 trips');

    // Stranger attempts to read Trip A expenses directly -> 403 Forbidden
    const forbiddenExp = await api(`/api/trips/${trip1Id}/expenses`, { token: tokenStranger });
    assert.strictEqual(forbiddenExp.status, 403, 'Non-member must be forbidden from trip expenses');
  });

  it('7. User A logs back in: All data restored cleanly without duplicates', async () => {
    const reloginRes = await api('/api/auth/google', {
      method: 'POST',
      body: {
        email: 'darpan.traveler@gmail.com',
        displayName: 'Darpan Cloud',
        googleId: 'google_oauth_sub_998877',
      },
    });

    assert.strictEqual(reloginRes.status, 200);
    const reloginToken = reloginRes.data.data.token;

    const finalPexp = await api('/api/personal/expenses', { token: reloginToken });
    assert.strictEqual(finalPexp.status, 200);
    assert.strictEqual(finalPexp.data.expenses.length, 2);

    const finalTrips = await api('/api/trips', { token: reloginToken });
    assert.strictEqual(finalTrips.status, 200);
    assert.strictEqual(finalTrips.data.data.length, 1);
  });
});
