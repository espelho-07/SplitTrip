const test = require('node:test');
const assert = require('node:assert');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const settlementService = require('../src/services/settlement_service');
const { db } = require('../src/db/database');
const { AppError } = require('../src/middleware/error_handler');

test.beforeEach(() => {
  db.clearAll();
});

test('Trip Member Management & Member Merge Test Suite', async (t) => {
  const creator = { id: 'usr_creator', displayName: 'Darpan', avatarUrl: null, upiId: 'darpan@upi' };
  const rahulUser = { id: 'usr_rahul', displayName: 'Rahul Patel', avatarUrl: 'https://avatar.com/rahul.png', upiId: 'rahul@upi' };
  const hardevUser = { id: 'usr_hardev', displayName: 'Hardev', avatarUrl: null, upiId: 'hardev@upi' };
  const strangerUser = { id: 'usr_stranger', displayName: 'Stranger', avatarUrl: null, upiId: 'stranger@upi' };

  await t.test('1. Creator adds unclaimed participant to trip', () => {
    const trip = tripService.createTrip(creator, { name: 'Goa Trip' });
    assert.strictEqual(trip.members.length, 1);

    const updated = tripService.addMember(trip.id, creator.id, { displayName: 'Rahul P' });
    assert.strictEqual(updated.members.length, 2);

    const added = updated.members.find((m) => m.displayName === 'Rahul P');
    assert.ok(added);
    assert.strictEqual(added.isClaimed, false);
    assert.strictEqual(added.status, 'unclaimed');
    assert.ok(added.userId.startsWith('unclaimed_'));
  });

  await t.test('2. Creator renames unclaimed member', () => {
    const trip = tripService.createTrip(creator, { name: 'Goa Trip', initialFriendNames: ['Rahul P'] });
    const member = trip.members.find((m) => m.displayName === 'Rahul P');

    const updated = tripService.renameMember(trip.id, creator.id, member.id, 'Rahul Patel');
    const renamed = updated.members.find((m) => m.id === member.id);
    assert.strictEqual(renamed.displayName, 'Rahul Patel');
  });

  await t.test('3. Rejects renaming registered real Kith users', () => {
    const trip = tripService.createTrip(creator, { name: 'Goa Trip' });
    tripService.joinTripByCode(rahulUser, trip.inviteCode);
    const updated = tripService.getTripById(trip.id, creator.id);
    const rahulMember = updated.members.find((m) => m.userId === rahulUser.id);

    assert.throws(
      () => tripService.renameMember(trip.id, creator.id, rahulMember.id, 'Impostor Rahul'),
      /Cannot rename registered Kith users/
    );
  });

  await t.test('4. Creator removes unclaimed member with ZERO financial activity', () => {
    const trip = tripService.createTrip(creator, { name: 'Goa Trip', initialFriendNames: ['Ghost Member'] });
    assert.strictEqual(trip.members.length, 2);
    const ghost = trip.members.find((m) => m.displayName === 'Ghost Member');

    const updated = tripService.removeMember(trip.id, creator.id, ghost.id);
    assert.strictEqual(updated.members.length, 1);
    assert.strictEqual(updated.members.find((m) => m.id === ghost.id), undefined);
  });

  await t.test('5. Blocks removing member with linked expenses or splits (Financial Safety)', () => {
    const trip = tripService.createTrip(creator, { name: 'Goa Trip', initialFriendNames: ['Rahul'] });
    const creatorM = trip.members.find((m) => m.role === 'creator');
    const rahulM = trip.members.find((m) => m.displayName === 'Rahul');

    // Create expense where Rahul is in splits
    expenseService.createExpense(creator, trip.id, {
      title: 'Dinner',
      amountInPaise: 100000,
      paidById: creatorM.id,
      splits: [
        { memberId: creatorM.id, amountInPaise: 50000 },
        { memberId: rahulM.id, amountInPaise: 50000 },
      ],
    });

    assert.throws(
      () => tripService.removeMember(trip.id, creator.id, rahulM.id),
      /Cannot remove member with financial activity/
    );
  });

  await t.test('6. Merge unclaimed member into real Kith user preserves all expenses, splits and balances', () => {
    // Scenario:
    // Trip Creator: Darpan
    // Members:
    //   - Unclaimed "Rahul" (mbr_unclaimed)
    //   - Real Kith user "Rahul Patel" (mbr_real)
    //   - Hardev (mbr_hardev)
    const trip = tripService.createTrip(creator, { name: 'Goa Trip', initialFriendNames: ['Rahul'] });
    const unclaimedRahul = trip.members.find((m) => m.displayName === 'Rahul');

    // Rahul Patel and Hardev join as real users
    tripService.joinTripByCode(rahulUser, trip.inviteCode);
    tripService.joinTripByCode(hardevUser, trip.inviteCode);

    const tripWithAll = tripService.getTripById(trip.id, creator.id);
    const creatorM = tripWithAll.members.find((m) => m.role === 'creator');
    const realRahul = tripWithAll.members.find((m) => m.userId === rahulUser.id);
    const hardevM = tripWithAll.members.find((m) => m.userId === hardevUser.id);

    // Expense 1: Paid by Unclaimed Rahul (₹1,200 total), split between Rahul (₹600) and Hardev (₹600)
    const { expense: exp1 } = expenseService.createExpense(creator, trip.id, {
      title: 'Breakfast by Unclaimed Rahul',
      amountInPaise: 120000,
      paidById: unclaimedRahul.id,
      splits: [
        { memberId: unclaimedRahul.id, amountInPaise: 60000 },
        { memberId: hardevM.id, amountInPaise: 60000 },
      ],
    });

    // Expense 2: Paid by Creator (₹2,000 total), split across creator (₹1,000) and Real Rahul Patel (₹1,000)
    const { expense: exp2 } = expenseService.createExpense(creator, trip.id, {
      title: 'Cab by Creator',
      amountInPaise: 200000,
      paidById: creatorM.id,
      splits: [
        { memberId: creatorM.id, amountInPaise: 100000 },
        { memberId: realRahul.id, amountInPaise: 100000 },
      ],
    });

    // Settlement: Hardev paid ₹300 to Unclaimed Rahul (Hardev owes ₹600 from exp1)
    settlementService.recordSettlement(hardevUser, trip.id, {
      fromMemberId: hardevM.id,
      toMemberId: unclaimedRahul.id,
      amountInPaise: 30000,
      recipientUpiId: 'rahul@upi',
      status: 'marked_paid',
    });

    // EXECUTE MERGE: Merge Unclaimed Rahul -> Real Rahul Patel (Keep Rahul Patel)
    const mergedTrip = tripService.mergeMembers(trip.id, creator.id, {
      sourceMemberId: unclaimedRahul.id,
      canonicalMemberId: realRahul.id,
      operationId: 'op_merge_test_1',
    });

    // Assert: Exactly 3 active participants remain (Darpan, Rahul Patel, Hardev)
    assert.strictEqual(mergedTrip.members.length, 3);
    assert.strictEqual(mergedTrip.members.find((m) => m.id === unclaimedRahul.id), undefined);
    assert.ok(mergedTrip.members.find((m) => m.id === realRahul.id));

    // Assert: Expense 1 payer repointed to Real Rahul Patel
    const updatedExp1 = db.get('expenses', exp1.id);
    assert.strictEqual(updatedExp1.paidById, realRahul.id);
    const exp1RahulSplit = updatedExp1.splits.find((s) => s.memberId === realRahul.id);
    assert.ok(exp1RahulSplit);
    assert.strictEqual(exp1RahulSplit.amountInPaise, 60000);

    // Assert: Settlements repointed to Real Rahul Patel
    const settlements = settlementService.getSettlementsForTrip(creator, trip.id);
    assert.strictEqual(settlements.length, 1);
    assert.strictEqual(settlements[0].toMemberId, realRahul.id);
    assert.strictEqual(settlements[0].fromMemberId, hardevM.id);
  });

  await t.test('7. Merge combines split shares if both duplicate members were in the same expense', () => {
    const trip = tripService.createTrip(creator, { name: 'Goa Trip', initialFriendNames: ['Rahul Dup 1', 'Rahul Dup 2'] });
    const m1 = trip.members.find((m) => m.displayName === 'Rahul Dup 1');
    const m2 = trip.members.find((m) => m.displayName === 'Rahul Dup 2');
    const creatorM = trip.members.find((m) => m.role === 'creator');

    // Expense where BOTH duplicates have splits
    const { expense: exp } = expenseService.createExpense(creator, trip.id, {
      title: 'Big Dinner',
      amountInPaise: 300000,
      paidById: creatorM.id,
      splits: [
        { memberId: creatorM.id, amountInPaise: 100000 },
        { memberId: m1.id, amountInPaise: 100000 },
        { memberId: m2.id, amountInPaise: 100000 },
      ],
    });

    // Merge m2 into m1
    tripService.mergeMembers(trip.id, creator.id, {
      sourceMemberId: m2.id,
      canonicalMemberId: m1.id,
    });

    const updatedExp = db.get('expenses', exp.id);
    assert.strictEqual(updatedExp.splits.length, 2); // m1 and creator
    const combinedSplit = updatedExp.splits.find((s) => s.memberId === m1.id);
    assert.strictEqual(combinedSplit.amountInPaise, 200000); // 100k + 100k
  });

  await t.test('8. Rejects merging two distinct authenticated real Kith accounts', () => {
    const trip = tripService.createTrip(creator, { name: 'Goa Trip' });
    tripService.joinTripByCode(rahulUser, trip.inviteCode);
    tripService.joinTripByCode(hardevUser, trip.inviteCode);

    const tripWithUsers = tripService.getTripById(trip.id, creator.id);
    const rahulM = tripWithUsers.members.find((m) => m.userId === rahulUser.id);
    const hardevM = tripWithUsers.members.find((m) => m.userId === hardevUser.id);

    assert.throws(
      () =>
        tripService.mergeMembers(trip.id, creator.id, {
          sourceMemberId: hardevM.id,
          canonicalMemberId: rahulM.id,
        }),
      /Cannot merge two distinct authenticated Kith accounts/
    );
  });

  await t.test('9. Rejects non-creator from managing, renaming, removing, or merging members', () => {
    const trip = tripService.createTrip(creator, { name: 'Goa Trip', initialFriendNames: ['Rahul'] });
    tripService.joinTripByCode(hardevUser, trip.inviteCode);

    const tripWithUsers = tripService.getTripById(trip.id, creator.id);
    const rahulM = tripWithUsers.members.find((m) => m.displayName === 'Rahul');
    const hardevM = tripWithUsers.members.find((m) => m.userId === hardevUser.id);

    // Hardev (regular member) attempts rename
    assert.throws(
      () => tripService.renameMember(trip.id, hardevUser.id, rahulM.id, 'Hacked Name'),
      /Only the trip creator can rename members/
    );

    // Hardev attempts remove
    assert.throws(
      () => tripService.removeMember(trip.id, hardevUser.id, rahulM.id),
      /Only the trip creator can remove members/
    );

    // Hardev attempts merge
    assert.throws(
      () =>
        tripService.mergeMembers(trip.id, hardevUser.id, {
          sourceMemberId: rahulM.id,
          canonicalMemberId: hardevM.id,
        }),
      /Only the trip creator can merge members/
    );
  });
});
