const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const personalService = require('../src/services/personal_service');
const { db } = require('../src/db/database');

describe('Auth UX + Recovery Key + Identity Continuity Test Suite', () => {
  beforeEach(() => {
    db.clearAll();
  });

  test('1. Google First Login: Creates canonical user with stable googleId', () => {
    const res = authService.loginWithGoogle({
      email: 'alex@example.com',
      displayName: 'Alex Traveler',
      googleId: 'google_sub_1001',
    });

    assert.ok(res.user.id.startsWith('usr_'));
    assert.equal(res.user.email, 'alex@example.com');
    assert.equal(res.user.displayName, 'Alex Traveler');
    assert.equal(res.user.isGuest, false);
    assert.ok(res.token.startsWith('kith_sess_'));
  });

  test('2. Same Google Account Login Again: Resolves to EXACT SAME canonical User ID', () => {
    const res1 = authService.loginWithGoogle({
      email: 'alex@example.com',
      displayName: 'Alex Traveler',
      googleId: 'google_sub_1001',
    });

    const res2 = authService.loginWithGoogle({
      email: 'alex@example.com',
      displayName: 'Alex T. (Updated)',
      googleId: 'google_sub_1001',
    });

    assert.equal(res1.user.id, res2.user.id, 'User ID must remain identical across logins');
    assert.equal(res2.user.displayName, 'Alex T. (Updated)');
    assert.equal(db.find('users', () => true).length, 1, 'Never create duplicate user accounts');
  });

  test('3. Google Login After Logout: Creates new session for same canonical user', () => {
    const res1 = authService.loginWithGoogle({
      email: 'alex@example.com',
      displayName: 'Alex Traveler',
      googleId: 'google_sub_1001',
    });

    // Invalidate session
    authService.logout(res1.token);
    assert.equal(db.findOne('sessions', (s) => s.token === res1.token), null);

    // Re-login
    const res2 = authService.loginWithGoogle({
      email: 'alex@example.com',
      displayName: 'Alex Traveler',
      googleId: 'google_sub_1001',
    });

    assert.equal(res1.user.id, res2.user.id);
    assert.notEqual(res1.token, res2.token);
    assert.ok(db.findOne('sessions', (s) => s.token === res2.token));
  });

  test('4. Recovery Key Login & Restoration: Restores original user ID and data', () => {
    const guest = authService.createGuest({ displayName: 'Sam Guest' });
    const recoveryKey = guest.user.recoveryKey;
    assert.ok(recoveryKey.startsWith('KITH-'));

    // Create some personal data for Sam
    personalService.createPersonalExpense(guest.user.id, {
      title: 'Coffee',
      amountInPaise: 25000,
      category: 'food',
    });

    // Recover on another device using recovery key
    const recovered = authService.recoverGuest({ recoveryKey });
    assert.equal(recovered.user.id, guest.user.id);
    assert.equal(recovered.user.displayName, 'Sam Guest');

    // Verify personal data is preserved
    const res = personalService.getPersonalExpenses(recovered.user.id);
    assert.equal(res.expenses.length, 1);
    assert.equal(res.expenses[0].title, 'Coffee');
    assert.equal(res.expenses[0].amountInPaise, 25000);
  });

  test('5. Google Linking to Existing Guest/Recovery-Key User with Data Preservation', () => {
    // 1. Guest creates trips & personal expenses
    const guest = authService.createGuest({ displayName: 'Charlie' });
    const trip = tripService.createTrip(guest.user, { name: 'Ladakh Trip' });
    personalService.createPersonalExpense(guest.user.id, { title: 'Gloves', amountInPaise: 40000 });

    // 2. Guest links with Google
    const linked = authService.loginWithGoogle({
      email: 'charlie@gmail.com',
      displayName: 'Charlie G.',
      googleId: 'google_charlie_555',
      currentGuestUserId: guest.user.id,
    });

    // 3. User ID should be preserved (upgraded in place)
    assert.equal(linked.user.id, guest.user.id);
    assert.equal(linked.user.email, 'charlie@gmail.com');
    assert.equal(linked.user.isGuest, false);

    // 4. Data must remain intact
    const trips = tripService.getUserTrips(linked.user.id);
    assert.equal(trips.length, 1);
    assert.equal(trips[0].name, 'Ladakh Trip');

    const res = personalService.getPersonalExpenses(linked.user.id);
    assert.equal(res.expenses.length, 1);
    assert.equal(res.expenses[0].title, 'Gloves');
  });

  test('6. Google Linking when Canonical User Already Existed (Guest Migration)', () => {
    // 1. Pre-existing Google account
    const existingGoogle = authService.loginWithGoogle({
      email: 'maya@gmail.com',
      displayName: 'Maya Google',
      googleId: 'google_maya_999',
    });

    // 2. Offline guest session creates a trip
    const guest = authService.createGuest({ displayName: 'Maya Offline' });
    tripService.createTrip(guest.user, { name: 'Offline Paris Trip' });
    personalService.createPersonalExpense(guest.user.id, { title: 'Croissant', amountInPaise: 15000 });

    // 3. Guest logs into Google -> Migrates guest data to canonical account
    const res = authService.loginWithGoogle({
      email: 'maya@gmail.com',
      displayName: 'Maya Google',
      googleId: 'google_maya_999',
      currentGuestUserId: guest.user.id,
    });

    assert.equal(res.user.id, existingGoogle.user.id);

    // Verify Paris trip and Croissant expense migrated to canonical Maya
    const trips = tripService.getUserTrips(res.user.id);
    assert.equal(trips.length, 1);
    assert.equal(trips[0].name, 'Offline Paris Trip');

    const personalExp = personalService.getPersonalExpenses(res.user.id);
    assert.equal(personalExp.expenses.length, 1);
    assert.equal(personalExp.expenses[0].title, 'Croissant');
  });

  test('7. Invalid Recovery Key & Invalid Google Identity Handling', () => {
    assert.throws(() => {
      authService.recoverGuest({ recoveryKey: 'KITH-INVALID-KEY9' });
    }, /Invalid recovery key/);

    assert.throws(() => {
      authService.loginWithGoogle({ email: 'not-an-email' });
    }, /valid Google email/);
  });

  test('8. Cross-User Data Isolation: User A cannot access User B data', () => {
    const userA = authService.loginWithGoogle({
      email: 'userA@kith.app',
      displayName: 'User A',
      googleId: 'g_user_A',
    });
    const userB = authService.loginWithGoogle({
      email: 'userB@kith.app',
      displayName: 'User B',
      googleId: 'g_user_B',
    });

    personalService.createPersonalExpense(userA.user.id, { title: 'Secret A', amountInPaise: 10000 });
    personalService.createPersonalExpense(userB.user.id, { title: 'Secret B', amountInPaise: 20000 });

    const expensesA = personalService.getPersonalExpenses(userA.user.id);
    assert.equal(expensesA.expenses.length, 1);
    assert.equal(expensesA.expenses[0].title, 'Secret A');

    const expensesB = personalService.getPersonalExpenses(userB.user.id);
    assert.equal(expensesB.expenses.length, 1);
    assert.equal(expensesB.expenses[0].title, 'Secret B');
  });
});
