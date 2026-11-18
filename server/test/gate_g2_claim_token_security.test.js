const test = require('node:test');
const assert = require('node:assert');
const tripService = require('../src/services/trip_service');
const { db } = require('../src/db/database');
const { AppError } = require('../src/middleware/error_handler');

test.beforeEach(() => {
  db.clearAll();
});

test('Gate G.2: Claim Token Security, Validation & IDOR Protection Suite', async (t) => {
  const creator = { id: 'usr_creator', displayName: 'Creator Dj', avatarUrl: null, upiId: 'creator@upi' };
  const userBob = { id: 'usr_bob', displayName: 'Bob Real', avatarUrl: 'https://avatar.com/bob.png', upiId: 'bob@upi' };
  const attackerEve = { id: 'usr_eve', displayName: 'Eve Malicious', avatarUrl: null, upiId: 'eve@upi' };

  await t.test('1. getTripPreviewByCode NEVER leaks claimToken in unclaimedMembers', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Secret Party',
      initialFriendNames: ['Bob', 'Charlie'],
    });

    const preview = tripService.getTripPreviewByCode(trip.inviteCode);
    assert.strictEqual(preview.unclaimedMembers.length, 2);

    for (const member of preview.unclaimedMembers) {
      assert.strictEqual(member.claimToken, undefined, 'claimToken must be stripped from public preview');
      assert.ok(member.id.startsWith('mbr_'));
      assert.ok(member.displayName);
    }
  });

  await t.test('2. Claiming with VALID claimToken succeeds atomically', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Beach Trip',
      initialFriendNames: ['Bob'],
    });

    const bobPlaceholder = trip.members.find((m) => m.displayName === 'Bob');
    assert.ok(bobPlaceholder.claimToken, 'Virtual member must be initialized with claimToken');
    const secretToken = bobPlaceholder.claimToken;

    const updatedTrip = tripService.joinTripByCode(userBob, trip.inviteCode, {
      claimMemberId: bobPlaceholder.id,
      claimToken: secretToken,
    });

    const claimedBob = updatedTrip.members.find((m) => m.id === bobPlaceholder.id);
    assert.strictEqual(claimedBob.userId, userBob.id);
    assert.strictEqual(claimedBob.isClaimed, true);
    assert.strictEqual(claimedBob.status, 'claimed');
  });

  await t.test('3. Claiming with MISSING claimToken is rejected with 403 Forbidden', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Beach Trip',
      initialFriendNames: ['Bob'],
    });

    const bobPlaceholder = trip.members.find((m) => m.displayName === 'Bob');

    assert.throws(() => {
      // Attacker Eve knows bobPlaceholder.id but does NOT have claimToken
      tripService.joinTripByCode(attackerEve, trip.inviteCode, {
        claimMemberId: bobPlaceholder.id,
      });
    }, (err) => {
      assert.strictEqual(err.statusCode, 403);
      assert.strictEqual(err.code, 'FORBIDDEN');
      assert.strictEqual(err.message, 'Invalid or missing claim token for this participant.');
      return true;
    });
  });

  await t.test('4. Claiming with INCORRECT claimToken is rejected with 403 Forbidden', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Beach Trip',
      initialFriendNames: ['Bob'],
    });

    const bobPlaceholder = trip.members.find((m) => m.displayName === 'Bob');

    assert.throws(() => {
      tripService.joinTripByCode(attackerEve, trip.inviteCode, {
        claimMemberId: bobPlaceholder.id,
        claimToken: 'clm_forged_guess_12345',
      });
    }, (err) => {
      assert.strictEqual(err.statusCode, 403);
      assert.strictEqual(err.code, 'FORBIDDEN');
      assert.strictEqual(err.message, 'Invalid or missing claim token for this participant.');
      return true;
    });
  });

  await t.test('5. Double claim prevention: already-claimed member throws 409 Conflict', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Beach Trip',
      initialFriendNames: ['Bob'],
    });

    const bobPlaceholder = trip.members.find((m) => m.displayName === 'Bob');
    const secretToken = bobPlaceholder.claimToken;

    // Legitimate claim
    tripService.joinTripByCode(userBob, trip.inviteCode, {
      claimMemberId: bobPlaceholder.id,
      claimToken: secretToken,
    });

    // Replay attack with same token
    assert.throws(() => {
      tripService.joinTripByCode(attackerEve, trip.inviteCode, {
        claimMemberId: bobPlaceholder.id,
        claimToken: secretToken,
      });
    }, (err) => {
      assert.strictEqual(err.statusCode, 409);
      assert.strictEqual(err.code, 'CONFLICT');
      assert.ok(err.message.includes('already been claimed'));
      return true;
    });
  });

  await t.test('6. Legacy member without claimToken: unauthorized non-creator is rejected (403)', () => {
    const trip = tripService.createTrip(creator, { name: 'Legacy Trip' });

    // Manually simulate a legacy member created before claim tokens existed
    const legacyMemberId = 'mbr_legacy_001';
    db.insert('trip_members', {
      id: legacyMemberId,
      tripId: trip.id,
      userId: 'unclaimed_leg_01',
      displayName: 'Legacy Friend',
      avatarUrl: null,
      role: 'member',
      status: 'unclaimed',
      isClaimed: false,
      claimToken: null, // Legacy: no token
      joinedAt: new Date().toISOString(),
      lastSeenAt: new Date().toISOString(),
      lastSyncedRevision: 1,
      pendingMutationsCount: 0,
    });

    // Eve tries to claim legacy member
    assert.throws(() => {
      tripService.joinTripByCode(attackerEve, trip.inviteCode, {
        claimMemberId: legacyMemberId,
      });
    }, (err) => {
      assert.strictEqual(err.statusCode, 403);
      assert.strictEqual(err.code, 'FORBIDDEN');
      assert.ok(err.message.includes('requires creator authorization'));
      return true;
    });
  });

  await t.test('7. Legacy member without claimToken: creator CAN reclaim their own slot', () => {
    const trip = tripService.createTrip(creator, { name: 'Legacy Trip 2' });

    // Legacy un-tokened slot
    const legacyCreatorSlotId = 'mbr_legacy_slot_dj';
    db.insert('trip_members', {
      id: legacyCreatorSlotId,
      tripId: trip.id,
      userId: 'unclaimed_dj_slot',
      displayName: 'Dj Placeholder',
      avatarUrl: null,
      role: 'member',
      status: 'unclaimed',
      isClaimed: false,
      claimToken: null,
      joinedAt: new Date().toISOString(),
      lastSeenAt: new Date().toISOString(),
      lastSyncedRevision: 1,
      pendingMutationsCount: 0,
    });

    // Create a new session for creator with same creator.id
    // But remove creator's original membership to simulate restoring/claiming
    const originalCreatorMember = db.findOne('trip_members', (m) => m.tripId === trip.id && m.userId === creator.id);
    if (originalCreatorMember) {
      db.delete('trip_members', originalCreatorMember.id);
    }

    const updated = tripService.joinTripByCode(creator, trip.inviteCode, {
      claimMemberId: legacyCreatorSlotId,
    });

    const claimed = updated.members.find((m) => m.id === legacyCreatorSlotId);
    assert.strictEqual(claimed.userId, creator.id);
    assert.strictEqual(claimed.isClaimed, true);
  });

  await t.test('8. Error messages and activity logs never leak claim tokens', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Safe Trip',
      initialFriendNames: ['Alice'],
    });

    const alice = trip.members.find((m) => m.displayName === 'Alice');
    const secret = alice.claimToken;

    // Trigger failure
    try {
      tripService.joinTripByCode(attackerEve, trip.inviteCode, {
        claimMemberId: alice.id,
        claimToken: 'bad_token',
      });
    } catch (e) {
      assert.ok(!e.message.includes(secret), 'Error message must never contain secret token');
      assert.ok(!e.message.includes('bad_token'), 'Error message must never echo supplied token');
    }

    // Trigger success
    tripService.joinTripByCode(userBob, trip.inviteCode, {
      claimMemberId: alice.id,
      claimToken: secret,
    });

    // Check activity log
    const activities = db.find('activity_logs', (a) => a.tripId === trip.id);
    for (const act of activities) {
      const actStr = JSON.stringify(act);
      assert.ok(!actStr.includes(secret), 'Activity log must never contain secret token');
    }
  });
});
