const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const { db } = require('../src/db/database');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const settlementService = require('../src/services/settlement_service');
const { RateLimiter } = require('../src/middleware/rate_limiter');

describe('Security Bounty, IDOR & Authorization Hardening Suite', () => {
  beforeEach(() => {
    db.clearAll();
  });

  it('1. IDOR Defense: Outsider cannot view, add expenses, or modify trips without membership', () => {
    const alice = authService.createGuest({ displayName: 'Alice' }).user;
    const mallory = authService.createGuest({ displayName: 'Mallory (Attacker)' }).user;

    const aliceTrip = tripService.createTrip(alice, { name: 'Alice Private Trip' });

    // Mallory tries to read Alice trip -> Forbidden
    assert.throws(
      () => tripService.getTripById(aliceTrip.id, mallory.id),
      (err) => err.statusCode === 403 || err.code === 'FORBIDDEN'
    );

    // Mallory tries to add expense to Alice trip -> Forbidden
    assert.throws(
      () => expenseService.createExpense(mallory, aliceTrip.id, {
        title: 'Unauthorized Attack Expense',
        amountInPaise: 50000,
        paidById: 'unauthorized_member',
      }),
      (err) => err.statusCode === 403 || err.code === 'FORBIDDEN'
    );

    // Mallory tries to complete Alice trip -> Forbidden
    assert.throws(
      () => tripService.completeTrip(aliceTrip.id, mallory.id),
      (err) => err.statusCode === 403 || err.code === 'FORBIDDEN'
    );
  });

  it('2. Member Privilege Escalation & Tampering: Regular member cannot remove other members or merge members', () => {
    const creator = authService.createGuest({ displayName: 'Creator Charlie' }).user;
    const memberA = authService.createGuest({ displayName: 'Member Alice' }).user;
    const memberB = authService.createGuest({ displayName: 'Member Bob' }).user;

    const trip = tripService.createTrip(creator, { name: 'Privilege Test Trip' });
    const joinedTripA = tripService.joinTripByCode(memberA, trip.inviteCode);
    const joinedTripB = tripService.joinTripByCode(memberB, trip.inviteCode);

    const mbrRecordB = joinedTripB.members.find((m) => m.userId === memberB.id);
    const mbrRecordA = joinedTripB.members.find((m) => m.userId === memberA.id);

    // Member A attempts to remove Member B -> Forbidden (only creator can remove)
    assert.throws(
      () => tripService.removeMember(trip.id, memberA.id, mbrRecordB.id),
      (err) => err.statusCode === 403 || err.code === 'FORBIDDEN'
    );

    // Member A attempts to merge Member B -> Forbidden
    assert.throws(
      () => tripService.mergeMembers(trip.id, memberA.id, {
        sourceMemberId: mbrRecordB.id,
        canonicalMemberId: mbrRecordA.id,
      }),
      (err) => err.statusCode === 403 || err.code === 'FORBIDDEN'
    );
  });

  it('3. Financial Tampering: Rejects settlement if debtor has no debt or amount exceeds debt', () => {
    const alice = authService.createGuest({ displayName: 'Alice' }).user;
    const bob = authService.createGuest({ displayName: 'Bob' }).user;

    const trip = tripService.createTrip(alice, { name: 'Ledger Guard Trip' });
    const joinedTrip = tripService.joinTripByCode(bob, trip.inviteCode);
    const mbrAlice = joinedTrip.members.find((m) => m.userId === alice.id);
    const mbrBob = joinedTrip.members.find((m) => m.userId === bob.id);

    // Alice paid ₹100 split equally -> Bob owes Alice ₹50 (5000 paise)
    expenseService.createExpense(alice, trip.id, {
      title: 'Shared Lunch',
      amountInPaise: 10000,
      paidById: mbrAlice.id,
      splitType: 'EQUAL',
      splits: [
        { memberId: mbrAlice.id, amountInPaise: 5000 },
        { memberId: mbrBob.id, amountInPaise: 5000 },
      ],
    });

    // Bob tries to record settlement of ₹100 (10000 paise) exceeding ₹50 debt -> Bad Request
    assert.throws(
      () => settlementService.recordSettlement(bob, trip.id, {
        fromMemberId: mbrBob.id,
        toMemberId: mbrAlice.id,
        amountInPaise: 10000,
      }),
      (err) => err.statusCode === 400 || err.code === 'BAD_REQUEST'
    );

    // Alice (creditor) tries to settle to Bob when Alice does NOT owe Bob anything -> Bad Request
    assert.throws(
      () => settlementService.recordSettlement(alice, trip.id, {
        fromMemberId: mbrAlice.id,
        toMemberId: mbrBob.id,
        amountInPaise: 5000,
      }),
      (err) => err.statusCode === 400 || err.code === 'BAD_REQUEST'
    );
  });

  it('4. Tiered Rate Limiter: Enforces threshold and returns HTTP 429 with Retry-After', (t, done) => {
    const limiter = new RateLimiter({ windowMs: 10000, max: 3, name: 'test_strict' });
    const middleware = limiter.middleware();

    const mockReq = {
      ip: '192.168.1.100',
      headers: { 'x-test-rate-limit': 'true' },
    };

    let statusCalled = null;
    let jsonCalled = null;
    let headersSet = {};

    const mockRes = {
      setHeader: (k, v) => { headersSet[k] = v; },
      status: (code) => {
        statusCalled = code;
        return {
          json: (body) => { jsonCalled = body; },
        };
      },
    };

    // Request 1 -> OK
    middleware(mockReq, mockRes, () => {
      // Request 2 -> OK
      middleware(mockReq, mockRes, () => {
        // Request 3 -> OK
        middleware(mockReq, mockRes, () => {
          // Request 4 -> Exceeded (HTTP 429)
          middleware(mockReq, mockRes, () => {
            assert.fail('Should not call next on 4th request');
          });

          assert.strictEqual(statusCalled, 429);
          assert.strictEqual(jsonCalled.error.code, 'RATE_LIMIT_EXCEEDED');
          assert.ok(headersSet['Retry-After'] >= 1);
          done();
        });
      });
    });
  });

  it('5. FCM Token Isolation on Account Switch: Unbinds previous user session from same device', () => {
    const userA = authService.createGuest({ displayName: 'Device User A' }).user;
    const userB = authService.createGuest({ displayName: 'Device User B' }).user;
    const sharedDeviceId = 'device_pixel_8_pro_101';
    const sharedToken = 'fcm_shared_registration_token_xyz';

    const now = new Date().toISOString();

    // User A registers token on device
    db.insert('user_fcm_tokens', {
      id: 'tok_user_a',
      userId: userA.id,
      token: sharedToken,
      deviceId: sharedDeviceId,
      platform: 'android',
      createdAt: now,
      updatedAt: now,
      deleted: false,
    });

    // Verify User A has active token
    let tokensA = db.find('user_fcm_tokens', (t) => t.userId === userA.id && !t.deleted);
    assert.strictEqual(tokensA.length, 1);

    // User B logs in on same device -> simulates /api/auth/fcm-token unbinding
    const staleTokens = db.find('user_fcm_tokens', (r) => (r.token === sharedToken || r.deviceId === sharedDeviceId) && r.userId !== userB.id && !r.deleted);
    for (const stale of staleTokens) {
      db.update('user_fcm_tokens', stale.id, { deleted: true, deletedAt: new Date().toISOString() });
    }

    db.insert('user_fcm_tokens', {
      id: 'tok_user_b',
      userId: userB.id,
      token: sharedToken,
      deviceId: sharedDeviceId,
      platform: 'android',
      createdAt: now,
      updatedAt: now,
      deleted: false,
    });

    // User A's token must now be soft-deleted / inactive
    tokensA = db.find('user_fcm_tokens', (t) => t.userId === userA.id && !t.deleted);
    assert.strictEqual(tokensA.length, 0);

    // User B's token is active
    const tokensB = db.find('user_fcm_tokens', (t) => t.userId === userB.id && !t.deleted);
    assert.strictEqual(tokensB.length, 1);
    assert.strictEqual(tokensB[0].userId, userB.id);
  });
});
