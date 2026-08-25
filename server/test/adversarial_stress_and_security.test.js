const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert');
const authService = require('../src/services/auth_service');
const personalService = require('../src/services/personal_service');
const tripService = require('../src/services/trip_service');
const expenseService = require('../src/services/expense_service');
const { db } = require('../src/db/database');

describe('Phase 19: Adversarial Concurrency, Stress & Security Tests', () => {
  beforeEach(() => {
    db.clearAll();
  });

  test('1. Concurrency Stress: 50 concurrent personal expense creations maintain exact total and order', async () => {
    const { user } = authService.createGuest({ displayName: 'Concurrent Tester' });

    const promises = [];
    for (let i = 0; i < 50; i++) {
      promises.push(
        Promise.resolve().then(() =>
          personalService.createPersonalExpense(user.id, {
            title: `Coffee #${i}`,
            amountInPaise: 15000, // ₹150 each
            category: 'food',
          })
        )
      );
    }

    const created = await Promise.all(promises);
    assert.strictEqual(created.length, 50);

    const result = personalService.getPersonalExpenses(user.id);
    assert.strictEqual(result.count, 50);
    assert.strictEqual(result.totalSpentInPaise, 50 * 15000); // 750,000 paise = ₹7,500
  });

  test('2. IDOR & Authorization Shield: Guest B cannot view or modify Guest A debts or budgets', () => {
    const { user: userA } = authService.createGuest({ displayName: 'User A' });
    const { user: userB } = authService.createGuest({ displayName: 'User B' });

    // User A creates a debt and budget
    const debtA = personalService.createPersonalDebt(userA.id, {
      personName: 'Rahul',
      debtType: 'lent',
      amountInPaise: 50000,
    });

    personalService.setBudget(userA.id, {
      monthYear: '2026-08',
      monthlyLimitInPaise: 1000000,
    });

    // User B attempts to access User A's debts -> should be empty
    const debtsB = personalService.getPersonalDebts(userB.id);
    assert.strictEqual(debtsB.debts.length, 0);

    // User B attempts to record a repayment on User A's debt -> must throw 403 Forbidden
    assert.throws(
      () => {
        personalService.recordDebtRepayment(userB.id, debtA.id, { amountInPaise: 20000 });
      },
      (err) => err.statusCode === 403
    );

    // User B attempts to delete User A's debt -> must throw 403 Forbidden
    assert.throws(
      () => {
        personalService.deletePersonalDebt(userB.id, debtA.id);
      },
      (err) => err.statusCode === 403
    );
  });

  test('3. Multi-Stage Lending & Repayment Settlement Boundary', () => {
    const { user } = authService.createGuest({ displayName: 'Lender' });

    // Lent ₹10,000 to Amit
    const debt = personalService.createPersonalDebt(user.id, {
      personName: 'Amit',
      debtType: 'lent',
      amountInPaise: 1000000,
    });
    assert.strictEqual(debt.isSettled, false);
    assert.strictEqual(debt.remainingAmountInPaise, 1000000);

    // Repayment 1: Amit returns ₹4,000
    const rep1 = personalService.recordDebtRepayment(user.id, debt.id, { amountInPaise: 400000 });
    assert.strictEqual(rep1.debt.remainingAmountInPaise, 600000);
    assert.strictEqual(rep1.debt.isSettled, false);

    // Repayment 2: Amit returns remaining ₹6,000 -> must settle
    const rep2 = personalService.recordDebtRepayment(user.id, debt.id, { amountInPaise: 600000 });
    assert.strictEqual(rep2.debt.remainingAmountInPaise, 0);
    assert.strictEqual(rep2.debt.isSettled, true);

    // Verify aggregate debt summary reflects zero outstanding lent money
    const summary = personalService.getPersonalDebts(user.id);
    assert.strictEqual(summary.totalLentPaise, 0);
    assert.strictEqual(summary.debts[0].isSettled, true);
  });

  test('4. Strict Financial Conservation: Rejects expenses with split amounts mismatch', () => {
    const { user } = authService.createGuest({ displayName: 'Trip Creator' });
    const trip = tripService.createTrip(user, {
      name: 'Shimla Trip',
      currencyCode: 'INR',
      initialFriendNames: ['Aarav', 'Neha'],
    });

    const members = tripService.getTripById(trip.id, user.id).members;
    assert.strictEqual(members.length, 3);

    // Attempting to add an expense of ₹300 with splits summing to ₹290 (10 paise leak)
    assert.throws(
      () => {
        expenseService.createExpense(user, trip.id, {
          title: 'Dinner',
          amountInPaise: 30000,
          paidById: members[0].id,
          splitType: 'equal',
          splits: [
            { memberId: members[0].id, amountInPaise: 9000 },
            { memberId: members[1].id, amountInPaise: 10000 },
            { memberId: members[2].id, amountInPaise: 10000 },
          ],
        });
      },
      (err) => err.statusCode === 400 && err.message.includes('Split sum mismatch')
    );
  });
});
