const test = require('node:test');
const assert = require('node:assert');
const { db } = require('../src/db/database');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const notificationService = require('../src/services/notification_service');

test('Expense Activity Notification Pipeline Test Suite', async (t) => {
  db.clearAll();

  // Create Users: Hardev (Actor), Member A, Member B, and Unrelated User C
  const hardevUser = authService.createGuest({ displayName: 'Hardev' }).user;
  const userA = authService.createGuest({ displayName: 'FriengA' }).user;
  const userB = authService.createGuest({ displayName: 'Friend B' }).user;
  const userC = authService.createGuest({ displayName: 'User C (Trip B)' }).user;

  // Create Trip A with Hardev, Member A, Member B
  const tripA = tripService.createTrip(hardevUser, {
    name: 'Goa Trip',
    currencyCode: 'INR',
    initialFriendNames: ['Friend A', 'Friend B', 'Placeholder Friend'],
  });

  const unclaimedA = tripA.members.find((m) => m.displayName === 'Friend A');
  const unclaimedB = tripA.members.find((m) => m.displayName === 'Friend B');

  // Claim memberships for real users
  const joinedA = tripService.joinTripByCode(userA, tripA.inviteCode, { claimMemberId: unclaimedA.id, claimToken: unclaimedA.claimToken });
  const joinedB = tripService.joinTripByCode(userB, tripA.inviteCode, { claimMemberId: unclaimedB.id, claimToken: unclaimedB.claimToken });

  const hardevMember = tripA.members.find((m) => m.userId === hardevUser.id);
  const memberA = joinedA.members.find((m) => m.userId === userA.id);
  const memberB = joinedB.members.find((m) => m.userId === userB.id);

  // Create an unrelated Trip B for User C
  const tripB = tripService.createTrip(userC, {
    name: 'Manali Trip',
    currencyCode: 'INR',
  });

  let createdExpenseId = null;

  await t.test('1. Hardev adds ₹2,400 Dinner -> notifies Member A & Member B, ZERO for Hardev or User C', async () => {
    const { expense } = expenseService.createExpense(hardevUser, tripA.id, {
      title: 'Dinner at Fishermans Wharf',
      amountInPaise: 240000,
      paidById: hardevMember.id,
      splits: [
        { memberId: hardevMember.id, amountInPaise: 80000 },
        { memberId: memberA.id, amountInPaise: 80000 },
        { memberId: memberB.id, amountInPaise: 80000 },
      ],
    });

    createdExpenseId = expense.id;
    assert.ok(createdExpenseId);

    // Member A should have 1 expense notification
    const notifsA = notificationService.getNotificationsForUser(userA.id);
    const expNotifsA = notifsA.filter(n => n.type.startsWith('EXPENSE_'));
    assert.strictEqual(expNotifsA.length, 1);
    assert.strictEqual(expNotifsA[0].type, 'EXPENSE_CREATED');
    assert.strictEqual(expNotifsA[0].actorUserId, hardevUser.id);
    assert.strictEqual(expNotifsA[0].tripId, tripA.id);
    assert.strictEqual(expNotifsA[0].expenseId, expense.id);
    assert.strictEqual(expNotifsA[0].amountInPaise, 240000);
    assert.ok(expNotifsA[0].body.includes('Hardev added') && expNotifsA[0].body.includes('Goa Trip'));
    assert.strictEqual(expNotifsA[0].route, '/trip/' + tripA.id + '?expenseId=' + expense.id);

    // Member B should also have 1 expense notification
    const notifsB = notificationService.getNotificationsForUser(userB.id);
    const expNotifsB = notifsB.filter(n => n.type.startsWith('EXPENSE_'));
    assert.strictEqual(expNotifsB.length, 1);
    assert.strictEqual(expNotifsB[0].type, 'EXPENSE_CREATED');
    assert.strictEqual(expNotifsB[0].expenseId, expense.id);

    // Hardev (creator/actor) should have 0 expense notifications (No self-notification rule)
    const notifsHardev = notificationService.getNotificationsForUser(hardevUser.id);
    const expNotifsHardev = notifsHardev.filter(n => n.type.startsWith('EXPENSE_'));
    assert.strictEqual(expNotifsHardev.length, 0);

    // User C in Trip B should receive 0 notifications (Security & Trip Isolation)
    const notifsC = notificationService.getNotificationsForUser(userC.id);
    assert.strictEqual(notifsC.length, 0);
  });

  await t.test('2. Idempotent sync retry: creating same expense ID does not generate duplicate notification', async () => {
    // Retry creation with same expense ID
    expenseService.createExpense(hardevUser, tripA.id, {
      id: createdExpenseId,
      title: 'Dinner at Fishermans Wharf',
      amountInPaise: 240000,
      paidById: hardevMember.id,
      splits: [
        { memberId: hardevMember.id, amountInPaise: 80000 },
        { memberId: memberA.id, amountInPaise: 80000 },
        { memberId: memberB.id, amountInPaise: 80000 },
      ],
    });

    // Member A should STILL only have 1 expense notification total
    const notifsA = notificationService.getNotificationsForUser(userA.id);
    const expNotifsA = notifsA.filter(n => n.type.startsWith('EXPENSE_'));
    assert.strictEqual(expNotifsA.length, 1);
  });

  await t.test('3. Hardev edits Dinner: Rs 2,400 -> Rs 2,800 -> dispatches EXPENSE_UPDATED notice to members', async () => {
    expenseService.updateExpense(hardevUser, tripA.id, createdExpenseId, {
      title: 'Dinner at Fishermans Wharf',
      amountInPaise: 280000,
      paidById: hardevMember.id,
      splits: [
        { memberId: hardevMember.id, amountInPaise: 100000 },
        { memberId: memberA.id, amountInPaise: 90000 },
        { memberId: memberB.id, amountInPaise: 90000 },
      ],
    });

    const notifsA = notificationService.getNotificationsForUser(userA.id);
    const expNotifsA = notifsA.filter(n => n.type.startsWith('EXPENSE_'));
    assert.strictEqual(expNotifsA.length, 2);
    const updateNotif = expNotifsA[0]; // Newest first
    assert.strictEqual(updateNotif.type, 'EXPENSE_UPDATED');
    assert.strictEqual(updateNotif.amountInPaise, 280000);
    assert.ok(updateNotif.body.includes('Hardev updated Dinner at Fishermans Wharf from ₹2,400 to ₹2,800.'));
    assert.strictEqual(updateNotif.route, '/trip/' + tripA.id + '?expenseId=' + createdExpenseId);
  });

  await t.test('4. Hardev deletes Dinner -> dispatches EXPENSE_DELETED notice with trip overview route', async () => {
    expenseService.deleteExpense(tripA.id, createdExpenseId, hardevUser);

    const notifsA = notificationService.getNotificationsForUser(userA.id);
    const expNotifsA = notifsA.filter(n => n.type.startsWith('EXPENSE_'));
    assert.strictEqual(expNotifsA.length, 3);
    const deleteNotif = expNotifsA[0];
    assert.strictEqual(deleteNotif.type, 'EXPENSE_DELETED');
    assert.strictEqual(deleteNotif.route, '/trip/' + tripA.id); // Not broken expense detail
  });
});
