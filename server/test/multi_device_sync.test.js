const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const personalService = require('../src/services/personal_service');
const { db } = require('../src/db/database');

describe('Phase 26 Production Core Multi-Device & Cloud Sync Suite', () => {
  beforeEach(() => {
    db.clearAll();
  });

  test('1. Multi-Device Google Authentication: Canonical Identity & Re-login', () => {
    // Phone 1 - User A
    const authA1 = authService.loginWithGoogle({
      email: 'user.a@kith.app',
      displayName: 'User A',
      googleId: 'g_user_a_001',
    });
    const userA_Id = authA1.user.id;
    assert.equal(authA1.user.email, 'user.a@kith.app');

    // Phone 2 - User B
    const authB1 = authService.loginWithGoogle({
      email: 'user.b@kith.app',
      displayName: 'User B',
      googleId: 'g_user_b_002',
    });
    const userB_Id = authB1.user.id;
    assert.notEqual(userA_Id, userB_Id, 'User A and User B must have distinct canonical identities');

    // User A logs out on Phone 1
    authService.logout(authA1.token);

    // User A logs back in on Phone 1 or Phone 3 with same Google Account
    const authA2 = authService.loginWithGoogle({
      email: 'user.a@kith.app',
      displayName: 'User A (Synced)',
      googleId: 'g_user_a_001',
    });
    assert.equal(authA2.user.id, userA_Id, 'Re-login must resolve to exact same canonical user ID');
  });

  test('2. Cross-Device Trip Creation, Joining, and Multiplayer Expense Sync', () => {
    // User A creates Trip on Device A
    const userA = authService.loginWithGoogle({
      email: 'creator.a@kith.app',
      displayName: 'Creator A',
      googleId: 'g_creator_a',
    });

    const userB = authService.loginWithGoogle({
      email: 'joiner.b@kith.app',
      displayName: 'Joiner B',
      googleId: 'g_joiner_b',
    });

    const trip = tripService.createTrip(userA.user, {
      name: 'Kith Production Test',
      currencyCode: 'INR',
    });
    assert.ok(trip.id);
    assert.ok(trip.inviteCode);

    // User B joins trip on Device B using invite code
    const joined = tripService.joinTripByCode(userB.user, trip.inviteCode);
    assert.equal(joined.id, trip.id);

    // Verify trip members
    const members = db.find('trip_members', (m) => m.tripId === trip.id);
    assert.equal(members.length, 2);
    const memberA = members.find((m) => m.userId === userA.user.id);
    const memberB = members.find((m) => m.userId === userB.user.id);
    assert.ok(memberA);
    assert.ok(memberB);

    // Device A adds ₹1000 expense (100000 paise) split equally
    const resA = expenseService.createExpense(userA.user, trip.id, {
      title: 'Airport Taxi',
      amountInPaise: 100000,
      paidById: memberA.id,
      splitType: 'equal',
      splits: [
        { memberId: memberA.id, amountInPaise: 50000 },
        { memberId: memberB.id, amountInPaise: 50000 },
      ],
    });
    assert.equal(resA.expense.amountInPaise, 100000);

    // Device B adds ₹500 expense (50000 paise) split equally
    const resB = expenseService.createExpense(userB.user, trip.id, {
      title: 'Lunch',
      amountInPaise: 50000,
      paidById: memberB.id,
      splitType: 'equal',
      splits: [
        { memberId: memberA.id, amountInPaise: 25000 },
        { memberId: memberB.id, amountInPaise: 25000 },
      ],
    });
    assert.equal(resB.expense.amountInPaise, 50000);

    // Verify balances on both devices
    const summary = expenseService.getBalanceSummary(trip.id, userA.user.id);
    const netA = summary.netBalancesInPaise[memberA.id];
    const netB = summary.netBalancesInPaise[memberB.id];

    // Member A paid 1000, owes 500+250=750 -> Net = +250
    // Member B paid 500, owes 500+250=750 -> Net = -250
    assert.equal(netA, 25000);
    assert.equal(netB, -25000);
    assert.equal(netA + netB, 0, 'Zero-sum conservation');
  });

  test('3. Personal Data Isolation: Zero Cross-User Leakage', () => {
    const userA = authService.loginWithGoogle({
      email: 'user.a.private@kith.app',
      displayName: 'User A Private',
      googleId: 'g_private_a',
    });

    const userB = authService.loginWithGoogle({
      email: 'user.b.private@kith.app',
      displayName: 'User B Private',
      googleId: 'g_private_b',
    });

    // User A creates personal expense ₹5000 (500000 paise)
    personalService.createPersonalExpense(userA.user.id, {
      title: 'User A Personal Gadget',
      amountInPaise: 500000,
      category: 'shopping',
    });

    // User B creates personal expense ₹9000 (900000 paise)
    personalService.createPersonalExpense(userB.user.id, {
      title: 'User B Rent Payment',
      amountInPaise: 900000,
      category: 'bills',
    });

    // User A fetches personal expenses -> sees only their ₹5000 expense
    const listA = personalService.getPersonalExpenses(userA.user.id);
    assert.equal(listA.expenses.length, 1);
    assert.equal(listA.expenses[0].title, 'User A Personal Gadget');
    assert.equal(listA.expenses[0].amountInPaise, 500000);

    // User B fetches personal expenses -> sees only their ₹9000 expense
    const listB = personalService.getPersonalExpenses(userB.user.id);
    assert.equal(listB.expenses.length, 1);
    assert.equal(listB.expenses[0].title, 'User B Rent Payment');
    assert.equal(listB.expenses[0].amountInPaise, 900000);
  });

  test('4. Multiple Trips Isolation: Private Trips are Invisible to Non-Members', () => {
    const userA = authService.loginWithGoogle({
      email: 'owner@kith.app',
      displayName: 'Trip Owner',
      googleId: 'g_owner',
    });

    const userB = authService.loginWithGoogle({
      email: 'guest@kith.app',
      displayName: 'Trip Guest',
      googleId: 'g_guest',
    });

    const tripA = tripService.createTrip(userA.user, { name: 'Trip A' });
    const tripB = tripService.createTrip(userA.user, { name: 'Trip B' });
    const tripC = tripService.createTrip(userA.user, { name: 'Trip C' });

    // User B only joins Trip A
    tripService.joinTripByCode(userB.user, tripA.inviteCode);

    // Verify User B only has 1 trip
    const userBTrips = tripService.getUserTrips(userB.user.id);
    assert.equal(userBTrips.length, 1);
    assert.equal(userBTrips[0].id, tripA.id);

    // User B tries to view Trip C -> Throws 403 Forbidden
    assert.throws(
      () => tripService.getTripById(tripC.id, userB.user.id),
      (err) => err.statusCode === 403
    );

    // User B joins Trip B
    tripService.joinTripByCode(userB.user, tripB.inviteCode);
    const userBTripsUpdated = tripService.getUserTrips(userB.user.id);
    assert.equal(userBTripsUpdated.length, 2);
  });

  test('5. Offline-to-Online Synchronization & Mutation Idempotency', () => {
    const user = authService.loginWithGoogle({
      email: 'offline.sync@kith.app',
      displayName: 'Sync Tester',
      googleId: 'g_sync',
    });

    const trip = tripService.createTrip(user.user, { name: 'Sync Trip' });
    const members = db.find('trip_members', (m) => m.tripId === trip.id);

    // Client generated deterministic clientMutationId
    const clientExpenseId = 'exp_offline_client_uuid_101';

    // First attempt (online replay)
    const res1 = expenseService.createExpense(user.user, trip.id, {
      id: clientExpenseId,
      title: 'Offline Fuel',
      amountInPaise: 150000,
      paidById: members[0].id,
      splitType: 'equal',
      splits: [{ memberId: members[0].id, amountInPaise: 150000 }],
    });
    assert.equal(res1.expense.id, clientExpenseId);

    // Second attempt (retry / duplicate sync packet)
    const res2 = expenseService.createExpense(user.user, trip.id, {
      id: clientExpenseId,
      title: 'Offline Fuel',
      amountInPaise: 150000,
      paidById: members[0].id,
      splitType: 'equal',
      splits: [{ memberId: members[0].id, amountInPaise: 150000 }],
    });
    assert.equal(res2.expense.id, clientExpenseId);

    // Check database has exactly 1 expense record
    const allExpenses = expenseService.getExpenses(trip.id, user.user.id);
    assert.equal(allExpenses.length, 1, 'Idempotency must prevent duplicate records');
  });
});
