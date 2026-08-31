const test = require('node:test');
const assert = require('node:assert');
const { db } = require('../src/db/database');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const notificationService = require('../src/services/notification_service');

test('Trip Activity Notification & Push Pipeline Test Suite', async (t) => {
  db.clearAll();

  // Create Users: Alice (Creator), Bob (Joiner), Charlie (Third member)
  const alice = authService.createGuest({ displayName: 'Alice' }).user;
  const bob = authService.createGuest({ displayName: 'Bob' }).user;
  const charlie = authService.createGuest({ displayName: 'Charlie' }).user;

  // Simulate FCM token registrations for Bob and Charlie
  db.insert('user_fcm_tokens', {
    id: 'tok_bob_1',
    userId: bob.id,
    token: 'fcm_token_bob_device_1',
    deviceId: 'dev_bob_android',
    platform: 'android',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    deleted: false,
  });

  db.insert('user_fcm_tokens', {
    id: 'tok_alice_1',
    userId: alice.id,
    token: 'fcm_token_alice_device_1',
    deviceId: 'dev_alice_android',
    platform: 'android',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    deleted: false,
  });

  // Create Trip
  const trip = tripService.createTrip(alice, {
    name: 'Kasol Trip',
    currencyCode: 'INR',
  });

  await t.test('1. Bob joins Kasol Trip -> Dispatches notification to Alice, NOT Bob', async () => {
    tripService.joinTripByCode(bob, trip.inviteCode);

    const aliceNotifs = notificationService.getNotificationsForUser(alice.id);
    const bobNotifs = notificationService.getNotificationsForUser(bob.id);

    assert.strictEqual(aliceNotifs.length, 1);
    assert.strictEqual(aliceNotifs[0].type, 'MEMBER_JOINED');
    assert.ok(aliceNotifs[0].body.includes('Bob joined'));
    assert.strictEqual(bobNotifs.length, 0); // Self should not be notified
  });

  await t.test('2. Charlie joins -> Dispatches notification to Alice and Bob, NOT Charlie', async () => {
    tripService.joinTripByCode(charlie, trip.inviteCode);

    const aliceNotifs = notificationService.getNotificationsForUser(alice.id);
    const bobNotifs = notificationService.getNotificationsForUser(bob.id);
    const charlieNotifs = notificationService.getNotificationsForUser(charlie.id);

    // Alice should now have 2 notifications
    assert.strictEqual(aliceNotifs.length, 2);
    // Bob should have 1 notification for Charlie joining
    assert.strictEqual(bobNotifs.length, 1);
    assert.strictEqual(bobNotifs[0].type, 'MEMBER_JOINED');
    assert.ok(bobNotifs[0].body.includes('Charlie joined'));
    // Charlie should have 0
    assert.strictEqual(charlieNotifs.length, 0);
  });

  await t.test('3. Alice completes trip -> Dispatches TRIP_COMPLETED notification to Bob and Charlie', async () => {
    tripService.completeTrip(trip.id, alice.id);

    const bobNotifs = notificationService.getNotificationsForUser(bob.id);
    const charlieNotifs = notificationService.getNotificationsForUser(charlie.id);

    const bobCompletion = bobNotifs.find((n) => n.type === 'TRIP_COMPLETED');
    const charlieCompletion = charlieNotifs.find((n) => n.type === 'TRIP_COMPLETED');

    assert.ok(bobCompletion, 'Bob must receive TRIP_COMPLETED notification');
    assert.ok(charlieCompletion, 'Charlie must receive TRIP_COMPLETED notification');
    assert.ok(bobCompletion.body.includes('Kasol Trip'));
  });
});
