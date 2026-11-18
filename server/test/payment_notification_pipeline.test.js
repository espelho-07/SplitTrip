const test = require('node:test');
const assert = require('node:assert');
const { db } = require('../src/db/database');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const settlementService = require('../src/services/settlement_service');
const notificationService = require('../src/services/notification_service');

test('Payment Notification & Verification Pipeline Test Suite', async (t) => {
  db.clearAll();

  // Create Users: User A (Payer) and Hardev (Receiver)
  const userA = authService.createGuest({ displayName: 'User A' }).user;
  const hardevUser = authService.createGuest({ displayName: 'Hardev' }).user;

  // Create Trip with User A and Hardev
  const trip = tripService.createTrip(userA, {
    name: 'Goa Trip',
    currencyCode: 'INR',
    initialFriendNames: ['Hardev'],
  });

  const memberA = trip.members.find((m) => m.userId === userA.id);
  const unclaimedHardev = trip.members.find((m) => m.displayName === 'Hardev');

  // Hardev claims his trip member record via joinTripByCode
  const joinedTrip = tripService.joinTripByCode(hardevUser, trip.inviteCode, {
    claimMemberId: unclaimedHardev.id,
    claimToken: unclaimedHardev.claimToken,
  });
  const hardevMember = joinedTrip.members.find((m) => m.userId === hardevUser.id);

  // Hardev pays for a group expense of ₹600 (User A owes ₹300)
  expenseService.createExpense(hardevUser, trip.id, {
    title: 'Dinner at Fisherman\'s Wharf',
    amountInPaise: 60000,
    paidById: hardevMember.id,
    splits: [
      { memberId: hardevMember.id, amountInPaise: 30000 },
      { memberId: memberA.id, amountInPaise: 30000 },
    ],
  });

  await t.test('1. Payer marks ₹300 paid -> creates payment and database notification strictly for Hardev', () => {
    const { settlement } = settlementService.recordSettlement(userA, trip.id, {
      fromMemberId: memberA.id,
      toMemberId: hardevMember.id,
      amountInPaise: 30000,
      paymentReference: 'UPI/1234567890',
      status: 'marked_paid',
    });

    // Check payment record in database
    assert.strictEqual(settlement.status, 'marked_paid');
    assert.strictEqual(settlement.isSettled, false);
    assert.strictEqual(settlement.fromMemberId, memberA.id);
    assert.strictEqual(settlement.toMemberId, hardevMember.id);
    assert.strictEqual(settlement.amountInPaise, 30000);

    // Check notifications table: exactly ONE notification for Hardev, ZERO for User A
    const hardevNotifs = notificationService.getNotificationsForUser(hardevUser.id);
    assert.strictEqual(hardevNotifs.length, 1);
    assert.strictEqual(hardevNotifs[0].recipientUserId, hardevUser.id);
    assert.strictEqual(hardevNotifs[0].actorUserId, userA.id);
    assert.strictEqual(hardevNotifs[0].type, 'PAYMENT_CONFIRMATION_REQUIRED');
    assert.strictEqual(hardevNotifs[0].status, 'UNREAD');
    assert.strictEqual(hardevNotifs[0].isRead, false);
    assert.strictEqual(hardevNotifs[0].amountInPaise, 30000);
    assert.ok(hardevNotifs[0].body.includes('User A says they paid you ₹300'));

    const payerPaymentNotifs = notificationService.getNotificationsForUser(userA.id).filter((n) => n.type === 'PAYMENT_CONFIRMATION_REQUIRED');
    assert.strictEqual(payerPaymentNotifs.length, 0, 'Payer must NEVER receive receiver notification');
  });

  await t.test('2. GET pending settlements endpoint returns authoritative verification request for Hardev', () => {
    const pendingData = notificationService.getPendingSettlementsForUser(hardevUser.id);
    assert.strictEqual(pendingData.pending.length, 1);
    const item = pendingData.pending[0];
    assert.strictEqual(item.tripId, trip.id);
    assert.strictEqual(item.payerUserId, userA.id);
    assert.strictEqual(item.payerName, 'User A');
    assert.strictEqual(item.receiverUserId, hardevUser.id);
    assert.strictEqual(item.amountInPaise, 30000);
    assert.strictEqual(item.status, 'pending_verification');

    // Payer A has 0 pending receipts
    const payerPending = notificationService.getPendingSettlementsForUser(userA.id);
    assert.strictEqual(payerPending.pending.length, 0);
  });

  await t.test('3. Hardev confirms payment -> resolves notification and creates confirmation notice for Payer A', () => {
    const hardevNotifs = notificationService.getNotificationsForUser(hardevUser.id);
    const notifId = hardevNotifs[0].id;
    const settlementId = hardevNotifs[0].settlementId;

    settlementService.confirmSettlement(hardevUser, trip.id, settlementId);

    // Hardev\'s notification should now be RESOLVED
    const updatedHardevNotif = db.get('notifications', notifId);
    assert.strictEqual(updatedHardevNotif.status, 'RESOLVED');

    // Payer A should now have a PAYMENT_CONFIRMED notification
    const payerConfirmedNotifs = notificationService.getNotificationsForUser(userA.id).filter((n) => n.type === 'PAYMENT_CONFIRMED');
    assert.strictEqual(payerConfirmedNotifs.length, 1);
    assert.strictEqual(payerConfirmedNotifs[0].recipientUserId, userA.id);
    assert.strictEqual(payerConfirmedNotifs[0].type, 'PAYMENT_CONFIRMED');
    assert.ok(payerConfirmedNotifs[0].title.includes('Payment Confirmed'));
  });

  await t.test('4. Mark all notifications as read works idempotently', () => {
    const res = notificationService.markAllAsRead(userA.id);
    assert.strictEqual(res.success, true);
    const unread = notificationService.getUnreadCount(userA.id);
    assert.strictEqual(unread, 0);
  });
});
