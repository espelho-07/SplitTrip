const test = require('node:test');
const assert = require('node:assert');
const tripService = require('../src/services/trip_service');
const { db } = require('../src/db/database');
const { AppError } = require('../src/middleware/error_handler');

test.beforeEach(() => {
  db.clearAll();
});

test('Trip Member Claim & Duplicate Prevention Tests', async (t) => {
  const creator = { id: 'usr_creator', displayName: 'Darpan', avatarUrl: null, upiId: 'darpan@upi' };
  const rahulUser = { id: 'usr_rahul', displayName: 'Rahul Sharma', avatarUrl: 'https://avatar.com/rahul.png', upiId: 'rahul@upi' };
  const amanUser = { id: 'usr_aman', displayName: 'Aman Verma', avatarUrl: null, upiId: 'aman@upi' };

  await t.test('1. Pre-added friend starts as UNCLAIMED with unique claimToken and no real userId', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Goa Trip',
      initialFriendNames: ['Rahul'],
    });

    assert.strictEqual(trip.members.length, 2);
    const creatorMember = trip.members.find((m) => m.role === 'creator');
    const rahulMember = trip.members.find((m) => m.displayName === 'Rahul');

    assert.strictEqual(creatorMember.isClaimed, true);
    assert.strictEqual(creatorMember.status, 'claimed');
    assert.strictEqual(creatorMember.userId, 'usr_creator');

    assert.strictEqual(rahulMember.isClaimed, false);
    assert.strictEqual(rahulMember.status, 'unclaimed');
    assert.ok(rahulMember.userId.startsWith('unclaimed_'));
    assert.ok(rahulMember.claimToken.startsWith('clm_'));

    // Check preview endpoint returns unclaimedMembers
    const preview = tripService.getTripPreviewByCode(trip.inviteCode);
    assert.strictEqual(preview.unclaimedMembers.length, 1);
    assert.strictEqual(preview.unclaimedMembers[0].id, rahulMember.id);
    assert.strictEqual(preview.unclaimedMembers[0].displayName, 'Rahul');
  });

  await t.test('2. Real user claims existing unclaimed member -> Updates record in-place with NO duplicates', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Goa Trip',
      initialFriendNames: ['Rahul'],
    });
    const placeholderMember = trip.members.find((m) => m.displayName === 'Rahul');

    // Attach expense to placeholder member before Rahul joins
    const expenseService = require('../src/services/expense_service');
    expenseService.createExpense(creator, trip.id, {
      title: 'Dinner at Beach Shack',
      amountInPaise: 200000,
      paidById: trip.members.find((m) => m.role === 'creator').id,
      splits: [
        { memberId: trip.members.find((m) => m.role === 'creator').id, amountInPaise: 150000 },
        { memberId: placeholderMember.id, amountInPaise: 50000 },
      ],
    });

    // Rahul joins and claims placeholder
    const updatedTrip = tripService.joinTripByCode(rahulUser, trip.inviteCode, {
      claimMemberId: placeholderMember.id,
    });

    // Exactly 2 members exist in trip
    assert.strictEqual(updatedTrip.members.length, 2);
    const claimedRahul = updatedTrip.members.find((m) => m.id === placeholderMember.id);

    assert.ok(claimedRahul);
    assert.strictEqual(claimedRahul.userId, rahulUser.id);
    assert.strictEqual(claimedRahul.isClaimed, true);
    assert.strictEqual(claimedRahul.status, 'claimed');
    assert.strictEqual(claimedRahul.avatarUrl, rahulUser.avatarUrl);

    // Verify financial integrity: split remains attached to the claimed member ID
    const expenses = expenseService.getExpenses(trip.id, creator.id);
    assert.strictEqual(expenses.length, 1);
    assert.strictEqual(expenses[0].splits[1].memberId, claimedRahul.id);
    assert.strictEqual(expenses[0].splits[1].amountInPaise, 50000);
  });

  await t.test('3. Second scan by same user is idempotent -> No duplicate member created', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Goa Trip',
      initialFriendNames: ['Rahul'],
    });
    const placeholder = trip.members.find((m) => m.displayName === 'Rahul');

    // First scan: claims member
    const firstJoin = tripService.joinTripByCode(rahulUser, trip.inviteCode, {
      claimMemberId: placeholder.id,
    });
    assert.strictEqual(firstJoin.members.length, 2);

    // Second scan: already a member
    const secondJoin = tripService.joinTripByCode(rahulUser, trip.inviteCode);
    assert.strictEqual(secondJoin.members.length, 2);
    assert.strictEqual(secondJoin.members.filter((m) => m.userId === rahulUser.id).length, 1);
  });

  await t.test('4. Double claim / Concurrency protection: claiming already-claimed member throws 409 Conflict', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Goa Trip',
      initialFriendNames: ['Rahul'],
    });
    const placeholder = trip.members.find((m) => m.displayName === 'Rahul');

    // Device A claims Rahul
    tripService.joinTripByCode(rahulUser, trip.inviteCode, { claimMemberId: placeholder.id });

    // Device B attempts to claim same Rahul with different user
    assert.throws(() => {
      tripService.joinTripByCode(amanUser, trip.inviteCode, { claimMemberId: placeholder.id });
    }, (err) => err.statusCode === 409 || err.message.includes('already been claimed'));
  });

  await t.test('5. Wrong user (Aman) joins as new member -> Leaves unclaimed Rahul untouched', () => {
    const trip = tripService.createTrip(creator, {
      name: 'Goa Trip',
      initialFriendNames: ['Rahul'],
    });
    const placeholder = trip.members.find((m) => m.displayName === 'Rahul');

    // Aman joins as new member (does NOT claim Rahul)
    const updatedTrip = tripService.joinTripByCode(amanUser, trip.inviteCode, { claimMemberId: null });

    assert.strictEqual(updatedTrip.members.length, 3);
    const rahulStillUnclaimed = updatedTrip.members.find((m) => m.id === placeholder.id);
    const amanClaimed = updatedTrip.members.find((m) => m.userId === amanUser.id);

    assert.strictEqual(rahulStillUnclaimed.isClaimed, false);
    assert.strictEqual(rahulStillUnclaimed.status, 'unclaimed');
    assert.strictEqual(amanClaimed.isClaimed, true);
    assert.strictEqual(amanClaimed.status, 'claimed');
  });

  await t.test('6. Database constraint: prevents duplicate real user insertions for same trip', () => {
    const trip = tripService.createTrip(creator, { name: 'Manali Trip' });

    assert.throws(() => {
      db.insert('trip_members', {
        id: 'mbr_duplicate_test',
        tripId: trip.id,
        userId: creator.id, // Duplicate userId in same trip
        displayName: 'Duplicate Darpan',
      });
    }, (err) => err.message.includes('already a member'));
  });
});
