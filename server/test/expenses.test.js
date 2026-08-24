const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../src/services/auth_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const { db } = require('../src/db/database');

describe('Expense Service Tests', () => {
  let userA, userB, trip;

  beforeEach(() => {
    db.clearAll();
    userA = authService.createGuest({ displayName: 'Alice' }).user;
    userB = authService.createGuest({ displayName: 'Bob' }).user;
    trip = tripService.createTrip(userA, { name: 'Weekend Trip' });
    trip = tripService.joinTripByCode(userB, trip.inviteCode);
  });

  test('Creates expense and strictly enforces split sum equals total paise', () => {
    const memberA = trip.members.find((m) => m.userId === userA.id);
    const memberB = trip.members.find((m) => m.userId === userB.id);

    // Total: ₹100.00 (10000 paise) split equally 5000 / 5000
    const result = expenseService.createExpense(userA, trip.id, {
      title: 'Dinner',
      amountInPaise: 10000,
      category: 'food',
      paidById: memberA.id,
      splitType: 'equal',
      splits: [
        { memberId: memberA.id, amountInPaise: 5000 },
        { memberId: memberB.id, amountInPaise: 5000 },
      ],
    });

    assert.equal(result.expense.amountInPaise, 10000);
    assert.equal(result.balanceSummary.totalTripSpendingInPaise, 10000);
    assert.equal(result.balanceSummary.netBalancesInPaise[memberA.id], 5000); // Alice paid 10000, owes 5000 -> +5000
    assert.equal(result.balanceSummary.netBalancesInPaise[memberB.id], -5000); // Bob paid 0, owes 5000 -> -5000
  });

  test('Rejects expense with split mismatch (Server-Side Financial Integrity)', () => {
    const memberA = trip.members.find((m) => m.userId === userA.id);
    const memberB = trip.members.find((m) => m.userId === userB.id);

    // Total: ₹100.00 (10000 paise) but splits sum to 9999 paise
    assert.throws(
      () =>
        expenseService.createExpense(userA, trip.id, {
          title: 'Mismatch Expense',
          amountInPaise: 10000,
          category: 'general',
          paidById: memberA.id,
          splitType: 'equal',
          splits: [
            { memberId: memberA.id, amountInPaise: 5000 },
            { memberId: memberB.id, amountInPaise: 4999 },
          ],
        }),
      (err) => err.statusCode === 400 && err.message.includes('Split sum mismatch')
    );
  });

  test('Rejects adding expense to a completed or settled trip', () => {
    const memberA = trip.members.find((m) => m.userId === userA.id);
    const memberB = trip.members.find((m) => m.userId === userB.id);

    // Creator completes trip
    tripService.updateLifecycle(trip.id, userA.id, 'completed');

    assert.throws(
      () =>
        expenseService.createExpense(userA, trip.id, {
          title: 'Post-completion Expense',
          amountInPaise: 2000,
          paidById: memberA.id,
          splits: [{ memberId: memberA.id, amountInPaise: 2000 }],
        }),
      (err) => err.statusCode === 400 && err.message.includes('completed')
    );
  });
});
