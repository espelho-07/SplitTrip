const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const { db } = require('../src/db/database');

describe('Google Play Production Compliance: Web Deletion & Reviewer Access Suite', () => {
  beforeEach(() => {
    db.clearAll();
  });

  test('1. Deletes account and all cloud data by user ID', () => {
    const guest = authService.createGuest({ displayName: 'DeleteMe' });
    const userId = guest.user.id;

    // Create associated personal data
    db.insert('personal_expenses', {
      id: 'pexp_test_1',
      userId,
      title: 'Coffee',
      amountPaise: 25000,
    });

    const res = authService.deleteAccount(userId);
    assert.equal(res.success, true);
    assert.equal(db.get('users', userId), null);
    assert.equal(db.find('personal_expenses', (e) => e.userId === userId).length, 0);
  });

  test('2. Deletes account by email via Web Deletion Portal handler', () => {
    const googleUser = authService.loginWithGoogle({
      email: 'user_delete@example.com',
      displayName: 'Web Delete User',
    });
    const userId = googleUser.user.id;

    db.insert('personal_expenses', {
      id: 'pexp_test_2',
      userId,
      title: 'Flight',
      amountPaise: 500000,
    });

    const res = authService.deleteAccountByEmailOrKey('user_delete@example.com');
    assert.equal(res.success, true);
    assert.equal(db.get('users', userId), null);
    assert.equal(db.find('personal_expenses', (e) => e.userId === userId).length, 0);
  });

  test('3. Deletes account by Recovery Key via Web Deletion Portal handler', () => {
    const guest = authService.createGuest({ displayName: 'KeyDelete' });
    const userId = guest.user.id;
    const recoveryKey = guest.user.recoveryKey;

    const res = authService.deleteAccountByEmailOrKey(recoveryKey);
    assert.equal(res.success, true);
    assert.equal(db.get('users', userId), null);
  });

  test('4. Logs in review.nirniq@gmail.com with auto-seeded rich Goa trip, expenses and budget', () => {
    const res = authService.loginReviewerAccount('review.nirniq@gmail.com');

    assert.ok(res.token, 'Token must be generated');
    assert.equal(res.user.email, 'review.nirniq@gmail.com');
    assert.equal(res.user.displayName, 'Google Play Reviewer');

    const reviewerId = res.user.id;

    // Verify seeded trip
    const memberships = db.find('trip_members', (m) => m.userId === reviewerId);
    assert.ok(memberships.length > 0, 'Reviewer must have seeded trip membership');

    const trip = db.get('trips', memberships[0].tripId);
    assert.ok(trip.name.includes('Goa'));

    // Verify seeded expenses
    const expenses = db.find('expenses', (e) => e.tripId === trip.id);
    assert.ok(expenses.length >= 2, 'Should have seeded trip expenses');

    // Verify seeded personal finance
    const personalExps = db.find('personal_expenses', (e) => e.userId === reviewerId);
    assert.ok(personalExps.length >= 2, 'Should have seeded personal expenses');

    const budget = db.findOne('personal_budgets', (b) => b.userId === reviewerId);
    assert.ok(budget, 'Should have seeded budget');
  });
});
